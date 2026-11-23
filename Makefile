# AirBattery — build interface.
#
# `make` prints the list of targets. Every target is phony.

APP_NAME     = AirBattery
APP_BUNDLE   = AirBattery.app
BUILD_DIR    = build/release
PRODUCTS_DIR = $(BUILD_DIR)/Build/Products/Release
APP_PATH     = $(PRODUCTS_DIR)/$(APP_BUNDLE)
ARM_DERIVED   = build/arm64
INTEL_DERIVED = build/x86_64
APP_ARM_PATH   = $(PRODUCTS_DIR)/AirBattery-arm64.app
APP_INTEL_PATH = $(PRODUCTS_DIR)/AirBattery-x86_64.app
INSTALL_DIR ?= $(HOME)/Applications
INSTALL_PATH = $(INSTALL_DIR)/$(APP_BUNDLE)
VERSION      := $(shell cat VERSION 2>/dev/null || echo 0.0.0)
RELEASE_DIR  = release
DMG_ARM      = $(RELEASE_DIR)/AirBattery-$(VERSION)-arm64.dmg
DMG_INTEL    = $(RELEASE_DIR)/AirBattery-$(VERSION)-x86_64.dmg
CHECKSUMS    = $(RELEASE_DIR)/checksums.txt
DMG          = AirBattery-$(VERSION).dmg
DMG_STAGE       = dmgstage
DMG_STAGE_ARM   = dmgstage-arm64
DMG_STAGE_INTEL = dmgstage-x86_64

HOST_ARCH := $(shell uname -m)
ifeq ($(HOST_ARCH),arm64)
HOST_APP_TARGET = app-arm
HOST_APP_PATH   = $(APP_ARM_PATH)
else
HOST_APP_TARGET = app-intel
HOST_APP_PATH   = $(APP_INTEL_PATH)
endif

XCODEBUILD = xcodebuild -project AirBattery.xcodeproj -scheme AirBattery \
	-configuration Release -destination 'generic/platform=macOS' \
	-derivedDataPath $(BUILD_DIR) ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
	CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=''

# $(1) architectures, $(2) derived-data directory
ARCH_XCODEBUILD = xcodebuild -project AirBattery.xcodeproj -scheme AirBattery \
	-configuration Release -destination 'generic/platform=macOS' \
	-derivedDataPath $(2) ARCHS='$(1)' ONLY_ACTIVE_ARCH=NO \
	CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=''

# $(1) staging directory, $(2) output image, $(3) application bundle
define create_dmg
	@command -v create-dmg >/dev/null || { echo "error: create-dmg is required; run brew install create-dmg."; exit 1; }
	@rm -rf "$(1)" "$(2)"
	@mkdir -p "$(1)" "$(dir $(2))"
	@cp -R "$(3)" "$(1)/$(APP_BUNDLE)"
	create-dmg --no-internet-enable --volname "AirBattery" \
		--window-pos 200 120 --window-size 660 400 --icon-size 100 \
		--icon "$(APP_BUNDLE)" 180 200 --app-drop-link 480 200 \
		"$(2)" "$(1)/$(APP_BUNDLE)"
	@rm -rf "$(1)"
	@echo "Created $(2)"
endef

# The version of a release comes from the command line:
#   make release VERSION=1.2.3
ifeq ($(origin VERSION),command line)
RELEASE_VERSION := $(strip $(VERSION))
else
RELEASE_VERSION := $(strip $(RELEASE))
endif

.PHONY: help build test verify app app-arm app-intel app-universal \
	dmg dmg-arm dmg-intel dmg-universal \
	release-artifacts release-notes release install run clean

.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'AirBattery — build targets.' \
		'' \
		'  help                 List every target (default).' \
		'  build                Build the Debug app.' \
		'  test                 Run the changelog check.' \
		'  verify               Check both built apps: version, architecture, embedded bundles, signature.' \
		'  app                  Build the arm64 and x86_64 Release app bundles.' \
		'  app-arm              Build the Apple silicon (arm64) bundle.' \
		'  app-intel            Build the Intel (x86_64) bundle.' \
		'  app-universal        Build the legacy universal bundle.' \
		'  dmg                  Build the arm64 and x86_64 disk images.' \
		'  dmg-arm              Build release/AirBattery-<version>-arm64.dmg.' \
		'  dmg-intel            Build release/AirBattery-<version>-x86_64.dmg.' \
		'  dmg-universal        Build the legacy universal disk image.' \
		'  release-artifacts    Build both disk images and release/checksums.txt, then verify the checksums.' \
		'  release-notes VERSION=x.y.z  Print the changelog section of a version.' \
		'  release VERSION=x.y.z  Bump the changelog and VERSION, test, build, verify, commit and tag.' \
		'  install              Build and copy the host architecture app into ~/Applications.' \
		'  run                  Install and launch the app from ~/Applications.' \
		'  clean                Remove the build output and the release directory.' \
		'' \
		'Notes' \
		'  AirBattery ships two bundles: AirBattery-arm64.app and AirBattery-x86_64.app.' \
		'  Signing stays ad-hoc: codesign --force --sign -.' \
		'  CHANGELOG.md follows the shared shape and `make test` checks it.' \
		'  `make release VERSION=1.2.3` moves [Unreleased] to the version, writes' \
		'  VERSION, runs the tests, builds and verifies the disk images, commits the' \
		'  bump, tags v1.2.3 locally and prints the push commands. It never pushes.' \
		'  create-dmg is required for the dmg targets: brew install create-dmg.'

