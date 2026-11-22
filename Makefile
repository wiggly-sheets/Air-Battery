# AirBattery — build interface.
#
# `make` prints the list of targets. Every target is phony.

APP_NAME     = AirBattery
APP_BUNDLE   = AirBattery.app
BUILD_DIR    = build/release
APP_PATH     = $(BUILD_DIR)/Build/Products/Release/$(APP_BUNDLE)
INSTALL_DIR ?= $(HOME)/Applications
INSTALL_PATH = $(INSTALL_DIR)/$(APP_BUNDLE)
VERSION      := $(shell cat VERSION 2>/dev/null || echo 0.0.0)
DMG          = AirBattery-$(VERSION).dmg
DMG_STAGE    = dmgstage

XCODEBUILD = xcodebuild -project AirBattery.xcodeproj -scheme AirBattery \
	-configuration Release -destination 'generic/platform=macOS' \
	-derivedDataPath $(BUILD_DIR) ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
	CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=''

# The version of a release comes from the command line:
#   make release VERSION=1.2.3
ifeq ($(origin VERSION),command line)
RELEASE_VERSION := $(strip $(VERSION))
else
RELEASE_VERSION := $(strip $(RELEASE))
endif

.PHONY: help build test verify app app-universal dmg dmg-universal \
	release-artifacts release-notes release install run clean

.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'AirBattery — build targets.' \
		'' \
		'  help                 List every target (default).' \
		'  build                Build the Debug app.' \
		'  test                 Run the changelog check.' \
		'  verify               Check the built app: version, architectures, embedded bundles, signature.' \
		'  app                  Build the universal Release app bundle.' \
		'  app-universal        Alias for app.' \
		'  dmg                  Build AirBattery-<version>.dmg from the universal bundle.' \
		'  dmg-universal        Alias for dmg.' \
		'  release-artifacts    Build the dmg and its .sha256 sidecar, then verify the checksum.' \
		'  release-notes VERSION=x.y.z  Print the changelog section of a version.' \
		'  release VERSION=x.y.z  Bump the changelog and VERSION, test, build, verify, commit and tag.' \
		'  install              Build and copy the app into ~/Applications.' \
		'  run                  Install and launch the app from ~/Applications.' \
		'  clean                Remove the build output.' \
		'' \
		'Notes' \
		'  AirBattery ships one universal bundle (arm64 + x86_64).' \
		'  Signing stays ad-hoc: codesign --force --sign -.' \
		'  CHANGELOG.md follows the shared shape and `make test` checks it.' \
		'  `make release VERSION=1.2.3` moves [Unreleased] to the version, writes' \
		'  VERSION, runs the tests, builds and verifies the dmg, commits the bump,' \
		'  tags v1.2.3 locally and prints the push commands. It never pushes.' \
		'  create-dmg is required for the dmg target: brew install create-dmg.'

build:
	xcodebuild -project AirBattery.xcodeproj -scheme AirBattery -configuration Debug \
		-destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

test:
	./scripts/changelog.sh check

app:
	rm -rf $(APP_PATH)
	$(XCODEBUILD) MARKETING_VERSION=$(VERSION) build

app-universal: app

verify:
	@test -d "$(APP_PATH)" || { echo "error: no app at $(APP_PATH); run make app first."; exit 1; }
	@version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '$(APP_PATH)/Contents/Info.plist')"; \
		test "$$version" = "$(VERSION)" || { echo "error: app reports $$version, but $(VERSION) was expected."; exit 1; }
	@archs="$$(lipo -archs '$(APP_PATH)/Contents/MacOS/AirBattery' | tr ' ' '\n' | sort | tr '\n' ' ' | xargs)"; \
		test "$$archs" = "arm64 x86_64" || { echo "error: app holds [$$archs], expected [arm64 x86_64]."; exit 1; }
	@test -d "$(APP_PATH)/Contents/PlugIns/AirBatteryWidgetExtension.appex" || { echo "error: the widget extension is missing."; exit 1; }
	@test -d "$(APP_PATH)/Contents/Library/LoginItems/AirBatteryHelper.app" || { echo "error: the login helper is missing."; exit 1; }
	@codesign --verify --deep --strict "$(APP_PATH)"
	@codesign -dv "$(APP_PATH)" 2>&1 | grep -q 'Signature=adhoc' || { echo "error: the app is not ad-hoc signed."; exit 1; }
	@echo "Verified $(APP_PATH)."

dmg: app
	@command -v create-dmg >/dev/null || { echo "error: create-dmg is required; run brew install create-dmg."; exit 1; }
	@rm -rf $(DMG_STAGE) $(DMG)
	@mkdir -p $(DMG_STAGE)
	@cp -R "$(APP_PATH)" $(DMG_STAGE)/$(APP_BUNDLE)
	create-dmg --no-internet-enable --volname "AirBattery" \
		--window-pos 200 120 --window-size 660 400 --icon-size 100 \
		--icon "$(APP_BUNDLE)" 180 200 --app-drop-link 480 200 \
		"$(DMG)" "$(DMG_STAGE)/$(APP_BUNDLE)"
	@rm -rf $(DMG_STAGE)
	@echo "Created $(DMG)"

dmg-universal: dmg

release-artifacts: dmg
	@shasum -a 256 "$(DMG)" > "$(DMG).sha256"
	@shasum -a 256 -c "$(DMG).sha256"
	@cat "$(DMG).sha256"

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

install: app
	@mkdir -p "$(INSTALL_DIR)"
	@rm -rf "$(INSTALL_PATH)"
	@ditto "$(APP_PATH)" "$(INSTALL_PATH)"
	@echo "Installed to $(INSTALL_PATH)"

run: install
	@open "$(INSTALL_PATH)"

clean:
	rm -rf build $(DMG_STAGE) AirBattery-*.dmg AirBattery-*.dmg.sha256
