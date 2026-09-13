import Foundation

struct CPUSnapshot {
    var total: Double = 0
    var perCore: [Double] = []
    var coreCount: Int = 0
    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0

    static let empty = CPUSnapshot()
}

struct MemorySnapshot {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var free: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0

    var usage: Double { total > 0 ? Double(used) / Double(total) : 0 }
    var swapUsage: Double { swapTotal > 0 ? Double(swapUsed) / Double(swapTotal) : 0 }

    static let empty = MemorySnapshot()
}

struct DiskSnapshot {
    var readPerSec: Double = 0
    var writePerSec: Double = 0
    var totalRead: UInt64 = 0
    var totalWritten: UInt64 = 0

    static let empty = DiskSnapshot()
}

struct NetworkSnapshot {
    var downPerSec: Double = 0
    var upPerSec: Double = 0
    var totalDown: UInt64 = 0
    var totalUp: UInt64 = 0

    static let empty = NetworkSnapshot()
}

struct FanReading: Identifiable {
    let id: Int
    var rpm: Double
    var minRPM: Double
    var maxRPM: Double
}

struct ThermalSnapshot {
    var available = false
    var maxTemp: Double?
    var averageTemp: Double?
    var fans: [FanReading] = []

    static let empty = ThermalSnapshot()
}

struct ProcessReading: Identifiable {
    let id: Int32
    var name: String
    var cpu: Double
    var mem: Double

    var pid: Int32 { id }
}

struct SystemSnapshot {
    var cpu = CPUSnapshot.empty
    var memory = MemorySnapshot.empty
    var disk = DiskSnapshot.empty
    var network = NetworkSnapshot.empty
    var thermal = ThermalSnapshot.empty
    var processes: [ProcessReading] = []
    var cpuHistory: [Double] = []
    var memHistory: [Double] = []
    var uptime: TimeInterval = 0
    var hostName = ""

    static let empty = SystemSnapshot()
}
