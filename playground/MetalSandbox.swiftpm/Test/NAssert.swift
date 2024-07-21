import Foundation
import PlaygroundTester

func NAssert(_ value: Bool, message: String = "", line:Int=#line) {
    Assert(value, message:"\(message) line:\(line)")
}

func NAssertEqual<T: Equatable>(_ expected: T, actual: T, message: String = "", line:Int=#line) {
    AssertEqual(expected, other: actual, message:"\(message) line:\(line)")
}

func NAssertNotEqual<T: Equatable>(_ expected: T, actual: T, message: String = "", line:Int=#line) {
    AssertNotEqual(expected, other: actual, message:"\(message) line:\(line)")
}
