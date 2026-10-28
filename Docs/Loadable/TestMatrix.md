# Loadable verification

## Behavioral suites

| Suite | Scope |
| --- | --- |
| ValueStoreTests | State, optional nil, non-Equatable models, failure, retry, constants, nested Observation |
| ValueConcurrencyTests | Stale success/failure, stale cleanup, caller cancellation, frozen state, release during fetch |
| CollectionStoreTests | Initial loading, query/cursor reset, retry mode, serialized pagination, constants |
| CollectionPaginationTests | Both directions, ID merge, custom merge, totals, empty pages, cyclic tokens, prefetch, page factories |
| CollectionConcurrencyTests | Response ordering, reload/page overlap, scoped cancellation, release, Observation availability |
| RequestSequenceTests | All six completion orders of three requests, stale successes and errors; cooperative cancellation |
| RetentionTests | Cross-query boundaries, retained-data cancellation, source CancellationError, reload metadata, refresh replacement |
| MappingTests | Async value/page conversion, base/transform errors, cancellation during mapping, filtered empty pages |
| SnapshotStreamTests | Replay, independent subscribers/buffers, cancellation, store release, coherent page publication |
| LocalMutationTests | Authoritative updates versus pending fetches, pagination invalidation, no-op/frozen behavior, retained refresh |
| QueryDebouncerTests | Controlled Clock deadlines, stale wakeup/failure, immediate commit, cancellation, deallocation, Observation |
| ConsumerMigrationTests | Statistics events, nested wrapper Observation, sorted debounced search and wrapper lifetime |
| CollectionPresentationTests | Retained rows in every phase, idle versus terminal empty, empty continuation and directional failures |
| CollectionContextTests | Live metadata/Observation, accurate action availability, start/refresh policy, both pagination directions, frozen/ended sessions, manual/disabled prefetch, bounded empty continuation and shared-store lifetime |
| AutomaticPaginationTests | Visible directional edges, duplicate triggers, boundary progress, empty/overlapping pages, cursor cycles, explicit retry/continuation, session reset, cancellation and frozen/manual/disabled states |
| CollectionSearchTests | Query mapping, gates, immediate/debounced submission, stale responses/wakeups, injected Clock, Observable requirements and controller lifetime |
| LoadableStateTests | 100-pair readiness/activity matrix, all failures, grouping associativity, stable error order and empty-group identity |
| StateProjectionTests | Value/collection phases, loaded optional nil, empty/intermediate pages, metadata-based readiness and page failure direction |
| StateObservationTests | Heterogeneous/nested groups, eager Observation reads, both completion orders, retained refresh/page failure, retry/query reset, cancellation, constant stores and lifetime |
| ConstantStateInitializerTests | Source-free frozen initialization, first-load failure shorthand, retained optional nil/empty results, explicit readiness and frozen commands |
| PreviewScenarioTests | Pentacomp demo failure/retry, empty intermediate pages, bidirectional data, case- and accent-insensitive search, minimum-length gate, one-shot value failures |
| ChatSourceTests | Keyset boundaries, complete backward traversal, one-shot directional failures, idempotent/concurrent sends and a page captured before live events |
| ChatModelTests | Previous/next composition, outbox/history deduplication, gap buffering, empty conversation, send/page overlap, cancelled retry cleanup, resume and lifetime |
| ChatPendingDeliveryTests | Local pending visibility before remote persistence, server reads during and after successful/failed writes, stable IDs and immutable frozen outbox fixtures |
| ChatSendTransitionTests | Stale visual completions, cancellation, Reduce Motion/history/missing-geometry fallback and animation completion independent from remote acknowledgement |

The suites use Swift Testing, fresh actors per case and checked continuations.
No sleeps, polling, scheduling yields, network calls or shared mutable fixtures
are used as synchronization barriers. Demo sources use zero response delays in
tests; real delays exist only for manual preview interaction. Internal request handles are awaitable completion barriers in tests;
they are not public API. Swift Testing time limits act as a failure watchdog.

## Pentacomp qualification

- Ported as behavioral scenarios: stale successes/failures; same-query start;
  invalidation before execution; cancelled session/request distinction; retry first
  page vs failed continuation; one in-flight page; query reset; retained data;
  terminal/intermediate empty pages; continuation limits; repeated tokens;
  small-page/late-row prefetch; constant snapshots and operation sources.
- Adapted: Combine publication assertions use Observation tracking. The new
  `load` intentionally has caller-owned cancellation; `refresh` remains store-owned.
- Extended: previous pages; cyclic cursors; ID deduplication and custom merge;
  source and caller cancellation; old-caller/new-request races; loaded nil;
  total-count preservation; deallocation during noncooperative suspension;
  all completion permutations of three requests.
