# Collection UI

Import `Loadable` and `SwiftUI`. The production UI lives in `Sources/Loadable/UI`
and ships in the same product as the Observation stores. It has no app-specific
assets, selection model or navigation policy. Default copy is English; replace
state views for application localization and branding.

## Namespace

`LoadableUI` and `LoadableUI.Components` are namespace enums in the existing
`Loadable` module. Public views are real nested types, each in its own file.
The new UI API uses these names throughout previews and consumer examples:

| Purpose | Type |
| --- | --- |
| Native list | `LoadableUI.List` |
| Custom collection layout | `LoadableUI.Collection` |
| Shared presentation policy | `LoadableUI.Configuration` |
| Pure snapshot-to-presentation projection | `LoadableUI.Presentation` |
| Collection data and actions | `LoadableUI.CollectionContext` |
| Directional page state and actions | `LoadableUI.PaginationContext` |
| Failure and optional retry | `LoadableUI.FailureContext` |
| Default state views | `LoadableUI.Components.Loading`, `.Empty`, `.Idle`, `.Failure` |
| Page loading/error/action view | `LoadableUI.Components.Pagination` |

Store, source and search controller names stay independent of this namespace.
`Pagination` can be placed at either edge of a vertical or horizontal collection;
constrain its width when using it in a LazyHStack. The namespace does not choose a
scroll axis. Existing state/footer customization modifiers work the same way.

## Ready-to-use list

Own the store with `@State` or inject an existing store as an ordinary property.

```swift
LoadableUI.List(store: store) { person in
    PersonRow(person: person)
}
.empty {
    ContentUnavailableView("No people", systemImage: "person.crop.circle")
}
.loading {
    PeopleSkeleton()
}
.failure { context in
    VStack {
        Text(context.error.localizedDescription)
        if let retry = context.retry {
            Button("Try again", action: retry)
        }
    }
}
.listStyle(.plain)
```

Only `store` and `row` are required. Typed ViewBuilder modifiers replace `empty`,
`loading`, `failure`, `idle` and `pagination` views without `AnyView`. `failure`
applies to full-surface and retained-refresh errors. Customize `pagination` to
replace page loading/error controls. Its context has `direction`, `state`, optional
`failure`, `load()` and `retry()`. Retry is optional on failure contexts because a
frozen store or an ended session cannot retry.

Rows are ordinary SwiftUI views: supply a Button, NavigationLink, swipe actions or
selection UI as needed. No tap handler or selected-items array is imposed.

## Custom layout

`LoadableUI.Collection` renders the main loading/empty/error/idle state. Its content
closure receives a live MainActor context, without creating another ViewModel or
request task. It supports the same state-view modifiers as LoadableUI.List.

```swift
LoadableUI.Collection(store: store) { context in
    ScrollView {
        LazyVStack(spacing: 16) {
            LoadableUI.Components.Pagination(context: context.pagination(.previous))
            ForEach(context.items) { person in
                PersonCard(person: person)
                    .onAppear { context.itemAppeared(person) }
            }
            LoadableUI.Components.Pagination(context: context.pagination)
        }
    }
    .refreshable { await context.refresh() }
}
.empty { Text("No people") }
```

Use LazyVGrid, sections or another container instead. Attach `itemAppeared` to
lazy items for optional automatic next-page prefetch. Place previous-page controls above
content and next-page controls below it. The context also exposes `query`,
`totalCount`, `phase`, `presentation.isRefreshing`, `canRefresh`, `refreshFailure`,
`reload()` and `retry()`. It reads the injected store live, including nested
Observation changes. Custom layouts own their refresh gesture/indicator and any
container-specific styling. The collection view displays retained refresh errors
above content; page errors belong to the corresponding pagination control.

## Policy and lifecycle

```swift
let configuration = LoadableUI.Configuration(
    pagination: .manual,
    isRefreshable: true,
    startsAutomatically: false
)
```

- `.automatic` prefetches next pages at the store's configured threshold when rows
  call `itemAppeared`. The shared `Pagination` component also loads its own direction
  when visible, so a header handles previous pages and a footer handles next pages.
  `.manual` only fetches from explicit pagination actions. `.disabled` hides the
  controls and suppresses context page actions. Custom pagination views own their
  own visibility/prefetch behavior; the configuration does not inject a trigger
  into arbitrary content.
