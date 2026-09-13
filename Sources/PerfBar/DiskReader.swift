import Foundation
import IOKit

final class DiskReader {
    private var previousRead: UInt64?
    private var previousWrite: UInt64?
    private var previousTime: Date?

    func sample() -> DiskSnapshot {
        guard let (read, write) = Self.readTotals() else {
            return DiskSnapshot(
                readPerSec: 0,
                writePerSec: 0,
                totalRead: previousRead ?? 0,
                totalWritten: previousWrite ?? 0
            )
        }

        let now = Date()
        var readRate: Double = 0
        var writeRate: Double = 0

        if let prevRead = previousRead, let prevWrite = previousWrite, let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                readRate = Double(byteDelta(read, prevRead)) / elapsed
                writeRate = Double(byteDelta(write, prevWrite)) / elapsed
            }
        }

        previousRead = read
        previousWrite = write
        previousTime = now

        return DiskSnapshot(
            readPerSec: readRate,
            writePerSec: writeRate,
            totalRead: read,
            totalWritten: write
        )
    }

    private func byteDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    private static func readTotals() -> (UInt64, UInt64)? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let properties = Self.properties(of: service),
               let statistics = properties["Statistics"] as? [String: Any] {
                totalRead += (statistics["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                totalWrite += (statistics["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return (totalRead, totalWrite)
    }

    private static func properties(of service: io_registry_entry_t) -> [String: Any]? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = unmanaged?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}
