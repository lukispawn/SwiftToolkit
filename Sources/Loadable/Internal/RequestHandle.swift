import Foundation

/// One store-owned request. Cancellation of an awaiting caller is scoped to this ID.
struct RequestHandle<Value: Sendable>: Sendable {
    let id: UUID
    let task: Task<Value, any Error>
}

@MainActor
func awaitRequest<Value: Sendable>(
    _ request: RequestHandle<Value>,
    onCancel: @escaping @MainActor @Sendable (UUID) -> Void
) async throws -> Value {
    try await withTaskCancellationHandler {
        try Task.checkCancellation()
        let value = try await request.task.value
        try Task.checkCancellation()
        return value
    } onCancel: {
        request.task.cancel()
        Task { @MainActor in onCancel(request.id) }
    }
}

/// A frozen preview can intentionally represent a state with no loaded value.
public enum LoadableUsageError: Error, Sendable {
    case constantHasNoValue
}
