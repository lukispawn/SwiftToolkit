# Loadable (new module)

An independent, Observation-based loading engine for iOS 17+ and macOS 15+.
The `Loadable` product coexists with `LoadableModel`; it does not replace or
deprecate existing types yet. It has no third-party or SwiftToolkit dependencies.
The product is dynamic to share a single module across app/framework consumers,
consistent with this package's existing dynamic-linking requirements.

## Sources and ownership

Implement `LoadableValueSource` or `LoadableCollectionSource`, or use an
`OperationSource` with a Sendable closure. Sources receive the query on every
request. Collection sources also receive a cursor and direction; a nil cursor
always means the initial page, requested with `.next`.

Both stores are `@MainActor @Observable`. Their snapshots are Sendable values,
conditionally Equatable when their data and errors are Equatable. Sources need
not be Observable. Perform network access and expensive processing in a source
with the appropriate isolation, not synchronously in a view.

| Command | Owner | Previous content |
| --- | --- | --- |
| `start(query:force:)` | Store | Cleared; repeated query ignored unless forced |
| `startIfNeeded()` | Store | Loads only when no successful result/error/request exists |
| `reload()` | Store | Cleared, using the current query |
| `refresh() async` | Store | Retained; errors live in the snapshot |
| `refreshInBackground()` | Store | Retained; schedules a refresh without waiting |
| `load(query:retainingValue:)` / `load(query:retainingItems:)` | Caller | Cleared by default |
| `retry()` | Store | Repeats the failed fetch with the same parameters and mode |
| `cancelRequest()` | Store | Retained; loading phase ends, session remains |
| `cancel()` | Store | Retained; session ends, retry context is discarded |

`load` returns data and throws failures or CancellationError. Cancellation of its
caller cancels only that caller's request. An already-cancelled caller does not
start work. A source that ignores cancellation can delay completion of the await,
but cannot publish the cancelled result. A superseded load throws CancellationError.
Retaining content for a different query is deliberately disallowed.

`refresh` waits but remains store-owned: cancelling the waiter does not cancel
the request. `start`, `reload`, pagination and retry return after scheduling work.
All superseding/cancellation commands invalidate request identity synchronously.
The store-owned task captures its source without retaining the store across
suspension; releasing the store cancels its active task.

Value snapshots distinguish `.missing` from `.value(nil)` when Value is Optional.
Failed refreshes preserve old content. Collection phases record whether a reload
or a particular page direction failed; an error with existing rows can be shown
inline without losing the list or retry cursor.

## Shared state

Value and collection snapshots/stores expose `loadableState`. Use
`LoadableState.merge(stores:)` in a computed ViewModel property to gate a screen
on all required results while retaining refresh/pagination activity and every
failure. See [shared state and aggregation](State.md) for semantics, Observation
and initial/constant values.

## SwiftUI

For production collection views, see [Collection UI](UI.md): `LoadableUI.List`
provides a configurable native list; `LoadableUI.Collection` accepts a custom
layout and context; `LoadableCollectionSearch` optionally coordinates search.


For interactive, library-local demos ported from Pentacomp, see
[SwiftUI preview gallery](Previews.md). Open
`Sources/Loadable/Preview/LoadablePreviewGallery.swift` in Xcode Canvas.
The [chat experiment](ChatPreview.md) combines both pagination directions with
optimistic sending and simulated incoming messages using the public collection UI.
`LoadableUI.Components.Pagination` automatically loads its direction when visible
under the default automatic policy. Place it at the top and bottom for a chat;
manual continuation remains available after stalled/cyclic pages or errors.

Own a store with `@State`, pass it as an ordinary property for reads, and use
`@Bindable` only when a child needs bindings. Nested Observation reads work
without manually forwarding `objectWillChange`.

```swift
import Loadable
import SwiftUI

struct CounterView: View {
    @State private var store = LoadableValueStore(operation: { 42 })

    var body: some View {
        VStack {
            if let value = store.value { Text(value, format: .number) }
            if store.snapshot.phase.isLoading { ProgressView() }
            if store.lastError != nil { Button("Retry") { store.retry() } }
        }
        .task { _ = try? await store.load() }
        .refreshable { await store.refresh() }
    }
}
```

For a list, attach `.task { store.startIfNeeded() }`,
`.refreshable { await store.refresh() }` and
`.onAppear { store.loadMoreIfNeeded(for: item) }` to rows. That task starts a
store-owned request, so disappearance does not automatically cancel the fetch.
Use `.task(id: query) { _ = try? await store.load(query: query) }` instead when
the view task should own cancellation.

Minimal compiler-checked examples remain in
`Tests/LoadableTests/Integration/SwiftUIExamples.swift`. The DEBUG preview gallery
adds interactive value, pagination and search scenarios inside the library.
Rendering and testing the actual consumer application remains a migration checkpoint.

## Pagination and merging

`loadMore()` requests the next page; `loadPage(.previous)` requests the previous
one. Only one request may be active. A reload/refresh supersedes pagination.
Pagination updates the cursor in its own direction and preserves the opposite
cursor. Server `totalCount` is preserved when a later page omits it and updated
when a later page explicitly supplies a new total.

The default merge updates overlapping IDs in place and appends/prepends new IDs.
Within a page the last version of an ID wins, keeping its first position. Initial
pages also deduplicate. A custom `merge` closure can replace the page-merge policy;
it must return unique IDs suitable for SwiftUI ForEach.

