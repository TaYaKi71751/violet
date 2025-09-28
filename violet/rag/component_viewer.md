# Reader & Viewer Experience

## `lib/pages/viewer/viewer_page.dart`
- Stateful `ViewerPage` wires `ViewerPageProvider`, `ViewerController`, and `ViewerContext` together, deciding between `HorizontalViewerPage` and `VerticalViewerPage` based on controller state.
- Keyboard shortcuts (WASD/arrows) and Apple Pencil double-tap (`ApplePencilDoubleTap`) map to `ViewerController` navigation methods, enabling cross-platform input support.
- `_jumpPage()` handles deeplinked page jumps or bookmark restoration, while `_allocLifetimeEventHandler()` and `_allocDeviceEventHandler()` (not shown in snippet) keep timers, overlays, and session stats in sync with app lifecycle events.
- Fullscreen management (`_enterFullScreen()`, `_exitFullScreen()`) honours `Settings.disableFullScreen`, ensuring desktop platforms drop the UI chrome when reading.

## `lib/pages/viewer/viewer_controller.dart`
- `ViewerController` (GetX) encapsulates viewing state: current page index, orientation (`ViewType`), animation toggles, right-to-left mode, overlay visibility, and timer-driven auto page turns.
- Constructor caches URIs, headers, and sizing arrays while inspecting `Settings.disableTwoPageView` to decide if dual-page display should be active in landscape mode.
- Navigation methods:
  - `jump(int page)` for immediate repositioning (vertical scroll to index, horizontal `PageController.jumpToPage`).
  - `move(int page)` for animated transitions with slider debouncing.
  - `prev()`, `next()`, `leftButton()`, `rightButton()` (defined later in file) wrap orientation-aware navigation and handle dual-page edge cases.
- Maintains image caches (`urlCache`, `headerCache`, `imgHeight`, etc.) to avoid redundant network calls and integrates with `ProviderManager` for memory eviction.

## `lib/pages/viewer/viewer_page_provider.dart`
- Describes a viewer session: ID, title, URI list, headers, and optional `VioletImageProvider` (e.g., `HitomiImageProvider`).
- Flags (`useFileSystem`, `useWeb`, `useProvider`) inform the controller how to retrieve pages—local files, web URLs, or provider-managed resources.
- `usableTabList` holds related `QueryResult` entries so overlays can present quick navigation to other works, while `jumpPage` supports resume-from-last-read behaviour.

## Overlay & Auxiliary Widgets
- `lib/pages/viewer/overlay/viewer_overlay.dart` and `viewer_thumbnails.dart` consume controller observables (`thumb`, `overlay`, `leftRightButton`) to render toolbars, sliders, and thumbnail strips.
- `lib/pages/viewer/horizontal_viewer_page.dart` and `vertical_viewer_page.dart` coordinate gesture detectors, caching, and preloading through `PreloadPageController` and `ScrollablePositionedList`, ensuring smooth transitions irrespective of orientation.
- `ViewerContext` (in `lib/context/viewer_context.dart`) offers a broadcaster so external modules (e.g., `ScriptManager.replaceScriptCacheIfRequired`) can request URL refreshes without tight coupling.
