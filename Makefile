KEYCHAIN_APPLE=emporter-cli-apple
KEYCHAIN_GITHUB=emporter-cli-gh

KEYCHAIN_KEY = $(shell security -q find-generic-password -s "$(1)" 2> /dev/null | grep acct | cut -d '=' -f 2)
KEYCHAIN_SECRET = $(shell security -q find-generic-password -s "$(1)" -w 2> /dev/null)
KEYCHAIN_DELETE = $(shell security delete-generic-password -s "$(1)" -a "$(2)" > /dev/null 2>&1 || true)
KEYCHAIN_STORE = $(shell security add-generic-password -s "$(1)" -a "$(2)" -p "$(3)")

# ---------------------------------------------------------------------------------------------------
# Building

.PHONY: bump
bump: PLIST = Support/Resources/Info.plist
bump: PLIST_SET = @plutil -replace "$(1)" -string "$(2)" "$(PLIST)"
bump: 
	@if [ -z "$(VERSION)" ]; then echo "Missing version number."; exit 1; fi

	$(eval NEW_BUILD_N=$(shell git rev-list --count HEAD))
	$(call PLIST_SET,CFBundleVersion,$(NEW_BUILD_N))
	$(call PLIST_SET,CFBundleShortVersionString,$(VERSION))

	$(eval PLIST_VERSION=$(VERSION))
	$(eval PLIST_BUILD_N=$(NEW_BUILD_N))

	@echo "==> Bumped version to \033[1m$(PLIST_VERSION) (build $(PLIST_BUILD_N))\033[0m"

# Build archive and extract its contents into build/
.PHONY: build
build:
	@echo "==> Building..."

	@xcodebuild -quiet -allowProvisioningUpdates -configuration Release -scheme EmporterRapidWeaverPlugin -archivePath build/EmporterRapidWeaverPlugin.xcarchive archive
	@cd build && cp -afR EmporterRapidWeaverPlugin.xcarchive/Products/Library/Bundles/* .

# ---------------------------------------------------------------------------------------------------
# Release / Deployment

# Build and sign for distribution, verify via the install script, and upload to notary
.PHONY: release
release-build: apple-creds build
release-build:
	@echo "==> Signing for distribution..."
	@codesign -fs "Developer ID Application: Young Dynasty" \
		--options runtime --timestamp --entitlements Support/Resources/Plugin.entitlements \
		build/Emporter.rapidweaverplugin

	@echo "==> Creating archive(s)..."
	@cd build \
		&& ditto -c -k --keepParent Emporter.rapidweaverplugin Emporter.rapidweaverplugin.zip

	@echo "==> Uploading to notary..."
	@xcrun altool --notarize-app --username $(APPLE_USERNAME) --password $(APPLE_PASSWORD) \
		--primary-bundle-id net.youngdynasty.emporter.rapidweaverplugin --file build/Emporter.rapidweaverplugin.zip

# Staple the release
.PHONY:
release-staple:
	@echo "==> Stapling package..."
	@cd build \
		&& xcrun stapler staple Emporter.rapidweaverplugin \
		&& ditto -c -k --keepParent Emporter.rapidweaverplugin Emporter.rapidweaverplugin.zip

# Release on GitHub (as draft)
.PHONY:
release-github: github-creds release-staple
	@echo "==> Uploading..."
	@GITHUB_CREDS=$(GITHUB_CREDS) GITHUB_REPO=youngdynasty/EmporterRapidWeaverPlugin \
		./Support/Tools/github_release build/Emporter.rapidweaverplugin.zip

# Release on Sparkle (after GitHub)
.PHONY:
release-appcast:
	@GITHUB_REPO=youngdynasty/EmporterRapidWeaverPlugin \
		./Support/Tools/appcast_release emporter.rapidweaverplugin.key Emporter.rapidweaverplugin.zip \
		| gsutil cp -a public-read - gs://emporter.io/feeds/rapidweaver.xml

# ---------------------------------------------------------------------------------------------------
# Credentials

.PHONY: .check-creds-args
.check-creds-args:
	@if [ -z "$(KEY)" ]; then echo "*** KEY is required."; exit 1; fi 
	@if [ -z "$(SECRET)" ]; then echo "*** SECRET is required."; exit 1; fi 

.PHONY: github-creds-store
github-creds-store: .check-creds-args
	$(call KEYCHAIN_DELETE,$(KEYCHAIN_GITHUB),$(KEY))
	$(call KEYCHAIN_STORE,$(KEYCHAIN_GITHUB),$(KEY),$(SECRET))
	
.PHONY: apple-creds-store
apple-creds-store: .check-creds-args
	$(call KEYCHAIN_DELETE,$(KEYCHAIN_APPLE),$(KEY))
	$(call KEYCHAIN_STORE,$(KEYCHAIN_APPLE),$(KEY),$(SECRET))
	
.PHONY: github-creds
github-creds: KEY=$(call KEYCHAIN_KEY,$(KEYCHAIN_GITHUB))
github-creds: SECRET=$(call KEYCHAIN_SECRET,$(KEYCHAIN_GITHUB))
github-creds:
	@if [ -z "$(KEY)" ] || [ -z "$(SECRET)" ]; then echo "*** Missing GitHub credentials. Run 'make github-creds-store' to continue."; exit 1; fi 
	
	$(eval GITHUB_CREDS=$(KEY):$(SECRET))

.PHONY: apple-creds
apple-creds: KEY=$(call KEYCHAIN_KEY,$(KEYCHAIN_APPLE))
apple-creds: SECRET=$(call KEYCHAIN_SECRET,$(KEYCHAIN_APPLE))
apple-creds:
	@if [ -z "$(KEY)" ] || [ -z "$(SECRET)" ]; then echo "*** Missing Apple credentials. Run 'make apple-creds-store' to continue."; exit 1; fi 
	
	$(eval APPLE_USERNAME=$(KEY))
	$(eval APPLE_PASSWORD=$(SECRET))
