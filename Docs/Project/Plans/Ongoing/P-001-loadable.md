# P-001 — Loadable: value and collection loading

Status: in progress. Started: 2026-10-27.

**Release follow-up, 2026-10-28:** the owner now explicitly requests legacy API
deprecation and a 1.8.0 release. This supersedes the original no-deprecation scope;
the dated iteration records below retain their historical meaning. Legacy
implementations and products remain available during consumer migration.

## Goal

Build a new, independently tested `Loadable` module alongside `LoadableModel`.
Keep the existing products and consumers working. Combine Pentacomp's explicit
request ownership and regression scenarios with SwiftToolkit's Observation,
bidirectional pagination and merging by identity. No dependency on either old engine.

## Contracts

- Stores are `@MainActor @Observable`; source operations are Sendable.
- Every request has an identity. Superseded success, failure and cleanup cannot
  affect the current request. Cancellation is cooperative, identity is authoritative.
- `start` opens a query and clears old data; repeated queries are ignored unless forced.
- `reload` clears data; `refresh` retains data. Both are store-owned operations.
- `load` awaits a request and forwards caller cancellation only to that request.
  An already-cancelled caller does not open a request. A source ignoring cancellation
  can delay the awaiting caller, but cannot publish its eventual result.
- Request tasks must not keep their store alive during suspended source operations.
- Errors retain previous data and query. Retry repeats the failed operation.
- A loaded optional nil is distinct from a value not yet requested.
- Value has no Identifiable/Equatable requirement. Snapshot equality is conditional.
- Collections merge by ID, support both directions, retain opposite cursors and
  server total counts, and serialize pagination against reload/refresh.
- Constant snapshots are frozen, suitable for previews without fake requests.

## Iterations and acceptance criteria

1. [x] Value core and test infrastructure: source, snapshot, typed failures,
   operation/constant sources, loading, retry, cancellation, deallocation.
   Review using swift-concurrency and swift-testing-expert.
2. [x] Collection core: query+cursor in every request, merging, retry, prefetch,
   bounded empty-page continuation. Port applicable Pentacomp scenarios.
   Review using swift-concurrency and swift-testing-expert.
3. [x] Observation and integration: nested read tracking, compiler-checked SwiftUI
   examples, build alongside existing targets, document API and limitations.
   Review using swiftui-expert-skill and concurrency/testing skills.
4. [ ] Optional capabilities and migration: assess real consumers before adding
   cache adapters, async transforms, event streams, CRUD, clock-driven debounce,
   refresh triggers, old-API adapters and deprecations. No speculative abstractions.
   Migrate one value screen and one list in their owning repositories before
   recommending broad adoption or removing the old implementation.

### Iteration 4a — consumer-backed capabilities (completed)

Consumer survey: BluetoothKit's ValueHistoryStatisticsUI needs event-driven
retained refresh; CollectionsManagerUI sorts fetched records; ValueHistoryUI
debounces queries and updates local rows. Pentacomp-style reducers need snapshots.

- [x] Async value/page transformation adapters with cancellation checks.
- [x] Explicit retained background refresh, separate from clearing reload.
- [x] Synchronous local updates that invalidate older requests; collection
  membership replacement invalidates pagination rather than reusing stale offsets.
- [x] Independent snapshot streams with initial replay and lifecycle cleanup.
- [x] Query debounce with an injectable Clock; immediate submission, cancellation,
  stale wakeup and deallocation tests without real delays.
- [x] Integration fixtures reflecting statistics refresh and sorted lists;
  concurrency, testing and Observation review; full package and iOS compile checks.

Iteration 4b remains real-consumer migration in owning repositories. Cache policy,
generic CRUD services, automatic refresh triggers and old-API deprecations remain
deferred until a specific migration requires them. This stage changes SwiftToolkit.

## Test qualification

### Interactive preview gallery (completed)

BluetoothKit migration is postponed at the user's request. Port the existing
Pentacomp basic, single-page and advanced search demos into DEBUG library sources,
preserving scenarios and improving hierarchy, controls and diagnostics. Adapt to
Observation and current phases/cursors; add value/frozen-state previews. Verify
demo sources without delays, macOS/iOS builds and preview rendering where available.

