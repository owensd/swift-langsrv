#!/bin/bash

SwiftToolchainPath=/Library/Developer/Toolchains/swift-3.1.1-RELEASE.xctoolchain
SourceKitHeaderPath=$SwiftToolchainPath/usr/lib/sourcekitd.framework/Versions/A/Headers/sourcekitd.h
ModuleMapPath=Sources/sourcekitd/include/module.modulemap

ModuleMap="module sourcekitd [system] {
  header \"$SourceKitHeaderPath\"
  export *
}"

echo "$ModuleMap" > $ModuleMapPath
