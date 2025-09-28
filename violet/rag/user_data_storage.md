# Local User Data Storage Guide

## 저장소 구조 (`lib/database/user/user.dart`)
- `CommonUserDatabase`는 `DataBaseManager`를 확장해 앱 전용 `user.db` 파일을 `getApplicationDocumentsDirectory()` 하위에 생성한다.
- `getInstance()`는 `synchronized` 락으로 단일 커넥션을 보장하고, 모든 사용자 데이터 도메인이 이 커넥션을 공유한다.

## 초기 로딩 (`lib/pages/splash/splash_page.dart`)
- `SplashPage.navigationPage()`에서 `Bookmark.load()`, `User.load()`가 호출되어 필요한 테이블을 생성하고 싱글턴 인스턴스를 준비한다.
- 다운로드/검색 로그는 처음 접근 시 정적 팩토리(`Download.getInstance()`, `SearchLogDatabase.getInstance()`, `LLMSearchLogDatabase.getInstance()`) 안에서 테이블 생성 여부를 검사한다.

## 북마크 도메인 (`lib/database/user/bookmark.dart`)
- `Bookmark.load()`가 북마크/아티스트/유저/크롭 이미지/히스토리 테이블을 생성하고 기본 그룹을 추가한다.
- `Bookmark` 싱글턴은 다음 API로 데이터를 다룬다:
  - `insertArticle()`, `insertArtist()`, `insertUser()` 등으로 항목 추가.
  - `createGroup()`, `deleteGroup()`으로 그룹 관리.
  - `insertCropImage()`는 크롭 썸네일을 저장해 뷰어 하이라이트에 사용한다.
  - 빠른 조회를 위해 `bookmarkSet`, `bookmarkArtistSet`, `bookmarkUserSet` 같은 메모리 캐시를 유지한다.
- UI 측에서는 `BookmarkPage`, `BookmarkIndicatorWidget`, `ViewerPage` 등이 `Bookmark.getInstance()`를 통해 데이터에 접근한다.

## 다운로드 상태 (`lib/database/user/download.dart`)
- `Download.getInstance()`는 `DownloadItem` 테이블을 초기화하고 완료된 항목을 해시셋 `_downloadedChecker`에 캐싱한다.
- `DownloadItemModel`은 단일 행을 추상화하며 `update()`, `delete()`로 상태를 갱신한다.
- 다운로드 흐름:
  - 새 작업 생성은 `Download.createNew(url)` → `DownloadItem` INSERT.
  - 백그라운드 진행 상황은 `DownloadItemModel.result`를 수정하고 `update()` 호출.
  - UI(`DownloadPage.refresh()`)가 `getDownloadItems()`로 모든 레코드를 불러와 필터링/정렬한다.
- 파일 존재 여부 검증은 `_isDownloadedFileExists()`가 실제 디스크를 확인해 재다운로드 여부를 판단한다.

## 열람 기록 (`lib/database/user/record.dart`)
- `User.load()`가 `ArticleReadLog` 테이블을 준비하고 `User` 싱글턴을 초기화한다.
- `insertUserLog(article, type)`은 읽기 세션 시작을 기록하고, `updateUserLog(article, lastPage)`는 종료 시각과 마지막 페이지를 갱신한다.
- `getUserLog()`는 최근 기록을 캐시에 보관해 `ViewerPage`가 읽기 이력/북마크 안내를 빠르게 조회할 수 있게 한다.

## 검색 로그 (`lib/database/user/search.dart`)
- `SearchLogDatabase.getInstance()`가 `SearchLog` 테이블을 lazily 생성한다.
- `getSearchLog()`는 최근 검색어 목록을 반환하고, `insertSearchLog()`는 Firebase Analytics와 연동해 모바일에서 검색 이벤트를 기록한다.
- `SearchPageController`는 검색 실행 시 이 API를 호출해 자동 완성 및 기록 패널에 사용한다.

## LLM 검색 로그 (`lib/database/user/llm_search.dart`)
- `LLMSearchLogDatabase`는 RAG/LLM 기능의 질의 기록을 `LLMSearchLog` 테이블에 저장한다.
- `insert()`로 질의를 추가하고 `getLogs()`, `getQueries()`를 통해 UI가 최근 쿼리를 표시할 수 있다.

## 사용 시나리오 요약
1. **초기화**: 앱 부팅에서 `Bookmark.load()`와 `User.load()`를 호출해 기본 스키마를 생성한다.
2. **읽기/다운로드 동작**: Viewer, Downloader, Search 페이지는 필요 시 싱글턴을 불러와 데이터를 INSERT/UPDATE 하고 메모리 캐시를 최신 상태로 유지한다.
3. **표시/필터링**: UI 위젯은 `get*()` 메서드를 통해 리스트를 가져오고, `Population` 등의 헬퍼로 정렬 후 화면에 바인딩한다.
4. **동기화/백업**: 일부 API(`Bookmark.insertArticle`, `SearchLogDatabase.insertSearchLog`)는 모바일 환경에서 Firebase Analytics 이벤트를 함께 전송해 외부 통계를 유지한다.
