# Consumer survey and adoption boundary

## Deprecation starting with 1.8.0

LoadableModel's public types are deprecated, not removed. Existing consumers can
keep compiling and running while migrating; compiler warnings identify the new
API or explain which responsibility must move to a domain wrapper. Projects
treating warnings as errors must account for these intentional diagnostics before
upgrading. No removal version is scheduled.

Add `.product(name: "Loadable", package: "SwiftToolkit")` to each importing target
and use `import Loadable`. Keep the existing SwiftToolkit dynamic product where
legacy modules still need it; do not introduce duplicate standalone LoadableModel
linkage. New APIs use different generics and semantics, so no automatic `renamed:`
fix-it is supplied.

| Deprecated API | Replacement / migration responsibility |
| --- | --- |
| `LoadableElementStore<Value>` | `LoadableValueStore<Source>` |
| `LoadableCollectionStore<Item, Cursor, Query>` | `LoadableCollectionStore<Source>` |
| `LoadableElementProvider`, `DefaultElementProvider` | `LoadableValueSource`, `LoadableValue.OperationSource` |
| `LoadableCollectionProvider`, `DefaultCollectionProvider` | `LoadableCollectionSource`, `LoadableCollection.OperationSource`; preserve normalization for local events explicitly |
| `LoadedElementStatus` | `LoadableValue.Snapshot`; inspect content/readiness separately from phase |
| `LoadedCollectionStatus`, `LoadableCollectionInfo` | `LoadableCollection.Snapshot`; readiness is not a raw phase case |
| `LoadableCollectionResult` | `LoadableCollection.Page` |
| `LoadableArrayPageCursorType` | `LoadableCollection.Direction` |
| `LoadableState`, `LoadableModelSupport` | `Loadable.LoadableState`, `LoadableStateProviding`, computed `merge(stores:)`; choose command ownership separately |
| `LoadableCollectionModifier`, `DefaultCollectionModifier` | domain-owned remote CRUD plus explicit store local mutations |
| `LoadSettings`, `ReloadSettings`, `RefreshSettings` | explicit clearing/retained commands; independent debounce/throttle scheduling |
| `RefreshDisposition`, `RefreshTrigger` | source/wrapper interception and owner-managed lifecycle refresh |
| `DebounceSettings` | `LoadableQueryDebouncer` |
| `LoadableError` | domain source errors or `LoadableUsageError`, as appropriate |

Do not replace a live initial seed with a frozen constant. Do not map legacy
processContent only to mapItems: local append/update/remove must preserve sorting,
filtering and limits too. Read [the API guide](README.md) before changing callers.

## Consumer adoption proposal

GetBlue's full adoption proposal is tracked in the BluetoothKit repository as
P-101 and epic E-310 (created 2026-10-28). The proposal inventories six SDK helpers
with nine stores, plus one app-owned detail store, and defines consumer tests,
package integration, state compatibility and ten execution tickets. It does not
start or claim completion of the migration. The narrower survey below records
the original library capability-selection work.

The next step after the independent core is driven by actual consumer code,
read on 2026-10-27. Only SwiftToolkit is changed in this iteration.

| Consumer | Existing dependency | New support / migration action |
| --- | --- | --- |
| BluetoothKit `ValueHistoryStatisticsUI` | Operation-backed statistics, retained refresh from persistence events, external throttling, lifecycle monitoring | Value source + `refreshInBackground`; preserve external throttler and MonitoringCoordinator |
| BluetoothKit `CollectionsManagerUI` | Sorted persistence list, initial lifecycle loading, provider injection, local updates, legacy state projection | `mapItems` for its non-paginated source, collection store, local mutation API; rewrite the state projection and injection seam deliberately |
| BluetoothKit `ValueHistoryUI` | Query debounce, multiple stores, history event updates, statistics throttling | QueryDebouncer, local rows, retained refresh cover individual mechanisms; combined monitoring/state lifecycle needs its own consumer tests |
| Pentacomp-style reducer | Published snapshots copied into reducer state | `snapshots()` with explicit consumer-task cancellation replaces Combine subscription |

Source locations inspected:

- `BluetoothKit/Sources/BluetoothKit/UI/ValueHistoryStatisticsUI.swift`
- `BluetoothKit/Sources/BluetoothKit/UI/CollectionsManagerUI.swift`
- `BluetoothKit/Sources/BluetoothKit/UI/ValueHistoryUI.swift`
- `BluetoothKit/Sources/BluetoothKit/UI/ActionTemplateUI.swift`

The repository-relative locations above refer to the sibling BluetoothKit
repository, not files in SwiftToolkit. They are evidence for capability selection,
not copies of application code or claims of completed migration.

## Tested contracts

`Tests/LoadableTests/Integration/ConsumerMigrationTests.swift` models the relevant
wrapping patterns without a dependency on BluetoothKit:

- a persistence event retains displayed statistics until refreshed;
- nested Observation tracks the wrapper's reads;
- a debounced query reaches a sorted source;
- an explicit repeat of the same search forces another fetch;
- releasing the wrapper releases its store and cancels pending query work.

Source transformation, local mutation, stream and scheduling suites separately
exercise cancellation, noncooperative completions and lifecycle cleanup.

## Real-consumer acceptance checklist (iteration 4b)

1. Change the owning package's product dependency/import and source definitions.
   Preserve the existing dynamic-linking arrangement; qualify old/new names if both
   modules coexist during migration.
2. Migrate statistics first and collections second. Update their public wrappers'
   state projection; retaining old data after failure is an intentional behavior change.
3. Preserve application-owned monitoring/throttling and explicitly select whether
   view tasks own cancellation or only start store-owned requests.
4. Update provider-injection tests and add lifecycle/navigation tests in the consumer.
   Local membership changes must refresh before further pagination.
5. Build/run the owning app on supported platforms and verify loading, errors,
   refresh gestures, navigation/re-entry and release. Unit fixtures and successful
   compiler checks are not runtime UI acceptance.
6. Only then consider adapters or wider migration. No old implementation was
   removed or deprecated by iteration 4a. The owner-requested 1.8.0 deprecation
   is a later, separate step and preserves those implementations.

## Deliberately deferred

No generic cache policy, remote CRUD coordinator, automatic reachability/timer
refresh, or exact didFetch/willAddItems event compatibility was justified by the
two initial migration candidates. Add those with consumer-specific contracts and
regression tests when required. Page mapping is not a replacement for an async
transform of the entire accumulated list.