- Added in iteration 4a: clock-injected debounce tests, async transformations,
  local changes, independent snapshot subscriptions and consumer-contract fixtures.
- Deferred with capabilities: automatic refresh triggers, cache/remote CRUD and
  real-consumer UI acceptance. Local mutation tests do not claim remote CRUD support.

## Skill review checkpoints

Verification on 2026-10-27, after iteration 4a: all 115 Loadable tests (12 suites,
including parameterized cases) and all 67 existing tests passed. LLVM coverage
for the new module was 98.38% of executable lines and 96.18% of regions. Value
Store line coverage was 100%; Collection Store was 98.53%. The new mapping,
snapshot channel and debouncer files had 100% line coverage. Coverage does not
replace behavioral review.

The module and SwiftUI examples also compile/typecheck for arm64 iOS Simulator
with deployment target iOS 17. Unit tests ran on macOS with Swift 6.4, language
mode 6, retaining the package's Swift tools 6.1 manifest. A Swift 6.1 toolchain
run has not been performed. Rendering in a real consumer app remains a migration
checkpoint. See the separate preview verification below.

### Interactive preview verification

After adding the DEBUG gallery, all 128 Loadable tests and all 67 existing tests
pass. There are 30 named previews, ported from Pentacomp and extended for value,
error, frozen states and responsive presentation. The coverage figures above were
recorded before the DEBUG UI gallery was added; they are not a new whole-module
coverage measurement including demo views.

Xcode RenderPreview produced macOS screenshots for loaded rows, advanced search,
value loading, a larger-text gallery and the final light gallery. Visual review
replaced hidden narrow-window tabs with a visible segmented demo selector. An iOS
render timed out; preview macros and source compile for iOS 17 Simulator. The
Release product builds using the native SwiftPM backend, excluding DEBUG demos.
See [preview instructions and scenarios](Previews.md).

Reproduce the package run with `swift test --enable-code-coverage`, or run only
the new tests with `swift test --filter LoadableTests`. In a restricted environment,
redirect CLANG_MODULE_CACHE_PATH and SWIFTPM_MODULECACHE_OVERRIDE to writable
temporary directories and use SwiftPM's `--disable-sandbox` for macro plugins.

### swift-concurrency

- Boundary: UI-facing mutable state and request replacement are MainActor isolated.
- An unstructured task is deliberate for store-owned operations; `load` explicitly
  forwards cancellation through a scoped request handle. No detached tasks.
- Identity and cancellation are checked before fetch and after suspension, before
  success/error publication. Cleanup compares the request ID.
- Sources are captured separately from weak stores; deallocation is tested.
- No unchecked Sendable or unsafe isolation escape hatches in the module.
- Source mapping checks cancellation before and after every source/transform await.
- Snapshot delivery is synchronous on MainActor; termination removes only the
  cancelled subscription and channel release finishes all streams.
- Debounce tasks capture sleep and weak self separately and validate both identity
  and cancellation after wakeup. A stale sleep failure cannot clear newer input.
- Swift tools remain 6.1; no Swift 6.2-only isolated deinit/default-isolation APIs.

### swift-testing-expert

- Each test has its own sources and mutable state. Suites remain parallel-enabled.
- Parameterized scenarios cover directions, limits, outcomes and completion orders.
- Preconditions use #require. Tests await the actual request, not arbitrary delays.
- The probe tests cancellation-aware sources; controlled sources deliberately ignore
  cancellation. Both behaviors are needed to test the engine's guarantees.
- A Clock spy records exact deadlines and lets tests release individual sleeps.
  It deliberately ignores cancellation to test the scheduler's own protections.
  Consumer fixtures are contract tests, not claims of migrating the host app.

### swiftui-expert-skill

- New types use Observation with MainActor isolation and view-owned @State.
- Nested reads are tracked without Combine forwarding.
- Session/frozen flags influencing command availability remain observable; task
  handles and implementation details are ObservationIgnored.
- Compiler-checked list/value examples use stable IDs, task and refreshable.
- The search example owns store/debouncer with @State and commits via a weak
  store capture. Debouncer state and local store changes are Observation-tested.
- Real SwiftUI rendering and consumer navigation/lifetime remain acceptance checks
  for migration, not claims made by these unit tests.

### Public collection UI verification

The production UI adds 31 test declarations in three suites; all 159 Loadable tests
and 67 existing package tests pass (226 declarations plus parameterized cases).
`ConsumerCompilationExamples.swift` checks typed state/footer modifiers and custom
layouts through public imports. Existing demo sources/search tests now exercise
the shared public UI/controller path. There are 42 named previews, including
List, cards, adaptive grid, empty continuation and default states.

