SWIFT_SDK    ?= swift-6.3.2-RELEASE_wasm-embedded
SWIFT        := swift
BUILD_OUTPUT := .build/plugins/PackageToJS/outputs/Package
WEB_PACKAGE  := web/Package

.PHONY: all clean serve

all:
	@echo "▶ Building Swift WASM…"
	$(SWIFT) package \
	    --swift-sdk $(SWIFT_SDK) \
	    js --product JunkbotWASM -c release
	@echo "▶ Copying package output to web/Package/…"
	rm -rf $(WEB_PACKAGE)
	cp -r $(BUILD_OUTPUT) $(WEB_PACKAGE)
	@echo "✓ Done."

clean:
	rm -rf node_modules .build $(WEB_PACKAGE)

serve:
	@echo "▶ Open http://localhost:8080/"
	python3 -m http.server 8080
