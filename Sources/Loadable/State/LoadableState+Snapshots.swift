public extension LoadableValue.Snapshot {
    var loadableState: LoadableState {
        let activity: LoadableState.Activity
        switch phase {
        case .idle, .failed: activity = .idle
        case .loading: activity = .loading
        case .refreshing: activity = .refreshing
        }
        return LoadableState(hasLoaded: hasValue, activity: activity, error: phase.error)
    }
}

public extension LoadableCollection.Snapshot {
    var loadableState: LoadableState {
        let activity: LoadableState.Activity
        let operation: LoadableState.Operation
        switch phase {
        case .idle, .failed: activity = .idle
        case .loading: activity = .loading
        case .refreshing: activity = .refreshing
        case .loadingPage(let direction): activity = .loadingPage(direction)
        }
        if case .failed(_, .page(let direction)) = phase { operation = .page(direction) }
        else { operation = .load }
        return LoadableState(hasLoaded: hasLoaded, activity: activity, error: phase.error, operation: operation)
    }
}
