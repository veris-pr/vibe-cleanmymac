.DEFAULT_GOAL := build

build:
	swift build

build-release:
	swift build -c release

run:
	swift run OpenCMM

test:
	swift test

clean:
	swift package clean
	rm -rf build/

app: build-release
	./scripts/build.sh

dmg: app
	./scripts/create-dmg.sh

release:
	@test -n "$(VERSION)" || (echo "Usage: make release VERSION=0.1.0" && exit 1)
	./scripts/release.sh $(VERSION)

install: dmg
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

xcode:
	open Package.swift

.PHONY: build build-release run test clean app dmg release install uninstall xcode
