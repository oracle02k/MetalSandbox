class GpuPassNode : Hashable {
    let pass: GpuPass
    let dependencies:[GpuPassNode]
    
    init(_ pass: GpuPass, dependencies:[GpuPassNode] = []){
        self.pass = pass
        self.dependencies = dependencies
    }
    
    static func == (lhs: GpuPassNode, rhs: GpuPassNode) -> Bool {
        return lhs === rhs // 参照比較
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
