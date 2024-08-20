// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncSubjects",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [.library(name: "AsyncSubjects", targets: ["AsyncSubjects"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-format", from: "510.1.0")
    ],
    targets: [
        .target(
            name: "AsyncSubjects"
        ),
        .testTarget(
            name: "AsyncSubjectsTests",
            dependencies: [
                .target(name: "AsyncSubjects"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
    ]
)
