import PlaygroundTester
import MetalKit

@objcMembers
final class TestSize: TestCase {
    struct Padding {
        let a: UInt8 // 1byte
        // 3 byte padding
        let b: UInt32 // 4byte
        let c: UInt8 // 1byte
        let d: UInt8 // 1byte
        // 2byte padding
    }

    func testSizeof() {
        NAssertEqual(1, actual: sizeof(UInt8.self))
        NAssertEqual(2, actual: sizeof(UInt16.self))
        NAssertEqual(4, actual: sizeof(UInt32.self))
        NAssertEqual(8, actual: sizeof(UInt64.self))
        NAssertEqual(12, actual: sizeof(Padding.self))
    }

    func testAlignof() {
        NAssertEqual(1, actual: alignof(UInt8.self))
        NAssertEqual(2, actual: alignof(UInt16.self))
        NAssertEqual(4, actual: alignof(UInt32.self))
        NAssertEqual(8, actual: alignof(UInt64.self))
        NAssertEqual(4, actual: alignof(Padding.self))
    }

    func testAlign() {
        NAssertEqual(16, actual: align(1, 16))
        NAssertEqual(16, actual: align(2, 16))
        NAssertEqual(16, actual: align(4, 16))
        NAssertEqual(16, actual: align(8, 16))
        NAssertEqual(16, actual: align(16, 16))
        NAssertEqual(32, actual: align(24, 16))
        NAssertEqual(32, actual: align(32, 16))
        NAssertEqual(16, actual: align(sizeof(Padding.self), 16))
    }

    func testSimd() {
        NAssertEqual(4, actual: sizeof(simd_float1.self))
        NAssertEqual(8, actual: sizeof(simd_float2.self))
        NAssertEqual(16, actual: sizeof(simd_float3.self))
        NAssertEqual(16, actual: sizeof(simd_float4.self))
        NAssertEqual(24, actual: sizeof(simd_float3x2.self))
    }

    func testPacked() {
        NAssertEqual(8, actual: sizeof(packed_float2.self))
        NAssertEqual(16, actual: sizeof(packed_float4.self))
    }
}
