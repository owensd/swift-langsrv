.PHONY: release debug clean generate-version tag

debug: generate-version
	swift build -c debug
	swift test -c debug

release: generate-version
ifeq ($(shell uname -s),Darwin)
	swift build -c release -Xswiftc -static-stdlib
	swift test -c release
else
	swift build -c release
endif

clean:
	swift package clean

generate-version:
	./Scripts/genvers.sh

tag:
	git tag "v$(shell sed 's/^version: \(.*\)/\1/' ./Sources/VersionInfo/VersionInfo.yaml)"
