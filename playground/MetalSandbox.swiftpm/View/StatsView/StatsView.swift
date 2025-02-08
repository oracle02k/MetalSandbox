import SwiftUI

struct StatsRow: View {
    let name: String
    var value: String
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
        }
    }
}

struct StatsView: View {
    let statsStore = DIContainer.resolve(StatsStore.self)
    let timer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            let stats = statsStore.stats
            Section(header: Text("Stats.")) {
                StatsRow(name: "FPS", value: String(format: "%.2ffps", stats.fps))
                StatsRow(name: "Delta", value: String(format: "%.2fms", stats.dt))
                StatsRow(name: "CPU", value: String(format: "%.2f%%", stats.cpuUsage))
                StatsRow(name: "MEM", value: String(format: "%dKB", stats.memoryUsed))
            }
        }
        .onReceive(timer, perform: { _ in
            statsStore.refresh()
        })
    }
}