Reviews use swiftui-expert-skill for composition/Observation and stable retained
content; swift-concurrency for MainActor actions, weak debounce captures and explicit
store task ownership; swift-testing-expert for isolated sources, Clock injection
and completion barriers. These unit tests prove state/action contracts, not actual
scroll gestures. Consumer-app UI acceptance remains postponed.

Final verification on 2026-10-27: Debug tests and public consumer examples pass;
preview macros and production UI compile for arm64 iOS 17 Simulator; the Release
Loadable product builds with demos excluded (native SwiftPM backend). macOS
RenderPreview snapshots were inspected for the native list/loading surface, loaded
grid, retained page error and default empty state. The empty-continuation live
preview rendered its initial loading surface; continuation behavior is covered by
deterministic context tests and remains available for interaction in Canvas.

LLVM coverage from the unit-test run is 100% executable lines for presentation,
context/actions and the search controller (search regions: 96.15%). Production
sources excluding DEBUG previews have 78.21% line coverage overall because SwiftUI
view bodies are validated through separate Xcode rendering, not executed by unit
tests. The 100% logic figures do not claim full UI or gesture coverage.

Gallery follow-up: the main entry now opens on LoadableUI.List and includes Layouts
with an interactive List / Cards / Grid selector sharing one store. Direct gallery
previews cover layouts and search; there are 42 named previews. The 44 relevant
scenario/context/search/presentation tests pass, iOS 17 preview macros compile,
and layout/search gallery previews render on macOS. Rendered live snapshots show
the initial loading state; loaded-state layouts have separate frozen previews.

Namespace verification: all UI consumers and public-import compilation examples use
`LoadableUI.List`, `.Collection`, `.Configuration`, action contexts and nested
`Components` views. All 159 Loadable tests plus 67 existing tests pass after this
refactor. Production UI/preview macros compile for iOS 17 Simulator; Release builds;
loaded-grid and retained-page-error previews render on macOS. Core store/source/
search names and request ownership are unchanged. No new behavioral tests were
needed for the naming refactor; existing scenarios validate the nested API.

## Shared state and initial-state conveniences

All 196 Loadable tests across 20 suites and all 67 existing package tests pass
(263 declarations plus parameterized cases). This iteration adds 26 shared-state
and 11 frozen-initializer test declarations. The shared-state pair matrix alone
checks 100 combinations. Public-import compilation examples verify heterogeneous
aggregation and an inferred-item `LoadableUI.List` initialized with only a failure.

LLVM coverage for the three shared-state files is 100% executable lines and
regions. The entire production module excluding DEBUG previews is 79.81% executable
lines and 83.36% regions: SwiftUI bodies are validated in a separate render process.
Frozen-initializer files include unused fallback-source closures that are never
called by a frozen store; tests intentionally verify that no fetch is started.

iOS 17 Simulator module/preview macros compile, and the native SwiftPM Release
product build succeeds. macOS preview images were inspected for all three required
stores loaded, retained refresh failure, and a retained page failure constructed
with `items:phase:`. The last render was initially deferred by an automatic approval
review usage-limit failure and later completed successfully through the same Xcode
tool. There are 49 named previews, including six multi-store scenarios and the
main gallery's Merged state entry. No consumer-app/device gesture acceptance is
claimed; BluetoothKit migration remains postponed.

Skill checks: swift-concurrency confirms pure Sendable state values, MainActor
provider reads and no added observer/request tasks; swift-testing-expert confirms
independent sources, explicit completion barriers and exhaustive table cases;
swiftui-expert-skill confirms computed nested Observation and view-owned @State
stores. Detailed snapshots and source Failure types are preserved. See
[shared state contracts and examples](State.md).

## Chat preview experiment

Verification on 2026-10-28: all 218 Loadable tests in 22 suites and all 67 existing
package tests pass (285 declarations plus parameterized cases). The 22 new chat
declarations exercise the real collection engine with generated keyset history
and a separate live/outgoing overlay. No core store behavior was changed.

The mock source has 98.02% executable line coverage, the chat model 89.20%, and
the generated message fixture 100%; together these three files have 93.14% line
coverage and 84.62% region coverage. These figures exclude chat SwiftUI bodies.
Controlled Clock cases cover stale cancelled sends, concurrent idempotent sends,
live events during a captured older page, and cancellation/resume of initial
windows. No test uses response-time sleeps as a synchronization barrier.