Port scenarios, not Combine machinery, from Pentacomp's Collection tests:
stale success/error, retry first vs next page, query invalidation, repeated
commands, empty pages, prefetch, constant snapshots. Extend to previous pages,
overlapping IDs, server totals, caller cancellation and store lifetime.
Use manually completed sources and awaitable barriers, not sleeps/polling.
Test noncooperative as well as cooperative sources. Test command sequences and
invariants in addition to examples. Keep tests parallel-safe and resource-local.
Use coverage as a diagnostic, not an acceptance percentage.

## Build and delivery

Retain Swift tools 6.1, iOS 17 and macOS 15. Do not adopt 6.2-only APIs.
New module has no external dependencies. Run focused tests first, then existing
package tests. Preserve unrelated pre-existing checkout/build changes.
Record commands, outcomes and review findings below. No migration/deprecation
until the new contract is verified in real consumers.

## Execution log

- Planning: inspected existing stores, Pentacomp collection engine and tests.
  Existing package uses Swift tools 6.1; installed compiler is Swift 6.4.
  User authorized both plan creation and implementation in this conversation.
- Implemented independent dynamic Loadable product, value and collection sources,
  snapshots, stores, constant/operation sources and scoped cancellation support.
  Existing LoadableModel source and tests are unchanged.
- Completed skill review checkpoints (swift-concurrency, swift-testing-expert,
  swiftui-expert-skill); review findings and test qualification are recorded in
  [TestMatrix](../../../Loadable/TestMatrix.md).
- Review adjustment: collection session/frozen flags remain observable because
  they affect canLoadMore; internal task handles remain ignored by Observation.
- Verification: 74 new tests across 7 suites passed, including parameterized
  completion permutations. Existing 58 utility tests and 9 LoadableModel tests
  also passed in the full package run (141 test declarations total).
- Coverage: new module 97.66% executable lines, 94.74% regions; Value Store 100%
  lines and Collection Store 98.22%. Defensive unreachable identity guards and
  a few factory/constant-source paths remain uncovered; coverage is diagnostic.
- Cross-platform check: emitted the module for arm64 iOS Simulator with deployment
  target iOS 17, and typechecked the SwiftUI examples for that target. Tests ran
  on macOS. The installed compiler is Swift 6.4, language mode 6; an actual Swift
  6.1 toolchain run has not been performed.
- Build environment: standard cache directories are read-only; module caches were
  redirected to /tmp, and nested compiler macro sandboxing disabled for these runs.
  No source workaround or minimum-platform change was needed.
- Iteration 4a: added source mapping, independent snapshot streams, retained
  background refresh, conservative local mutations and clock-injected debounce.
  Membership changes clear pagination, while existing-ID updates preserve cursors.
  Page publication was made atomic for stream consumers.
- Iteration 4a verification: 115 Loadable tests across 12 suites and all 67 existing
  tests pass (182 declarations total, with additional parameterized cases).
  New module coverage is 98.38% executable lines and 96.18% regions. New mapping,
  channel and debouncer files have 100% executable line coverage.
- Iteration 4a reviews: checked MainActor boundaries, cancellation before/after
  each mapping await, weak task ownership and subscription termination using
  swift-concurrency; checked deterministic clocks and barriers with
  swift-testing-expert; checked @State, weak commit callbacks, nested Observation
  and compiled search examples using swiftui-expert-skill. The module compiles
  for iOS Simulator with deployment target iOS 17.
- Remaining: iteration 4b migrates real consumers in their owning repositories.
  See [migration survey](../../../Loadable/Migration.md). Cache policy, remote CRUD,
  exact old event compatibility and automatic refresh triggers remain deferred;
  no consumer migration, deprecation or old-implementation removal is claimed.
- User postponed BluetoothKit migration while other work is in progress there.
  Completed the requested library-local preview gallery instead: 30 named DEBUG
  previews based on Pentacomp's scenarios, with refreshed presentation, value
  demos, one-shot retry failures, frozen states and visible gallery navigation.
- Preview verification: 13 new scenario tests bring Loadable to 128 tests; all
  67 existing tests pass as well (195 declarations plus parameterized cases).
  macOS and iOS 17 Simulator preview sources/macros compile. Native SwiftPM Release
  build succeeds; the default backend's release dSYM step was sandbox-blocked.
- Xcode RenderPreview rendered the loaded list, search, value skeleton, larger
  text gallery and final light gallery on macOS. The iOS preview render timed out;
  iOS verification is compilation, not a rendered-device claim. Visual review
  fixed gallery navigation in narrow windows. Preview verification used
  swiftui-expert-skill, gotap-apple-hig and gotap-swiftui-testing; actor fixtures
  propagate cancellation and scenario tests use no real wait barriers.
