# Chat preview experiment

Open `Sources/Loadable/Preview/Chat/LoadableChat+Preview.swift` in Xcode Canvas,
resume **Chat · bidirectional history** and enable interaction. The main
`LoadablePreviewGallery` also exposes a **Chat** entry. Everything is DEBUG-only,
in English, generated locally and independent of BluetoothKit or a network.

The default conversation contains 90 messages and starts around message 45,
loading 12 messages at a time. Older pages appear above the conversation and newer
pages below it. **Jump to latest** starts a new history window at the live end.
Only one history request runs at a time, as in the production store.

## Feature structure

The example is scoped to the internal, DEBUG-only `LoadableChat` enum. Its entry
point is `LoadableChat.LoadableView`: it owns the `@State` ViewModel, simulation
configuration and demo NavigationStack. Changing the scenario, window or latency
stops the old model before replacing it. `LoadableChat.ContentView` receives the
model through `@Bindable`; it contains no NavigationStack and owns only transient
presentation state such as the send transition and pagination toggle.

`LoadableChat.ViewModel` is `@MainActor @Observable`. Its declaration contains
stored properties, initializers and deinitialization; computed conversation state,
lifecycle, composing, incoming messages and delivery helpers live in extensions.
Message, Query, Cursor, Failure, Configuration, Scenario and Window are nested
feature types in `Models/`; the simulated Source actor is in `Services/`.
`Components/` contains Composer, Bubble, Transcript, ScrollContent and the send
transition helpers, all nested under the same namespace. Shared library types
such as `LoadableUI` and shared demo latency/presentation helpers remain shared.

The gallery and the 12 conversation previews use the same LoadableView host;
the two composer previews render the nested Composer directly. Refactoring does
not change the public Loadable API or introduce a production chat component.

## Try it

1. Scroll to the top to load older messages automatically; reach the bottom of a
   historical window to load newer messages. The shared pagination component sits
   at each edge. Message IDs remain stable when a page is prepended. Turn off
   **Load pages automatically** to expose manual controls for comparison.
2. Write a message, or expand **Simulation controls** and choose **Generate text**.
   Send with the arrow button. At the latest window, the bubble appears immediately
   with a pending indicator and keeps its client ID after delivery.
   The bubble shows **Sending…** until the simulated server confirms the write,
   then **Sent**; a rejected write shows **Not sent** with a retry action.
3. Use **Receive a message** in the toolbar to simulate an incoming event.
4. Send or receive while viewing the middle of history. A message-count banner
   offers **Jump to latest**. Live-tail messages remain hidden until the newer
   history gap is filled, avoiding a transcript with missing messages in the middle.
5. Choose **Older and newer pages fail once** to exercise directional retry while
   retaining the conversation. Choose **First send fails once** at the latest
   window to retry a failed bubble. Retry reuses the original client ID.
6. Choose **Empty conversation** to send the first message, or **First load fails
   once** to exercise initial recovery. Changing a scenario, starting window or
   response time resets the local conversation and starts loading it again.
7. Increase response time, reach the older-history edge and send a message while it is
   loading. Sending does not cancel the page or reset either cursor.

For a persistent visual example, open **Chat · pending message before remote
save**. Its pending message lives in a frozen local outbox, separate from loaded
history. **Chat · slow sending (3 seconds)** is interactive: after history loads,
send a message to observe the pending-to-sent transition. Both use the same bubble
and transcript as the main demo. Frozen pending fixtures do not send on exit.

The explicit **Follow new messages** toggle controls scrolling to new tail items.
Requesting older messages turns it off. Jumping to latest turns it on again.
Incoming simulation is button-driven; there is no background timer or real stream.

The default header/footer are `LoadableUI.Components.Pagination`, using the same
visible-sentinel pattern as IKP. Available pages normally have no load button;
visibility starts the request and the edge shows progress. Errors expose Retry.
An empty/overlapping page that does not advance the edge, or a repeated cursor,
requires explicit continuation to prevent a visibility loop. The automatic-load
guard tracks the directional boundary, so an incoming/outgoing overlay or a page
at the opposite edge cannot falsely unblock a stalled edge. All requests still
pass through the store's one-request gate.

## Composer presentation

On iOS/macOS 26+, the bottom composer uses `safeAreaBar`, a glass text field and
a blue native `glassProminent` send button. A `GlassEffectContainer` groups the
two surfaces. While messages are pending and the draft is empty, a noninteractive
blue glass progress indicator replaces the send action. Typing another draft
restores the send button, so pending delivery does not block composing or sending
another message. VoiceOver identifies the progress state as waiting for the server.

Older systems use `safeAreaInset`, a material text field and a bordered prominent
button. Neither path ignores the keyboard safe area. Focused ready/sending
previews live in `Chat/Components/LoadableChat+Composer.swift`; the full pending-chat preview also
shows the composer. Keyboard opening/dismissal still requires interactive checks.

## Composer-to-bubble animation

The user's [Kavsoft reference video](https://www.youtube.com/watch?v=oethb4xWhY8)
demonstrates text moving from the composer into a chat bubble. This demo adapts
that visual idea with its own SwiftUI implementation, keeping the iOS 17 target
and the existing glass composer.

