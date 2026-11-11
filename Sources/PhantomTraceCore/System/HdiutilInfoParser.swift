import Foundation

/// Pure parser for the output of `/usr/bin/hdiutil info -plist` (Requirements 1.4, 1.5).
///
/// It does no I/O, so it can be tested with a captured plist. The live adapter runs the tool through
/// `ProcessRunning` and hands the bytes to `parse(_:)`.
public enum HdiutilInfoParser {
    /// One mounted (or at least attached) volume of an image.
    public struct Volume: Equatable, Sendable {
        public let deviceNode: String
        /// Nil for entities that are attached but not mounted (partition maps, unmounted volumes).
        public let mountPoint: String?

        public init(deviceNode: String, mountPoint: String?) {
            self.deviceNode = deviceNode
            self.mountPoint = mountPoint
        }
    }

    /// An attached disk image and its volumes in the order `hdiutil` lists them.
    public struct Image: Equatable, Sendable {
        public let imagePath: String
        public let volumes: [Volume]

        public init(imagePath: String, volumes: [Volume]) {
            self.imagePath = imagePath
            self.volumes = volumes
        }
    }

    /// Returns the attached images, or nil when `data` is not a plist with the expected `images` array.
    /// Images without an `image-path` are skipped; the function never traps.
    public static func parse(_ data: Data) -> [Image]? {
        guard let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = root as? [String: Any],
              let images = dictionary["images"] as? [[String: Any]] else {
            return nil
        }
        return images.compactMap(image(from:))
    }

    private static func image(from entry: [String: Any]) -> Image? {
        guard let path = entry["image-path"] as? String, !path.isEmpty else { return nil }
        let entities = entry["system-entities"] as? [[String: Any]] ?? []
        let volumes = entities.compactMap { entity -> Volume? in
            guard let device = entity["dev-entry"] as? String else { return nil }
            return Volume(deviceNode: device, mountPoint: entity["mount-point"] as? String)
        }
        return Image(imagePath: path, volumes: volumes)
    }
}
