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
        .package(url: "https://github.com/RougeWare/Swift-SerializationTools.git", from: "1.1.1"),
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "AnacacuyaBot",
            dependencies: [
                .product(name: "SerializationTools", package: "Swift-SerializationTools"),
            ],
        ),
        .testTarget(
            name: "AnacacuyaBotTests",
            dependencies: ["AnacacuyaBot"],
        ),
    ],

    swiftLanguageModes: [.v6],
)
