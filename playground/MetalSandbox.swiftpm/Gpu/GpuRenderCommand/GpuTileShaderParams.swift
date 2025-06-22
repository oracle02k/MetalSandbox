import Metal

class GpuTileShaderParams {
    var tileSize: MTLSize = .init(width: 32, height: 16, depth: 1)
    private(set) var maxImageBlockSampleLength: Int = 0

    func setMaxImageBlockSampleLength(tryValue: Int) {
        if maxImageBlockSampleLength < tryValue {
            maxImageBlockSampleLength = tryValue
        }
    }

    func reset() {
        maxImageBlockSampleLength = 0
        tileSize = .init(width: 32, height: 16, depth: 1)
    }
}
