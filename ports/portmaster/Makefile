REPO_ROOT    := ../..
REPO_ABS     := $(abspath $(REPO_ROOT))
PACKAGE_DIR  := .build-package/junkbot

# The PortMaster release targets aarch64 Linux handhelds; binaries are produced by
# cross-compiling inside Docker (see Dockerfile) since the dev machine is a Mac. Docker
# Desktop on Apple Silicon runs linux/arm64 containers natively, so this is fast - no
# emulation involved.
DOCKER_IMAGE := junkbot-portmaster-build
TARGET_ARCH  := aarch64
# Separate scratch path so container (Linux) build products never collide with the
# host (macOS) .build directories used by ordinary dev builds.
SCRATCH_DIR  := .build-linux-$(TARGET_ARCH)

.PHONY: build docker-image docker-build package zip clean

# Host-architecture dev build (macOS on this machine) - NOT what gets packaged.
# Statically links the Swift stdlib/runtime (--static-swift-stdlib) so the packaged
# binaries run on a Portmaster handheld's Linux image without depending on a
# system-installed Swift runtime (which these devices don't have) - ordinary
# `make -C ports/SDL3 build` dev builds stay dynamically linked.
build:
	$(MAKE) -C $(REPO_ROOT)/ports/SDL3 build SWIFT_BUILD_FLAGS=--static-swift-stdlib
	$(MAKE) -C $(REPO_ROOT)/ports/SDL2 build SWIFT_BUILD_FLAGS=--static-swift-stdlib

docker-image:
	docker build --platform linux/arm64 -t $(DOCKER_IMAGE) .

# Builds both the SDL3 (ports/SDL3) and SDL2 (ports/SDL2) release binaries for aarch64
# Linux inside the Docker image - see Junkbot.sh, which picks between them at launch
# time based on which SDL3 libraries are actually present on the device. The named
# volume caches SwiftPM's dependency downloads between runs.
docker-build: docker-image
	docker run --rm --platform linux/arm64 \
		-v $(REPO_ABS):/junkbot-swift \
		-v junkbot-swiftpm-cache:/root/.cache \
		-w /junkbot-swift $(DOCKER_IMAGE) \
		bash -ec '\
			swift build --package-path ports/SDL3 --scratch-path ports/SDL3/$(SCRATCH_DIR) \
				--product JunkbotSDL3 -c release --static-swift-stdlib; \
			swift build --package-path ports/SDL2 --scratch-path ports/SDL2/$(SCRATCH_DIR) \
				--product JunkbotSDL2 -c release --static-swift-stdlib; \
			strip ports/SDL3/$(SCRATCH_DIR)/release/JunkbotSDL3 \
				ports/SDL2/$(SCRATCH_DIR)/release/JunkbotSDL2'

# Assembles a PortMaster-shaped port folder at .build-package/junkbot/ following
# portmaster.games/packaging.html: outer folder has port.json/README.md/gameinfo.xml/the
# launcher .sh; the inner junkbot/ folder has both binaries, bundled assets, controller
# mapping, and licenses/.
package: docker-build
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
	cp $(REPO_ROOT)/ports/SDL3/$(SCRATCH_DIR)/release/JunkbotSDL3 \
		$(PACKAGE_DIR)/junkbot/junkbot-sdl3.$(TARGET_ARCH)
	cp $(REPO_ROOT)/ports/SDL2/$(SCRATCH_DIR)/release/JunkbotSDL2 \
		$(PACKAGE_DIR)/junkbot/junkbot-sdl2.$(TARGET_ARCH)
	cp -r $(REPO_ROOT)/images $(PACKAGE_DIR)/junkbot/images
	cp -r $(REPO_ROOT)/font $(PACKAGE_DIR)/junkbot/font
	cp -r $(REPO_ROOT)/levels $(PACKAGE_DIR)/junkbot/levels
	cp -r $(REPO_ROOT)/audio $(PACKAGE_DIR)/junkbot/audio
	@echo "✓ Port folder assembled at ports/portmaster/$(PACKAGE_DIR)/"
	@echo "  Still needed before submitting: screenshot.png, cover.png, filled-in licenses/ —"
	@echo "  see README.md."

# Zips the assembled folder into the junkbot.zip named by port.json, ready to submit.
zip: package
	rm -f .build-package/junkbot.zip
	cd $(PACKAGE_DIR) && zip -qr ../junkbot.zip .
	@echo "✓ .build-package/junkbot.zip"

clean:
	rm -rf .build-package
	rm -rf $(REPO_ROOT)/ports/SDL3/$(SCRATCH_DIR) $(REPO_ROOT)/ports/SDL2/$(SCRATCH_DIR)
	$(MAKE) -C $(REPO_ROOT)/ports/SDL3 clean
	$(MAKE) -C $(REPO_ROOT)/ports/SDL2 clean
