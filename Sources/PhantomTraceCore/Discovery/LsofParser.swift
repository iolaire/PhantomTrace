import Foundation

/// Pure, total parser of `lsof -F` field output (Requirement 4).
///
/// Fields are terminated by NUL or LF. The first byte of a field is its tag, the rest is its value.
/// A process set starts with a `p` field; a file set starts with an `f` field. An empty field
/// terminated by LF (the LF that follows the last NUL-terminated field of a set) ends the open file
/// set. A file set also ends when the next `f` or `p` field starts.
///
/// Truncation rule: a file set still open at the end of input is emitted only when the input ends
/// with LF. Otherwise it is dropped with a `truncatedTail` warning, so that parsing a prefix never
/// yields a record that the full input would not yield (Requirement 4.7, 4.13).
public enum LsofParser {
    /// Largest input size the parser is specified for (Requirement 4.1). Larger input is still parsed.
    public static let maximumSpecifiedInputSize = 104_857_600

    /// Parses `data`. Never throws or traps; malformed fragments become `ParseWarning`s.
    public static func parse(_ data: Data) -> ParseResult {
        var machine = LsofParserMachine()
        data.withUnsafeBytes { buffer in
            for (offset, byte) in buffer.enumerated() {
                machine.consume(byte, at: offset)
            }
        }
        return machine.finish(inputCount: data.count)
    }
}

/// Internal state machine. Value type; every step is bounds-safe because it only appends and iterates.
struct LsofParserMachine {
    private enum ProcessState {
        /// No pid seen yet: file sets are discarded without a warning.
        case none
        /// An invalid pid was seen: discard until the next valid pid.
        case discarding
        case valid(UInt32)
    }

    private struct OpenSet {
        var fileDescriptor = ""
        var accessMode: AccessMode?
        var fileType: String?
        var pathBytes = Data()
    }

    private static let nul: UInt8 = 0
    private static let lineFeed: UInt8 = 10
    private static let backslash: UInt8 = 92

    private var records: [RawLsofRecord] = []
    private var warnings: [ParseWarning] = []
    private var field: [UInt8] = []
    private var fieldStart = 0
    private var lastByte: UInt8?
    private var process = ProcessState.none
    private var commandBytes = Data()
    private var user: String?
    private var loginName: String?
    private var openSet: OpenSet?

    mutating func consume(_ byte: UInt8, at offset: Int) {
        lastByte = byte
        if byte == Self.nul || byte == Self.lineFeed {
            finishField(terminator: byte)
            fieldStart = offset + 1
        } else {
            if field.isEmpty { fieldStart = offset }
            field.append(byte)
        }
    }

    mutating func finish(inputCount: Int) -> ParseResult {
        var truncated = false
        if !field.isEmpty {
            warnings.append(.truncatedTail(offset: fieldStart))
            field.removeAll()
            truncated = true
        }
        if openSet != nil {
            if lastByte == Self.lineFeed && !truncated {
                commitOpenSet()
            } else {
                if !truncated { warnings.append(.truncatedTail(offset: inputCount)) }
                openSet = nil
            }
        }
        return ParseResult(records: records, warnings: warnings)
    }

    // MARK: Field handling

    private mutating func finishField(terminator: UInt8) {
        defer { field.removeAll(keepingCapacity: true) }
        guard let tag = field.first else {
            if terminator == Self.lineFeed { commitOpenSet() }
            return
        }
        let value = field.dropFirst()
        switch tag {
        case UInt8(ascii: "p"): startProcess(value)
        case UInt8(ascii: "f"): startFile(value)
        case UInt8(ascii: "c"), UInt8(ascii: "L"), UInt8(ascii: "u"): setProcessField(tag, value)
        case UInt8(ascii: "a"), UInt8(ascii: "t"), UInt8(ascii: "n"): setFileField(tag, value)
        default: break // Unknown tags are ignored (Requirement 4.8).
        }
    }

    /// Process-level fields apply only while no file set is open.
    private mutating func setProcessField(_ tag: UInt8, _ value: ArraySlice<UInt8>) {
        guard openSet == nil else { return }
        switch tag {
        case UInt8(ascii: "c"): commandBytes = unescape(value, base: fieldStart + 1)
        case UInt8(ascii: "L"): loginName = Self.display(value)
        default: user = Self.display(value)
        }
    }

