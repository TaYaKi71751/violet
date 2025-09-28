# App Lifecycle & Bootstrap

## `lib/main.dart`
- `main()` wraps startup in `runZonedGuarded` to initialise `RustLib.init()`, `Logger.init()`, optional `FlutterDownloader.initialize()`, and global error capture via `recordFlutterError()`.
- `warmupFlare()` caches Flare animations before the UI appears, reducing first-use stalls.
- `initUserId()` and `initFirebase()` (Android/iOS only) provision analytics IDs and wire `FirebaseAnalyticsObserver` into `GetMaterialApp`.
- `MyApp` injects `DynamicTheme`, constructs shared routes (`/AfterLoading`, `/DatabaseDownload`, `/SplashPage`), and builds the `GetMaterialApp` root with custom `CustomScrollBehavior` for desktop drag gestures.
- `EscapeKeyListener` plus `MouseBackRecognizer` provide desktop keyboard/mouse navigation and one-key fullscreen toggling through `FullScreenWindow`.

## `lib/pages/splash/splash_page.dart`
- `SplashPage` orchestrates the heavy first-run pipeline: settings (`Settings.init()`), bookmarks, user records, variables, tag translations, popularity tables, and downloader isolate.
- `navigationPage()` checks connectivity, triggers `ScriptManager.init()` when online, and runs database sync via `SyncManager.checkSyncLatest()` before pushing `/AfterLoading`.
- `checkAuth()` handles Android storage permission workflow and hints the user when downloads require elevated access.
- The page tracks progress UI (`chunkDownloadProgress`, `showIndicator`) to surface sync status while assets and chunk updates stream in.

## Early Navigation
- After assets load, navigation switches to `lib/pages/after_loading/afterloading_page.dart` (not covered in detail) which determines whether to launch the main tab view or auxiliary flows such as database download or lock screen based on the settings prepared at splash time.
