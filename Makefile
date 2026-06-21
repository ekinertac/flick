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

.PHONY: build run cli clean install sign help

help:
	@echo "flick - Build targets:"
	@echo "  make build    - Build the app and CLI"
	@echo "  make run      - Build and run the app"
	@echo "  make cli      - Build the CLI and print its path"
	@echo "  make install  - Build and install to /Applications and /usr/local/bin"
	@echo "  make clean    - Remove build artifacts"

build: $(EXECUTABLE) $(CLI_EXECUTABLE)
	@echo "✓ Built $(APP_BUNDLE) and $(CLI_EXECUTABLE)"

$(EXECUTABLE): $(SWIFT_FILES) Info.plist
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
