import SwiftUI

@main
struct PerfBarApp: App {
    @StateObject private var store = MonitorStore()

    init() {
        if CommandLine.arguments.contains("--dump") {
            Self.dump()
            exit(0)
        }
    }

    private static func dump() {
        let cpu = CPUReader()
        let memory = MemoryReader()
        let disk = DiskReader()
        let network = NetworkReader()
        let processReader = ProcessReader()
        let thermal = SMCReader()

        _ = cpu.sample()
        _ = disk.sample()
        _ = network.sample()
        Thread.sleep(forTimeInterval: 1.0)

        let cpuSnapshot = cpu.sample()
        let memorySnapshot = memory.sample()
        let diskSnapshot = disk.sample()
        let networkSnapshot = network.sample()

        print("== CPU ==")
        print("总占用: \(formatPercent(cpuSnapshot.total))  核心: \(cpuSnapshot.coreCount)")
        print("负载: \(String(format: "%.2f %.2f %.2f", cpuSnapshot.load1, cpuSnapshot.load5, cpuSnapshot.load15))")
        print("核心明细: " + cpuSnapshot.perCore.map { formatPercent($0) }.joined(separator: " "))

        print("== 内存 ==")
        print("已用: \(formatBytes(memorySnapshot.used)) / \(formatBytes(memorySnapshot.total)) (\(formatPercent(memorySnapshot.usage)))")
        print("App: \(formatBytes(memorySnapshot.app))  联动: \(formatBytes(memorySnapshot.wired))  压缩: \(formatBytes(memorySnapshot.compressed))")
        print("交换区: \(formatBytes(memorySnapshot.swapUsed)) / \(formatBytes(memorySnapshot.swapTotal))")

        print("== 磁盘 ==")
        print("读: \(formatRate(diskSnapshot.readPerSec))  写: \(formatRate(diskSnapshot.writePerSec))")
        print("累计读: \(formatBytes(diskSnapshot.totalRead))  累计写: \(formatBytes(diskSnapshot.totalWritten))")

        print("== 网络 ==")
        print("下载: \(formatRate(networkSnapshot.downPerSec))  上传: \(formatRate(networkSnapshot.upPerSec))")
        print("累计下载: \(formatBytes(networkSnapshot.totalDown))  累计上传: \(formatBytes(networkSnapshot.totalUp))")

        print("== 温度 / 风扇 ==")
        let thermalSnapshot = thermal.sample()
        if thermalSnapshot.available {
            print("最高: \(thermalSnapshot.maxTemp.map { String(format: "%.1f°C", $0) } ?? "—")  平均: \(thermalSnapshot.averageTemp.map { String(format: "%.1f°C", $0) } ?? "—")")
            for fan in thermalSnapshot.fans {
                print("风扇 \(fan.id + 1): \(String(format: "%.0f RPM", fan.rpm))")
            }
            if thermalSnapshot.fans.isEmpty { print("无风扇") }
        } else {
            print("SMC 不可用")
        }

        print("== Top 进程 ==")
        for process in processReader.sample(limit: 8) {
            print(String(format: "%@  pid=%d  cpu=%.1f%%  mem=%.1f%%", process.name, process.pid, process.cpu, process.mem))
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
