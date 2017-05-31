#!/bin/bash

VersionInfoPath=./Sources/langsrv/VersionInfo.swift
VersionInfo=./VersionInfo.info

FileContents="/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

public enum VersionInfo {
    static public let version = \"\$VersionNumber\"
}"

echo "$FileContents" > $VersionInfoPath

Version=$(sed 's/^version: \(.*\)$/\1/' $VersionInfo)
sed -i '' "s/\$VersionNumber/$Version/g" $VersionInfoPath