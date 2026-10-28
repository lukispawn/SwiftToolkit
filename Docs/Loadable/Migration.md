# Consumer survey and adoption boundary

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
6. Only then consider adapters/deprecations or wider migration. No old implementation
   is removed or deprecated by iteration 4a.

## Deliberately deferred

No generic cache policy, remote CRUD coordinator, automatic reachability/timer
refresh, or exact didFetch/willAddItems event compatibility was justified by the
two initial migration candidates. Add those with consumer-specific contracts and
regression tests when required. Page mapping is not a replacement for an async
transform of the entire accumulated list.
