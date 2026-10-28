# Interactive SwiftUI previews

The DEBUG-only gallery lives inside the `Loadable` library. Collection demos now
use the [public collection UI](UI.md), and search uses the public Observation controller. It adapts Pentacomp's
existing basic, single-page and advanced search demos to Observation, with updated
presentation and the new snapshot/cursor APIs. BluetoothKit is not involved.

## Open in Xcode

1. Open SwiftToolkit's `Package.swift` in Xcode and select the Loadable scheme
   (the SwiftToolkit-Package scheme can also build the preview target).
2. Open `Sources/Loadable/Preview/LoadablePreviewGallery.swift`.
3. Show Canvas, resume the named preview and enable interaction.
4. Use the visible Value / List / Search / All items / Layouts / Merged state / Chat selector to change demos.

The gallery opens on the paginated list. Choose Layouts to switch between a
native List, scrollable cards and an adaptive grid using the same store. Refresh
and Reload buttons work across these layouts. Named gallery previews also open
directly on collection layouts, the searchable list or merged store states.

Each demo also has its own file with named previews. macOS previews supply an
initial window size; iPhone/iPad use the Canvas device size. Light/dark and larger
text variants are included. All data is generated locally; no network is used.

## Scenarios

| File under Sources/Loadable/Preview | What to exercise |
| --- | --- |
| `Value/LoadableValueDemoView.swift` | Skeleton, retained refresh, clearing reload, cancellation, first-load/refresh errors and retry; versions increment on successful fetches |
| `Basic/LoadableCollectionBasicDemoView.swift` | Pagination, empty result, one-shot first/next-page failures, empty intermediate page and both directions |
| `Basic/LoadableCollectionSinglePageDemoView.swift` | The full-list example with UK cities; empty and loaded states, no cursors |
| `Search/LoadableCollectionSearchDemoView.swift` | 120 generated people, query threshold, accent/case-insensitive names, 400 ms debounce, explicit submission, filtered pagination and no results |
| `LoadableCollectionUIPreviews.swift` | Public UI with List, scrollable cards, adaptive grid, default states and manual empty-page continuation |
| `State/LoadableStateDemoView.swift` | Three-store ViewModel, partial readiness, blocking initial failure, retained refresh/page errors, retry/reload/cancel and frozen group states |
| `Chat/LoadableChat+Preview.swift` | Generated chat, previous/next history, optimistic sending, incoming events, gaps, delivery/page retry and an empty conversation; see [chat instructions](ChatPreview.md) |
| `Chat/Components/LoadableChat+Composer.swift` | Native glass send button, grouped text field and noninteractive pending progress, with material fallback on older systems |
| `LoadableSnapshotPreviews.swift` | Frozen loaded/loading/empty/error states using the same row/result presentation |
| `Shared/DemoComponents.swift` | Isolated row, empty/error presentation, introduction and diagnostic footer |

There are 64 named previews. Collection/value controls expose a scenario picker,
response time (0 / 0.6 / 1.5 / 3 seconds), restart and cancellation. The collection
demo also allows disabling automatic prefetch and requesting previous pages.
Errors are deliberately one-shot, so Retry demonstrates recovery; resetting the
scenario resets the failure. Frozen previews intentionally do not react to fetch
commands: use live demos to test behavior. Snapshot examples use `items:phase:`
initialization without a custom source, with `.failed(error)` for first-load errors.
The Merged state example combines two value stores and one collection; content
remains visible after retained refresh/page failures.

## Advanced search from Pentacomp

The original options remain available in the public DEBUG view initializer:

- `minimumLength` (default 2);
- `debounce` (default 400 ms);
- `showsAllWhenEmpty`;
- `showsLoadingWhileWaiting`;
- `responseDelay` (default 1.5 seconds).

Named variants cover showing all results for an empty query, requiring text first,
a one-second debounce with a waiting indicator, and a wide window. Example chips
search for Smith, García using the unaccented query `garcia` (Ignore accents),
or a phrase with no matches. All demo labels, preview titles and descriptions
are in English; the accented surname is a search fixture.
Return/Search and the search button submit immediately. The diagnostic footer
shows the active query, pending query, debounce state and next cursor.

Changes to the query cancel outdated work before the next debounce commits.
Below-threshold text hides results and ends the previous session. Re-entering
the same valid query after this gate closes can start a fresh request.

## Validation

Preview sources and search gating have 13 additional Swift Testing tests. Tests
use zero response delays and explicit task completion, not sleeps as barriers.
The chat adds 28 further tests with controlled pagination/send/event overlap,
pending delivery before remote persistence and transient animation lifecycle.
Its 12 named conversation previews include a frozen pending outbox, an interactive
three-second send and a composer-to-bubble animation with requested keyboard focus.
Two further composer previews isolate the ready and pending glass controls.
The shared pagination edges add 13 tests for automatic loading and bounded/manual
continuation. The library suite now contains 237 tests; all 67 existing package
tests also pass. Chat uses automatic header/footer loading by default; its controls
include a manual-mode toggle for comparison.
Previews and their macros compile for iOS 17 Simulator and macOS. The Release
product builds with demo declarations excluded by `#if DEBUG`.

Xcode RenderPreview rendered the loaded frozen list, live search, value skeleton,
gallery in light appearance and the larger-text gallery on macOS. Visual review
identified hidden gallery tabs in a narrow window; the final gallery uses an
segmented selector when space permits and a labelled menu in narrow windows. An iOS preview render timed out;
iOS validation here is a compiler check. These screenshots validate layout, not
a substitute for interactive testing in Canvas. Runtime UI acceptance in
BluetoothKit remains postponed.

Chat follow-up: real iOS 27.1 iPhone preview renders also verify pending delivery
and the native bottom safe-area glass composer in light/dark appearances, plus
the blue ready-to-send button. All 24 chat tests pass after the styling change;
the DEBUG module still compiles with deployment target iOS 17.
