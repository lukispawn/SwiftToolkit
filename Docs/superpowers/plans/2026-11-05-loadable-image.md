# LoadableImage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać do modułu `Loadable` widok `LoadableImage` (odpowiednik `AsyncImage` z pamięcią podręczną, wspólnym ładowaniem i stylem) oraz wbudowane źródła: obraz z URL, miniatura wideo, migawka mapy.

**Architecture:** Źródło obrazka to `LoadableValueSource` z kluczem niosącym `contentID`. Dekorator `CachedImageSource` nad aktorem `LoadableImageCache` daje jedno ładowanie na klucz, limit bajtów i limit współbieżności. Widok trzyma `@Observable @MainActor` model nad `LoadableValueStore`, który zachowuje poprzedni obraz przy tym samym `contentID`.

**Tech Stack:** Swift 6.1 (ścisła współbieżność), SwiftUI, Observation, `Loadable` 1.8.0, ImageIO, AVFoundation, MapKit (tylko plik źródła mapy), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-05-loadable-image-design.md`

## Global Constraints

- iOS 17 / macOS 15; Swift 6.1, zero ostrzeżeń strict concurrency.
- Kod w istniejącym targecie `Sources/Loadable/Image/` i produkcie `Loadable`; żadnych nowych zależności pakietowych ani produktów.
- MapKit tylko w `MapSnapshotSource.swift`; AVFoundation tylko w `VideoThumbnailSource.swift`; importy pod `#if canImport`.
- Wartość obrazu to `Sendable` typ z `CGImage` i skalą (nie `UIImage`/`NSImage`).
- Cache tylko w pamięci (`NSCache`, koszt w bajtach), bez dysku. Limit ładowań domyślnie 2. Limit bajtów: 64 MB iOS, 256 MB macOS. Błędy i anulowania nie trafiają do cache.
- Odczekanie domyślnie 150 ms, tylko przy zmianie klucza z tym samym `contentID`, gdy coś już widać; pierwsze ładowanie i zmiana `contentID` bez odczekania.
- Styl: protokół `LoadableImageStyle` z rozszerzeniem statycznym (`.loadableImageStyle(.automatic)`), czyta `@Environment`; bez `ObservableObject`, `AnyView`, `GeometryReader` do prostego rozmiaru; rozmiar przez `onGeometryChange`; układ nie zależy od idiomu ani `UIScreen.main`.
- Współbieżność: nazwać domenę izolacji każdego stanu; `@unchecked Sendable` / `nonisolated(unsafe)` tylko z komentarzem o niezmienniczości; bez GCD; sprawdzanie anulowania w długiej pracy.
- Podglądy `#Preview` oparte na źródłach testowych (bez sieci i MapKit), weryfikowane przez `RenderPreview`.
- Testy w Swift Testing (`@Test`, `@Suite`) w `Tests/LoadableTests/Image/`. Polskie teksty bez em dasha.
- Kroki `git commit` wykonuj dopiero po zgodzie użytkownika w danej sesji.

## Review Focus

- Ramka `.zero` lub ujemna (pierwszy układ widoku): funkcja klucza dostaje rozmiar 0, widok nie ładuje i nie pokazuje błędu.
- URL zwraca HTTP non-2xx albo dane, które nie są obrazem: stan błędu, nie wieczne ładowanie i nie cache.
- Szybka zmiana klucza A→B→A przy tym samym `contentID`: kończy na A, bez migania cudzym obrazem i bez dwóch aktywnych ładowań.
- Wszyscy oczekujący na wspólne ładowanie anulują: zadanie bazowe też jest anulowane i zwalnia slot.
- Dwa różne źródła z równymi kluczami w jednej pamięci: nie podają sobie nawzajem obrazów (przestrzeń nazw).

---

### Task 1: Typy rdzenia

**Files:**
- Create: `Sources/Loadable/Image/LoadableImageValue.swift`
- Create: `Sources/Loadable/Image/LoadableImageKey.swift`
- Create: `Sources/Loadable/Image/LoadableImageSource.swift`
- Create: `Sources/Loadable/Image/LoadableImageSize.swift`
- Test: `Tests/LoadableTests/Image/LoadableImageCoreTests.swift`

