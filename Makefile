.PHONY: android ios macos windows all clean deps

SHELL := /bin/bash

android:
	@bash scripts/build.sh android

ios:
	@bash scripts/build.sh ios

macos:
	@bash scripts/build.sh macos

windows:
	@bash scripts/build.sh windows

all:
	@bash scripts/build.sh all

clean:
	@bash scripts/build.sh clean

deps:
	flutter pub get
