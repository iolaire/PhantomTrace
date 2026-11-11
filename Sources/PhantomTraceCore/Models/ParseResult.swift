import Foundation

/// The total result of parsing `lsof -F` bytes. Parsing never throws.
public struct ParseResult: Equatable, Sendable {
    public var records: [RawLsofRecord]
    public var warnings: [ParseWarning]

    public init(records: [RawLsofRecord] = [], warnings: [ParseWarning] = []) {
        self.records = records
        self.warnings = warnings
    }
}