**Interfaces:**
- Produces:
  - `public struct LoadableImageValue: Sendable, Equatable { public let cgImage: CGImage; public let scale: CGFloat; public var cost: Int; public init(cgImage: CGImage, scale: CGFloat) }` (`cost` = bajty `bytesPerRow * height`; `@unchecked Sendable` uzasadnione niezmiennością `CGImage`; `==` po tożsamości obiektu `CGImage`).
  - `public protocol LoadableImageKey: Hashable, Sendable { associatedtype ContentID: Hashable & Sendable; var contentID: ContentID { get } }`
  - `public protocol LoadableImageSource: LoadableValueSource where Value == LoadableImageValue, Query: LoadableImageKey {}`
  - `public enum LoadableImageSize { public static func rounded(_ size: CGSize, upTo step: CGFloat = 64) -> CGSize }`

- [ ] **Step 1: Napisz testy** `roundedUpToMultipleOf64`: `rounded(CGSize(width: 65, height: 1))` == `64*2 x 64`; `rounded(.zero)` == `.zero`; `rounded(CGSize(width: 64, height: 128))` bez zmian; `valueCostIsBytes`: obraz 10x10 RGBA daje `cost >= 400`.
- [ ] **Step 2: Uruchom** `swift test --filter LoadableImageCoreTests`; oczekiwane: błąd kompilacji (brak typów).
- [ ] **Step 3: Zaimplementuj** cztery pliki o sygnaturach z Interfaces; `rounded` używa `ceil(width/step)*step`, wartości `<= 0` zwraca jako 0.
- [ ] **Step 4: Uruchom** ten sam test; oczekiwane: PASS.
- [ ] **Step 5: Commit** `feat(loadable): add image core types`.

### Task 2: Źródła testowe i podglądowe

**Files:**
- Create: `Sources/Loadable/Image/Sources/PreviewImageSources.swift`
- Test: `Tests/LoadableTests/Image/PreviewImageSourcesTests.swift`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `public struct PreviewImageKey: LoadableImageKey { public var contentID: String; public var variant: Int; public init(contentID: String, variant: Int = 0) }`
  - `public struct StaticImageSource: LoadableImageSource` (`init(color: CGColor, size: CGSize)`, zwraca jednokolorowy obraz)
  - `public struct DelayedImageSource: LoadableImageSource` (`init(base: StaticImageSource, delay: Duration)`; `Task.sleep` przerywalny)
  - `public struct FailingImageSource: LoadableImageSource` (`init(error: any Error = PreviewImageError.failed)`)
  - `public actor CountingImageSource: LoadableImageSource` (`init(base:)`, `var fetchCount: Int`, `var maxConcurrent: Int`; używany w testach cache)

- [ ] **Step 1: Napisz testy** `staticSourceReturnsImageOfRequestedKeySize`, `delayedSourceThrowsCancellationWhenCancelled`, `failingSourceThrows`, `countingSourceTracksPeakConcurrency` (dwa równoległe `fetch` z opóźnieniem dają `maxConcurrent == 2`).
- [ ] **Step 2: Uruchom** filtr `PreviewImageSourcesTests`; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** źródła o powyższych sygnaturach; obraz rysowany `CGContext` w rozmiarze 8x8.
- [ ] **Step 4: Uruchom**; oczekiwane: PASS.
- [ ] **Step 5: Commit** `feat(loadable): add preview and test image sources`.

### Task 3: Aktor `LoadableImageCache`

**Files:**
- Create: `Sources/Loadable/Image/LoadableImageCache.swift`
- Test: `Tests/LoadableTests/Image/LoadableImageCacheTests.swift`

**Interfaces:**
- Consumes: Task 1, `CountingImageSource` z Task 2.
- Produces:
  ```swift
  public actor LoadableImageCache {
      public static let shared: LoadableImageCache
      public init(byteLimit: Int = LoadableImageCache.defaultByteLimit, maxConcurrentLoads: Int = 2)
      public static var defaultByteLimit: Int { get } // 64 MB iOS, 256 MB macOS
      public func image<Key: Hashable & Sendable>(
          for key: Key, namespace: String,
          load: @escaping @Sendable () async throws -> LoadableImageValue
      ) async throws -> LoadableImageValue
      public func removeAll()
  }
  ```
  Zachowanie: trafienie w `NSCache` zwraca od razu; równoczesne prośby o ten sam `(namespace, key)` czekają na jedno `Task`; gdy wszyscy czekający anulują, zadanie bazowe jest anulowane; kolejka FIFO ogranicza liczbę aktywnych `load` do `maxConcurrentLoads`, anulowane zadanie zwalnia slot; błąd i anulowanie nie są zapamiętywane; `NSCache.totalCostLimit = byteLimit`, koszt = `LoadableImageValue.cost`.

