#!/bin/bash

VersionInfoTemplatePath=./Sources/VersionInfo/VersionInfo.swiftpartial
VersionInfoPath=./Sources/VersionInfo/VersionInfo.swift
VersionInfo=./Sources/VersionInfo/VersionInfo.yaml

Version=$(sed 's/^version: \(.*\)$/\1/' $VersionInfo)
sed "s/\$VersionNumber/$Version/g" <$VersionInfoTemplatePath >$VersionInfoPath