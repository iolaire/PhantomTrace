// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Command Line Tools bundle swift-testing's macro plugin but SwiftPM does not
// auto-load it. Full Xcode finds it on its own, so pass the flag only if present.
let commandLineToolsTestingMacros =
    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testingPluginFlags: [String] = FileManager.default.fileExists(atPath: commandLineToolsTestingMacros)
    ? ["-load-plugin-library", commandLineToolsTestingMacros]
    : []
let testingSettings: [SwiftSetting] = testingPluginFlags.isEmpty ? [] : [.unsafeFlags(testingPluginFlags)]

let package = Package(
    name: "PhantomTrace",
    platforms: [.macOS("27.2.1")],
    products: [
        .library(name: "PhantomTraceCore", targets: ["PhantomTraceCore"]),
        .library(name: "PhantomTraceUI", targets: ["PhantomTraceUI"]),
        .executable(name: "phantomtrace", targets: ["phantomtrace"]),
        .executable(name: "PhantomTraceApp", targets: ["PhantomTraceApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/x-sheep/swift-property-based.git", exact: "2.0.1")
    ],
    targets: [
        .target(name: "PhantomTraceCore"),
        .executableTarget(name: "phantomtrace", dependencies: ["PhantomTraceCore"]),
        // AppKit UI. Sprites under Resources/ are plain files copied into the app bundle by the
        // bundling script and read from Bundle.main.resourceURL, so SwiftPM must not process them.
        .target(
            name: "PhantomTraceUI",
            dependencies: ["PhantomTraceCore"],
            exclude: ["Resources"]
        ),
        .executableTarget(name: "PhantomTraceApp", dependencies: ["PhantomTraceUI", "PhantomTraceCore"]),
        // Shared hand-written mocks for the test targets. Not a product.
        .target(
            name: "PhantomTraceTestSupport",
            dependencies: ["PhantomTraceCore"],
            path: "Tests/PhantomTraceTestSupport"
        ),
        .testTarget(
            name: "PhantomTraceCoreTests",
            dependencies: ["PhantomTraceCore", "PhantomTraceTestSupport"],
            swiftSettings: testingSettings
        ),
        .testTarget(
            name: "PhantomTraceUITests",
            dependencies: ["PhantomTraceUI", "PhantomTraceCore"],
            swiftSettings: testingSettings
        ),
        .testTarget(
            name: "PhantomTracePropertyTests",
            dependencies: [
                "PhantomTraceCore",
                "PhantomTraceTestSupport",
                .product(name: "PropertyBased", package: "swift-property-based")
            ],
            swiftSettings: testingSettings
        )
    ]
)
