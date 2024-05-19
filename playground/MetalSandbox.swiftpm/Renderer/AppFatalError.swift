import SwiftUI

func appFatalError(_ message: String) -> Never {
    print(message)
    sleep(1)
    fatalError()
}
