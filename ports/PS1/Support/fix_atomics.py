#!/usr/bin/env python3
"""Rewrites atomic RMW/cmpxchg/atomic-load/atomic-store IR into plain
non-atomic equivalents -- see KNOWN_ISSUES.md.

Swift's IRGen emits real `atomicrmw`/`cmpxchg` for refcounting (retain/
release) and copy-on-write uniqueness checks throughout the compiled module
-- not just in the few weak_odr runtime entry points (`swift_retain`,
`swift_once`, etc.) that `-assume-single-threaded`/manual C overrides can
shadow at link time. Dozens of *other* functions (Array/Dictionary growth,
GameEngine's own methods) have these inlined directly, with no exported
symbol to override. LLVM's Mips backend lowers `atomicrmw`/`cmpxchg` to
`ll`/`sc` (Load-Linked/Store-Conditional) regardless of `-mcpu=mips1` --
those instructions don't exist on the PS1's R3000A (MIPS-I only), and on
this target `sc` never reports success, so the retry loop spins forever (or,
per KNOWN_ISSUES.md, sometimes traps as a Reserved Instruction exception
instead once other, unrelated bugs are fixed and different code paths
execute).

This target only ever runs one thread, so real atomicity buys nothing --
this script mechanically rewrites the IR text (before `llc` lowers it) into
the equivalent plain load/op/store sequence, uniformly, for every such site
in the module at once (rather than patching each affected Swift function
individually, or maintaining an ever-growing list of C overrides).
"""

import re
import sys

# The pointer operand can be a simple `%name`/`@global` OR a parenthesized
# constant expression (e.g. `getelementptr inbounds nuw (i8, ptr @X, i32
# 4)`), which itself contains internal `, i32 N` sequences -- so this can't
# anchor the pointer capture to a simple `%\S+`. Instead it greedily captures
# everything up to the LAST `, i32 <value> <ordering>` at the end of the
# line (backtracking past any internal commas inside a constant expression).
_ORDERING = r"(?:monotonic|acquire|release|acq_rel|seq_cst)"
ATOMICRMW_RE = re.compile(
    r"^(\s*)(%\S+) = atomicrmw (\w+) ptr (.+), i32 (\S+) " + _ORDERING + r"(?:, align (\d+))?\s*$"
)
CMPXCHG_RE = re.compile(
    r"^(\s*)(%\S+) = cmpxchg (?:weak )?ptr (.+), i32 (\S+), i32 (\S+) "
    + _ORDERING + r" " + _ORDERING + r"(?:, align (\d+))?\s*$"
)
LOAD_ATOMIC_RE = re.compile(
    r"= load atomic i32, ptr (%\S+) \w+, align (\d+)"
)
STORE_ATOMIC_RE = re.compile(
    r"store atomic i32 (\S+), ptr (%\S+) \w+, align (\d+)"
)


_counter = [0]


def _fresh(tag: str) -> str:
    # LLVM's numeric SSA names (e.g. `%39`) can't be suffixed with text --
    # `%39.atomicfix` parses as the numeric id `39` followed by a stray
    # `.atomicfix` token, a syntax error. Fresh temp names must never start
    # with a digit, regardless of what the original destination was named,
    # so this never reuses/extends the original name at all.
    _counter[0] += 1
    return f"%__atomicfix.{tag}.{_counter[0]}"


def fix_line(line: str) -> list[str]:
    m = ATOMICRMW_RE.match(line)
    if m:
        indent, name, op, ptr, operand, align = m.groups()
        align = align or "4"
        new_name = _fresh("new")
        return [
            f"{indent}{name} = load i32, ptr {ptr}, align {align}\n",
            f"{indent}{new_name} = {op} i32 {name}, {operand}\n",
            f"{indent}store i32 {new_name}, ptr {ptr}, align {align}\n",
        ]

    m = CMPXCHG_RE.match(line)
    if m:
        indent, name, ptr, cmp_val, new_val, align = m.groups()
        align = align or "4"
        old = _fresh("old")
        succ = _fresh("succ")
        store_val = _fresh("store")
        tmp = _fresh("tmp")
        return [
            f"{indent}{old} = load i32, ptr {ptr}, align {align}\n",
            f"{indent}{succ} = icmp eq i32 {old}, {cmp_val}\n",
            f"{indent}{store_val} = select i1 {succ}, i32 {new_val}, i32 {old}\n",
            f"{indent}store i32 {store_val}, ptr {ptr}, align {align}\n",
            f"{indent}{tmp} = insertvalue {{ i32, i1 }} undef, i32 {old}, 0\n",
            f"{indent}{name} = insertvalue {{ i32, i1 }} {tmp}, i1 {succ}, 1\n",
        ]

    line = LOAD_ATOMIC_RE.sub(r"= load i32, ptr \1, align \2", line)
    line = STORE_ATOMIC_RE.sub(r"store i32 \1, ptr \2, align \3", line)
    return [line]


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: fix_atomics.py <in.ll> <out.ll>", file=sys.stderr)
        sys.exit(1)
    src, dst = sys.argv[1], sys.argv[2]
    atomicrmw_count = 0
    cmpxchg_count = 0
    out_lines = []
    with open(src) as f:
        for line in f:
            if ATOMICRMW_RE.match(line):
                atomicrmw_count += 1
            elif CMPXCHG_RE.match(line):
                cmpxchg_count += 1
            out_lines.extend(fix_line(line))
    with open(dst, "w") as f:
        f.writelines(out_lines)
    print(f"fix_atomics: rewrote {atomicrmw_count} atomicrmw, {cmpxchg_count} cmpxchg instructions")


if __name__ == "__main__":
    main()
