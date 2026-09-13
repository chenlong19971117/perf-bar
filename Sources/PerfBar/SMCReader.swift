import Foundation
import IOKit

// Must match the C layout of SMCKeyData_t exactly (80 bytes). Swift does not
// preserve the tail padding of nested C structs, so the layout is flattened
// with explicit padding fields.
private struct SMCKeyData {
    var key: UInt32 = 0
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
    var pad0: UInt16 = 0
    var plVersion: UInt16 = 0
    var plLength: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var pad1a: UInt8 = 0
    var pad1b: UInt8 = 0
    var pad1c: UInt8 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var pad2: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

private struct SMCKeyInfo {
    var dataSize: UInt32
    var dataType: UInt32
}

final class SMCReader {
    private let kernelSelector: UInt32 = 2
    private let commandReadKey: UInt8 = 5
    private let commandKeyFromIndex: UInt8 = 8
    private let commandKeyInfo: UInt8 = 9

    private var connection: io_connect_t = 0
    private var opened = false
    private var cachedTemperatureKeys: [String]?

    init() {
        open()
    }

    deinit {
        if opened {
            IOServiceClose(connection)
        }
    }

    func sample() -> ThermalSnapshot {
        guard opened else { return .empty }

        let temperatures = readTemperatures()
        let fans = readFans()

        return ThermalSnapshot(
            available: true,
            maxTemp: temperatures.max,
            averageTemp: temperatures.average,
            fans: fans
        )
    }

    private func open() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else { return }
        connection = conn
        opened = true
    }

    private func call(_ input: inout SMCKeyData, _ output: inout SMCKeyData) -> kern_return_t {
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let inputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(connection, kernelSelector, &input, inputSize, &output, &outputSize)
    }

    private func keyInfo(_ key: UInt32) -> SMCKeyInfo? {
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = key
        input.data8 = commandKeyInfo
        guard call(&input, &output) == KERN_SUCCESS, output.dataSize > 0 else { return nil }
        return SMCKeyInfo(dataSize: output.dataSize, dataType: output.dataType)
    }

    private func readBytes(_ key: UInt32, size: UInt32) -> [UInt8]? {
        guard size > 0, size <= 32 else { return nil }
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = key
        input.dataSize = size
        input.data8 = commandReadKey
        guard call(&input, &output) == KERN_SUCCESS else { return nil }
        return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(size))) }
    }

    private func readValue(_ key: String) -> Double? {
        let code = fourCC(key)
        guard let info = keyInfo(code),
              let bytes = readBytes(code, size: info.dataSize),
              let type = string(fromKey: info.dataType) else { return nil }
        return decode(type: type, bytes: bytes)
    }

    private func readTemperatures() -> (max: Double?, average: Double?) {
        if cachedTemperatureKeys == nil {
            let allKeys = enumerateKeys().filter { $0.hasPrefix("T") && $0.count == 4 }
            let prefixes = ["Tp", "Te", "Tg", "Tc", "Tf", "Ts", "TP", "TC", "TA", "TG", "TB"]
            let preferred = allKeys.filter { key in prefixes.contains { key.hasPrefix($0) } }
            cachedTemperatureKeys = preferred.isEmpty ? allKeys : preferred
        }
        guard let keys = cachedTemperatureKeys, !keys.isEmpty else { return (nil, nil) }

        var values: [Double] = []
        for key in keys {
            if let value = readValue(key), value > 1, value < 125 {
                values.append(value)
            }
        }
        guard !values.isEmpty else { return (nil, nil) }
        return (values.max(), values.reduce(0, +) / Double(values.count))
    }

    private func readFans() -> [FanReading] {
        guard let countValue = readValue("FNum") else { return [] }
        let count = Int(countValue)
        guard count > 0, count <= 10 else { return [] }

        var fans: [FanReading] = []
        for index in 0..<count {
            guard let rpm = readValue("F\(index)Ac") else { continue }
            let minRPM = readValue("F\(index)Mn") ?? 0
            let maxRPM = readValue("F\(index)Mx") ?? 0
            fans.append(FanReading(id: index, rpm: rpm, minRPM: minRPM, maxRPM: maxRPM))
        }
        return fans
    }

    private func enumerateKeys() -> [String] {
        guard let countValue = readValue("#KEY") else { return [] }
        let count = Int(countValue)
        guard count > 0, count <= 100_000 else { return [] }

        var keys: [String] = []
        for index in 0..<count {
            var input = SMCKeyData()
            var output = SMCKeyData()
            input.data8 = commandKeyFromIndex
            input.data32 = UInt32(index)
            guard call(&input, &output) == KERN_SUCCESS else { continue }
            if let key = string(fromKey: output.key) {
                keys.append(key)
            }
        }
        return keys
    }

    private func fourCC(_ string: String) -> UInt32 {
        var value: UInt32 = 0
        for byte in string.utf8 {
            value = (value << 8) + UInt32(byte)
        }
        return value
    }

    private func string(fromKey key: UInt32) -> String? {
        var characters: [UInt8] = []
        for shift in stride(from: 24, through: 0, by: -8) {
            let byte = UInt8((key >> UInt32(shift)) & 0xFF)
            guard byte != 0 else { return nil }
            characters.append(byte)
        }
        return String(bytes: characters, encoding: .ascii)
    }

    private func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        case "sp87":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 128.0
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bigEndian = Float(
                bitPattern: UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            )
            let littleEndian = Float(
                bitPattern: UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
            )
            // SMC stores floats little-endian on Apple Silicon and big-endian on
            // Intel Macs. Pick whichever interpretation is physically plausible.
            for candidate in [littleEndian, bigEndian]
            where candidate.isFinite && (candidate == 0 || (abs(candidate) >= 1e-6 && abs(candidate) <= 1e6)) {
                return Double(candidate)
            }
            return Double(littleEndian)
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return Double(raw)
        case "ui8 ":
            return bytes.first.map(Double.init)
        case "si8 ":
            guard let first = bytes.first else { return nil }
            return Double(Int8(bitPattern: first))
        default:
            return nil
        }
    }
}