- Entry point: [preview guide](../../../Loadable/Previews.md). Runtime consumer
  migration stays postponed and no BluetoothKit files were modified.
- Preview language follow-up: all 30 preview titles, controls, messages,
  accessibility labels, diagnostics and sample data now use English. The full-list
  example uses UK cities; search uses English names with García as an explicit
  accent-insensitive fixture. Updated matching tests and the preview guide.
  All 195 test declarations pass, preview sources/macros compile for iOS 17
  Simulator, and the English gallery and search render successfully on macOS.

- Public UI iteration completed: added `LoadableCollectionView`, `LoadableList`,
  live MainActor contexts, pure presentation projection, directional pagination
  footer and typed state/footer customization. Store availability exposes
  `canReload` and Observable `canRetry`. Existing collection demos now use this UI.
- Extracted `LoadableCollectionSearch` as an independent Observation controller,
  with generic query mapping, injected Clock, input gate, immediate submission,
  invalidation before debounce and explicit lifetime management. Selection and
  local filtering remain caller composition.
- Added 31 behavioral test declarations: all 159 Loadable tests plus 67 existing
  tests pass (226 declarations plus parameterized cases). Public-import consumer
  examples compile; presentation, context/actions and search have 100% executable
  line coverage. Whole production module excluding DEBUG previews is 78.21% lines:
  view bodies are separately rendered, not counted as exercised by unit tests.
- Verified production UI and preview macros for iOS 17 Simulator, native SwiftPM
  Release build, and macOS renders of list, loaded grid, retained error and empty
  presentation. The library now includes 40 named previews. Reviewed with
  swiftui-expert-skill, swift-concurrency, swift-testing-expert and
  gotap-swiftui-testing. Real consumer/device gesture acceptance is still deferred.
- Usage and explicit startup/refresh/search ownership are documented in
  [Collection UI](../../../Loadable/UI.md). No BluetoothKit migration was made.

- Preview usage follow-up: main gallery now opens on the public LoadableList and
  exposes Layouts (List / Cards / Grid sharing one store), plus direct layout/search
  previews. Gallery selection adapts to narrow windows with a labelled menu.
  Refresh/reload controls work across live custom layouts. All 44 relevant tests
  pass, iOS 17 preview compilation succeeds, and both new gallery entries render
  on macOS. There are 42 named previews; app migrations remain postponed.

- Namespace follow-up completed: production UI is nested under `LoadableUI`
  (`List`, `Collection`, `Configuration`, `Presentation` and action contexts).
  Default views live under `LoadableUI.Components` (`Loading`, `Empty`, `Idle`,
  `Failure`, `Pagination`), each in its own file. `Pagination` names its role
  without tying placement to the bottom edge. Root namespace enums add no state
  or isolation; context MainActor boundaries and store ownership stay unchanged.
- Updated all in-module previews, public-import consumer examples, tests and
  current API documentation. Native list construction explicitly uses SwiftUI.List
  to avoid shadowing by LoadableUI.List. Store/source/search APIs stay independent.
- Namespace verification: all 159 Loadable and 67 existing tests pass (226 total
  declarations plus parameterized cases); iOS 17 Simulator module/preview compilation
  and Release build succeed. Inspected macOS renders of the loaded grid and retained
  page-error list. No old flat UI declarations or references remain in production
  sources, tests or current Loadable docs. See [UI API](../../../Loadable/UI.md).

- Shared-state iteration completed: `LoadableState` projects value/collection
  snapshots and stores through `LoadableStateProviding`. Pure merge and eager
  MainActor provider aggregation preserve nested leaf counts, all error details,
  blocking classification and refresh/page activity. All required data gates the
  content; loaded empty collections and optional nil are valid results. No task,
  subscription, implicit fetch/retry or common-generation guarantee is added.
- Added frozen collection `init(items:phase:hasLoaded:)`, value `init(phase:)` and
  `init(constant:phase:)`, plus collection `.failed(error)` shorthand. Existing
  OperationSource types provide the internal source without changing typed real
  sources. Frozen snapshot previews now use the conveniences directly.
