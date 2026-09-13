import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var store: MonitorStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.50percent")
            Text(text).monospacedDigit()
        }
    }

    private var text: String {
        let cpu = Int((store.snapshot.cpu.total * 100).rounded())
        let mem = Int((store.snapshot.memory.usage * 100).rounded())
        return "\(cpu)% · \(mem)%"
    }
}
