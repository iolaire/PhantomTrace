import Foundation

/// Source of the mounted volumes shown in the volume picker (Requirements 19.3, 19.9, 19.11).
///
/// Synchronous and blocking; callers invoke it off the main actor. The result is unfiltered:
/// `VolumeLister.list` decides what the user sees.
public protocol MountedVolumeEnumerating: Sendable {
    func enumerate() throws -> [MountInfo]
}