build:
	xcodebuild -project AirBattery.xcodeproj -scheme AirBattery -configuration Debug \
		-destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

test:
	./scripts/changelog.sh check

app: app-arm app-intel

app-arm:
	@rm -rf "$(APP_ARM_PATH)"
	$(call ARCH_XCODEBUILD,arm64,$(ARM_DERIVED)) MARKETING_VERSION=$(VERSION) build
	@ditto "$(ARM_DERIVED)/Build/Products/Release/$(APP_BUNDLE)" "$(APP_ARM_PATH)"
	@echo "Built $(APP_ARM_PATH)"

app-intel:
	@rm -rf "$(APP_INTEL_PATH)"
	$(call ARCH_XCODEBUILD,x86_64,$(INTEL_DERIVED)) MARKETING_VERSION=$(VERSION) build
	@ditto "$(INTEL_DERIVED)/Build/Products/Release/$(APP_BUNDLE)" "$(APP_INTEL_PATH)"
	@echo "Built $(APP_INTEL_PATH)"

app-universal:
	rm -rf $(APP_PATH)
	$(XCODEBUILD) MARKETING_VERSION=$(VERSION) build

verify:
	@for pair in "arm64:$(APP_ARM_PATH)" "x86_64:$(APP_INTEL_PATH)"; do \
		arch="$${pair%%:*}"; path="$${pair#*:}"; \
		test -d "$$path" || { echo "error: no app at $$path; run make app first."; exit 1; }; \
		version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$$path/Contents/Info.plist")"; \
		test "$$version" = "$(VERSION)" || { echo "error: $$path reports $$version, but $(VERSION) was expected."; exit 1; }; \
		check_arch() { \
			got="$$(lipo -archs "$$1" | tr ' ' '\n' | sort | tr '\n' ' ' | xargs)"; \
			test "$$got" = "$$2" || { echo "error: $$1 holds [$$got], expected [$$2]."; exit 1; }; \
		}; \
		check_arch "$$path/Contents/MacOS/AirBattery" "$$arch"; \
		check_arch "$$path/Contents/Library/LoginItems/AirBatteryHelper.app/Contents/MacOS/AirBatteryHelper" "$$arch"; \
		check_arch "$$path/Contents/PlugIns/AirBatteryWidgetExtension.appex/Contents/MacOS/AirBatteryWidgetExtension" "$$arch"; \
		test -d "$$path/Contents/PlugIns/AirBatteryWidgetExtension.appex" || { echo "error: the widget extension is missing from $$path."; exit 1; }; \
		test -d "$$path/Contents/Library/LoginItems/AirBatteryHelper.app" || { echo "error: the login helper is missing from $$path."; exit 1; }; \
		codesign --verify --deep --strict "$$path"; \
		codesign -dv "$$path" 2>&1 | grep -q 'Signature=adhoc' || { echo "error: $$path is not ad-hoc signed."; exit 1; }; \
		echo "Verified $$path ($$arch)."; \
	done

dmg: dmg-arm dmg-intel

dmg-arm: app-arm
	$(call create_dmg,$(DMG_STAGE_ARM),$(DMG_ARM),$(APP_ARM_PATH))

dmg-intel: app-intel
	$(call create_dmg,$(DMG_STAGE_INTEL),$(DMG_INTEL),$(APP_INTEL_PATH))

dmg-universal: app-universal
	$(call create_dmg,$(DMG_STAGE),$(DMG),$(APP_PATH))

release-artifacts: dmg
	@cd $(RELEASE_DIR) && shasum -a 256 "$$(basename $(DMG_ARM))" "$$(basename $(DMG_INTEL))" > "$$(basename $(CHECKSUMS))"
	@cd $(RELEASE_DIR) && shasum -a 256 -c "$$(basename $(CHECKSUMS))"
	@cat "$(CHECKSUMS)"

release-notes:
	@if [ -z "$(RELEASE_VERSION)" ]; then \
		echo "error: make release-notes needs a version, for example: make release-notes VERSION=1.2.3"; \
		exit 1; \
	fi
	@./scripts/changelog.sh notes "$(RELEASE_VERSION)"

release:
	@if [ -z "$(RELEASE_VERSION)" ]; then \
		echo "error: make release needs a version, for example: make release VERSION=1.2.3"; \
		exit 1; \
	fi
	@APP_NAME="$(APP_NAME)" ./scripts/release.sh "$(RELEASE_VERSION)"

install: $(HOST_APP_TARGET)
	@mkdir -p "$(INSTALL_DIR)"
	@rm -rf "$(INSTALL_PATH)"
	@ditto "$(HOST_APP_PATH)" "$(INSTALL_PATH)"
	@echo "Installed $(HOST_ARCH) build to $(INSTALL_PATH)"

run: install
	@open "$(INSTALL_PATH)"

clean:
	rm -rf build $(RELEASE_DIR) $(DMG_STAGE) $(DMG_STAGE_ARM) $(DMG_STAGE_INTEL) \
		AirBattery-*.dmg AirBattery-*.dmg.sha256