Empty pages with a cursor are followed up to `emptyPageFetchLimit` additional
requests. Repeated/cyclic cursors stop automatic continuation. The cursor remains
available for an explicit user action; the engine does not claim the server has
no more data. At the limit, an empty list needs an explicit load-more control.
Prefetch triggers on every observed row at or beyond the configured threshold.

`snapshot.canLoad(direction)` describes data and phase; the store's
`canLoad(direction)` additionally accounts for active sessions and constant mode.
Views should use store command availability, especially after `cancel()`.

## Constant states

`LoadableValueStore(constant: value)` and `LoadableCollectionStore(items: items)`
are immediately loaded, frozen stores. `init(source:constantSnapshot:)` and
`setConstantState` can freeze arbitrary loading/error states for previews.
Frozen `init(items:phase:hasLoaded:)`, `init(phase:)` for a value, and
`init(constant:phase:)` create presentation states without a custom source.
Collection `.failed(error)` defaults to a first-load/refresh failure. Item/value
types must be inferable from data or surrounding context. See [initial state
examples](State.md#initial-and-constant-values).
No loading command mutates a frozen snapshot. `load()` returns frozen loaded
content; if the frozen snapshot has no successful content, it throws
`LoadableUsageError.constantHasNoValue` without invoking the source.

## Transforming sources

`source.mapValue { value in ... }` supports asynchronous value conversion.
`source.mapItems { items in ... }` transforms each collection page, preserving
its query, cursors and server total. For example, a non-paginated persistence
source can sort records before publishing them. These adapters may change the
output type and expose `any Error`, since transformation errors can differ from
the base source's Failure. Implement a dedicated source when typed error mapping
is part of the domain contract.

Cancellation is checked before fetching, before transformation, and after it.
The store also checks request identity before publication. An old noncooperative
transform cannot overwrite the current query or a locally committed value.

Page-level mapping does not sort the entire accumulated list. Use the store's
merge policy for accumulated ordering. A page filtered down to zero items still
participates in bounded empty-page continuation. Its server total remains a
server total, not a count of the filtered rows.

## Local persistence events

Use `refreshInBackground()` to refresh after a database event while retaining
displayed content. This schedules immediately and does not debounce by itself.

`setValue` commits an authoritative local value and invalidates previous work.
Collections offer `setItems`, `appendItems`, `updateItem` and `removeItem(withID:)`.
All effective local mutations invalidate older requests and retry context.

`updateItem` updates an existing ID in place and retains cursors/total because
membership is unchanged. It returns false for unknown IDs without cancelling work.
`setItems`, append and removal change membership: they discard cursors and end
the pagination session, since an opaque server cursor could encode an offset.
An explicit total can be supplied to `setItems`; otherwise old totals are cleared.
Refresh/start a new session before loading further pages. Unknown-ID updates or
removals, empty appends, and mutations of frozen stores leave pending work/state
untouched. Explicit setValue/setItems calls are authoritative commits even when
the supplied data looks identical; they invalidate older requests.

## Query debounce

`LoadableQueryDebouncer<Query>` is an independent Observable scheduler with
`pendingQuery` and `isWaiting`. It uses ContinuousClock by default and accepts any
Clock in `init(delay:clock:onCommit:)`, allowing tests to release sleeps manually.

```swift
let debouncer = LoadableQueryDebouncer<String>(delay: .milliseconds(300)) { [weak store] query, mode in
    store?.start(query: query, force: mode == .immediate)
}
debouncer.submit("phrase")       // Commit after the delay
debouncer.submitNow("phrase")    // Cancel waiting work and commit immediately
debouncer.cancelPending()        // Abandon the pending query
```

Debounce cancellation does not cancel an already committed store request. If an
old result must disappear as soon as the user types, the owning model can call
`store.cancelRequest()` before submitting the new query. Minimum text length and
text normalization remain presentation/domain decisions. Commit closures should
capture their owning model/store weakly to avoid a retain cycle.

## Snapshot streams

`store.snapshots()` synchronously registers a new independent AsyncStream and
replays current state immediately. The default `.bufferingNewest(1)` coalesces
updates for state rendering. Pass `bufferingPolicy: .unbounded` when every
transition matters, accounting for potentially unbounded memory use.

```swift
let snapshots = store.snapshots()
observationTask = Task { [weak self] in
    for await snapshot in snapshots {
        self?.state = snapshot
    }
}
// Cancel observationTask when its owner finishes observing.
```

Every subscriber has its own buffer. Cancelling one consumer does not terminate
others. Releasing a store finishes its streams; streams do not retain the store.
Page success publishes rows, cursors, totals and phase as one coherent snapshot.
These are state streams, not a durable log of fetch/CRUD side effects. Session
availability outside the snapshot is still exposed by the store's `canLoad` API.

## Adoption boundary

Import the new `Loadable` product explicitly. When both modules are imported,
qualify colliding names, e.g. `Loadable.LoadableCollectionStore` versus
`LoadableModel.LoadableCollectionStore`.

Cache policy, automatic refresh triggers, remote CRUD services and the old
didFetch/willAddItems event API are not provided by the new engine. Existing
consumers needing those features remain on LoadableModel until their migration
adapters are designed and tested. The new local mutations do not perform remote
CRUD, and snapshot streams do not reproduce the old event API.
No old public API is deprecated in this iteration.

See [migration candidates](Migration.md), [the test matrix](TestMatrix.md) and
[P-001](../Project/Plans/Ongoing/P-001-loadable.md) for verification and remaining work.
