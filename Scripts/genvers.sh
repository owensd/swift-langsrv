#!/bin/bash

VersionInfoTemplatePath=./Sources/VersionInfo/Version.swiftpartial
VersionInfoPath=./Sources/VersionInfo/Version.swift
VersionInfo=./Sources/VersionInfo/VersionInfo.yaml

Version=$(sed 's/^version: \(.*\)$/\1/' $VersionInfo)
sed "s/\$VersionNumber/$Version/g" <$VersionInfoTemplatePath >$VersionInfoPath