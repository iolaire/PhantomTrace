import Foundation
import Testing
@testable import PhantomTraceCore

/// Pure parsing tests; nothing here runs `hdiutil` or reads the mount table (Requirements 1.4, 1.5).
struct HdiutilInfoParserTests {
    private static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/hdiutil-info.plist")

    @Test func parserReadsImagePathsAndMountPointsFromCapturedPlist() throws {
        let images = try #require(HdiutilInfoParser.parse(Data(contentsOf: Self.fixture)))
        #expect(images.map(\.imagePath) == ["/Users/test/Desktop/My Disk.dmg", "/Users/test/Other.dmg"])
        #expect(images[0].volumes == [
            HdiutilInfoParser.Volume(deviceNode: "/dev/disk4", mountPoint: nil),
            HdiutilInfoParser.Volume(deviceNode: "/dev/disk4s1", mountPoint: "/Volumes/My Disk")
        ])
    }

    @Test func parserReturnsNilForMalformedInput() {
        #expect(HdiutilInfoParser.parse(Data()) == nil)
        #expect(HdiutilInfoParser.parse(Data("not a plist".utf8)) == nil)
        #expect(HdiutilInfoParser.parse(Data("<plist version=\"1.0\"><array/></plist>".utf8)) == nil)
    }

    @Test func parserReturnsEmptyListWhenNoImagesAreAttached() {
        let text = "<plist version=\"1.0\"><dict><key>images</key><array/></dict></plist>"
        #expect(HdiutilInfoParser.parse(Data(text.utf8)) == [])
    }
}

struct FirmlinkMapTests {
    private let map = FirmlinkMap(firmlinksFileText: "/Users\tUsers\n/Volumes\tVolumes\n/usr/local\tusr/local\n")

    @Test func firmlinkedDataVolumePathMapsToUserFacingPath() {
        #expect(map.userFacingPath("/System/Volumes/Data/Users/me/a.txt") == "/Users/me/a.txt")
        #expect(map.userFacingPath("/System/Volumes/Data/usr/local/bin") == "/usr/local/bin")
    }

    @Test func nonFirmlinkedAndLookalikePathsAreUnchanged() {
        #expect(map.userFacingPath("/System/Volumes/Data/.Spotlight-V100") == "/System/Volumes/Data/.Spotlight-V100")
        #expect(map.userFacingPath("/System/Volumes/Data/UsersX/me") == "/System/Volumes/Data/UsersX/me")
        #expect(map.userFacingPath("/System/Volumes/Data") == "/System/Volumes/Data")
        #expect(map.userFacingPath("/Volumes/A") == "/Volumes/A")
    }
}
