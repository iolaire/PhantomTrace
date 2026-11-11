import Darwin
import Foundation
import Testing
@testable import PhantomTraceCore

/// Read-only checks against the test process itself. No other process is inspected or signaled.
struct LiveProcessInspectorTests {
    @Test func inspectingOwnProcessReportsOwnIdentityAndOwner() throws {
        let inspector = LiveProcessInspector()
        let details = try #require(inspector.inspect(pid: inspector.currentProcessID))
        #expect(details.identity.pid == UInt32(getpid()))
        #expect(details.ownerUserID == inspector.currentUserID)
        #expect(details.identity.startTime < Date())
        #expect(details.processGroupID == getpgrp())
        #expect(details.executablePath?.path.isEmpty == false)
        #expect(details.currentDirectory?.path.isEmpty == false)
    }

    @Test func startTimeIsStableAcrossCalls() throws {
        let inspector = LiveProcessInspector()
        let first = try #require(inspector.inspect(pid: inspector.currentProcessID))
        let second = try #require(inspector.inspect(pid: inspector.currentProcessID))
        #expect(first.identity == second.identity)
    }

    @Test(arguments: [Int32(0), -1, Int32.max])
    func unknownPidsReturnNil(pid: Int32) {
        #expect(LiveProcessInspector().inspect(pid: pid) == nil)
    }
}
