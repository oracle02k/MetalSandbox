class GpuCounterSampleItemRepository {
    var items = [GpuCounterSampleItem]()

    func fetch(groupLabel: String) -> [GpuCounterSampleItem] {
        return items.filter { item in item.groupLabel == groupLabel }
    }

    func fetchAll() -> [GpuCounterSampleItem] {
        return items
    }

    func persist(_ item: GpuCounterSampleItem) {
        items.append(item)
    }

    func deleteAll() {
        items.removeAll()
    }
}