- [ ] **Step 1: Napisz testy** (każdy z asercją z nazwy): `sameKeyLoadsOnce` (50 równoległych prośb, `fetchCount == 1`), `differentKeysRespectConcurrencyLimit` (20 kluczy, limit 2, `maxConcurrent <= 2`), `cancelledWaiterReleasesSlot` (anuluj aktywne, kolejne ruszy), `allWaitersCancelCancelsLoad` (po anulowaniu wszystkich `load` obserwuje `Task.isCancelled`), `errorIsNotCached` (pierwszy `load` rzuca, drugi się wykonuje), `namespacesDoNotCollide` (te same klucze, różne namespace, dwa różne obrazy), `byteLimitEvictsOldest` (limit na dwa obrazy, trzeci wypycha pierwszy: kolejny `image` woła `load` ponownie).
- [ ] **Step 2: Uruchom** `swift test --filter LoadableImageCacheTests`; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** aktor: słownik `inFlight: [CacheKey: Flight]` z licznikiem oczekujących, `NSCache<CacheKey, Box>` (wrapper klasy z `LoadableImageValue`), kolejka `[CheckedContinuation<Void, Never>]` jako semafor liczący. `CacheKey` to `Hashable` klasa (`NSObject` subclass) z `AnyHashable` i namespace. Pamiętaj o ponownym wejściu aktora po `await`.
- [ ] **Step 4: Uruchom**; oczekiwane: PASS, bez ostrzeżeń współbieżności (`swift build 2>&1 | grep -i warning` puste dla `Loadable`).
- [ ] **Step 5: Commit** `feat(loadable): add shared image cache with load limiter`.

### Task 4: `CachedImageSource` i testy obciążeniowe

**Files:**
- Create: `Sources/Loadable/Image/CachedImageSource.swift`
- Test: `Tests/LoadableTests/Image/CachedImageSourceTests.swift`

**Interfaces:**
- Consumes: Task 1 do 3.
- Produces:
  ```swift
  public struct CachedImageSource<Base: LoadableImageSource>: LoadableImageSource {
      public init(_ base: Base, cache: LoadableImageCache = .shared, namespace: String = String(reflecting: Base.self))
  }
  ```
  `Failure` równe `any Error`; `fetch(query:)` z `nil` rzuca `LoadableImageError.missingKey` (typ zdefiniowany w Task 7; do tego czasu użyj tymczasowego błędu w tym samym pliku).

- [ ] **Step 1: Napisz testy** `wrapsBaseAndCachesByKey`, `missingKeyThrowsMissingKey`, oraz obciążeniowe: `stress500ConcurrentRequestsSameKey` (500 zadań, `fetchCount == 1`, test < 5 s), `stressManyKeysWithRapidCancellation` (500 kluczy, anuluj losowe 80 procent, po zakończeniu `maxConcurrent <= 2` i żadne `load` nie wisi: `TaskGroup` kończy się), `stressResizeLikeKeyChurn` (1000 kolejnych kluczy z tym samym `contentID`, anulowanie poprzedniego przed następnym, końcowo dokładnie jeden obraz zwrócony).
- [ ] **Step 2: Uruchom** filtr; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** `CachedImageSource.fetch(query:)` delegujące do `cache.image(for:namespace:load:)` z `base.fetch`.
- [ ] **Step 4: Uruchom**; oczekiwane: PASS, łączny czas pliku < 10 s.
- [ ] **Step 5: Commit** `feat(loadable): add CachedImageSource with stress tests`.

### Task 5: Model widoku (zmiana klucza, zachowanie obrazu, odczekanie)

**Files:**
- Create: `Sources/Loadable/Image/LoadableImageModel.swift`
- Test: `Tests/LoadableTests/Image/LoadableImageModelTests.swift`

