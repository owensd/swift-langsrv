#!/bin/bash

ProjectRoot=$(pwd)
BuildPath=$ProjectRoot/.build/$1

echo "Changing rpath of libsourcekitd.dylib"
install_name_tool -change "$BuildPath/libsourcekitd.dylib" "@executable_path/libsourcekitd.dylib" $BuildPath/langsrv
