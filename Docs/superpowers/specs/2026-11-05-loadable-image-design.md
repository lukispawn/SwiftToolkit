# LoadableImage na module Loadable: projekt

Status: do akceptacji. Data: 2026-11-05. Wydanie docelowe: SwiftToolkit 1.9.0.
Źródło wymagań: prompt z Active Regions (P-023, T9) plus ustalenia z rozmowy.

## Po co

Active Regions pokazuje podgląd mapy w kafelkach miejsc bez zdjęcia (do 8 naraz
na szerokiej stronie). Dziś każda mapka liczy się od nowa przez `MKMapSnapshotter`:
bez pamięci podręcznej, przy każdej zmianie rozmiaru (na Macu w każdej klatce
przeciągania okna), bez stanu ładowania, bez przeładowania po zmianie miejsca.
Komponent ma to rozwiązać raz, ogólnie, i być używalny także dla zdjęć z adresów
URL i miniatur wideo (HomePhysio, GetBlue). Odpowiednik `AsyncImage`, ale z
pamięcią podręczną, wspólnym ładowaniem, limitem współbieżności i stylowaniem.

## Cele

- `LoadableImage`: widok SwiftUI w stylu `AsyncImage`, zbudowany na
  `LoadableValueSource` i `LoadableValueStore` (moduł `Loadable`, 1.8.0+).
- Wbudowane źródła: obraz z URL (lokalny i zdalny), miniatura wideo z URL,
  migawka mapy z lokalizacji. Wszystkie `async`, poza `MainActor`.
- Pamięć podręczna z limitem w bajtach, jedno ładowanie na klucz, limit
  jednoczesnych ładowań (domyślnie 2).
- Styl wyglądu przez protokół `LoadableImageStyle` (jak `ButtonStyle`).

## Poza zakresem (non-goals)

- Cache na dysku. Tylko pamięć z limitem (decyzja użytkownika). Dysk w przyszłości.
- Stary `LoadableModel` (przestarzały od 1.8.0) i kopiowanie kodu z
  `HomePhysio/.../ComponentKit/Sources/LoadableImage/`. Z HomePhysio bierzemy tylko
  kształt: źródło z zewnątrz, odczekanie, przeładowanie po zmianie źródła,
  osobne widoki stanów.
- Pinezka, kolory marki, ikony rodzajów miejsc: to robi aplikacja nad komponentem.
- Pełny odtwarzacz wideo, przycisk play, efekty hover z HomePhysio.

## Anty-cele (porażka nawet jeśli działa)

- Pokazanie cudzego obrazka przy zmianie treści.
- Nowe ładowanie przy zmianie rozmiaru o kilka punktów.
- Dodanie zależności pakietowej do `Loadable` albo drugiego obrazu dynamicznego.
- Ostrzeżenia strict concurrency.

## Ograniczenia

- Swift 6.1, ścisła współbieżność bez ostrzeżeń. iOS 17, macOS 15.
- Kod w istniejącym targecie `Sources/Loadable/Image/` i produkcie `Loadable`
  (dynamiczny; ADR-033 z BluetoothKit: osobny produkt w pakiecie duplikuje obrazy).
  To decyzja asystenta, nie użytkownika.
- MapKit, AVFoundation, ImageIO to frameworki systemowe (brak zależności
  pakietowej). Importy pod `#if canImport`. Zmienia to zapis z promptu "bez MapKit
  w komponencie": MapKit jest tylko w pliku źródła mapy, rdzeń widoku go nie zna.
  Potwierdzone przez użytkownika 2026-11-05.
- Wartość obrazu: typ `Sendable` z `CGImage` i skalą (nie `UIImage`/`NSImage`).
- Zasady z gotap-swift-concurrency: najpierw nazwać domenę izolacji każdego
  stanu; źródła to `Sendable` (aktor lub typ wartościowy), współdzielona pamięć
  i kolejka limitu w aktorze; `Task.detached`, `@unchecked Sendable` i
  `nonisolated(unsafe)` tylko z udokumentowaną niezmienniczością; struktura
  zamiast GCD; anulowanie sprawdzane w długiej pracy; brak założeń o stanie po `await`.