    private mutating func setFileField(_ tag: UInt8, _ value: ArraySlice<UInt8>) {
        guard var set = openSet else { return }
        switch tag {
        case UInt8(ascii: "a"): set.accessMode = Self.accessMode(value)
        case UInt8(ascii: "t"): set.fileType = Self.display(value)
        default: set.pathBytes = unescape(value, base: fieldStart + 1)
        }
        openSet = set
    }

    private mutating func startProcess(_ value: ArraySlice<UInt8>) {
        commitOpenSet()
        commandBytes = Data()
        user = nil
        loginName = nil
        if let pid = Self.parsePid(value) {
            process = .valid(pid)
        } else {
            process = .discarding
            warnings.append(.invalidPid(offset: fieldStart))
        }
    }

    private mutating func startFile(_ value: ArraySlice<UInt8>) {
        commitOpenSet()
        var set = OpenSet()
        set.fileDescriptor = Self.display(value)
        openSet = set
    }

    private mutating func commitOpenSet() {
        defer { openSet = nil }
        guard let set = openSet, case .valid(let pid) = process, !set.pathBytes.isEmpty else { return }
        records.append(RawLsofRecord(
            pid: pid,
            commandBytes: commandBytes,
            user: loginName ?? user,
            fileDescriptor: set.fileDescriptor,
            accessMode: set.accessMode,
            fileType: set.fileType,
            pathBytes: set.pathBytes
        ))
    }

    // MARK: Value decoding

    /// Parses a decimal pid in 1...4,294,967,295. Digits only; anything else is invalid.
    private static func parsePid(_ value: ArraySlice<UInt8>) -> UInt32? {
        guard !value.isEmpty else { return nil }
        var result: UInt64 = 0
        for byte in value {
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else { return nil }
            result = result * 10 + UInt64(byte - UInt8(ascii: "0"))
            if result > UInt64(UInt32.max) { return nil }
        }
        return result == 0 ? nil : UInt32(result)
    }

    private static func accessMode(_ value: ArraySlice<UInt8>) -> AccessMode? {
        AccessMode(rawValue: display(value))
    }

    private static func display(_ value: ArraySlice<UInt8>) -> String {
        RawLsofRecord.displayString(Data(value))
    }

    /// Decodes octal (`\ooo`), hex (`\xHH`) and `\\` escapes. A malformed escape keeps the backslash
    /// literally, records one warning at the backslash offset, and decoding continues after it.
    /// `base` is the input offset of the first value byte.
    private mutating func unescape(_ value: ArraySlice<UInt8>, base: Int) -> Data {
        let bytes = Array(value)
        var output = Data()
        output.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            guard byte == Self.backslash else {
                output.append(byte)
                continue
            }
            if let (decoded, consumed) = Self.decodeEscape(bytes, from: index) {
                output.append(decoded)
                index += consumed
            } else {
                warnings.append(.malformedEscape(offset: base + index - 1))
                output.append(Self.backslash)
            }
        }
        return output
    }

    /// Decodes the escape body after a backslash starting at `start`; returns the byte and body length.
    private static func decodeEscape(_ bytes: [UInt8], from start: Int) -> (UInt8, Int)? {
        guard let first = bytes[safe: start] else { return nil }
        if first == backslash { return (backslash, 1) }
        if first == UInt8(ascii: "x") {
            guard let high = bytes[safe: start + 1].flatMap(hexValue),
                  let low = bytes[safe: start + 2].flatMap(hexValue) else { return nil }
            return (UInt8(high * 16 + low), 3)
        }
        var value = 0
        var digits = 0
        while digits < 3, let digit = bytes[safe: start + digits].flatMap(octalValue) {
            value = value * 8 + digit
            digits += 1
        }
        guard digits > 0, value <= 255 else { return nil }
        return (UInt8(value), digits)
    }

    private static func octalValue(_ byte: UInt8) -> Int? {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "7") ? Int(byte - UInt8(ascii: "0")) : nil
    }

    private static func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return Int(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return Int(byte - UInt8(ascii: "a")) + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return Int(byte - UInt8(ascii: "A")) + 10
        default: return nil
        }
    }
}

private extension Array {
    /// Bounds-checked element access.
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
