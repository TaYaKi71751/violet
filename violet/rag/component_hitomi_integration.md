# Hitomi Integration Layer

## Search & Metadata (`lib/component/hentai.dart`)
- `SearchResult` encapsulates query outputs plus paging metadata.
- `HentaiManager.search()` orchestrates ID lookups, random pulls, local DB queries, or network fallbacks based on user settings (`Settings.searchNetwork`).
- ID search delegates to `idSearchHitomi()` (Hitomi via `ScriptManager.runHitomiGetHeaderContent()` and gallery block parsing), `idSearchEhentai()`, and `idSearchExhentai()` with multi-tier fallback and logging on failure.
- Database-backed searches compose SQL via `translate2query()` and `Settings.includeTags`/`serializedExcludeTags`, while network searches (not shown here) rely on provider-specific helpers.

## Hitomi Data Accessors
- `lib/component/hitomi/hitomi_parser.dart` exposes `HitomiParser.parseGalleryBlock()` to extract titles, artists, and language strings from gallery HTML.
- `lib/component/hitomi/hitomi.dart` wraps the downloadable `ImageList` structure and exposes `HitomiManager.getImageList()` which defers to `ScriptManager.runHitomiGetImageList()`.
- `lib/component/hitomi/hitomi_provider.dart` implements `HitomiImageProvider`, bridging the viewer with image URLs, headers, and thumbnail estimations. It:
  - Fetches small thumbnails and big thumbnail URLs from `ImageList`.
  - Uses `ScriptManager.runHitomiGetHeaderContent()` so every image request carries the correct referer/user-agent pair.
  - Supplies estimated image heights by downloading small thumbnails and reading dimensions via `image_size_getter`.
  - Supports dynamic refresh by re-calling `HitomiManager.getImageList()` when scripts update routing rules.

## JavaScript Runtime (`lib/script/script_manager.dart`)
- `ScriptManager.init()` downloads Hitomi helper scripts (`hitomi_get_image_list_v3.js`, optional V4 model) from GitHub, caching them and seeding a shared `JavascriptRuntime` (`flutter_js`).
- `refreshV4NoWebView()` and `refreshV3()` keep the script cache fresh, automatically reinitialising the runtime and broadcasting refresh signals (`ProviderManager.checkMustRefresh()`, `ViewerContext.signal`).
- `runHitomiGetImageList()` executes the cached script to compute encrypted image URLs and thumbnails, returning an `ImageList` consumed by `HitomiImageProvider`.
- `runHitomiGetHeaderContent()` evaluates script-provided header generation, ensuring network requests to `ltn.gold-usergeneratedcontent.net` succeed even when Hitomi rotates host keys.
- `getGalleryInfoRaw()` fetches gallery metadata via script-generated download URLs, allowing height calculation and offline processing.

## Supporting Assets
- Popularity weighting is provided by `lib/component/hitomi/population.dart` (`Population.init()`, `sortByPopulation()`), used to rank search results.
- Tag translation and auto-complete rely on `lib/component/index.dart` and `lib/component/hitomi/tag_translate.dart`, both initialised during splash to speed up query UX and provide multi-language tag display.
