import Foundation

final class MonitorStore: ObservableObject {
    @Published var snapshot = SystemSnapshot.empty

    private let queue = DispatchQueue(label: "com.local.perfbar.sample", qos: .utility)
    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()
    private let diskReader = DiskReader()
    private let networkReader = NetworkReader()
    private let processReader = ProcessReader()
    private let thermalReader = SMCReader()

    private var timer: Timer?
    private var tick = 0
    private var processes: [ProcessReading] = []
    private var thermal = ThermalSnapshot.empty
    private var cpuHistory: [Double] = []
    private var memHistory: [Double] = []
    private let historyLimit = 60

    init() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }

            let cpu = self.cpuReader.sample()
            let memory = self.memoryReader.sample()
            let disk = self.diskReader.sample()
            let network = self.networkReader.sample()

            if self.tick % 2 == 0 {
                self.processes = self.processReader.sample()
            }
            if self.tick % 3 == 0 {
                self.thermal = self.thermalReader.sample()
            }

            self.cpuHistory.append(cpu.total)
            self.memHistory.append(memory.usage)
            if self.cpuHistory.count > self.historyLimit {
                self.cpuHistory.removeFirst(self.cpuHistory.count - self.historyLimit)
            }
            if self.memHistory.count > self.historyLimit {
                self.memHistory.removeFirst(self.memHistory.count - self.historyLimit)
            }
            self.tick += 1

            var snapshot = SystemSnapshot()
            snapshot.cpu = cpu
            snapshot.memory = memory
            snapshot.disk = disk
            snapshot.network = network
            snapshot.thermal = self.thermal
            snapshot.processes = self.processes
            snapshot.cpuHistory = self.cpuHistory
            snapshot.memHistory = self.memHistory
            snapshot.uptime = ProcessInfo.processInfo.systemUptime
            snapshot.hostName = ProcessInfo.processInfo.hostName

            DispatchQueue.main.async {
                self.snapshot = snapshot
            }
        }
    }
}
