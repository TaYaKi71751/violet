# Search & Discovery

## `lib/pages/search/search_page.dart`
- `SearchPage` seeds a GetX controller (`SearchPageController`) and kicks off `doInitialSearch()` after the first frame, applying a five-second timeout unless `Settings.ignoreTimeout` is true.
- The widget builds sliver-based lists with animated headers, reusing cached `ResultPanelWidget` instances and toggling layouts based on `Settings.searchResultType`.
- Keyboard navigation support, Cupertino navigation, and bottom sheets (`SearchPageModify`, `FilterPage`) are wired through helper widgets referenced in this file.

## `lib/pages/search/search_page_controller.dart`
- Holds the core search state: `queryResult`, `filterResult`, pagination offsets, and the rolling `_scrollQueue` used to detect scroll direction and toggled header visibility.
- `scrollPositionListener()` lazily measures card heights, updates the active result index (`searchPageNum`), and triggers infinite scroll by calling `loadNextQuery()` when the list nears the bottom.
- `FilterController` integration (from `lib/pages/segment/filter_page_controller.dart`) lets users apply advanced filters; when filters change, `reloadForce()` is invoked via the callback passed from the widget.
- `showErrorToast()` provides long-lived error toasts using `FToast`, keeping the user informed on timeouts or network errors.

## Data Shaping Helpers
- `lib/component/hentai.dart` supplies search data via `HentaiManager.search()` and `HentaiManager.countSearch()`, factoring in `Settings.includeTags` and `Population.sortByPopulation()` when population sort is active.
- `Population.sortByPopulation()` (in `lib/component/hitomi/population.dart`) reorders results based on global readership metrics loaded at splash.
- Auto-complete and tag display rely on `HentaiIndex.queryAutoComplete()` and `TagTranslate.containsTotal()` (from `lib/component/index.dart` and `lib/component/hitomi/tag_translate.dart`), which feed the `SearchBar` suggestions pipeline.

## User History & Saved Queries
- `lib/database/user/search.dart` (not detailed here) is consumed to persist recent searches, enabling the search page to recall suggestions across sessions.
- `SearchPageController.latestQuery` caches the last successful query/result tuple, simplifying rerenders when filters toggle without hitting the network again.