Reviewed with swift-concurrency (actor server, MainActor model, cancellation,
weak task ownership and identity-checked cleanup), swift-testing-expert (fresh
sources, parameterized directions, awaitable handles and controlled Clock), and
swiftui-expert-skill (Observation ownership, stable row IDs, custom public UI
contexts, scroll position, Reduce Motion and delivery accessibility labels).

The DEBUG module and preview macros compile for iOS 17 Simulator; the native
SwiftPM Release product builds with demos excluded. macOS RenderPreview snapshots
were inspected for loaded bubbles, retained page error, terminal empty and live
initial loading. The gallery now has 59 named previews, nine specific to chat.
Interactive keyboard/gesture and prepend-anchor acceptance remains a Canvas
check; it is not established by model tests or static screenshots. See the
[chat experiment and manual checks](ChatPreview.md). BluetoothKit is untouched.

Pending-delivery follow-up: all 220 Loadable tests in 23 suites and 67 existing
tests pass (287 declarations plus parameterized cases). A controlled Clock holds
the server write while a separate server read completes, proving that a pending
message is local-only. After release, success persists the same ID; failure leaves
the message local with retry. A second test verifies frozen pending fixtures
remain unchanged and do not send when the view exits. The earlier coverage
percentages describe the preceding run, before these two declarations were added.
Visible Sending / Sent / Not sent labels and two new named previews make this
behavior inspectable. The iOS 17 DEBUG module compiles and macOS RenderPreview
shows the pending bubble at the bottom; there are now 61 named previews overall.

Composer styling follow-up: all 24 chat test declarations pass; iOS 17 DEBUG
compilation succeeds with guarded iOS/macOS 26 glass/safeAreaBar APIs and older
safeAreaInset/material fallbacks. iPhone iOS 27.1 RenderPreview images were
inspected for a ready blue glassProminent button and a pending conversation in
light/dark appearances. Pending progress is a read-only accessibility element;
typing a new draft restores the send action without changing request ownership.
No new unit tests mirror this visual refactor. Keyboard/gesture acceptance is
still an interactive check. The gallery has 63 named previews.

Composer-to-bubble follow-up: all 224 Loadable tests in 24 suites and 67 existing
tests pass (291 declarations plus parameterized cases). Chat has 28 declarations
in four suites. New tests cover repeated/stale visual completions, cancellation,
Reduce Motion, historical windows, invalid geometry and a flight landing before
the server write completes. A missing destination leaves the real bubble visible.
The visual copy is accessibility-hidden and noninteractive; the native TextField
and message identity are retained. No animation timers or delivery changes were
added. The iOS 17 DEBUG module compiles. iPhone iOS 27.1 renders were inspected
for retained pending content and the new focused-input preview's initial loading.
The gallery has 64 named previews. Interactive motion/keyboard verification was
explicitly postponed by the user after the Mac was found locked. Static renders
and state tests do not claim a verified frame-by-frame animation.

## Automatic pagination edges

Verification on 2026-10-28: all 237 Loadable tests in 25 suites and all 67
existing package tests pass (304 declarations plus parameterized cases). The 13
new declarations exercise both header/footer directions with controlled request
completion, including the engine's bounded empty-page chain. Observation tracks
fresh session identity even when a refresh reuses the same query and snapshot.

The automatic edge guard and its context accessors have 100% executable line
coverage (33/33) and 95.65% region coverage (22/23); these figures exclude SwiftUI
bodies and native visibility callbacks. Reviewed using swift-concurrency,
swift-testing-expert and swiftui-expert-skill: the view owns only the trigger
guard, requests remain store-owned, and disappearance does not cancel shared work.

The iOS 17 DEBUG module compiles and the Release product builds. An iPhone Duo
iOS 27.1 RenderPreview confirms the shared pagination failure presentation keeps
loaded chat bubbles and the bottom composer visible. There are still 64 named
previews. Interactive scrolling, keyboard and animation acceptance remains
explicitly deferred; static renders do not establish native gesture behavior.

## Chat namespace refactor

The DEBUG chat example now uses LoadableChat.ViewModel, ContentView, LoadableView
and nested models/components/source types. Existing tests use the nested types
directly, without compatibility aliases. All 304 package declarations still pass
(237 Loadable in 25 suites, 67 existing); the chat's 28 behavioral declarations
continue to cover pending writes, pagination, cancellation and model lifetime.
No tests were added solely to mirror file placement or type names.

Xcode builds successfully, DEBUG preview macros compile for iOS 17 Simulator,
and the Release product builds with the entire feature excluded. The iPhone Duo
iOS 27.1 pending-message render was inspected after moving the feature files.
The gallery still has 64 named previews. Interactive acceptance remains deferred.
