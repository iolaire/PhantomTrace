// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhantomTrace",
    platforms: [.macOS("27.2.1")],
    products: [
        .library(name: "PhantomTraceCore", targets: ["PhantomTraceCore"]),
        .executable(name: "phantomtrace", targets: ["phantomtrace"])
    ],
    dependencies: [
        .package(url: "https://github.com/x-sheep/swift-property-based.git", exact: "2.0.1")
    ],
    targets: [
        .target(name: "PhantomTraceCore"),
        .executableTarget(name: "phantomtrace", dependencies: ["PhantomTraceCore"]),
        .testTarget(name: "PhantomTraceCoreTests", dependencies: ["PhantomTraceCore"]),
        .testTarget(
            name: "PhantomTracePropertyTests",
            dependencies: [
                "PhantomTraceCore",
                .product(name: "PropertyBased", package: "swift-property-based")
            ]
        )
    ]
)