**Interfaces:**
- Consumes: Task 1 do 4, `LoadableValueStore`.
- Produces:
  ```swift
  @MainActor @Observable
  final class LoadableImageModel<Source: LoadableImageSource> {
      enum Phase { case none, loading, loaded(LoadableImageValue), failed(any Error) }
      init(source: Source, debounce: Duration = .milliseconds(150))
      private(set) var phase: Phase
      private(set) var displayedContentID: Source.Query.ContentID?
      func update(key: Source.Query?) async
      func retry() async
  }
  ```
  `update` jest wywoływane z `.task(id: key)`. Zasady: `nil` czyści obraz i daje `.none`; ten sam `contentID` i coś widać → odczekanie, obraz zostaje podczas ładowania; inny `contentID` → obraz czyszczony od razu, ładowanie bez odczekania; pierwsze ładowanie bez odczekania; anulowanie (`CancellationError`) nie zmienia stanu na `.failed`.

- [ ] **Step 1: Napisz testy** `nilKeyShowsNoneAndDoesNotLoad`, `firstLoadHasNoDebounce` (źródło liczące, brak opóźnienia), `sameContentKeepsPreviousImageWhileLoading`, `differentContentClearsImageImmediately`, `sameContentChangeIsDebounced` (dwie zmiany w 20 ms wołają źródło raz), `rapidFlipABAEndsOnA` (A→B→A z tym samym contentID kończy na A), `cancellationDoesNotSetFailed`, `errorSetsFailedAndRetryReloads`, `zeroSizeKeyFromProviderIsNil` (kontrakt widoku opisany w Task 6).
- [ ] **Step 2: Uruchom** filtr; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** model nad `LoadableValueStore<Source>` używając `store.load(query:)` w wywołaniu `update`; odczekanie przez `Task.sleep` przerywalny, nie `Task.sleep` bez sprawdzenia anulowania.
- [ ] **Step 4: Uruchom**; oczekiwane: PASS.
- [ ] **Step 5: Commit** `feat(loadable): add LoadableImage view model`.

### Task 6: Widok `LoadableImage` i styl

**Files:**
- Create: `Sources/Loadable/Image/LoadableImage.swift`
- Create: `Sources/Loadable/Image/LoadableImageStyle.swift`
- Test: `Tests/LoadableTests/Image/LoadableImageViewTests.swift`

**Interfaces:**
- Consumes: Task 5.
- Produces:
  ```swift
  public struct LoadableImage<Source: LoadableImageSource, Placeholder: View, Failure: View>: View {
      public init(
          source: Source, accessibilityLabel: LocalizedStringKey? = nil,
          key: @escaping @Sendable (CGSize, ColorScheme, CGFloat) -> Source.Query?,
          @ViewBuilder placeholder: @escaping () -> Placeholder,
          @ViewBuilder failure: @escaping (_ retry: @escaping () -> Void) -> Failure)
  }
  public protocol LoadableImageStyle { /* Configuration: phase + image; makeBody */ }
  extension LoadableImageStyle where Self == AutomaticLoadableImageStyle { public static var automatic: Self { get } }
  extension View { public func loadableImageStyle(_ style: some LoadableImageStyle) -> some View }
  ```
  Widok mierzy ramkę przez `onGeometryChange`, ramka `<= 0` daje klucz `nil` i brak ładowania; obraz `scaledToFill`, `clipped`; pojawienie przez `.transition(.opacity)` z `.animation(.default)` wyłączoną przy `@Environment(\.accessibilityReduceMotion)`; domyślnie `accessibilityHidden(true)`, z etykietą: `accessibilityLabel` i `.isImage`; styl `.automatic` daje szare tło `.fill.tertiary` jako domyślny placeholder.

- [ ] **Step 1: Napisz testy** (ViewInspector nie jest dostępny, więc testuj logikę wydzieloną do `LoadableImageLayout`): `zeroOrNegativeSizeYieldsNilKey`, `reduceMotionDisablesAnimation`, `labelNilHidesFromAccessibility`, `labelNonNilExposesImageTrait`. Dla pozostałego zachowania patrz Task 10.
- [ ] **Step 2: Uruchom** filtr; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** widok z `@State private var model`, `.task(id: currentKey)`, `onGeometryChange(for: CGSize.self)`. Klucz obliczany z `(size, colorScheme, displayScale)`.
- [ ] **Step 4: Uruchom** testy i `swift build`; oczekiwane: PASS, zero ostrzeżeń.
- [ ] **Step 5: Commit** `feat(loadable): add LoadableImage view and style`.

### Task 7: `ImageURLSource`

