# Build and run flick (menu bar app + CLI) without Xcode.
# Usage: make build, make run, make install, make clean

PROJECT_NAME = Flick
BUNDLE_ID = com.ekinertac.flick
MIN_OS_VERSION = 14.0
SWIFT_FILES = Flick.swift ServicesModel.swift Config.swift Logger.swift HotkeyManager.swift
CLI_NAME = flick
CLI_FILE = flick-cli.swift
BUILD_DIR = .build
APP_NAME = $(PROJECT_NAME).app
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME)
EXECUTABLE = $(APP_BUNDLE)/Contents/MacOS/$(PROJECT_NAME)
CLI_EXECUTABLE = $(BUILD_DIR)/$(CLI_NAME)
CONTENTS_DIR = $(APP_BUNDLE)/Contents
INSTALL_PATH = /usr/local/bin

.PHONY: build run cli icon clean install sign help

help:
	@echo "flick - Build targets:"
	@echo "  make build    - Build the app and CLI"
	@echo "  make run      - Build and run the app"
	@echo "  make cli      - Build the CLI and print its path"
	@echo "  make icon     - Regenerate Flick.icns from icon.png"
	@echo "  make install  - Build and install to /Applications and /usr/local/bin"
	@echo "  make clean    - Remove build artifacts"

build: $(EXECUTABLE) $(CLI_EXECUTABLE)
	@echo "✓ Built $(APP_BUNDLE) and $(CLI_EXECUTABLE)"

$(EXECUTABLE): $(SWIFT_FILES) Info.plist Flick.icns
	@mkdir -p $(CONTENTS_DIR)/MacOS
	@mkdir -p $(CONTENTS_DIR)/Resources
	@echo "Compiling app..."
	@swiftc -parse-as-library \
		-O \
		-o $(EXECUTABLE) \
		$(SWIFT_FILES)
	@chmod +x $(EXECUTABLE)
	@echo "Copying Info.plist..."
	@cp Info.plist $(CONTENTS_DIR)/Info.plist
	@echo "Installing app icon..."
	@cp Flick.icns $(CONTENTS_DIR)/Resources/Flick.icns
	@echo "Creating PkgInfo..."
	@echo -n "APPL????" > $(CONTENTS_DIR)/PkgInfo
	@echo "Code signing app..."
	@codesign --force --sign - $(APP_BUNDLE) 2>/dev/null || true

$(CLI_EXECUTABLE): $(CLI_FILE)
	@echo "Compiling CLI tool..."
	@swiftc -O -o $(CLI_EXECUTABLE) $(CLI_FILE)
	@chmod +x $(CLI_EXECUTABLE)

run: build
	@echo "Launching app..."
	@$(EXECUTABLE) &

cli: $(CLI_EXECUTABLE)
	@echo "CLI built. Run it without installing:"
	@echo "  $(abspath $(CLI_EXECUTABLE)) <service_id> [status|toggle]"

# Regenerate the .icns from icon.png (1024x1024 source). Committed to the repo
# so normal builds just copy it and don't depend on iconutil being available.
icon: icon.png
	@echo "Generating Flick.icns from icon.png..."
	@rm -rf $(BUILD_DIR)/Flick.iconset
	@mkdir -p $(BUILD_DIR)/Flick.iconset
	@sips -z 1024 1024 icon.png --out $(BUILD_DIR)/base.png >/dev/null
	@sips -z 16 16     $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_16x16.png >/dev/null
	@sips -z 32 32     $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_16x16@2x.png >/dev/null
	@sips -z 32 32     $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_32x32.png >/dev/null
	@sips -z 64 64     $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_32x32@2x.png >/dev/null
	@sips -z 128 128   $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_128x128.png >/dev/null
	@sips -z 256 256   $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_128x128@2x.png >/dev/null
	@sips -z 256 256   $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_256x256.png >/dev/null
	@sips -z 512 512   $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_256x256@2x.png >/dev/null
	@sips -z 512 512   $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_512x512.png >/dev/null
	@sips -z 1024 1024 $(BUILD_DIR)/base.png --out $(BUILD_DIR)/Flick.iconset/icon_512x512@2x.png >/dev/null
	@iconutil -c icns $(BUILD_DIR)/Flick.iconset -o Flick.icns
	@echo "✓ Wrote Flick.icns"

install: build
	@echo "Installing app to /Applications..."
	@rm -rf /Applications/$(APP_NAME)
	@cp -r $(APP_BUNDLE) /Applications/
	@echo "✓ Installed $(APP_NAME) to /Applications"
	@echo ""
	@echo "Installing CLI to $(INSTALL_PATH)..."
	@sudo mkdir -p $(INSTALL_PATH)
	@sudo cp $(CLI_EXECUTABLE) $(INSTALL_PATH)/$(CLI_NAME)
	@sudo chmod +x $(INSTALL_PATH)/$(CLI_NAME)
	@echo "✓ Installed $(CLI_NAME) to $(INSTALL_PATH)"
	@echo ""
	@echo "To launch app at startup:"
	@echo "  1. System Settings → General → Login Items"
	@echo "  2. Click '+' and add /Applications/$(APP_NAME)"
	@echo ""
	@echo "CLI usage: flick <service_id> [status|toggle]"

sign: build
	@echo "Signing app..."
	@codesign --deep --force --verify --verbose --sign - $(APP_BUNDLE)
	@echo "✓ Signed $(APP_BUNDLE)"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "✓ Cleaned build artifacts"
