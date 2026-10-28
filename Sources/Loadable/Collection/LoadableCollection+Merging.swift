extension LoadableCollection {
    /// Incoming versions win. Existing rows retain their position; new rows append/prepend.
    static func mergeByID<Item: Identifiable>(existing: [Item], incoming: [Item], direction: Direction) -> [Item] {
        var result = existing
        let indices = Dictionary(uniqueKeysWithValues: existing.enumerated().map { ($0.element.id, $0.offset) })
        var additions: [Item] = []
        var additionIndices: [Item.ID: Int] = [:]
        for item in incoming {
            if let index = indices[item.id] {
                result[index] = item
            } else if let index = additionIndices[item.id] {
                additions[index] = item
            } else {
                additionIndices[item.id] = additions.count
                additions.append(item)
            }
        }
        return direction == .next ? result + additions : additions + result
    }
}