**Files:**
- Create: `Sources/Loadable/Image/Sources/ImageURLSource.swift`
- Test: `Tests/LoadableTests/Image/ImageURLSourceTests.swift`

**Interfaces:**
- Consumes: Task 1, `LoadableImageSize`.
- Produces:
  ```swift
  public struct ImageURLKey: LoadableImageKey { public var url: URL; public var pixelSize: CGSize (rounded); public var contentID: URL { url }; public init(url: URL, size: CGSize, scale: CGFloat) }
  public struct ImageURLSource: LoadableImageSource { public init(session: URLSession = .shared) }
  ```
  `file://` czytany przez `Data(contentsOf:)` w zadaniu poza `MainActor`; http(s) przez `session.data(from:)`; odpowiedź non-2xx → `LoadableImageError.badStatus(Int)`; dane nie będące obrazem → `LoadableImageError.undecodable`; dekodowanie `CGImageSourceCreateThumbnailAtIndex` z `kCGImageSourceThumbnailMaxPixelSize` = większy wymiar `pixelSize`, `kCGImageSourceCreateThumbnailWithTransform`.

- [ ] **Step 1: Napisz testy** `decodesLocalPNGDownscaledToKeySize` (zapisz PNG 1000x1000 do pliku tymczasowego, wynik <= 128 px), `missingLocalFileThrows`, `nonImageDataThrowsUndecodable`, `badStatusThrows` (własny `URLProtocol`), `keyContentIDIsURLIgnoringSize`, `sizeRoundedInKey`.
- [ ] **Step 2: Uruchom** filtr; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** źródło i błędy `LoadableImageError` (wspólny `enum` w tym pliku: `missingKey`, `badStatus(Int)`, `undecodable`).
- [ ] **Step 4: Uruchom**; oczekiwane: PASS.
- [ ] **Step 5: Commit** `feat(loadable): add ImageURLSource`.

### Task 8: `VideoThumbnailSource`

**Files:**
- Create: `Sources/Loadable/Image/Sources/VideoThumbnailSource.swift`
- Test: `Tests/LoadableTests/Image/VideoThumbnailSourceTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct VideoThumbnailKey: LoadableImageKey { public var url: URL; public var timeMilliseconds: Int; public var pixelSize: CGSize; public var contentID: URL { url }; public init(url: URL, time: Duration = .zero, size: CGSize, scale: CGFloat) }
  public struct VideoThumbnailSource: LoadableImageSource { public init() }
  ```
  `AVAssetImageGenerator` z `appliesPreferredTrackTransform = true`, `maximumSize = pixelSize`, `generateCGImageAsynchronously` / `image(at:)` (async); nieczytelne wideo → `LoadableImageError.undecodable`.

- [ ] **Step 1: Napisz testy** `keyContentIDIgnoresTime`, `keysDifferByTimeAndSize`, `missingFileThrows`; test z prawdziwym wideo pomiń (brak fixture), opisz w komentarzu.
- [ ] **Step 2: Uruchom** filtr; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** źródło pod `#if canImport(AVFoundation)`.
- [ ] **Step 4: Uruchom**; oczekiwane: PASS.
- [ ] **Step 5: Commit** `feat(loadable): add VideoThumbnailSource`.

### Task 9: `MapSnapshotSource`

**Files:**
- Create: `Sources/Loadable/Image/Sources/MapSnapshotSource.swift`
- Test: `Tests/LoadableTests/Image/MapSnapshotKeyTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MapSnapshotKey: LoadableImageKey {
      public var latitudeE5: Int; public var longitudeE5: Int   // współrzędne * 1e5, zaokrąglone
      public var radiusMeters: Int; public var isDark: Bool
      public var scaleTimes100: Int; public var width: Int; public var height: Int // w górę do 64 pt
      public var contentID: MapSnapshotContent { MapSnapshotContent(latitudeE5, longitudeE5, radiusMeters) }
      public init(latitude: Double, longitude: Double, radiusMeters: Int = 3000, colorScheme: ColorScheme, displayScale: CGFloat, size: CGSize)
  }
  public struct MapSnapshotSource: LoadableImageSource { public init() }
  ```
  `MKMapSnapshotter.Options`: `region` wokół współrzędnych (`MKCoordinateRegion(center:latitudinalMeters:longitudinalMeters:)` z promieniem), `size`, `pointOfInterestFilter = .excludingAll`, iOS: `traitCollection` z `userInterfaceStyle` i `displayScale`; macOS: `appearance` `.aqua`/`.darkAqua`; wynik `CGImage` (iOS `UIImage.cgImage`, macOS `NSImage.cgImage(forProposedRect:context:hints:)`) ze skalą z klucza; `MainActor` tylko na utworzenie i start `MKMapSnapshotter`, `await snapshotter.start()` poza nim.

