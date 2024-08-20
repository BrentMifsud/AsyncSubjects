// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncSubject",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [.library(name: "AsyncSubject", targets: ["AsyncSubject"])],
    dependencies: [.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),],
    targets: [
        .target(name: "AsyncSubject"),
        .testTarget(
            name: "AsyncSubjectTests",
            dependencies: [
                .target(name: "AsyncSubject"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
    ]
)
