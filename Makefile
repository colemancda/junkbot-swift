SWIFT_SDK    ?= swift-DEVELOPMENT-SNAPSHOT-2026-06-24-a_wasm-embedded
SWIFT        := $(HOME)/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-06-24-a.xctoolchain/usr/bin/swift
BUILD_OUTPUT := .build/plugins/PackageToJS/outputs/Package
WEB_PACKAGE  := web/Package

.PHONY: all clean serve

all:
	@echo "▶ Building Swift Embedded WASM…"
	$(SWIFT) package --build-system native \
	    --swift-sdk $(SWIFT_SDK) \
	    js -c release
	@echo "▶ Copying package output to web/Package/…"
	rm -rf $(WEB_PACKAGE)
	cp -r $(BUILD_OUTPUT) $(WEB_PACKAGE)
	@echo "✓ Done."

clean:
	rm -rf node_modules .build $(WEB_PACKAGE)

serve:
	@echo "▶ Open http://localhost:8080/"
	python3 -m http.server 8080
