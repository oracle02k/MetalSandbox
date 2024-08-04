import PlaygroundTester
import MetalKit

@objcMembers
final class TestAlignedBuffer: TestCase {
    struct Padding {
        let a: UInt8 // 1byte
        // 3 byte padding
        let b: UInt32 // 4byte
        let c: UInt8 // 1byte
        let d: UInt8 // 1byte
        // 2byte padding
    };
    
    func testAlignedByteSize() {
        let alignedBuffer = AlignedBuffer(count: 4, align: 16) as AlignedBuffer<Padding>
        let byteSize = alignedBuffer.byteSize
        
        NAssertEqual(64, actual: byteSize)
    }
    
    func testAlignedAccess() {
        let alignedBuffer = AlignedBuffer(count: 4, align: 16) as AlignedBuffer<Padding>
        let byteSize = alignedBuffer.byteSize
        let alignment = alignedBuffer.align
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: byteSize, alignment: alignment)
    
        alignedBuffer.bind(pointer: pointer)
        alignedBuffer[0] = .init(a: 0, b: 1, c: 2, d: 3)
        alignedBuffer[1] = .init(a: 4, b: 5, c: 6, d: 7)
        
        NAssertEqual(4, actual: alignedBuffer[1].a)
        NAssertEqual(5, actual: alignedBuffer[1].b)
        NAssertEqual(6, actual: alignedBuffer[1].c)
        NAssertEqual(7, actual: alignedBuffer[1].d)
    }
    
}
