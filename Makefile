# Junkbot — Swift Embedded WASM build
#
# Prerequisites:
#   - Swift 5.9+ with Embedded + Extern experimental features
#   - wasm-ld on PATH (ships with the Swift toolchain under ~/.swiftly/bin/)
#   - Optionally: wasm-opt (binaryen) for smaller output
#
# Build:  make
# Serve:  make serve

SWIFTC    := swiftc
WASM_LD   := wasm-ld
SOURCES   := $(wildcard Sources/Junkbot/*.swift)
OBJ       := /tmp/junkbot.o
OUTPUT    := web/junkbot.wasm

SWIFTFLAGS := \
    -enable-experimental-feature Embedded \
    -enable-experimental-feature Extern \
    -target wasm32-unknown-none-wasm \
    -wmo \
    -Osize \
    -disable-reflection-metadata \
    -parse-as-library

LDFLAGS := \
    --no-entry \
    --export-dynamic \
    --allow-undefined \
    --import-memory

.PHONY: all clean serve check

all: $(OUTPUT)

$(OBJ): $(SOURCES)
	@echo "▶ Compiling Swift → WASM object…"
	$(SWIFTC) $(SWIFTFLAGS) -emit-object -o $(OBJ) $(SOURCES)
	@echo "✓ Compiled"

$(OUTPUT): $(OBJ)
	@echo "▶ Linking…"
	$(WASM_LD) $(LDFLAGS) -o $(OUTPUT) $(OBJ)
	@echo "✓ $(OUTPUT) ($$(wc -c < $(OUTPUT)) bytes)"
ifdef HAS_WASM_OPT
	wasm-opt -Oz --strip-debug -o $(OUTPUT) $(OUTPUT)
	@echo "✓ Optimized with wasm-opt"
endif

# Type-check only (fast, no codegen, uses host target)
check:
	@echo "▶ Type-checking…"
	$(SWIFTC) -typecheck \
	    -enable-experimental-feature Embedded \
	    -enable-experimental-feature Extern \
	    -wmo \
	    $(SOURCES)

clean:
	rm -f $(OBJ) $(OUTPUT)

# Local HTTP server at project root
serve:
	@echo "▶ Open http://localhost:8080/web/"
	python3 -m http.server 8080
