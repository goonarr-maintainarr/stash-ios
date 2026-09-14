.PHONY: build test clean check help

help:
	@echo "Available commands:"
	@echo "  make build  - Build the Stash iOS app scheme"
	@echo "  make test   - Run unit tests on available iOS simulator"
	@echo "  make clean  - Clean build artifacts"

build:
	xcodebuild build -project Stash.xcodeproj -scheme Stash -destination 'generic/platform=iOS'

test:
	xcodebuild test -project Stash.xcodeproj -scheme Stash -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:StashTests

clean:
	xcodebuild clean -project Stash.xcodeproj -scheme Stash
