import Foundation
import Darwin

final class NetworkReader {
    private var previousDown: UInt64?
    private var previousUp: UInt64?
    private var previousTime: Date?

    func sample() -> NetworkSnapshot {
        guard let (down, up) = Self.readTotals() else {
            return NetworkSnapshot(
                downPerSec: 0,
                upPerSec: 0,
                totalDown: previousDown ?? 0,
                totalUp: previousUp ?? 0
            )
        }

        let now = Date()
        var downRate: Double = 0
        var upRate: Double = 0

        if let prevDown = previousDown, let prevUp = previousUp, let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                downRate = Double(byteDelta(down, prevDown)) / elapsed
                upRate = Double(byteDelta(up, prevUp)) / elapsed
            }
        }

        previousDown = down
        previousUp = up
        previousTime = now

        return NetworkSnapshot(
            downPerSec: downRate,
            upPerSec: upRate,
            totalDown: down,
            totalUp: up
        )
    }

    private func byteDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        if current >= previous { return current - previous }
        let previous32 = previous & 0xFFFF_FFFF
        let current32 = current & 0xFFFF_FFFF
        return 0x1_0000_0000 - previous32 + current32
    }

    private static func readTotals() -> (UInt64, UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var down: UInt64 = 0
        var up: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            if let address = interface.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK) {
                let flags = Int32(interface.ifa_flags)
                let isLoopback = (flags & IFF_LOOPBACK) != 0
                if !isLoopback, let data = interface.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    down += UInt64(stats.ifi_ibytes)
                    up += UInt64(stats.ifi_obytes)
                }
            }
            pointer = interface.ifa_next
        }
        return (down, up)
    }
}
