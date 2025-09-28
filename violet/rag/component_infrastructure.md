# Core Infrastructure

## Database (`lib/database/database.dart`)
- `DataBaseManager` abstracts SQLite access for all platforms, choosing the path per OS (mobile documents directory vs. desktop alongside executable).
- `getInstance()` and `checkOpen()` guard singleton access with `Lock` to avoid concurrent opens, while `_openInner()` selects `openDatabase` or `databaseFactoryFfi` on desktop.
- CRUD helpers (`query`, `insert`, `update`, `delete`, `swap`) expose low-level operations; `test()` verifies the Hitomi metadata table is populated during diagnostics.

## Settings (`lib/settings/settings.dart`)
- Central `Settings` class wraps hundreds of persisted options via `SettingItem`, `EnumSettingItem`, and `FutureSettingItem`, backed by `SharedPreferences`.
- Reader preferences (e.g., `isHorizontal`, `rightToLeft`, `disableTwoPageView`), search toggles (`searchNetwork`, `includeTags`, `serializedExcludeTags`), and theming (`themeWhat`, `majorColor`) are exposed as static fields used throughout the app.
- Download paths are resolved dynamically in `downloadBasePath`, handling Android scoped storage upgrades and auto-migrating legacy `/Violet/` folders.
- Utility setters like `serializedExcludeTags` normalise user input into query-ready strings consumed by `HentaiManager`.

## Networking (`lib/network/wrapper.dart`)
- `HttpWrapper` provides default headers (`accept`, `userAgent`) and throttling semaphores for EH/exHentai requests to respect rate limits.
- `get()` routes requests: e-hentai URLs through `_ehentaiGet()` (with retry/timeout logic, response caching), Hitomi script hosts through `_scriptGet()` (per-URL cache), and generic GETs via `http.get`.
- `_ehentaiGet()` uses `http.Client` streams with configurable timeouts (`Settings.ignoreTimeout`) and shares cached responses across the app.
- `post()` logs outbound POST calls, forwarding body/encoding to `http.post` while capturing non-OK status codes.

## Utilities & Shared Context
- `lib/thread/semaphore.dart` (used by `HttpWrapper`) offers lightweight async semaphores for throttled sections.
- `lib/variables.dart` and related helpers populate application directories and global constants consumed by data loaders, though their details are initialised in the splash workflow.
- HMAC-protected server calls are handled by `lib/server/violet_v2.dart`: `VioletServerV2.init()` creates a `chopper` client with `HmacInterceptor.hmacHeader()` ensuring every API request carries time-based validation headers.
