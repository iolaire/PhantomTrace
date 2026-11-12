import PhantomTraceCore
import Testing

struct ModelValueTests {
    @Test func allowVerdictIsAllowed() {
        #expect(SafetyVerdict.allow.isAllowed)
    }

    @Test(arguments: SafetyDenial.allCases)
    func everyDenialVerdictIsNotAllowed(denial: SafetyDenial) {
        #expect(!SafetyVerdict.deny(denial).isAllowed)
    }

    @Test(arguments: [0, 1, 17, 4_096])
    func parseWarningReportsItsByteOffset(offset: Int) {
        #expect(ParseWarning.invalidPid(offset: offset).offset == offset)
        #expect(ParseWarning.truncatedTail(offset: offset).offset == offset)
        #expect(ParseWarning.malformedEscape(offset: offset).offset == offset)
    }

    @Test func parseWarningsOfDifferentKindsAtTheSameOffsetAreDistinct() {
        #expect(ParseWarning.invalidPid(offset: 3) != ParseWarning.truncatedTail(offset: 3))
    }
}
