// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Codable",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Codable",
            targets: ["Codable"]
        ),
        .executable(
            name: "CodableClient",
            targets: ["CodableClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/schibsted/swift-syntax-xcframeworks.git", from: "600.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "CodableMacros",
            dependencies: [
                .product(name: "SwiftSyntaxWrapper", package: "swift-syntax-xcframeworks"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "Codable", dependencies: ["CodableMacros"]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "CodableClient", dependencies: ["Codable"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "CodableTests",
            dependencies: [
                "CodableMacros",
                .product(name: "SwiftSyntaxWrapper", package: "swift-syntax-xcframeworks"),
            ]
        ),
    ]
)
