import Foundation

func formatPercent(_ fraction: Double) -> String {
    String(format: "%.0f%%", max(0, min(1, fraction)) * 100)
}

func formatBytes(_ bytes: UInt64) -> String {
    let value = Double(bytes)
    let units = ["B", "KB", "MB", "GB", "TB"]
    var index = 0
    var scaled = value
    while scaled >= 1024 && index < units.count - 1 {
        scaled /= 1024
        index += 1
    }
    if index == 0 { return "\(bytes) B" }
    return String(format: "%.1f %@", scaled, units[index])
}

func formatRate(_ bytesPerSecond: Double) -> String {
    guard bytesPerSecond >= 0 else { return "0 B/s" }
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var scaled = bytesPerSecond
    var index = 0
    while scaled >= 1024 && index < units.count - 1 {
        scaled /= 1024
        index += 1
    }
    if index == 0 { return String(format: "%.0f B/s", scaled) }
    return String(format: "%.1f %@", scaled, units[index])
}

func formatUptime(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    let days = total / 86400
    let hours = (total % 86400) / 3600
    let minutes = (total % 3600) / 60
    if days > 0 { return "\(days)天\(hours)小时" }
    if hours > 0 { return "\(hours)小时\(minutes)分" }
    return "\(minutes)分"
}