- Zasady z gotap-swiftui: styl jako protokół `*Style` z rozszerzeniem statycznym
  (`.loadableImageStyle(.placeholder)`, nie `LoadableImageStyle(...)`), czytający
  `@Environment`; stan widoku w `@Observable @MainActor` bez `ObservableObject`
  i `AnyView`; bez `GeometryReader` do prostego rozmiaru, jeśli wystarczy
  `onGeometryChange`; układ zależny od rozmiaru kontenera, nie od idiomu ani
  `UIScreen.main` (zawsze resizowalny); API iOS 27 tylko z `#available`.

## Projekt

### Rdzeń

- `LoadableImageSource`: protokół oparty o `LoadableValueSource`. `Query` to
  klucz (`Hashable & Sendable`), `Value` to `LoadableImageValue` (`CGImage` + scale).
  Źródło nie zna widoku.
- Klucz niesie tożsamość treści bez rozmiaru: `contentID`, żeby zmiana rozmiaru
  lub trybu jasny/ciemny nie kasowała starej miniatury, a zmiana treści tak.
  Kształt (protokół `LoadableImageKey` z `contentID` czy para) to wybór budowniczego.
- `CachedImageSource` (dekorator nad dowolnym źródłem): ten sam klucz liczy się
  raz, równoczesne prośby czekają na jedno ładowanie; `NSCache` z kosztem w
  bajtach (czyszczony przez system); błąd i anulowanie nie trafiają do cache;
  limit jednoczesnych ładowań (domyślnie 2) z kolejką, anulowane zadanie zwalnia miejsce.
- Zasób współdzielony między widokami (jedna pamięć na proces): przekazywany z
  otoczenia SwiftUI lub parametrem. Domyślny współdzielony egzemplarz.

### Widok `LoadableImage`

- Wejście: funkcja `(CGSize, ColorScheme, displayScale) -> Key?` (nil = brak
  obrazka) i źródło. Widok mierzy własną ramkę (bez zgadywania rozmiaru).
- `.task(id: klucz)`: zmiana klucza przeładowuje, zniknięcie widoku anuluje.
- Odczekanie (debounce) przed ładowaniem tylko gdy widok już coś pokazuje;
  pierwsze ładowanie bez odczekania.
- Ta sama treść (`contentID`) zachowuje poprzedni obraz na czas ładowania;
  inna treść od razu pokazuje widok zastępczy.
- Stany jako `ViewBuilder`: ładowanie, błąd. Gotowy obraz: `scaledToFill`,
  przycięty do ramki. Rogi i proporcję daje rodzic.
- Pojawienie się obrazu łagodne; bez animacji przy Reduce Motion.
- VoiceOver: domyślnie ukryty (dekoracyjny), opcjonalna etykieta.
- Styl: `LoadableImageStyle` z konfiguracją stanów, `.loadableImageStyle(_:)`.
  Szczegóły kształtu protokołu zostawione budowniczemu (wzór: `LoadableUI.Configuration`).

### Wbudowane źródła (`Sources/Loadable/Image/Sources/`)

- `ImageURLSource`: URL lokalny (`file://`) i zdalny (http/https, `URLSession`);
  dekodowanie ImageIO ze zmniejszaniem do rozmiaru ramki (nie ładuje pełnej
  rozdzielczości do pamięci). Klucz: URL + zaokrąglony rozmiar.
- `VideoThumbnailSource`: klatka z wideo (lokalnego lub zdalnego) przez
  `AVAssetImageGenerator`. Klucz: URL + moment.
- `MapSnapshotSource`: `MKMapSnapshotter`, `MKMapSnapshotter.Options`: `region`
  wokół współrzędnych, `size` z klucza, `pointOfInterestFilter = .excludingAll`,
  tryb jawnie (iOS: `traitCollection` z `userInterfaceStyle` i `displayScale`;
  macOS: `appearance` `.aqua` / `.darkAqua`). Wynik jako `CGImage` ze skalą z klucza
  (iOS `UIImage.cgImage`, macOS `NSImage.cgImage(forProposedRect:context:hints:)`).
  `MainActor` tylko na start liczenia, reszta poza nim.
  Klucz: współrzędne do 5 miejsc po przecinku (~1 m), zasięg w metrach (dziś
  3000), tryb, skala, szerokość i wysokość w górę do wielokrotności 64 pt.
  `contentID` = współrzędne + zasięg.
- Źródła do podglądów i testów: stały obraz, obraz z opóźnieniem, obraz z błędem.

### Wydajność

Zmiana rozmiaru o kilka punktów nie uruchamia ładowania: zaokrąglanie jest w
kluczu (po stronie użytkownika lub wbudowanego źródła), komponent tylko porównuje
klucze. Siatka dwunastu obrazów przy przeciąganiu okna na Macu bez zacięć.

