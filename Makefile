.PHONY: release debug clean generate-version publish tag

# Use the standard tools to change the version of Swift you would like to compile with.
SwiftToolPath=$(shell xcrun -f swift)
ToolchainPath=$(SwiftToolPath:/usr/bin/swift=)
ToolchainLibPath=$(ToolchainPath)/usr/lib
SwiftPlatformSdkPath=$(ToolchainLibPath)/swift/macosx/
Flags=-Xswiftc -framework -Xswiftc sourcekitd -Xswiftc -F -Xswiftc $(ToolchainLibPath) -Xlinker -rpath -Xlinker $(ToolchainLibPath) -Xlinker -rpath -Xlinker $(SwiftPlatformSdkPath)

Version=v$(shell sed 's/^version: \(.*\)/\1/' ./VersionInfo)

debug: generate-version
	swift build -c debug $(Flags)
	swift test -c debug $(Flags)
	./Scripts/fixrpath.sh debug

release: generate-version
ifeq ($(shell uname -s),Darwin)
	swift build -c release -Xswiftc -static-stdlib $(Flags)
	swift test -c release $(Flags)
	./Scripts/fixrpath.sh release
else
	swift build -c release $(Flags)
	./Scripts/fixrpath.sh release
endif

clean:
	swift package clean

generate-version:
	./Scripts/genvers.sh

package: release
	mkdir -p .build/releases
	cp .build/release/langsrv .build/releases
	cp .build/release/libsourcekitd.dylib .build/releases
	rm -f .build/releases/langsrv-macos-$(Version).zip
	zip -ojm .build/releases/langsrv-macos-$(Version).zip .build/releases/*

publish: zip tag
	@echo "Please upload .build/releases/langsrv-macos-$(Version).zip to GitHub manually."

tag:
	git tag $(Version)
