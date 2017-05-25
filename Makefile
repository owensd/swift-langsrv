ToolchainPath=/Library/Developer/Toolchains/swift-latest.xctoolchain/
ToolchainLibPath=$(ToolchainPath)/usr/lib
BuildCommand=swift build -Xswiftc -framework -Xswiftc sourcekitd -Xswiftc -F -Xswiftc $(ToolchainLibPath) -Xlinker -rpath -Xlinker $(ToolchainLibPath)

debug:
	$(BuildCommand) -c debug

release:
	$(BuildCommand) -c release

.PHONY: debug release
