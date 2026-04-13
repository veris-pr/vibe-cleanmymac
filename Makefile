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

xcode:
	open Package.swift

.PHONY: build build-release run test clean xcode
