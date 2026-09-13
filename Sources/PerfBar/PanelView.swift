import SwiftUI
import AppKit

struct PanelView: View {
    @ObservedObject var store: MonitorStore
    @State private var hoveredHelp: HelpRequest?
    @State private var bubbleHeight: CGFloat = 44

    private var snapshot: SystemSnapshot { store.snapshot }

    private let panelWidth: CGFloat = 360
    private let panelHeight: CGFloat = 620

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Divider()
                    cpuSection
                    Divider()
                    memorySection
                    Divider()
                    storageSection
                    Divider()
                    thermalSection
                    Divider()
                    processSection
                    Divider()
                    footer
                }
                .padding(16)
            }
            .environment(\.hoverHelp, { hoveredHelp = $0 })

            if let help = hoveredHelp {
                let width: CGFloat = 300
                let gap: CGFloat = 6
                let below = help.frame.maxY + gap
                let placeBelow = below + bubbleHeight + 8 <= panelHeight
                let rawY = placeBelow ? below : help.frame.minY - bubbleHeight - gap
                let y = min(max(rawY, 8), panelHeight - bubbleHeight - 8)
                let x = min(max(help.frame.minX - 10, 8), panelWidth - width - 8)

                HelpBubble(text: help.text)
                    .frame(width: width, alignment: .leading)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: BubbleHeightKey.self, value: proxy.size.height)
                        }
                    )
                    .offset(x: x, y: y)
                    .allowsHitTesting(false)
                    .onPreferenceChange(BubbleHeightKey.self) { bubbleHeight = $0 }
                    .transition(.opacity)
            }
        }
        .coordinateSpace(name: "panel")
        .frame(width: panelWidth, height: panelHeight)
        .animation(.easeInOut(duration: 0.12), value: hoveredHelp)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("系统性能监控")
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !snapshot.hostName.isEmpty { parts.append(snapshot.hostName) }
        if snapshot.uptime > 0 { parts.append("已运行 " + formatUptime(snapshot.uptime)) }
        return parts.isEmpty ? "采集中…" : parts.joined(separator: " · ")
    }

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                icon: "cpu",
                title: "CPU",
                trailing: "\(snapshot.cpu.coreCount) 核心",
                help: "负载均值 = 最近 1 / 5 / 15 分钟内处于可运行或不可中断状态的进程平均数\n约等于核心数表示 CPU 刚好占满，超过说明有任务在排队等待\n1 分钟值明显高于 15 分钟值，说明负载正在上升"
            )
            HStack(alignment: .firstTextBaseline) {
                Text(formatPercent(snapshot.cpu.total))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(loadColor(snapshot.cpu.total))
                    .monospacedDigit()
                Spacer()
                Text("满载 ≈ \(snapshot.cpu.coreCount * 100)%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .hoverHelp("每个核心满载计 100%，\(snapshot.cpu.coreCount) 个核心合计 \(snapshot.cpu.coreCount * 100)%")
            }
            MeterBar(fraction: snapshot.cpu.total, color: loadColor(snapshot.cpu.total))
            Sparkline(values: snapshot.cpuHistory, color: loadColor(snapshot.cpu.total))
            CoreGrid(cores: snapshot.cpu.perCore)
            loadRow
        }
    }

    private var loadRow: some View {
        HStack(spacing: 0) {
            loadItem("1 分钟", snapshot.cpu.load1)
            loadItem("5 分钟", snapshot.cpu.load5)
            loadItem("15 分钟", snapshot.cpu.load15)
        }
    }

    private func loadItem(_ title: String, _ value: Double) -> some View {
        let fraction = value / Double(max(snapshot.cpu.coreCount, 1))
        return VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f", value))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(loadColor(fraction))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverHelp("\(title)平均负载 \(String(format: "%.2f", value))，约等于 \(snapshot.cpu.coreCount) 核中 \(String(format: "%.1f", value)) 个核心持续繁忙")
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                icon: "memorychip",
                title: "内存",
                trailing: "\(formatBytes(snapshot.memory.used)) / \(formatBytes(snapshot.memory.total))",
                help: "App 内存 = 应用与进程当前占用\n联动内存 = 不可换出的内核/驱动常驻内存\n已压缩 = 被内存压缩器压缩、可解压复用的内存\n交换区 = 磁盘上的虚拟内存使用量"
            )
            HStack(alignment: .firstTextBaseline) {
                Text(formatPercent(snapshot.memory.usage))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(loadColor(snapshot.memory.usage))
                    .monospacedDigit()
                Spacer()
                Text("可用 \(formatBytes(snapshot.memory.free))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            MeterBar(fraction: snapshot.memory.usage, color: loadColor(snapshot.memory.usage))
            Sparkline(values: snapshot.memHistory, color: loadColor(snapshot.memory.usage), height: 24)
            StatRow(label: "App 内存", value: formatBytes(snapshot.memory.app))
            StatRow(label: "联动内存", value: formatBytes(snapshot.memory.wired))
            StatRow(label: "已压缩", value: formatBytes(snapshot.memory.compressed))
            if snapshot.memory.swapTotal > 0 {
                StatRow(
                    label: "交换区",
                    value: "\(formatBytes(snapshot.memory.swapUsed)) / \(formatBytes(snapshot.memory.swapTotal))",
                    valueColor: snapshot.memory.swapUsage > 0.5 ? .orange : .primary
                )
            }
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                icon: "internaldrive",
                title: "磁盘 I/O",
                help: "读取 / 写入 = 当前每秒速率\n累计值 = 本次开机以来的总量"
            )
            HStack(alignment: .top, spacing: 0) {
                MetricBlock(title: "读取", value: formatRate(snapshot.disk.readPerSec), color: .blue)
                MetricBlock(title: "写入", value: formatRate(snapshot.disk.writePerSec), color: .purple)
            }
            StatRow(label: "本次启动累计读", value: formatBytes(snapshot.disk.totalRead))
            StatRow(label: "本次启动累计写", value: formatBytes(snapshot.disk.totalWritten))
            SectionHeader(
                icon: "network",
                title: "网络",
                help: "下载 / 上传 = 当前每秒速率\n累计值 = 本次开机以来的总量"
            )
            HStack(alignment: .top, spacing: 0) {
                MetricBlock(title: "下载", value: formatRate(snapshot.network.downPerSec), color: .green)
                MetricBlock(title: "上传", value: formatRate(snapshot.network.upPerSec), color: .orange)
            }
            StatRow(label: "累计下载", value: formatBytes(snapshot.network.totalDown))
            StatRow(label: "累计上传", value: formatBytes(snapshot.network.totalUp))
        }
    }

    private var thermalSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                icon: "thermometer",
                title: "温度 / 风扇",
                help: "数据来自 SMC 传感器\n最高 / 平均 = 各温度传感器读数\n风扇 = 当前转速 RPM"
            )
            if snapshot.thermal.available {
                HStack(alignment: .top, spacing: 0) {
                    MetricBlock(
                        title: "最高温度",
                        value: snapshot.thermal.maxTemp.map { String(format: "%.1f°C", $0) } ?? "—",
                        color: tempColor(snapshot.thermal.maxTemp)
                    )
                    MetricBlock(
                        title: "平均温度",
                        value: snapshot.thermal.averageTemp.map { String(format: "%.1f°C", $0) } ?? "—"
                    )
                }
                if snapshot.thermal.fans.isEmpty {
                    Text("未检测到风扇（或无风扇机型）")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.thermal.fans) { fan in
                        StatRow(
                            label: "风扇 \(fan.id + 1)",
                            value: String(format: "%.0f RPM", fan.rpm)
                        )
                    }
                }
            } else {
                Text("SMC 不可用，无法读取传感器")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(
                icon: "list.bullet",
                title: "占用最高进程",
                help: "CPU% = 进程自启动以来的平均占用（多核可超过 100%）\n内存% = 常驻内存占系统总内存的比例\n列表按 CPU 占用从高到低排序"
            )
            if snapshot.processes.isEmpty {
                Text("采集中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    Text("#")
                        .frame(width: 14, alignment: .trailing)
                    Text("进程")
                    Spacer(minLength: 8)
                    Text("CPU%")
                        .frame(width: 52, alignment: .trailing)
                        .hoverHelp("进程占用的 CPU 百分比。ps 统计的是自进程启动以来的平均占用，多核机器上可超过 100%（每个核心计 100%）")
                    Text("内存%")
                        .frame(width: 46, alignment: .trailing)
                        .hoverHelp("进程常驻物理内存（RSS）占系统总物理内存的百分比")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                ForEach(Array(snapshot.processes.enumerated()), id: \.element.id) { index, process in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14, alignment: .trailing)
                        Text(process.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(String(format: "%.1f%%", process.cpu))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(loadColor(process.cpu / 100))
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                        Text(String(format: "%.1f%%", process.mem))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("每 1.5 秒刷新")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .hoverHelp("CPU / 内存 / 磁盘 / 网络 = 每 1.5 秒采样\n进程 = 每 3 秒\n温度 / 风扇 = 每 4.5 秒\n传感器为只读")
            Spacer()
            Button {
                store.refresh()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.secondary)
    }

    private func tempColor(_ value: Double?) -> Color {
        guard let value else { return .primary }
        if value >= 90 { return .red }
        if value >= 75 { return .orange }
        return .green
    }
}
