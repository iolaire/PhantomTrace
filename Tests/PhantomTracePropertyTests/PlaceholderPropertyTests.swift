import PhantomTraceCore
import PropertyBased
import Testing

@Test func versionIsStableAcrossReads() async {
    await propertyCheck(count: 500, input: Gen.int(in: 0...100)) { _ in
        #expect(PhantomTraceCore.version == "0.0.0")
    }
}
