import SwiftUI

class CounterSampleSummaryRepository {
    var summaries = [CounterSampleSummary]()
    
    func fetchAll() -> [CounterSampleSummary] {
        return summaries
    }
    
    func persist(_ item: CounterSampleSummary) {
        summaries.append(item)
    }
    
    func persist(_ items: [CounterSampleSummary]) {
        summaries.append(contentsOf: items)
    }
    
    func deleteAll() {
        summaries.removeAll()
    }
    
    func count() -> Int{
        return summaries.count
    }
}
