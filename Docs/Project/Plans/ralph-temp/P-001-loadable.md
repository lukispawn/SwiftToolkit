# Active execution plan — P-001

Follow [P-001](../Ongoing/P-001-loadable.md), including its contracts, iterations,
test qualification and review checkpoints. The user explicitly authorized plan
creation and implementation; no autonomous loop or recurring goal is requested.

Implement and verify the independent core first. Record completed work and
remaining migration work in P-001. Leave the old LoadableModel source untouched.

## Current UI iteration

1. Add a tested presentation/context layer over the existing collection store.
   Preserve retained content, distinguish idle/terminal empty/empty continuation,
   and expose accurate retry and pagination availability.
2. Add public LoadableCollectionView, LoadableList and pagination/status components
   with typed ViewBuilder customization, automatic/manual pagination and explicit
   start/refresh policy. Reuse them in library demos and custom layout previews.
3. Extract the demo's search coordination into a public Observation controller;
   test debounce, gating, cancellation and immediate submission deterministically.
4. Run unit tests, iOS compiler checks, Release build and macOS preview rendering.
   Record results and API examples. BluetoothKit migration remains postponed.

UI iteration completed on 2026-10-27. Verification and remaining consumer acceptance
are recorded in P-001 and Docs/Loadable/TestMatrix.md. See Docs/Loadable/UI.md for
public API usage. Existing consumer migrations remain outside this iteration.

## Namespace follow-up

Move production UI declarations into the LoadableUI enum: List, Collection,
Configuration, Presentation and their contexts. Place default views under
LoadableUI.Components (Loading, Empty, Idle, Failure and Pagination). Keep stores,
sources and search coordination outside this UI namespace, in the same module.
Update preview/consumer examples, tests and documentation to the nested types;
verify public API compilation, all unit tests, iOS 17 and macOS previews.

Namespace follow-up completed: nested public types, migrated previews/examples/docs,
226 passing tests, iOS 17 compilation, Release build and macOS render verification.

## Shared state and aggregation

Add an immutable Sendable LoadableState projection to value/collection snapshots
and stores. Expose a MainActor LoadableStateProviding protocol for heterogeneous
store groups. Keep detailed snapshots and request ownership unchanged.

Merge requires all supplied leaves to have loaded data (empty collections and
loaded optional nil count). Preserve readiness during refresh/pagination and keep
all failures, classifying them as blocking only when their leaf has no loaded
result. Blocking failure precedes loading; unfinished inactive groups are idle.
Empty groups are idle. Preserve leaf counts and activity through nested merges.

Test projection, exhaustive phase combinations, merge associativity/order,
nested Observation, cancellation/retry/query reset and store lifetime. Add an
interactive multi-store ViewModel preview with ready/loading/blocking and retained
failure scenarios. Document that state aggregation does not schedule requests or
guarantee a common request generation. Verify all tests, coverage, iOS and Release.

Initial-state convenience follow-up: add frozen collection init(items:phase:hasLoaded:)
and value init(phase:)/init(constant:phase:) without supplying a fake Source.
Use existing OperationSource types internally; retain strongly typed real sources.
Add first-load Phase.failed(error) shorthand. Verify frozen commands and loaded
empty/nil semantics and use shortcuts in snapshot previews.

Shared state and convenience follow-ups completed: 263 passing test declarations,
100% shared-state line/region coverage, iOS 17 compilation, Release build and macOS
render verification. Usage is in Docs/Loadable/State.md. The preview gallery has
49 named examples. No required work remains for these two follow-ups.

## Chat preview experiment

Build a DEBUG-only chat demo around LoadableUI.Collection with previous/next
keyset pagination, generated messages, outgoing delivery/retry and simulated
incoming events. Start in the middle of history; also support jumping to latest.
Keep the engine unchanged: appendItems/setItems invalidate cursor membership, so
compose paged history with an ID-deduplicated outbox/live overlay in the demo model.
Hide live-tail messages behind a newer-history gap until the user catches up.
Use stable row IDs and SwiftUI scroll positioning for older-page anchoring, with
an explicit follow-new-messages toggle. Cancel view-owned demo work on exit.

Test source cursor boundaries/overlap, failure retry, idempotent sending, overlay
deduplication, sending during page fetch, gap handling, cancellation and lifetime
using completion barriers and a controlled Clock. Add the chat to the gallery,
render representative states, compile for iOS 17 and run all tests. Document
supported composition and actual limitations rather than changing core semantics.

Completed on 2026-10-28: chat is available in the gallery and nine dedicated
previews. It includes a 90-message mock server, both directions, empty/history
windows, generated drafts/incoming events, optimistic sending and one-shot
failures with retry. Stable client IDs deduplicate delivery and history. Initial
window loading resumes after cancellation; resetting options replaces and starts
the model. Production store semantics and BluetoothKit remain unchanged.

Verification: 22 new chat tests; all 285 package test declarations pass. The three
chat source/model/fixture files have 93.14% executable line coverage. iOS 17
module/preview compilation, Release build and macOS preview rendering succeed.
Scroll anchoring and keyboard gestures still need interactive Canvas acceptance.
Contracts and manual checks are in Docs/Loadable/ChatPreview.md.

## Pending delivery follow-up

Make optimistic delivery visible with Sending / Sent / Not sent labels. Add a
frozen full-conversation preview with a local pending outbox item and a live
three-second response variant. Keep frozen outbox fixtures immutable on exit.
Use a controlled Clock to prove pending messages are visible locally but absent
from the simulated server until commit, and remain local after a failed write.
Verify chat tests, iOS compilation and a rendered pending bubble.

