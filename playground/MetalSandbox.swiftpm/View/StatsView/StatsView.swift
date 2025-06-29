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
    let timer = Timer.publish(every: 1/10, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            let stats = statsStore.stats
            Section(header: Text("Common")) {
                StatsRow(name: "FPS", value: String(format: "%.2ffps", stats.fps))
                StatsRow(name: "Delta", value: String(format: "%.2fms", stats.dt))
                StatsRow(name: "CPU", value: String(format: "%.2f%%", stats.cpuUsage))
                StatsRow(name: "MEM", value: String(format: "%dKB", stats.memoryUsed))
                StatsRow(name: "GPU", value: String(format: "%0.2fms", stats.gpuTime))
                StatsRow(name: "VRAM", value: String(format: "%dKB", stats.vram))
            }
            ForEach(stats.counterSampleReportGroups, id: \.name) { group in
                Section(header: Text(group.name)) {
                    ForEach(group.reports, id: \.type) { report in
                        let name = switch report.type {
                        case .VertexTime: "vs"
                        case .FragmentTime: "fs"
                        case .ComputeTime: "cs"
                        case .BlitTime: "blit"
                        }
                        StatsRow(name: name, value: String(format: "%.2fms", report.interval))
                    }
                }
            }
        }
        .onReceive(timer, perform: { _ in
            statsStore.refresh()
        })
    }
}
