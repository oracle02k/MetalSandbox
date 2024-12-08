import SwiftUI

class Lifegame {
    private(set) var field = [Int]()
    private(set) lazy var gridWidth: Int = uninitialized()
    private(set) lazy var gridHeight: Int = uninitialized()
    var gridNum: Int {gridWidth * gridHeight}

    func reset(width: Int, height: Int) {
        self.gridWidth = width
        self.gridHeight = height
        self.field = [Int](repeating: 0, count: gridNum)

        for i in 0..<field.count {
            field[i] = .random(in: 0...1)
        }
    }

    func update() {
        var newField = [Int](repeating: 0, count: gridNum)
        let gw = gridWidth
        let pattern = [
            [-gw-1, -gw, -gw+1, -1, +1, +gw-1, +gw, +gw+1], // free case 0b00000000:
            [-gw, -gw+1, +1, +gw, +gw+1], // left case 0b00000001:
            [-1, +1, +gw-1, +gw, +gw+1], // top case 0b00000010:
            [+1, +gw, +gw+1], // left top case 0b00000011:
            [-gw-1, -gw, -1, +gw-1, +gw], // right case 0b00000100:
            [-gw, +gw], // left right case 0b00000101:
            [-1, +gw-1, +gw], // right top case 0b00000110:
            [+gw], // left right top case 0b00000111:
            [-gw-1, -gw, -gw+1, -1, +1], // bottom case 0b00001000:
            [-gw, -gw+1, +1], // left bottom case 0b00001001:
            [-1, +1], // top bottom case 0b00001010:
            [+1], // left top bottom case 0b00001011:
            [-gw-1, -gw, -1], // right bottom case 0b00001100:
            [-gw], // left right bottom case 0b00001101:
            [-1], // right top bottom case 0b00001110:
            [] // left right top bottom case 0b00001111:
        ]

        for i in 0..<field.count {
            let x = i%gridWidth
            let y = i/gridWidth

            var flags = 0
            flags |= x == 0 ? 1 << 0 : 0
            flags |= y == 0 ? 1 << 1 : 0
            flags |= x == gridWidth-1 ? 1 << 2 : 0
            flags |= y == gridHeight-1 ? 1 << 3 : 0

            let neighborhoodOffsets = pattern[flags]

            // 近傍状態取得
            var neighborhoodStatus = 0
            for offset in neighborhoodOffsets {
                neighborhoodStatus += field[i+offset]
            }

            neighborhoodStatus = neighborhoodStatus <= 4 ? neighborhoodStatus : 4

            let next = [0, 0, field[i], 1, 0]
            newField[i] = next[neighborhoodStatus]
        }
        field = newField
    }
}
