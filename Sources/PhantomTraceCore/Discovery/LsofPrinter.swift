import Foundation

/// Pure serializer from `RawLsofRecord`s to `lsof -F` field bytes (Requirements 4.11, 4.12).
///
/// Output is accepted by `LsofParser` with zero warnings. Consecutive records that share pid, command
/// and user are written as one process set; each file set ends with NUL then LF, and every process
/// header ends with LF, so the output always ends in LF (the parser emits a final record only then).
/// Records the parser would never emit (pid 0 or empty `pathBytes`) are skipped.
public enum LsofPrinter {
    private static let nul: UInt8 = 0
    private static let lineFeed: UInt8 = 10
    private static let backslash: UInt8 = 92

    /// Serializes `records` in order. Never throws or traps.
    public static func print(_ records: [RawLsofRecord]) -> Data {
        var output = Data()
        var previous: RawLsofRecord?
        for record in records where record.pid != 0 && !record.pathBytes.isEmpty {
            if !isSameProcess(previous, record) {
                appendProcessHeader(record, to: &output)
            }
            appendFileSet(record, to: &output)
            previous = record
        }
        return output
    }

    private static func isSameProcess(_ previous: RawLsofRecord?, _ record: RawLsofRecord) -> Bool {
        guard let previous else { return false }
        return previous.pid == record.pid
            && previous.commandBytes == record.commandBytes
            && previous.user == record.user
    }

    private static func appendProcessHeader(_ record: RawLsofRecord, to output: inout Data) {
        appendField("p", Data(String(record.pid).utf8), to: &output)
        appendField("c", escaped(record.commandBytes), to: &output)
        if let user = record.user {
            appendField("L", plain(user), to: &output)
        }
        output.append(lineFeed)
    }

    private static func appendFileSet(_ record: RawLsofRecord, to output: inout Data) {
        appendField("f", plain(record.fileDescriptor), to: &output)
        if let mode = record.accessMode {
            appendField("a", plain(mode.rawValue), to: &output)
        }
        if let type = record.fileType {
            appendField("t", plain(type), to: &output)
        }
        appendField("n", escaped(record.pathBytes), to: &output)
        output.append(lineFeed)
    }

    private static func appendField(_ tag: Character, _ value: Data, to output: inout Data) {
        output.append(contentsOf: Array(String(tag).utf8))
        output.append(value)
        output.append(nul)
    }

    /// Fields that the parser does not unescape (`f`, `a`, `t`, `L`) cannot carry NUL or LF; drop them.
    private static func plain(_ text: String) -> Data {
        Data(text.utf8.filter { $0 != nul && $0 != lineFeed })
    }

    /// Escapes backslash as `\\` and control bytes (including NUL and LF) as three-digit octal.
    private static func escaped(_ bytes: Data) -> Data {
        var output = Data()
        output.reserveCapacity(bytes.count)
        for byte in bytes {
            if byte == backslash {
                output.append(backslash)
                output.append(backslash)
            } else if byte < 0x20 || byte == 0x7F {
                output.append(backslash)
                output.append(UInt8(ascii: "0") + (byte >> 6))
                output.append(UInt8(ascii: "0") + ((byte >> 3) & 7))
                output.append(UInt8(ascii: "0") + (byte & 7))
            } else {
                output.append(byte)
            }
        }
        return output
    }
}