- `Pagination` uses scroll visibility on iOS 18+/macOS 15+ and appearance on iOS 17,
  following IKP's sentinel pattern. Its view-owned guard survives loading-state
  changes. A repeated cursor or unchanged directional boundary switches to manual
  continuation; a failure requires Retry. The store still bounds empty-page
  follow-ups and serializes requests. New reload/refresh sessions reset the guard
  even when the query and cursor values are reused. Requests are store-owned;
  hiding the edge does not cancel them.
- An optional `willLoad` callback runs before the component's accepted automatic,
  manual or retry action. The chat uses it on the header to stop following incoming
  messages while earlier history loads:

  ```swift
  LoadableUI.Components.Pagination(context: context.pagination(.previous)) {
      model.followsNewMessages = false
  }
  ```
- Automatic start calls `store.startIfNeeded()` from a view task. Requests remain
  store-owned. Disappearance never cancels an injected/shared store. The owner
  decides whether to call `cancelRequest()` or `cancel()`. Use caller-owned `load`
  from your own `.task` and set `startsAutomatically: false` if cancellation should
  follow that task's lifetime.
- Keep refresh policy stable while displaying a list: changing refresh support
  changes its SwiftUI container branch and can reset scroll state. The built-in
  refresh gesture is available on the content list; initial/empty/error surfaces
  use their configured state views instead. Supply an external reload action for
  those surfaces when needed.
- Constants show frozen states without enabled reload/refresh/retry commands.
  The core store additionally exposes `canReload` and observable `canRetry`.

The presentation projection keeps existing rows visible during refreshes and page
failures. Terminal empty results differ from idle and empty pages with cursors.
The ready-made list shows refresh progress and directional page progress/errors.
It adds no NavigationStack, search field, diagnostics or app-specific theme.

## Optional search

`LoadableCollectionSearch<Source>` is an independent `@MainActor @Observable`
controller. Inject a store, minimum length, debounce duration, empty-input policy,
optional initial text and a String-to-Query mapping. String queries have a shorter
initializer. A Clock initializer supports deterministic testing.

```swift
@State private var search = LoadableCollectionSearch(
    store: LoadableCollectionStore(source: PeopleSource()),
    minimumLength: 2,
    showsAllWhenEmpty: false
)

// In body:
Group {
    switch search.requirement {
    case .tooShort(let minimum):
        Text("Enter at least \(minimum) characters")
    case .satisfied:
        LoadableUI.List(store: search.store,
                     configuration: .init(startsAutomatically: false)) {
            PersonRow(person: $0)
        }
    }
}
.searchable(text: $search.text, prompt: "First or last name")
.onSubmit(of: .search) { search.submitNow() }
.task { search.startIfNeeded() }
```

Search coordination owns startup here; disable the list's automatic start to
avoid a request before the search requirement is satisfied. Observe
`search.debouncer.isWaiting` and `pendingQuery` for an optional waiting indicator.
Input is trimmed before query mapping. Each edit cancels pending debounce and
invalidates an active fetch immediately; below-threshold input ends the session.
Immediate submission cancels debounce and starts a fresh request. Only the latest
query can publish, even when an old source or Clock ignores cancellation.

The controller does not install a search field, choose filtering/case/accent rules,
or infer whether an arbitrary Query represents a filtered result. Hide previous
results while requirements are unmet and choose an appropriate empty message in
your presentation. Call `search.stop()` explicitly when its owner finishes the
search session; deallocation only cancels pending debounce, preserving shared-store
work. Local filtering and selected-item presentation remain caller concerns.

## Verification and demos

`LoadableCollectionUIPreviews.swift` demonstrates List, scrollable cards, an
adaptive grid, frozen states and explicit empty-page continuation. Existing
pagination, single-page and remote-search demos use the public UI. There are
49 named previews overall; the main gallery includes a Layouts example with a
live List / Cards / Grid selector backed by the same store.

31 new test declarations cover presentation, live context actions/Observation,
manual/automatic/disabled pagination, both directions, retained errors, retry
availability, empty continuations, search gates/mapping/debounce/cancellation and
lifetime. Consumer examples compile using only public imports. Unit tests do not
claim to validate actual scroll gestures or UI event delivery; those need live
Canvas or consumer-app UI tests.

For a screen depending on multiple stores, see [shared state](State.md).
`LoadableState.merge(stores:)` provides a computed screen gate while preserving
background work and nonblocking failures. The gallery's Merged state entry shows
this composition; a production LoadableUI.Group wrapper is not introduced here.
