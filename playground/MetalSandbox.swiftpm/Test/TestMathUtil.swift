import Foundation
import PlaygroundTester

@objcMembers
final class TestMathUtil: TestCase {
    func testF16ToF32() {
        NAssertEqual(0, actual: F16ToF32(0))
        NAssertEqual(1, actual: F16ToF32(1))
        NAssertEqual(-1, actual: F16ToF32(-1))
        NAssert(F16ToF32(Float16.nan).isNaN)
    }

    func testGenerateRandomVector() {
        for _ in 0..<100 {
            let range: ClosedRange<Float> = 0.0...1.0
            let vector = generate_random_vector(range)
            NAssert(range.contains(vector.x), message: "vector.x = \(vector.x)")
        }
    }

    func testRandI() {
        seedRand(0xffff)
        let value1 = randi()

        seedRand(0xffff)
        let value2 = randi()
        let value3 = randi()

        NAssertEqual(value1, actual: value2)
        NAssertNotEqual(value1, actual: value3)
    }

    func testRandF() {
        seedRand(0xffff)
        let value1 = randf(1)
        NAssertEqual(1, actual: value1)
    }
}
