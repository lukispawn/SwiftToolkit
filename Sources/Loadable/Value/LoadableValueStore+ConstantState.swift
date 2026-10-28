public extension LoadableValueStore {
    /// A frozen missing-value state, e.g. loading or first-load failure.
    /// Value is inferred from the surrounding store/view type.
    convenience init<Value>(phase: LoadableValue.Phase<any Error>)
    where Source == LoadableValue.OperationSource<Value, Never, any Error> {
        self.init(source: .init { _ in throw LoadableUsageError.constantHasNoValue },
                  constantSnapshot: .init(phase: phase))
    }

    /// A frozen retained value, including a successfully loaded optional nil.
    convenience init<Value>(constant value: Value, phase: LoadableValue.Phase<any Error>)
    where Source == LoadableValue.OperationSource<Value, Never, any Error> {
        self.init(source: .init { _ in value }, constantSnapshot: .init(content: .value(value), phase: phase))
    }
}
