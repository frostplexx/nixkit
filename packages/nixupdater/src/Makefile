APP_NAME   = NixUpdater
BUNDLE     = $(APP_NAME).app
BIN_DIR    = $(BUNDLE)/Contents/MacOS
PLIST      = $(BUNDLE)/Contents/Info.plist
SRC        = ./main.swift
BINARY     = $(BIN_DIR)/$(APP_NAME)

.PHONY: all build clean run

all: build

build: $(BINARY) $(PLIST)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BINARY): $(SRC) | $(BIN_DIR)
	swiftc $(SRC) \
		-o $(BINARY) \
		-framework Cocoa \
		-framework Foundation

$(PLIST): | $(BIN_DIR)
	mkdir -p $(BUNDLE)/Contents
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable    string $(APP_NAME)"       $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier   string com.local.nixupdater" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleName         string $(APP_NAME)"       $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType  string APPL"              $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0"         $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion      string 1"                 $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :LSUIElement          bool true"                $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass     string NSApplication"     $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true"             $(PLIST)

run: build
	open $(BUNDLE)

clean:
	rm -rf $(BUNDLE)
