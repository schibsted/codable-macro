// swift-tools-version: 6.0

// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Codable",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
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
        // We use a pre-built dependency on the swift-syntax package (https://github.com/swiftlang/swift-syntax)
        // in order to prevent excessive slow compilation.
        // See https://forums.swift.org/t/compilation-extremely-slow-since-macros-adoption/67921/132 for details.
        .package(url: "https://github.com/schibsted/swift-syntax-xcframeworks.git", from: "600.0.1"),
    ],
    targets: [
        .macro(
            name: "CodableMacros",
            dependencies: [
                .product(name: "SwiftSyntaxWrapper", package: "swift-syntax-xcframeworks"),
            ]
        ),
        .target(name: "Codable", dependencies: ["CodableMacros"]),
        .executableTarget(name: "CodableClient", dependencies: ["Codable"]),
        .testTarget(
            name: "CodableTests",
            dependencies: [
                "CodableMacros",
                .product(name: "SwiftSyntaxWrapper", package: "swift-syntax-xcframeworks"),
            ]
        ),
    ]
)
