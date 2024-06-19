import SwiftUI

func appFatalError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) -> Never {
    if let unwrappedError = error {
        Logger.errorLog("fatalerror: \(message)", error: unwrappedError, file: file, function: function, line: line)
    } else {
        Logger.log("fatalerror: \(message)", file: file, function: function, line: line)
    }
    Logger.log("stack trace:")
    for symbol in Thread.callStackSymbols {
        print(symbol)
    }
    sleep(1)
    fatalError()
}

func uninitialized<T>(file: String = #file, function: String = #function, line: Int = #line) -> T {
    appFatalError("accessed an uninitialized lazy property.", file: file, function: function, line: line)
}
