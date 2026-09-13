import Darwin

final class CPUReader {
    private var previousTicks: [UInt64] = []

    func sample() -> CPUSnapshot {
        var snapshot = readTicks()
        if previousTicks.isEmpty {
            previousTicks = snapshot.ticks
            usleep(150_000)
            snapshot = readTicks()
        }

        let coreCount = snapshot.coreCount
        var perCore = [Double](repeating: 0, count: coreCount)
        if previousTicks.count == snapshot.ticks.count {
            for core in 0..<coreCount {
                let base = core * 4
                let user = delta(snapshot.ticks[base + 0], previousTicks[base + 0])
                let system = delta(snapshot.ticks[base + 1], previousTicks[base + 1])
                let idle = delta(snapshot.ticks[base + 2], previousTicks[base + 2])
                let nice = delta(snapshot.ticks[base + 3], previousTicks[base + 3])
                let busy = user + system + nice
                let total = busy + idle
                perCore[core] = total > 0 ? Double(busy) / Double(total) : 0
            }
        }
        previousTicks = snapshot.ticks

        let average = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)
        let loads = loadAverages()

        return CPUSnapshot(
            total: average,
            perCore: perCore,
            coreCount: coreCount,
            load1: loads.0,
            load5: loads.1,
            load15: loads.2
        )
    }

    private func readTicks() -> (ticks: [UInt64], coreCount: Int) {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return ([], 0)
        }

        defer {
            let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let coreCount = Int(numCPUs)
        var ticks = [UInt64](repeating: 0, count: coreCount * 4)
        for core in 0..<coreCount {
            let base = core * 4
            for state in 0..<4 {
                ticks[base + state] = UInt64(UInt32(bitPattern: info[base + state]))
            }
        }
        return (ticks, coreCount)
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    private func loadAverages() -> (Double, Double, Double) {
        var loads = [Double](repeating: 0, count: 3)
        let count = loads.withUnsafeMutableBufferPointer { pointer -> Int32 in
            getloadavg(pointer.baseAddress, 3)
        }
        guard count == 3 else { return (0, 0, 0) }
        return (loads[0], loads[1], loads[2])
    }
}
