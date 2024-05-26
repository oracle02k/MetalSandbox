import SwiftUI

func appFatalError(_ message: String) -> Never {
    Logger.log("fatalerror: \(message)")
    Logger.log("stack trace:")
    for symbol in Thread.callStackSymbols {
        print(symbol)
    }
    sleep(1)
    fatalError()
}

func uninitialized<T>() -> T {
    appFatalError("accessed an uninitialized lazy property.")
}
