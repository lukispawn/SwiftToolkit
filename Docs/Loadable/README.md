# Loadable

An independent, Observation-based loading engine for iOS 17+ and macOS 15+.
The `Loadable` product is the recommended API starting with **1.8.0**. It coexists
with the deprecated `LoadableModel` module, whose implementation remains available
for existing consumers. It has no third-party or SwiftToolkit dependencies.
The product is dynamic to share a single module across app/framework consumers,
consistent with this package's existing dynamic-linking requirements.

## Start here

This is the canonical guide for humans and coding agents adopting this module.
The examples below use the public `Loadable` API, not the older `LoadableModel`
module and not Pentacomp's Combine implementation.

| Need | Use | Read next |
| --- | --- | --- |
| One asynchronously fetched value | `LoadableValueSource` + `LoadableValueStore` | [Value quick start](#value-quick-start) |
| A list, with or without pages | `LoadableCollectionSource` + `LoadableCollectionStore` | [Collection quick start](#collection-quick-start) |
| A native SwiftUI List | `LoadableUI.List` | [Collection UI](UI.md) |
| A horizontal strip, grid, chat or existing custom layout | `LoadableUI.Collection` + contexts | [Custom layouts](#custom-layouts) |
| Search text, debounce and minimum length | `LoadableCollectionSearch` | [Search](#search) |
| All required stores ready together | computed `LoadableState.merge(stores:)` | [Shared state](#shared-state) |
| An immutable loaded/error/loading fixture | constant store initializers | [Constant states](#constant-states) |
| Live persistence events | wrapper-owned event subscription + local mutation or refresh | [Local persistence events](#local-persistence-events) |
| Reducer integration | `snapshots()` and an owned subscription task | [Snapshot streams](#snapshot-streams) |
| Existing LoadableModel consumer | staged source/store/state migration | [Migration notes](Migration.md) |

The three layers are **Source → Store → View**. A source fetches one result/page;
the store owns request identity, state and page merging; the view renders state
and issues commands. A ViewModel composes stores and domain behavior. Do not add
a second request task around every command: most commands already start
store-owned work. Choose cancellation ownership deliberately.

## Installation and imports

Add the **Loadable product**, not only SwiftToolkit, to each target that imports
this module:

```swift
// In a consuming Package.swift target's dependencies:
.product(name: "Loadable", package: "SwiftToolkit")
```

Then use `import Loadable`. The containing package is SwiftToolkit; the product
and import are Loadable. The release/revision selected by the consumer must
actually contain this product: use SwiftToolkit **1.8.0 or later**. The first
implementation is present in commit `5a96311`; older tagged releases do not
contain the product.
When working locally, use the workspace's existing local-package override.

Keep a single resolved SwiftToolkit package identity across the app and embedded
frameworks. Loadable is an independent dynamic image without a dependency back
to SwiftToolkit or LoadableModel. During migration retain the existing combined
SwiftToolkit product where legacy modules still need it; do not add a second
standalone LoadableModel product to that same client.

## Value quick start

For a simple closure, no custom source type is necessary:

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
        .task { store.startIfNeeded() }
        .refreshable { await store.refresh() }
    }
}
```

For a domain source, implement `LoadableValueSource` with `Value`, optional
`Query` (defaults to `Never`) and optional `Failure` (defaults to `any Error`):

```swift
import Foundation

actor ServerTimeSource: LoadableValueSource {
    typealias Value = Date

    func fetch(query: Never?) async throws -> Date {
        try Task.checkCancellation()
        return Date() // Replace with the actual async service call.
    }
}
```

Create it with `LoadableValueStore(source: ServerTimeSource())`. A source is
Sendable; the store is MainActor-isolated. The source should return data, not
mutate the store from inside its fetch implementation.

## Collection quick start

This local source demonstrates search and next-page cursors without a backend:

```swift
struct Product: Identifiable, Sendable {
    let id: Int
    let title: String
}

actor ProductSource: LoadableCollectionSource {
    typealias Item = Product
    typealias Query = String
    typealias Cursor = Int

    private let products = (1...80).map { Product(id: $0, title: "Product \($0)") }

    func fetchPage(query: String?, cursor: Int?,
                   direction: LoadableCollection.Direction) async throws -> Page {
        try Task.checkCancellation()
        let text = query ?? ""
        let matching = products.filter { text.isEmpty || $0.title.localizedCaseInsensitiveContains(text) }
        let start = cursor ?? 0
        let page = Array(matching.dropFirst(start).prefix(20))
        let end = start + page.count
        return Page(items: page, nextCursor: end < matching.count ? end : nil,
                    totalCount: matching.count)
    }
}

struct ProductsView: View {
    @State private var store = LoadableCollectionStore(source: ProductSource())

    var body: some View {
        LoadableUI.List(store: store) { product in
            Text(product.title)
        }
        .empty { Text("No products found") }
        .loading { ProgressView("Loading products…") }
        .failure { failure in
            VStack {
                Text(failure.error.localizedDescription)
                if let retry = failure.retry { Button("Try again", action: retry) }
            }
        }
    }
}
```

The default list starts when needed, supports pull-to-refresh and automatically
loads pages. Do not attach another initial-load task to this example. For a
source without search or pagination, leave `Query` and `Cursor` at their `Never`
defaults and return `Page(items: fetchedItems)` from
`fetchPage(query: Never?, cursor: Never?, direction:)`.

The example source supports next pages only. A bidirectional source also returns
`previousCursor` and handles `.previous`; a nil cursor always requests the initial
page with `.next`. Prefer backend keyset cursors for mutable histories. The core
accepts any Sendable, Equatable cursor; it need not be Hashable.

## Custom layouts

Pass your own layout to `LoadableUI.Collection`. The same component works in a
vertical stack, horizontal stack or grid; it does not choose scroll direction:

```swift
struct ProductStrip: View {
    let store: LoadableCollectionStore<ProductSource>

    var body: some View {
        LoadableUI.Collection(store: store) { context in
            ScrollView(.horizontal) {
                LazyHStack {
                    LoadableUI.Components.Pagination(context: context.pagination(.previous))
                    ForEach(context.items) { product in Text(product.title) }
                    LoadableUI.Components.Pagination(context: context.pagination(.next))
                }
            }
        }
    }
}
```

Here the `.next` sentinel sits at the trailing edge; `.previous` is hidden because
ProductSource supplies no previous cursor. For a chat, place these components at
the top/bottom of a `LazyVStack`, keep chronological order and use
`.defaultScrollAnchor(.bottom)`. See [the chat feature](ChatPreview.md) for pending
delivery, bidirectional history and its namespaced ViewModel/ContentView example.
The public UI kit is collection-oriented; values use ordinary SwiftUI rendering.

## Search

`LoadableCollectionSearch` owns text-to-query scheduling, not a second collection
store. With `ProductSource` above:

```swift
import Observation

enum ProductSearch {
    @MainActor @Observable
    final class ViewModel {
        let store: LoadableCollectionStore<ProductSource>
        let search: LoadableCollectionSearch<ProductSource>

        init() {
            let store = LoadableCollectionStore(source: ProductSource())
            self.store = store
            search = LoadableCollectionSearch(store: store, minimumLength: 2)
        }
    }

    struct ContentView: View {
        @Bindable var viewModel: ViewModel

        var body: some View {
            @Bindable var search = viewModel.search
            LoadableUI.List(store: viewModel.store,
                            configuration: .init(startsAutomatically: false)) { product in
                Text(product.title)
            }
            .searchable(text: $search.text)
            .onSubmit(of: .search) { search.submitNow() }
            .task { search.startIfNeeded() }
        }
    }
}
```

Create and retain this ViewModel in a feature's lifecycle/LoadableView host;
ContentView receives it. Only the search controller starts the initial query in
this example. An empty phrase shows all by default; a nonempty phrase below the
minimum does not fetch. Render `search.requirement` when the UI needs a minimum
length hint. The last data may remain available behind that hint: do not assume
an unsatisfied requirement empties the store. Search cancels stale requests as
text changes; `submitNow()` cancels pending debounce and forces the current query.
Call `stop()` only when the owning search session should actually end.

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

```swift
enum Overview {
    @MainActor @Observable
    final class ViewModel {
        let products = LoadableCollectionStore(source: ProductSource())
        let lastUpdate = LoadableValueStore(source: ServerTimeSource())
    }
}

extension Overview.ViewModel {
    var loadableState: LoadableState {
        LoadableState.merge(stores: [products, lastUpdate])
    }
}
```

Read `viewModel.loadableState.hasLoaded` to require both successful results.
A loaded empty collection or a successfully loaded optional nil counts as ready.
An empty group is not ready. A retained refresh/page error can coexist with
`phase == .loaded`; inspect `failures`, `isRefreshing` and `isLoadingPage` as well.
The merge only reads state: it does not start work, wait, retry or cancel either
store. Compute it on demand so nested Observation reads remain tracked; do not
cache a merged value once in init or make optional panels block the whole screen.

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

For a list, attach `.task { store.startIfNeeded() }`,
`.refreshable { await store.refresh() }` and
`.onAppear { store.loadMoreIfNeeded(for: item) }` to rows when composing the
entire list yourself without `LoadableUI.List`. That task starts a
store-owned request, so disappearance does not automatically cancel the fetch.
Use `.task(id: query) { _ = try? await store.load(query: query) }` instead when
the view task should own cancellation.

Minimal compiler-checked examples remain in
`Tests/LoadableTests/Integration/SwiftUIExamples.swift`. The DEBUG preview gallery
adds interactive value, pagination and search scenarios inside the library.
Rendering and testing the actual consumer application remains a migration checkpoint.

### Reading snapshots correctly

Raw snapshot phases describe activity/error, not readiness. A successful fetch
returns the phase to `.idle`; there is no raw `.loaded` phase. Use
`valueStore.snapshot.hasValue`, `collectionStore.snapshot.hasLoaded`, or the
common `loadableState.hasLoaded` to check readiness. `.loaded` is a common-state
phase and a snapshot factory, not a collection/value activity case.

In SwiftUI, observe the original store or read through an Observable ViewModel.
Pass a plain snapshot only when you intentionally want a frozen value projection.

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

Constant does not mean "initially loaded, then refreshable". For live data with
an initial value, create a normal source-backed store, commit `setValue(initial)`
or `setItems(initial)`, then explicitly refresh when needed. The local commit
already counts as loaded, so `startIfNeeded()` will not refresh that seed.
For collections, `setItems` ends the pagination session; establish fresh cursors
through refresh/start before trying to load a page. `setConstantState` is one-way;
create a different normal store to leave frozen mode.

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

Neither `mapItems` nor the custom page merge closure is a universal post-mutation
hook. In particular, a migration from legacy `processContent` must preserve
sorting, max-count limits and filtering for local event mutations too. Normalize
the authoritative collection in the owning wrapper before committing it, or
design a separate tested domain adapter. Do not silently drop that invariant.

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
Since 1.8.0, the legacy LoadableModel public types are deprecated with migration
messages. They remain implemented and available; deprecation introduces warnings,
not a runtime redirect or an unavailable API. Use the migration guide to adapt
contracts that the new engine deliberately leaves to domain wrappers.

## Checklist for coding agents

1. Read this guide, then the relevant UI/state/migration document. Confirm whether
   the target imports Loadable or LoadableModel; their similarly named types have
   different generic parameters and contracts.
2. Choose a value or collection source. Check Sendable data and query/cursor
   constraints; keep actor isolation explicit. Do not introduce `@unchecked
   Sendable` just to silence a migration error.
3. Select store-owned versus caller-owned cancellation. Preserve wrapper-owned
   monitoring, throttle/debounce and stream lifetime rather than moving them
   implicitly into SwiftUI appearance callbacks.
4. Decide clearing versus retained reloads, and live seed versus frozen fixture.
   Use readiness metadata, not an assumed raw `.loaded` phase.
5. Keep source errors typed when useful. Source `Failure` defaults to `any Error`;
   caller-owned `load()` can also throw CancellationError. Retry only the failed
   operation and preserve the query, cursor and direction.
6. Use the default ID merge unless domain ordering requires more. Test overlapping
   pages and local-event normalization; mapItems handles fetched pages only.
7. Use Pagination at the corresponding edge for automatic loading. Custom
   pagination builders own their visibility behavior. Do not add unbounded retry
   loops, global cancellation on every disappearance, or a second paging task.
8. Compute merged state from required stores only. Continue displaying retained
   content during refresh and nonblocking errors.
9. Use fresh controlled sources and completion barriers in concurrency tests.
   Test stale results, cancellation, retry and release. Do not synchronize tests
   with arbitrary sleeps or use the internal requestTask in production code.
10. Compile consumer examples, run affected tests, then verify real consumer UI.
    Library preview renders do not prove keyboard, scroll anchoring or application
    navigation acceptance. Interactive chat verification is still deferred.

## Verification and source map

On 2026-10-28, 237 Loadable declarations in 25 suites and 67 existing package
tests pass (304 total, plus parameterized cases). DEBUG preview macros compile
for iOS 17 Simulator; Release excludes the demo feature. There are 64 named
previews, including the chat and composer examples. Detailed coverage and limits
are recorded in [the test matrix](TestMatrix.md); these counts are a dated record,
not a promise about future runs.

| Area | Repository path |
| --- | --- |
| Value protocol/store/snapshots | `Sources/Loadable/Value/` |
| Collection protocol/store/merging | `Sources/Loadable/Collection/` |
| Search/debounce | `Sources/Loadable/Query/` |
| Common readiness and aggregation | `Sources/Loadable/State/` |
| SwiftUI collection presentation | `Sources/Loadable/UI/` |
| Library preview gallery | `Sources/Loadable/Preview/LoadablePreviewGallery.swift` |
| Namespaced chat feature | `Sources/Loadable/Preview/Chat/` |
| Public-import compilation examples | `Tests/LoadableTests/UI/ConsumerCompilationExamples.swift` |
| Consumer migration contracts | `Tests/LoadableTests/Integration/ConsumerMigrationTests.swift` |
| Behavioral suites and controlled sources | `Tests/LoadableTests/` |

See [migration candidates](Migration.md), [the test matrix](TestMatrix.md) and
[P-001](../Project/Plans/Ongoing/P-001-loadable.md) for verification and remaining work.
