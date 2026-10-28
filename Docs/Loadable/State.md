# Shared loading state

`LoadableState` is an immutable Sendable projection shared by value stores,
collection stores and their snapshots. It describes readiness and activity without
owning data, requests, subscriptions or retry actions. Detailed snapshots remain
the source of values, queries, cursors and typed errors.

```swift
profileStore.loadableState
peopleStore.loadableState
profileStore.snapshot.loadableState
```

## Combining required stores

Both stores conform to the read-only MainActor `LoadableStateProviding` protocol.
A ViewModel can also conform and expose a computed group:

```swift
@MainActor @Observable
final class ScreenModel: LoadableStateProviding {
    let profileStore: LoadableValueStore<ProfileSource>
    let permissionsStore: LoadableValueStore<PermissionsSource>
    let peopleStore: LoadableCollectionStore<PeopleSource>

    // Initialize these stores in your initializer.

    var loadableState: LoadableState {
        .merge(stores: [profileStore, permissionsStore, peopleStore])
    }
}
```

Alternatively, merge state values directly:

```swift
let state = LoadableState.merge([
    profileStore.loadableState,
    peopleStore.loadableState
])
```

Every provider is read eagerly on MainActor. SwiftUI/Observation tracking reaches
the nested store snapshots through the computed property, even when an earlier
provider is already failed. No Combine forwarding or observing task is needed.
Custom providers must expose observable data if updates should invalidate a view.

A returned state is a snapshot. Storing it once in a property does not subscribe
to future changes; recompute it from providers inside `body` or a computed
ViewModel property. `LoadableState` itself does not need `@Observable`.

## Readiness and activity

| Property | Meaning |
| --- | --- |
| `phase` | `.idle`, `.loading`, `.loaded` or `.failed` for the entire required group |
| `hasLoaded` | Every leaf has a successfully loaded result; false for an empty group |
| `storeCount` / `loadedStoreCount` | Number of required leaves and ready leaves, including nested groups |
| `isLoading` | Any active initial load, refresh or page request |
| `isRefreshing` | At least one refresh is active |
| `isLoadingPage` | At least one directional page request is active |
| `failures` | All failures with original error, operation and `isBlocking` classification |
| `errors` | All underlying errors, preserving input order |
| `blockingFailures` | Failures whose originating leaf has no loaded result |

The phase uses the following precedence:

1. All required leaves are ready: `.loaded`, including retained errors/activity.
2. A leaf without a loaded result failed: `.failed`, even while other leaves load.
3. Any work is active while the group is incomplete: `.loading`.
4. Otherwise: `.idle` (not started or cancelled before success).

A successfully loaded optional nil counts as ready. An empty collection also counts,
including an empty intermediate page with a continuation cursor. Collection
readiness means an initial successful result, not that all server pages have been
fetched. `hasLoaded` is taken from success metadata, not inferred from row count.

A retained refresh or page failure leaves its leaf ready and records a nonblocking
failure. `Operation.load` identifies value/collection loading or refreshing;
`.page(.next/.previous)` preserves failed pagination direction. Failures are never
collapsed into a single arbitrary error or compared as if all errors were equal.
The state deliberately has no Equatable conformance for arbitrary Error values;
`Phase` and activity flags support focused `.onChange` checks.

```swift
switch model.loadableState.phase {
case .loaded:
    ScreenContent(model: model) // Use activity/errors for inline presentation.
case .loading:
    ProgressView()
case .failed:
    ErrorContent(errors: model.loadableState.blockingFailures.map(\.error))
case .idle:
    WaitingContent()
}
```

## Nested groups and boundaries

`merge` adds leaf counts, ORs activity flags and concatenates failures without
reclassifying them. Nested grouping produces the same readiness, activity and
error order as merging the flattened leaves. An empty nested group contributes
zero leaves; a completely empty group is idle. Supplying the same store twice
counts it twice; aggregate membership is explicitly chosen by the caller.