- [ ] **Step 1: Napisz testy** `coordinatesRoundedTo5Places` (49.30000004 i 49.299999999 dają ten sam klucz), `sizeRoundedUpTo64`, `contentIDIgnoresSizeAndScheme`, `contentIDChangesWithCoordinateOrRadius`, `schemeAndScaleAffectKey`. Sama migawka bez testów jednostkowych (sieć).
- [ ] **Step 2: Uruchom** filtr; oczekiwane: błąd kompilacji.
- [ ] **Step 3: Zaimplementuj** klucz i źródło pod `#if canImport(MapKit)`; konwersje platformowe w dwóch małych funkcjach `#if os(iOS)` / `#if os(macOS)`.
- [ ] **Step 4: Uruchom**; oczekiwane: PASS.
- [ ] **Step 5: Commit** `feat(loadable): add MapSnapshotSource`.

### Task 10: Podglądy i weryfikacja

**Files:**
- Create: `Sources/Loadable/Preview/Image/LoadableImagePreviews.swift`
- Modify: `Sources/Loadable/Preview/LoadablePreviewGallery.swift` (dodaj wpis galerii)

**Interfaces:**
- Consumes: Task 2, 6.

- [ ] **Step 1: Napisz podglądy** `#Preview`: `Loading`, `Loaded`, `Failed` (z przyciskiem ponowienia), `KeyChangeSameContent` (przycisk zmienia rozmiar, stary obraz zostaje), `KeyChangeDifferentContent` (placeholder od razu), `Grid12` (12 `LoadableImage` w `LazyVGrid`), `DarkMode`, `ReduceMotion`; wszystkie na `StaticImageSource` / `DelayedImageSource` / `FailingImageSource` w `CachedImageSource` z własną pamięcią.
- [ ] **Step 2: Wyrenderuj** każdy podgląd przez `RenderPreview` (Xcode MCP) i sprawdź brak błędów; oczekiwane: obrazy odpowiednich stanów, w `Grid12` dwanaście kafli.
- [ ] **Step 3: Ręcznie na macOS** przeciągnij okno z `Grid12`; oczekiwane: brak zacięć i brak nowych ładowań (licznik `CountingImageSource` w podglądzie pokazuje stałą wartość).
- [ ] **Step 4: Uruchom** `swift build` i `swift test`; oczekiwane: zielone, zero ostrzeżeń.
- [ ] **Step 5: Commit** `feat(loadable): add LoadableImage previews`.

### Task 11: Dokumentacja i wydanie

**Files:**
- Create: `Docs/Loadable/Image.md`
- Modify: `Docs/Loadable/README.md` (wiersz w tabeli "Start here"), `CHANGELOG.md` (sekcja 1.9.0)

**Interfaces:**
- Consumes: wszystkie poprzednie.

- [ ] **Step 1: Napisz `Docs/Loadable/Image.md`**: szybki start `LoadableImage` z `ImageURLSource`; przykład mapy z `MapSnapshotSource` (jako gotowy szybki przykład) oraz jak napisać własne źródło pod Active Regions na `LoadableImageSource`; kontrakt zaokrąglania rozmiaru w kluczu; opis stylu; tabela wbudowanych źródeł i ich kluczy.
- [ ] **Step 2: Dodaj** wiersz do tabeli README i sekcję `## 1.9.0` w CHANGELOG (Added: LoadableImage, cache, źródła).
- [ ] **Step 3: Zweryfikuj** przykłady z dokumentu: skopiuj do tymczasowego pliku w `Tests/` i `swift build --build-tests`; oczekiwane: kompilują się; usuń plik.
- [ ] **Step 4: Uruchom** pełne `swift test`; oczekiwane: PASS.
- [ ] **Step 5: Commit** `docs(loadable): document LoadableImage and release notes`. Tag `1.9.0` i push tylko po wyraźnej zgodzie użytkownika.