Open **Chat · animated send with keyboard**, enable Canvas interaction and wait
for history to load. The composer requests keyboard focus. Enter a message and
send: the pending item is created immediately, while a noninteractive visual copy
moves from the measured field bounds to the new bubble's layout anchor. The native
TextField stays mounted. A software keyboard may need to be enabled in the preview
device. The initial rendered screenshot shows focused input and initial loading;
it does not establish keyboard or animation behavior.

The normal bubble stays visible until the flight actually mounts. Its layout and
stable ID remain in the lazy stack while the copy animates. Animation completion
restores the real bubble with its current delivery state; it never acknowledges,
delays or cancels a server write. Reduce Motion, unavailable geometry and historical
windows skip the flight. Reset, exit, a clearing load or enabling Reduce Motion
clear visual state. Unique flight IDs prevent an old completion from removing a
newer flight, even when a message ID is reused.

Before interactive acceptance, check short/multiline drafts, long drafts that scroll
inside the four-line composer, repeated sends, incoming messages during a flight,
keyboard dismissal, narrow windows and Reduce Motion. Text wrapping during the
size change and final viewport alignment need visual review. Interactive motion
acceptance was explicitly postponed by the user; no recorded animation is claimed.

## How it uses Loadable

- `LoadableChat.Source` is an actor implementing `LoadableCollectionSource`. Its cursors
  are exclusive sequence boundaries (`before` / `after`), so new server messages
  do not shift existing page boundaries. A query can open the latest or a middle
  window. Generated text varies in length to exercise multiline bubbles.
- `LoadableChat.ViewModel` owns an Observation-based collection store for server history
  and a separate observable overlay for outgoing and incoming messages. A sorted
  projection deduplicates both by stable message ID. Successfully loaded history
  wins over an already delivered overlay item.
- `LoadableUI.Collection` selects initial loading, failure, empty and content
  states. Custom content uses a `ScrollView` and `LazyVStack`; public directional
  `PaginationContext` values drive the shared automatic header and footer. The empty-state builder
  also renders overlay content, allowing the first outgoing message to appear
  before any history rows exist.
- Client IDs are idempotency keys for the simulated server. Retries and concurrent
  calls with the same ID commit at most one message. Cancellation is checked before
  and after asynchronous work. The model tracks send/event tasks, cancels them on
  exit and release, and checks attempt identity during cleanup. Sources are
  captured separately from weak model references.

The store's `appendItems` intentionally invalidates pagination membership and
cursors. The demo therefore does not append live messages into the history store.
It demonstrates composition using the current public API; it does not add remote
CRUD or change the store's general cursor safety contract. Server totals describe
the last fetched history snapshot, not the combined overlay transcript.

## Verification and limits

There are 28 chat Swift Testing declarations in `ChatSourceTests`,
`ChatModelTests`, `ChatPendingDeliveryTests` and `ChatSendTransitionTests`, including parameterized directional
failures and successful/failed writes. They cover complete
backward traversal, stable cursor boundaries, overlap with live events, exact retry,
idempotent delivery, deduplication, historical gaps, an empty conversation, sending
during pagination, cancelled attempt cleanup, resuming a cancelled initial window
and model lifetime. Controlled Clock continuations exercise response order without
timing sleeps. These tests exercise the demo through the real collection store.
Pending-delivery tests complete a server read while a send is suspended: the new
message is visible in the local timeline but absent from that read. Only a
successful write makes it visible to a subsequent server read, preserving its ID.

The full package passes 304 test declarations (237 Loadable and 67 existing,
plus parameterized cases). DEBUG sources and preview macros compile for iOS 17
Simulator; the Release product excludes the demo. macOS Canvas snapshots were
inspected for a loaded conversation, retained page error, empty conversation and
live initial loading. A further snapshot verifies the explicit **Sending…** bubble.
The glass composer follow-up passes all 24 chat tests and the iOS 17 compiler
check. iPhone iOS 27.1 renders were inspected for the blue ready-to-send button
and full pending conversation in light/dark appearances. These are real iOS
preview renders, beyond the earlier iOS-only compiler check.
The transition adds four declarations for stale/cancelled completions, invalid
geometry, motion/read-position fallback and independence from remote persistence.
The iOS 17 compiler check and 28 chat tests pass; the pending and focused-input
previews render on iPhone iOS 27.1. Per the user's instruction, interactive Canvas
testing remains deferred.
The shared edge-loading guard adds 13 declarations covering both directions,
visibility, duplicate triggers, errors/retry, bounded empty pages, overlaps/cycles,
opposite-edge progress, fresh sessions, cancellation and frozen/manual/disabled
states. These tests drive the real store with controlled sources. Native gesture
and visibility acceptance remains an interactive check, separate from gate tests.

Stable IDs, `scrollPosition` and a bottom default anchor provide the native
scrolling setup. Screenshots and model tests do not prove pixel-stable anchoring,
keyboard behavior or touch interaction. In Canvas, check older-page prepending
with long bubbles, the composer with the keyboard open, narrow widths, larger text
and the follow toggle. Automatic detection of whether the reader is near the
bottom, unread tracking, persistence, a real transport, delivery receipts and
reconciliation of edited/deleted server messages remain outside this experiment.