Completed: visible delivery labels, a frozen local outbox preview and a live
three-second send preview. Clock-controlled tests verify server reads before and
after successful/failed persistence, stable client IDs and frozen exit behavior.
All 287 package test declarations pass; iOS 17 DEBUG compilation succeeds and the
pending full-chat preview renders on macOS. There are 61 named previews overall.

## Chat composer visual follow-up

Place the composer in a native bottom safeAreaBar on iOS/macOS 26+, keeping a
safeAreaInset fallback for older deployments. Use native blue glassProminent send
buttons and a grouped glass text field. Show a separate noninteractive glass
progress indicator while the outbox is sending and no new draft is ready; typing
another draft still allows concurrent sends. Preserve keyboard safe-area behavior.
Add focused ready/pending previews, compile for iOS 17, run chat tests and inspect
real iOS light/dark renders. No production store changes are required.

Completed: extracted ChatDemoComposer with native glass controls, explicit
pending progress and availability fallbacks. All 24 chat tests and iOS 17 DEBUG
compilation pass. Real iPhone iOS 27.1 light/dark pending-chat and ready-button
renders were inspected. Added two focused previews (63 overall). Keyboard gesture
acceptance remains manual; store/source ownership and behavior are unchanged.

## Composer-to-bubble transition

Use the Kavsoft video supplied by the user as a visual reference for a local
send transition. Keep the native TextField mounted and focused; animate a
noninteractive visual copy from its measured bounds to the new bubble's anchor.
Resolve the lazy destination after scrolling, preserve stable message IDs and
keep pending/server acknowledgement independent from animation completion.
Reduce Motion, historical windows or unavailable geometry skip the flight.
Identity-check cleanup so repeated sends or stale completions cannot hide a newer
message. Cancel visual state on reset, exit or a clearing history request.
Add an interactive keyboard preview and verify transition state, pending delivery,
iOS 17 compilation and representative iPhone renders. The public engine is unchanged.

Implementation completed with an anchor-driven visual copy, stable flight IDs,
completion-based cleanup, native field focus and no timers. The real bubble is
hidden only after the copy mounts, so missing layout preferences cannot hide a
message. Animation cleanup is independent from source acknowledgement. All 291
package declarations pass, including 28 chat tests; iOS 17 DEBUG compilation
succeeds. iPhone pending and focused-input previews render (64 previews overall).
Interactive motion/keyboard acceptance is explicitly deferred at the user's
request; the Mac was locked, so no gesture or recording result is claimed.

## Automatic pagination edges

Replace the chat's manual page controls with the shared Pagination component,
following IKP's visible sentinel pattern. In automatic mode, visible headers and
footers load their direction; manual/disabled policies remain available. Use actual
scroll visibility on iOS 18+/macOS 15+ and appearance on iOS 17. Keep a persistent
per-edge gate across loading-state changes: one request at a time, no automatic
retry, stop at repeated cursors or no directional boundary progress, and offer
explicit continuation. A fresh reload/refresh session resets that gate, even when
query/cursors are reused. Keep requests store-owned and preserve bounded empty-page
handling. Test both directions, repeated visibility, errors, empty/overlapping
pages, cycles, sessions, cancellation and frozen/manual/disabled states. Update
chat previews, docs and public-import examples; compile iOS 17 and verify tests.

Completed: shared Pagination now uses visible automatic sentinels in both
directions, with explicit retry/continuation after errors or stalled/cyclic pages.
The chat uses this component at both edges and offers a manual-mode toggle.
Directional boundary identity prevents an opposite page from unblocking a stalled
edge; an Observation-tracked session identity resets the guard on reload/refresh.
Added 13 controlled tests; all 304 package declarations pass (237 Loadable and 67
existing). The guard has 100% executable line coverage and 95.65% region coverage.
iOS 17 DEBUG compilation and the Release build succeed. Inspected an iPhone
iOS 27.1 render of retained content with the shared pagination failure view.
Interactive Canvas acceptance remains deferred as previously requested.

## Chat feature organization

Refactor the DEBUG chat example into the LoadableChat namespace, following the
user's gotap-swiftui feature convention. Keep ViewModel stored state/initializers
separate from computed projections and actions. A LoadableView owns and resets
the observable ViewModel; ContentView receives it through Bindable and owns only
transient presentation state. Nest configuration, message/source types and child
views under the feature, using extension filenames and small role folders.
Move NavigationStack to the demo host. Update all tests, gallery and documentation
references without compatibility aliases. Preserve pagination, pending delivery,
cancellation, frozen fixtures and the iOS 17 deployment target. Verify existing
behavior tests, DEBUG iOS compilation, Release and a representative preview.

Completed: all chat declarations are nested under LoadableChat. LoadableView owns
the observable model, configuration and demo navigation; ContentView receives a
Bindable model and only holds presentation state. Models, Source actor and child
views live in role folders; ViewModel methods/projections are grouped in same-file
extensions, preserving private task ownership. Updated gallery, all fixtures/tests
and current documentation without aliases. All 304 tests pass, Xcode builds,
iOS 17 DEBUG compilation and Release succeed. Inspected the iPhone iOS 27.1
pending-delivery preview. There are still 64 named previews; interactive acceptance
remains deferred. No production store or public API changes were required.