- Verification: 37 additional declarations bring Loadable to 196 tests in 20
  suites; all 67 existing tests also pass (263 total plus parameterized cases).
  Shared-state files have 100% executable line/region coverage. iOS 17 module and
  preview compilation and Release build succeed. Inspected macOS ready-group,
  retained-refresh-error and simplified retained-page-error previews. A temporary
  Xcode approval-review usage-limit failure was resolved by a later successful
  render. The library now has 49 named previews, including Merged state.
- Usage and lifetime/initial-state contracts are documented in
  [Shared state](../../../Loadable/State.md). A production LoadableUI.Group view
  wrapper and consumer migrations remain outside this iteration.

- Chat preview experiment completed on 2026-10-28: `LoadableUI.Collection` builds
  a custom chat ScrollView with previous/next history, generated text and incoming
  messages, optimistic delivery, retry and historical-gap buffering. A separate
  outbox/live overlay preserves the history store's cursors and deduplicates by
  stable ID; no core mutation policy was changed. Reset/resume and task lifetime
  are explicit. Added the Chat gallery entry and nine dedicated previews.
- Verification: 22 new tests; all 218 Loadable and 67 existing tests pass (285
  declarations plus parameterized cases). Chat source/model/fixture line coverage
  is 93.14%. DEBUG preview macros compile for iOS 17, Release builds, and macOS
  loaded/error/empty/loading snapshots were inspected. Reviewed with
  swift-concurrency, swift-testing-expert and swiftui-expert-skill. Interactive
  scroll/keyboard acceptance remains a documented manual check. See
  [Chat preview](../../../Loadable/ChatPreview.md); BluetoothKit is unchanged.
- Pending-delivery follow-up: bubbles explicitly show Sending / Sent / Not sent.
  Added frozen pending-outbox and live three-second send previews. Two test
  declarations verify local-only visibility during a suspended remote write,
  success/failure persistence, stable IDs and frozen exit behavior. All 287 package
  declarations pass (220 Loadable, 67 existing); iOS 17 compilation and a macOS
  pending-chat render succeed. There are 61 named previews overall.
- Composer styling: native bottom safeAreaBar and grouped Liquid Glass input with
  blue glassProminent sending action on iOS/macOS 26+, older safeAreaInset/material
  fallback, and read-only blue glass progress during pending delivery. New drafts
  restore the action without blocking concurrent sends. All 24 chat tests and the
  iOS 17 DEBUG compilation pass. Inspected real iPhone iOS 27.1 ready-button and
  full pending-chat light/dark renders. Two new composer previews bring the total
  to 63. Interactive keyboard checks remain manual.
- Added the composer-to-bubble visual transition inspired by the user-supplied
  Kavsoft video. The native field remains mounted, a visual copy moves to the
  bubble anchor, and pending delivery remains independent. Missing geometry,
  historical windows and Reduce Motion skip the flight; unique IDs protect
  interrupted completion. Four new declarations bring the package to 291 tests
  (224 Loadable, 67 existing); all pass. iOS 17 compilation and iPhone focused-input/
  pending renders succeed. There are 64 named previews. The user explicitly
  deferred interactive Canvas motion/keyboard acceptance after the Mac was locked.
- Automatic pagination edges: the chat now places the shared Pagination component
  above and below the transcript. Visible sentinels load their respective direction;
  manual mode remains available. A persistent view-owned guard stops automatic
  retries, repeated cursors and pages with no directional boundary progress. A
  fresh reload/refresh resets the guard through observed session identity. Request
  ownership and cancellation remain in the store. Added 13 controlled declarations;
  all 304 package tests pass (237 Loadable and 67 existing). Guard line coverage is
  100%, region coverage 95.65%. iOS 17 DEBUG compilation and Release build pass;
  an iPhone iOS 27.1 retained-error render uses the shared pagination presentation.
  Interactive Canvas acceptance remains deferred at the user's request.
- Chat feature organization: all demo types now live under the internal DEBUG-only
  LoadableChat enum. LoadableView owns/reset-cancels the ViewModel and hosts demo
  navigation; ContentView receives a Bindable model. Configuration/message models,
  the Source actor and child views use Models/Services/Components folders and
  extension filenames. ViewModel contains stored state/initializers, with domain
  projections/actions in extensions. Existing fixtures and tests use the new names
  directly. All 304 tests pass; Xcode, iOS 17 DEBUG and Release builds succeed.
  Inspected an iPhone iOS 27.1 pending-message render; 64 previews remain available.
  Interactive Canvas acceptance remains deferred and public Loadable APIs are unchanged.
