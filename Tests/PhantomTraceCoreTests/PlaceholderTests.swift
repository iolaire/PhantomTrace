import Testing
@testable import PhantomTraceCore

struct PlaceholderTests {
    @Test func versionIsPlaceholder() {
        #expect(PhantomTraceCore.version == "0.0.0")
    }
}
