# Agent Usage Examples

## Example 1 — Fix search layout spacing
```
TASK: Reduce vertical padding between search results when using `SearchResultType.ultra`.
SCOPE/CONSTRAINTS: No regression to tablet two-column layout; keep 60 FPS on mid-tier Android.
BRANCH: fix/search-spacing
```
1. Read `rag/violet_project_overview.md` → `rag/component_search.md` → `rag/search_page_ui_ux.md` for layout rules and UX expectations.
2. Collect Evidence references before coding:
   - `Evidence: rag/search_page_ui_ux.md#L8-L48`
   - `Evidence: rag/component_search.md#L24-L72`
3. Draft Short Design describing padding adjustment in `ResultPanelWidget` and verification plan.
4. Update code + run `flutter analyze` + describe manual scroll test.
5. If spacing contract changes, update `rag/search_page_ui_ux.md` with new measurements.

## Example 2 — Add bookmark sync prompt
```
TASK: Prompt users to sync bookmarks when opening Viewer if local/bookmark set is stale.
SCOPE/CONSTRAINTS: Do not block viewer startup; reuse existing Bookmark APIs.
BRANCH: feat/viewer-bookmark-sync
```
1. Start with `rag/violet_project_overview.md`, then read `rag/component_viewer.md`, `rag/user_data_storage.md` for Bookmark APIs.
2. Evidence collection:
   - `Evidence: rag/component_viewer.md#L4-L52`
   - `Evidence: rag/user_data_storage.md#L18-L62`
3. Plan overlay prompt logic in Short Design, noting impact on `ViewerPage` lifecycle.
4. After patch, verify viewer launch & analytics; document the new UX in `rag/component_viewer.md`.

## Example 3 — Update ScriptManager cache policy
```
TASK: Refresh Hitomi script cache more aggressively when network flaps detected.
SCOPE/CONSTRAINTS: Avoid blocking search; consider desktop offline mode.
BRANCH: refactor/script-cache
```
1. Read `rag/component_hitomi_integration.md`, `rag/component_infrastructure.md` (network wrapper) after overview.
2. Evidence references:
   - `Evidence: rag/component_hitomi_integration.md#L28-L78`
   - `Evidence: rag/component_infrastructure.md#L26-L72`
3. Modify `ScriptManager.refresh()` with new policy, ensuring Viewer refresh signals remain intact.
4. Document policy change in `rag/component_hitomi_integration.md` and add verification steps (e.g., forced refresh scenario).

## Example 4 — Document new download filter
```
TASK: Introduce a “Downloaded Today” filter in the Download page.
SCOPE/CONSTRAINTS: No schema change; rely on existing DateTime fields.
BRANCH: docs/download-filter
```
1. Consult `rag/component_download.md`, `rag/user_data_storage.md` for download item structure.
2. Update docs first with filter logic summary, citing evidence.
3. Provide Short Design + Diff adjusting `DownloadPage` filter menu, with manual test instructions.

이 패턴을 따라, 모든 작업은 문서→Evidence→설계→코드→검증→RAG 업데이트 순으로 진행한다.
