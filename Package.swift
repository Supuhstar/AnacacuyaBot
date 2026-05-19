// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnacacuyaBot",
    
    platforms: [
        .custom("CachyOS", versionString: "26"),
        .macOS(.v26),
    ],
    
    dependencies: [
        .package(url: "https://github.com/RougeWare/Swift-Collection-Tools.git", from: "3.2.1"),
        .package(url: "https://github.com/RougeWare/Swift-Rectangle-Tools", from: "2.17.1"),
        .package(url: "https://github.com/RougeWare/Swift-SemVer.git", from: "2.0.0"),
        .package(url: "https://github.com/RougeWare/Swift-SerializationTools.git", from: "1.1.1"),
        .package(url: "https://github.com/RougeWare/Swift-Special-String", from: "1.2.0"),
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "AnacacuyaBot",
            dependencies: [
                .product(name: "CollectionTools", package: "Swift-Collection-Tools"),
                .product(name: "RectangleTools", package: "Swift-Rectangle-Tools"),
                .product(name: "SemVer", package: "Swift-SemVer"),
                .product(name: "SerializationTools", package: "Swift-SerializationTools"),
                .product(name: "SpecialString", package: "Swift-Special-String"),
            ],
            swiftSettings: [
                .strictMemorySafety(),
                .treatAllWarnings(as: .error),
                .unsafeFlags([
                    "-enable-bare-slash-regex",
                ])
            ],
        ),
        .testTarget(
            name: "AnacacuyaBotTests",
            dependencies: ["AnacacuyaBot"],
        ),
    ],
    
    swiftLanguageModes: [.v6],
)
