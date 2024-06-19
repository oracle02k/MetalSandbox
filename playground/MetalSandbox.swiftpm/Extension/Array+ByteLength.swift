extension Array {
    var byteLength: Int {
        return self.count * MemoryLayout.stride(ofValue: self[0])
    }
}
