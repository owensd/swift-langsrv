#!/bin/bash

ProjectRoot=$(pwd)
BuildPath=$ProjectRoot/.build/$1

echo "Changing rpath of libsourcekitd.dylib"
install_name_tool -change "$BuildPath/libsourcekitd.dylib" "@rpath/libsourcekitd.dylib" $BuildPath/langsrv
