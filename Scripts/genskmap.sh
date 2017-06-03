#!/bin/bash

SwiftToolchainPath=/Library/Developer/Toolchains/swift-3.1.1-RELEASE.xctoolchain
SourceKitHeaderPath=$SwiftToolchainPath/usr/lib/sourcekitd.framework/Versions/A/Headers/sourcekitd.h
SourceKitDIncludePath=Sources/sourcekitd/include
ModuleMapPath=$SourceKitDIncludePath/module.modulemap

ModuleMap="module sourcekitd [system] {
  header \"$SourceKitHeaderPath\"
  export *
}"

mkdir -p $SourceKitDIncludePath
echo "$ModuleMap" > $ModuleMapPath
