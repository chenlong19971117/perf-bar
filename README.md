# Perf Bar

macOS 菜单栏系统性能监视器。常驻菜单栏，实时显示 CPU 与内存占用，点开即可查看磁盘 I/O、网络流量、温度/风扇和占用最高的进程。

纯 Swift / SwiftUI 编写，无第三方依赖。

## 功能

- **CPU**：总体占用、每核心占用柱状图、实时曲线、负载均值（1 / 5 / 15 分钟）
- **内存**：已用/总量、App 内存、联动内存、已压缩内存、交换区、历史曲线
- **磁盘 I/O**：实时读写速率、本次开机累计读写
- **网络**：实时上下行速率、本次开机累计流量
- **温度 / 风扇**：通过 SMC 读取最高/平均温度与各风扇转速
- **占用最高进程**：按 CPU 占用排序的进程列表（CPU% 与内存%）
- **菜单栏标签**：直接显示 `CPU% · 内存%`，无需点开

## 环境要求

- macOS 14 (Sonoma) 或更高版本
- Swift 5.9+（Xcode Command Line Tools 即可）
- 温度 / 风扇读取依赖 AppleSMC，Apple Silicon 上验证通过

## 构建与运行

```bash
# 构建 release 并打包为 .app
./build.sh

# 构建并立即启动
./build.sh --run
```

产物位于 `build/Perf Bar.app`。也可用 SwiftPM 直接运行（无 app bundle）：

```bash
swift run
```

### 安装到「应用程序」

```bash
cp -R "build/Perf Bar.app" /Applications/
```

之后可用 Spotlight（`⌘空格` → `Perf Bar`）启动。

### 开机自启

系统设置 → 通用 → 登录项 → 「+」添加 `Perf Bar.app`。

## 调试：命令行输出全部指标

```bash
.build/release/PerfBar --dump
```

会打印一次当前 CPU / 内存 / 磁盘 / 网络 / 温度 / 进程快照，便于排查。

## 指标说明

**CPU 负载均值**：最近 1 / 5 / 15 分钟内处于可运行或不可中断状态的进程平均数。数值约等于核心数表示 CPU 刚好占满，超过说明有任务在排队；1 分钟值明显高于 15 分钟值，说明负载正在上升。

**进程 CPU%**：`ps` 统计的是进程自进程启动以来的平均占用，并非瞬时值；多核机器上单进程可超过 100%（每个核心计 100%）。

**进程内存%**：进程常驻物理内存（RSS）占系统总物理内存的百分比。

**内存各项**：App 内存 = 应用与进程当前占用；联动内存 = 不可换出的内核/驱动常驻内存；已压缩 = 被内存压缩器压缩、可解压复用的内存；交换区 = 磁盘上的虚拟内存使用量。

**温度 / 风扇**：数据来自 SMC 传感器，只读。

## 采样频率

- CPU / 内存 / 磁盘 / 网络：每 1.5 秒
- 进程：每 3 秒
- 温度 / 风扇：每 4.5 秒

采样在后台串行队列执行，不阻塞界面。

## 项目结构

```
Sources/PerfBar/
├── PerfBarApp.swift     # App 入口、MenuBarExtra、--dump 调试模式
├── MonitorStore.swift   # 采样管线与定时器
├── PanelView.swift      # 下拉面板 UI
├── MenuBarLabel.swift   # 菜单栏标签
├── Components.swift     # 复用组件（进度条、曲线、核心网格、悬停提示等）
├── Models.swift         # 数据模型
├── Formatters.swift     # 格式化函数
├── CPUReader.swift      # CPU 占用与负载
├── MemoryReader.swift   # 内存与交换区
├── DiskReader.swift     # 磁盘 I/O（IOKit）
├── NetworkReader.swift  # 网络流量
├── ProcessReader.swift  # 进程列表（ps）
└── SMCReader.swift      # 温度 / 风扇（AppleSMC）
```

## 实现备注

- SMC 的 `SMCKeyData_t` 结构体必须严格为 80 字节；Swift 不保留嵌套 C 结构体的尾部填充，因此采用扁平结构体加显式 padding。
- Apple Silicon 上 SMC `flt ` 类型为小端序，代码通过数值合理性判断兼容 Intel 的大端序。
- `build.sh` 使用 ad-hoc 签名（`codesign --sign -`），首次打开如被 Gatekeeper 拦截，可在「系统设置 → 隐私与安全性」中允许。
