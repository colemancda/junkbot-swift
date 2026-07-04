REPO_ROOT    := ../..
PACKAGE_DIR  := .build-package/junkbot
BINARY_NAME  := junkbot

.PHONY: build package clean

build:
	swift build --product JunkbotSDL3 -c release

# Assembles a PortMaster-shaped port folder at .build-package/junkbot/ following
# portmaster.games/packaging.html: outer folder has port.json/README.md/gameinfo.xml/the
# launcher .sh; the inner junkbot/ folder has the binary, bundled assets, controller mapping,
# and licenses/. NOTE: this only packages a binary built for the CURRENT host architecture
# (this is a dev machine, not a cross-compilation setup) - for a real aarch64/x86_64 Linux
# release, build on/for the target arch first, then re-run this with BINARY that arch's build.
package: build
	@echo "▶ Assembling PortMaster port folder…"
	rm -rf $(PACKAGE_DIR)
	mkdir -p $(PACKAGE_DIR)/junkbot/licenses
	cp packaging/port.json $(PACKAGE_DIR)/port.json
	cp packaging/README.md $(PACKAGE_DIR)/README.md
	cp packaging/gameinfo.xml $(PACKAGE_DIR)/gameinfo.xml
	cp packaging/Junkbot.sh $(PACKAGE_DIR)/Junkbot.sh
	chmod +x $(PACKAGE_DIR)/Junkbot.sh
	cp packaging/junkbot.gptk $(PACKAGE_DIR)/junkbot/junkbot.gptk
	cp -r packaging/licenses/. $(PACKAGE_DIR)/junkbot/licenses/
	cp .build/release/JunkbotSDL3 "$(PACKAGE_DIR)/junkbot/$(BINARY_NAME).$$(uname -m)"
	cp -r $(REPO_ROOT)/images $(PACKAGE_DIR)/junkbot/images
	cp -r $(REPO_ROOT)/font $(PACKAGE_DIR)/junkbot/font
	cp -r $(REPO_ROOT)/levels $(PACKAGE_DIR)/junkbot/levels
	cp -r $(REPO_ROOT)/audio $(PACKAGE_DIR)/junkbot/audio
	@echo "✓ Port folder assembled at ports/Linux/$(PACKAGE_DIR)/"
	@echo "  Still needed before submitting: screenshot.png, cover.png, filled-in licenses/ —"
	@echo "  see packaging/README.md."

clean:
	rm -rf .build .build-package
