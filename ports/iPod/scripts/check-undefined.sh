#!/bin/sh
# Audit the undefined symbols of the Embedded Swift object against the
# allowlist that rockbox_shim.c + libgcc satisfy. Catching a new stdlib
# dependency here beats a cryptic GNU ld error deep in the Rockbox build.
#
# usage: check-undefined.sh <object-or-archive> [nm-tool]
set -e

OBJ="${1:?usage: check-undefined.sh <object> [nm]}"
NM="${2:-nm}"

# __aeabi_*      soft-float + EABI mem helpers (libgcc / rockbox_shim.c)
# __atomic_*     non-atomic stubs in rockbox_shim.c (single-threaded plugin)
# __clzsi2       libgcc
# mem*/free/posix_memalign/malloc/calloc  allocator + mem in rockbox_shim.c
# __stack_chk_*  rockbox_shim.c
# floor/ceil/round(+f) sinf/cosf/fmodf  rockbox_shim.c libm gap-fillers
# rb_audio_*/rb_puts   the C-side hooks Swift calls
ALLOW='^(__aeabi_|__atomic_|__stack_chk_|__clzsi2$|__ctzsi2$|posix_memalign$|free$|malloc$|calloc$|realloc$|memcpy$|memmove$|memset$|memcmp$|bzero$|floor$|ceil$|round$|floorf$|ceilf$|roundf$|sinf$|cosf$|fmodf$|putchar$|arc4random_buf$|rb_audio_|rb_puts$|junkbot_shim_init$)'

BAD=$("$NM" -u "$OBJ" | awk '{print $NF}' | grep -Ev "$ALLOW" || true)

if [ -n "$BAD" ]; then
    echo "error: libjunkbot has undefined symbols outside the shim allowlist:" >&2
    echo "$BAD" | sed 's/^/    /' >&2
    echo "add an implementation to rockbox_shim.c (and this allowlist) or" >&2
    echo "avoid the Swift construct pulling it in." >&2
    exit 1
fi
echo "undefined-symbol audit: OK"
