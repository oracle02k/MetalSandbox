import Metal

class GpuPipeline {
    var passNodes = [GpuPassNode]()
    
    func registerNode(_ node: GpuPassNode){
        passNodes.append(node)
    }
    
    func registerNode(_ nodes: [GpuPassNode]){
        passNodes.append(contentsOf: nodes)
    }
    
    func dispatch(to commandBuffer: MTLCommandBuffer){
        for node in topologicalSort(nodes: passNodes) {
            node.pass.dispatch(commandBuffer)
        }
    }
    
    private func topologicalSort(nodes: [GpuPassNode]) -> [GpuPassNode] {
        // グラフの構造を作成
        var incomingEdges: [GpuPassNode: Int] = [:]        // 入ってくる依存の数
        var adjacencyList: [GpuPassNode: [GpuPassNode]] = [:]   // 出ていく先（依存先）
        
        for node in nodes {
            incomingEdges[node, default: 0] += 0 // 初期化（依存0でも入れる）
            for dep in node.dependencies {
                adjacencyList[dep, default: []].append(node)
                incomingEdges[node, default: 0] += 1
            }
        }
        
        // 依存がないノードをキューに追加
        var queue = incomingEdges.filter { $0.value == 0 }.map { $0.key }
        var result: [GpuPassNode] = []
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            
            for neighbor in adjacencyList[current] ?? [] {
                incomingEdges[neighbor]! -= 1
                if incomingEdges[neighbor]! == 0 {
                    queue.append(neighbor)
                }
            }
        }
        
        // ソートされたノード数が元のノード数と一致すれば成功
        guard result.count == nodes.count else{
            abort() // ループあり
        }
        
        return  result
    }
    
    }
