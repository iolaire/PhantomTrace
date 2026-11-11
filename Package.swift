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
        .executable(name: "phantomtrace", targets: ["phantomtrace"])
    ],
    dependencies: [
        .package(url: "https://github.com/x-sheep/swift-property-based.git", exact: "2.0.1")
    ],
    targets: [
        .target(name: "PhantomTraceCore"),
        .executableTarget(name: "phantomtrace", dependencies: ["PhantomTraceCore"]),
        .testTarget(
            name: "PhantomTraceCoreTests",
            dependencies: ["PhantomTraceCore"],
            swiftSettings: testingSettings
        ),
        .testTarget(
            name: "PhantomTracePropertyTests",
            dependencies: [
                "PhantomTraceCore",
                .product(name: "PropertyBased", package: "swift-property-based")
            ],
            swiftSettings: testingSettings
        )
    ]
)
