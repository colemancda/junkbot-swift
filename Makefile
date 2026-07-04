.PHONY: all clean serve codegen linux

# Web (WASM) build - delegates to ports/Web, whose own Makefile does the actual
# `swift package ... js --product JunkbotWASM` build and copies the result to web/Package/
# (relative to repo root) so index.html's `./web/Package/index.js` import keeps working
# unchanged. Kept as `make all`/`make serve` here so existing muscle memory and
# .claude/launch.json's dev-server configs don't need to change.
all:
	$(MAKE) -C ports/Web all

serve:
	$(MAKE) -C ports/Web serve

clean:
	$(MAKE) -C ports/Web clean

codegen:
	python3 tools/generate_render_tables.py

# Linux (SDL3/Portmaster) build - delegates to ports/Linux.
linux:
	$(MAKE) -C ports/Linux build
