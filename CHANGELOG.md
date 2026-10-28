# Changelog

## 1.8.0 — 2026-10-28

### Added

- Independent dynamic `Loadable` product with `@MainActor @Observable` value and
  collection stores, Sendable sources and coherent snapshots.
- Previous/next pagination, ID-based merging, cancellation and stale-result
  protection, local state updates, snapshot streams, source mapping and query debounce.
- `LoadableState` readiness aggregation and `LoadableUI` configurable lists,
  custom layouts and automatic pagination edges.
- SwiftUI preview gallery, including the namespaced chat example with optimistic
  pending delivery, retry and simulated history/live events.
- Expanded API/agent guide and consumer migration documentation.

### Deprecated

- The public types in the legacy `LoadableModel` module, with migration messages
  pointing to `LoadableValueStore`, `LoadableCollectionStore`, sources, snapshots
  and owner-managed domain behavior as appropriate.
- Existing implementations and products remain available. No removal version is
  scheduled. Existing callers receive intentional compiler warnings; consumers
  treating warnings as errors must plan for these diagnostics.
- This is a migration, not a drop-in rename: remote CRUD, lifecycle refresh,
  whole-content normalization and event ordering remain domain responsibilities.

### Adoption

Use SwiftToolkit `from: "1.8.0"`, add
`.product(name: "Loadable", package: "SwiftToolkit")`, then `import Loadable`.
Preserve the existing combined SwiftToolkit dynamic product while legacy modules
are still used. See [the API guide](Docs/Loadable/README.md) and
[migration guide](Docs/Loadable/Migration.md).

The release includes 237 Loadable and 67 existing package test declarations
(304 total, plus parameterized cases). Interactive chat gesture/keyboard
acceptance and the GetBlue application migration remain separate work.
