# Download Management

## `lib/pages/download/download_page.dart`
- `DownloadPage` is a long-lived stateful widget (kept alive via `AutomaticKeepAliveClientMixin`) that renders local downloads, filter menus, and index navigation.
- `DownloadPageManager` exposes static `StreamController`s so background tasks can enqueue new downloads (`taskController`) or `QueryResult` objects (`taskFromQueryResultController`) for immediate UI refresh.
- `refresh()` loads downloads via `Download.getInstance().getDownloadItems()`, rebuilds lookup maps, triggers automatic filename recovery on iOS updates, and re-applies filters before calling `setState`.
- `_autoRecoveryFileName()` compares stored file paths against the current app documents directory, rewriting entries when iOS sandbox IDs change after app updates.
- UI features include sticky headers, AZ index bars, align/filter sheets, and bulk actions; they leverage helpers like `DownloadFeaturesMenu` and `DownloadAlignType` to keep the main build method manageable.

## Item Rendering (`lib/pages/download/download_item_widget.dart`)
- Presents individual downloads using metadata from `DownloadItemModel`, displaying Hitomi thumbnails by instantiating `HitomiImageProvider` when necessary.
- Integrates `Population.sortByPopulationDownloadItem()` so sorting respects global popularity metrics when the user requests it.
- Offers context menus for open-in-viewer, redownload, delete, and metadata operations, delegating long-running work to isolate downloaders.

## Persistence & Background Work
- `lib/database/user/download.dart` manages the underlying SQLite tables containing download metadata, resume points, and file paths. It is accessed through `Download.getInstance()` used above.
- `lib/downloader/isolate_downloader.dart` co-ordinates background download isolates, respecting thread count limits defined by `Settings.threadCount` and honouring Android storage permissions checked at splash time.
- Combined with `ScriptManager.getGalleryInfoRaw()` and `HitomiImageProvider.refresh()`, the download module can re-resolve image URLs when Hitomi rotates host keys, preventing stale downloads.