Every supplied store is required. Leave optional sections out of the screen gate
and render them independently. Membership can change through an Observable
ViewModel property when dependencies depend on user selection.

Aggregation describes current readiness. It does not start/await/retry/cancel
requests, enforce dependency order or guarantee that loaded results came from the
same query/session/generation. The owning model controls those operations and
cross-store consistency. Use existing `snapshots()` streams when an asynchronous
consumer needs updates; no additional observer lifetime is introduced here.

Custom providers can project their own state with
`LoadableState(hasLoaded:activity:error:operation:)`. Failure severity is derived
from that leaf's readiness, keeping aggregation rules consistent.

## Initial and constant values

Frozen stores are immediately ready when initialized with a result:

```swift
let profile = LoadableValueStore(constant: cachedProfile)
let people = LoadableCollectionStore(items: cachedPeople)
```

Frozen presentation can also be created without supplying a source:

```swift
LoadableCollectionStore(items: cachedPeople, phase: .refreshing)
LoadableCollectionStore(items: cachedPeople, phase: .failed(error))
LoadableCollectionStore(items: cachedPeople,
                        phase: .failed(error, operation: .page(.next)))
LoadableValueStore(constant: cachedProfile, phase: .refreshing)
```

`init(phase:)` also creates missing-value/loading/failure stores when the item/value
type is known from context. A typed row can supply that context without a Source:

```swift
LoadableUI.List(store: LoadableCollectionStore(phase: .failed(error))) { (person: Person) in
    PersonRow(person: person)
}
```

 `.failed(error)` defaults collection failure operation
to the initial load/refresh. `hasLoaded:` can disambiguate a failed refresh of an
empty collection; refreshing/page phases otherwise imply prior success. Idle or
initial-loading/initial-failure collection phases infer prior success from nonempty
items. Use `init(items:)` for an unambiguously loaded empty collection.

`init(source:constantSnapshot:)` and `setConstantState` remain available for arbitrary
queries/cursors and typed source snapshots. Commands do not mutate frozen stores.
These convenience initializers use existing OperationSource types internally and
expose `any Error`; production sources retain their own Failure types.

A writable, source-backed store can instead be seeded explicitly:

```swift
let profile = LoadableValueStore(source: ProfileSource())
profile.setValue(cachedProfile)

let people = LoadableCollectionStore(source: PeopleSource())
people.setItems(cachedPeople)
```

Those stores remain refreshable. `setItems` ends pagination and clears cursors;
start/refresh a session before loading subsequent pages. There is no live
`initialSnapshot` initializer for arbitrary cursors/phases. `startIfNeeded` sees
seeded data as loaded; use an explicit refresh to fetch a newer version.

## Examples and verification

The gallery's Merged state example uses an Observable ViewModel with two value
stores and a collection. Live scenarios cover partial completion, initial failure,
retained refresh/page failures, retry, reload and cancellation. Frozen previews
cover each screen presentation without waiting for tasks. The owner controls all
commands; the common-state getter only merges.

26 new test declarations cover the 100-pair state matrix, projection, nested merge
semantics, eager reads through heterogeneous providers, nested Observation,
completion order, retry/query reset, cancellation, constants and lifetime. Public
consumer examples compile without `@testable`. When importing both loading
modules, qualify `Loadable.LoadableState` versus the legacy
`LoadableModel.LoadableState`.

An additional 11 initializer tests verify frozen commands, actual error payloads,
readiness inference/overrides, optional nil and item/value type inference. All
196 Loadable tests and 67 existing package tests pass (263 declarations, with
additional parameterized cases). The three shared-state production files have
100% executable line and region coverage. Compiler-checked consumer examples use
only public imports. iOS 17 Simulator preview/module compilation and the Release
product build succeed. macOS renders cover the ready three-store screen, retained
refresh failure, and the retained-page-error list using the new initializer.
These renders verify layout; live interaction remains available in Canvas.
