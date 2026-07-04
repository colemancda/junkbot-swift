REPO_ROOT    := ../..
PACKAGE_DIR  := .build-package/junkbot

.PHONY: build package clean

# Builds both the SDL3 (ports/SDL3) and SDL2 (ports/SDL2) release binaries - see
# Junkbot.sh, which picks between them at launch time based on which SDL3 libraries are
# actually present on the device.
build:
	$(MAKE) -C $(REPO_ROOT)/ports/SDL3 build
	$(MAKE) -C $(REPO_ROOT)/ports/SDL2 build

# Assembles a PortMaster-shaped port folder at .build-package/junkbot/ following
# portmaster.games/packaging.html: outer folder has port.json/README.md/gameinfo.xml/the
# launcher .sh; the inner junkbot/ folder has both binaries, bundled assets, controller
# mapping, and licenses/. NOTE: this only packages binaries built for the CURRENT host
# architecture (this is a dev machine, not a cross-compilation setup) - for a real
# aarch64/x86_64 Linux release, build on/for the target arch first, then re-run this.
package: build
	@echo "▶ Assembling PortMaster port folder…"
	rm -rf $(PACKAGE_DIR)
	mkdir -p $(PACKAGE_DIR)/junkbot/licenses
	cp port.json $(PACKAGE_DIR)/port.json
	cp README.md $(PACKAGE_DIR)/README.md
	cp gameinfo.xml $(PACKAGE_DIR)/gameinfo.xml
	cp Junkbot.sh $(PACKAGE_DIR)/Junkbot.sh
	chmod +x $(PACKAGE_DIR)/Junkbot.sh
	cp junkbot.gptk $(PACKAGE_DIR)/junkbot/junkbot.gptk
	cp -r licenses/. $(PACKAGE_DIR)/junkbot/licenses/
	cp $(REPO_ROOT)/ports/SDL3/.build/release/JunkbotSDL3 \
		"$(PACKAGE_DIR)/junkbot/junkbot3.$$(uname -m)"
	cp $(REPO_ROOT)/ports/SDL2/.build/release/JunkbotSDL2 \
		"$(PACKAGE_DIR)/junkbot/junkbot2.$$(uname -m)"
	cp -r $(REPO_ROOT)/images $(PACKAGE_DIR)/junkbot/images
	cp -r $(REPO_ROOT)/font $(PACKAGE_DIR)/junkbot/font
	cp -r $(REPO_ROOT)/levels $(PACKAGE_DIR)/junkbot/levels
	cp -r $(REPO_ROOT)/audio $(PACKAGE_DIR)/junkbot/audio
	@echo "✓ Port folder assembled at ports/portmaster/$(PACKAGE_DIR)/"
	@echo "  Still needed before submitting: screenshot.png, cover.png, filled-in licenses/ —"
	@echo "  see README.md."

clean:
	rm -rf .build-package
	$(MAKE) -C $(REPO_ROOT)/ports/SDL3 clean
	$(MAKE) -C $(REPO_ROOT)/ports/SDL2 clean