## Dostawa

- Testy: jedno ładowanie na klucz przy wielu prośbach; limit jednoczesnych
  ładowań; anulowanie zwalnia miejsce; zmiana klucza przeładowuje; ta sama
  treść trzyma poprzedni obraz, inna nie; błąd nie zostaje w cache; limit
  bajtów w cache. Źródła wbudowane: testy klucza i dekodowania lokalnego pliku
  (sieć, wideo i migawka mapy bez testów jednostkowych w sieci).
- Podglądy (`#Preview`) mają działać naprawdę, bez sieci i bez MapKit: oparte na
  źródłach testowych, w Xcode renderują się bez błędów i każdy stan da się
  oglądać (ładuje się, gotowe, błąd, zmiana klucza, ta sama treść w innym
  rozmiarze, siatka dwunastu, jasny i ciemny, Reduce Motion). Weryfikacja przez
  `RenderPreview`. Wzór: istniejąca galeria podglądów w `Sources/Loadable/Preview`.
- Testy obciążeniowe (odczytane z "strcnosty", to założenie asystenta): setki
  równoległych próśb o ten sam klucz i o różne klucze, szybkie zmiany klucza i
  rozmiaru (symulacja przeciągania okna), masowe anulowanie, limit bajtów pod
  presją pamięci. Sprawdzają: jedno ładowanie na klucz, brak przekroczenia limitu
  współbieżności, brak wycieków zadań i brak zakleszczeń.
- Dokumentacja w `Docs/Loadable/` (nowy plik o obrazach, wpis w README).
- CHANGELOG, tag 1.9.0. Active Regions podnosi zależność z 1.8.0. Może użyć
  wbudowanego `MapSnapshotSource` (pinezka i tło po ich stronie) albo napisać
  własne, bardziej dopasowane źródło na tym samym protokole (decyzja użytkownika
  2026-11-05). Wbudowane źródło mapy zostaje w bibliotece jako gotowy, szybki w
  użyciu przykład, więc protokół źródła musi być na tyle otwarty, żeby własne
  źródło niczego nie traciło.

## Zostawione budowniczemu

Nazwy i dokładne kształty typów, wybór między `Image`/`CGImage`-wrapperem a
alternatywą, sposób wstrzykiwania współdzielonej pamięci, dobór domyślnych
limitów bajtów, struktura plików.

## Decyzje asystenta po kontroli budowniczego (do sprawdzenia)

- Platformy: iOS 17 i macOS 15 (tak jest w `Package.swift`; wzmianka o iOS 15 w
  `CLAUDE.md` jest nieaktualna i nie dotyczy `Loadable`).
- `contentID`: dla `ImageURLSource` to sam URL; dla wideo URL bez momentu
  (moment jest tylko w kluczu cache); dla mapy współrzędne + zasięg. Tryb
  jasny/ciemny nie wchodzi do `contentID`, więc przy jego zmianie stary obraz
  zostaje do czasu nowego.
- Odczekanie: dotyczy tylko zmiany klucza przy tym samym `contentID`, gdy coś
  już widać. Zmiana `contentID` ładuje od razu. Domyślnie 150 ms, ustawiane stylem
  lub parametrem. Mieszka w widoku (`.task(id:)`), nie w cache.
- Zaokrąglanie rozmiaru: biblioteka daje pomocnik `LoadableImageSize.rounded(up: 64)`,
  wbudowane źródła go używają; własne źródła są odpowiedzialne same (udokumentowane).
  Odczekanie łapie resztę (przeciąganie okna).
- Pamięć i limit: jeden wspólny egzemplarz domyślny (`CachedImageSource.shared`),
  ale można podać własny z otoczenia lub parametrem. Limit współbieżności jest
  jeden na egzemplarz pamięci (aktor), niezależnie od typu źródła.
- Klucz `nil`: osobny stan "brak obrazka", pokazuje widok zastępczy bez ładowania.
  Błąd: widok błędu, bez automatycznego ponawiania; przycisk ponowienia dostępny
  przez kontekst stanu. Błędy nie są cache'owane (zgodnie z promptem).
- Limit bajtów: domyślnie 64 MB na iOS, 256 MB na macOS (do dostrojenia).
- Testy obciążeniowe: wymagane, progi dobiera budowniczy (np. 500 próśb, test
  poniżej 5 s, zero żyjących zadań po zakończeniu).
