import SwiftUI

class Lifegame {
    var field = [Int]()
    var newField = [Int]()
    var pattern = [[Int]]()
    var gridWidth: Int = 0
    var gridHeight: Int = 0
    var gridNum:Int = 0
    var writer = AlignedBuffer<Int>(count:0)
    
    func reset(width: Int, height: Int) {
        self.gridNum = width * height
        self.gridWidth = width
        self.gridHeight = height
        self.field = [Int](repeating: 0, count: gridNum)
        self.newField = [Int](repeating: 0, count: gridNum)
        self.pattern = genPattern()
        
        for i in 0..<field.count {
            field[i] = .random(in: 0...1)
        }
        
        writer = AlignedBuffer<Int>(count: gridNum)
        writer.bind(pointer: &newField)
    }
    
    private func genPattern() -> [[Int]]{
        let gw = gridWidth
        return [
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
    }
}

class LifegameProc {
    let lifegame = Lifegame()
    var field = [Int]()
    
    func reset(width: Int, height: Int) {
        lifegame.reset(width: width, height: height)
        field = lifegame.field
    }
    
    func update() {
        let queue = OperationQueue()
        queue.name = "com.example.queue"
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        var operations: [UpdateOperation] = []
        
        let divCount = 4
        let divSize = lifegame.gridNum / divCount
        for i in 0..<divCount {
            let start = i * divSize
            let end = i == divCount-1 ? lifegame.gridNum : start + divSize
            operations.append(UpdateOperation(lifegame: lifegame, range: start..<end))
        }
        
        queue.addOperations(operations, waitUntilFinished: true)
        
        lifegame.field = lifegame.newField
        field = lifegame.field
    }
}


class UpdateOperation: Operation {
    let lifegame:Lifegame
    let range:Range<Int>
    
    init(lifegame: Lifegame, range: Range<Int>) {
        self.lifegame = lifegame
        self.range = range
    }
    
    override func main() {
        for i in range {
            let x = i%lifegame.gridWidth
            let y = i/lifegame.gridWidth
            
            var flags = 0
            flags |= x == 0 ? 1 << 0 : 0
            flags |= y == 0 ? 1 << 1 : 0
            flags |= x == lifegame.gridWidth-1 ? 1 << 2 : 0
            flags |= y == lifegame.gridHeight-1 ? 1 << 3 : 0
            
            let neighborhoodOffsets = lifegame.pattern[flags]
            
            // 近傍状態取得
            var neighborhoodStatus = 0
            for offset in neighborhoodOffsets {
                neighborhoodStatus += lifegame.field[i+offset]
            }
            
            neighborhoodStatus = neighborhoodStatus <= 4 ? neighborhoodStatus : 4
            
            let next = [0, 0, lifegame.field[i], 1, 0]
            lifegame.writer.write(i, value: next[neighborhoodStatus])
        }
    }
}
