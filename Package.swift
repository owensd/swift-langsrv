// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "swift-langsrv",
    targets: [
        Target(name: "langsrv", dependencies: ["langsrvlib"])
    ],
    dependencies: [
        .Package(url: "https://github.com/owensd/json-swift.git", majorVersion: 2, minor: 0),
        .Package(url: "https://github.com/owensd/swift-lsp.git", majorVersion: 0, minor: 21)
    ]
)
