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
    let model = DIContainer.resolve(StatsModel.self)
    let timer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section(header: Text("Stats.")) {
                StatsRow(name: "FPS", value: model.fps)
                StatsRow(name: "Delta", value: model.dt)
                StatsRow(name: "CPU", value: model.cpuUsage)
                StatsRow(name: "MEM", value: model.memoryUsed)
            }
        }
        .onReceive(timer, perform: { _ in
            model.refresh()
        })
    }
}
