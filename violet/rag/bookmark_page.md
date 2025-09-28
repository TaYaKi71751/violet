# Bookmark Page UX & Logic

## Entry Page (`lib/pages/bookmark/bookmark_page.dart`)
- `BookmarkPage`는 앱 탭 중 하나로, `ThemeSwitchableState`와 `DoubleTapToTopMixin`을 사용해 테마 및 탭-탑 기능을 상속한다.(lib/pages/bookmark/bookmark_page.dart:17)
- 본문은 `FutureBuilder`로 `Bookmark.getInstance().getGroup()`을 호출해 그룹 목록을 비동기로 로드한다.(lib/pages/bookmark/bookmark_page.dart:38)
- 화면 우측 하단 `SpeedDial` FAB는 두 가지 액션을 제공한다.
  - `editorder`: 그룹 카드에 흔들리는 애니메이션을 켜고/끄는 재정렬 모드 토글.(lib/pages/bookmark/bookmark_page.dart:53)
  - `newgroup`: `Bookmark.createGroup()`로 새 그룹 생성 후 즉시 UI 리프레시.(lib/pages/bookmark/bookmark_page.dart:58)

## 목록 & 재정렬 UX
- `reorder` 플래그가 켜지면 `ReorderableListView`를 사용하고, 꺼져 있으면 일반 `ListView.builder`로 그린다.(lib/pages/bookmark/bookmark_page.dart:88)
- 리스트 상단에는 두 개의 예약 행이 있으며 인덱스 -2/-1이 각각 “읽기 기록”(`RecordViewPage`)과 “크롭 북마크”(`CropBookmarkPage`)로 연결된다.(lib/pages/bookmark/bookmark_page.dart:119)
- 그룹 카드 UI
  - `ShakeAnimatedWidget`으로 재정렬 모드에서 가벼운 흔들림 효과 제공.(lib/pages/bookmark/bookmark_page.dart:149)
  - `ListTile` 탭 → 그룹별 아티클 리스트(`GroupArticleListPage`) 또는 두 예약 페이지로 네비게이션한다.(lib/pages/bookmark/bookmark_page.dart:177)
  - `ListTile` 롱프레스 → `GroupModifyPage` 다이얼로그를 열어 이름/설명을 수정하거나 삭제할 수 있다. 기본 그룹(`violet_default`)은 보호된다.(lib/pages/bookmark/bookmark_page.dart:188)
- 재정렬 동작
  - `onReorder`는 예약 인덱스를 이동하려 할 때 경고 토스트로 막는다.(lib/pages/bookmark/bookmark_page.dart:99)
  - 정상 재정렬 시 `Bookmark.positionSwap()`을 호출해 DB의 `Gorder` 값을 교환하고 화면을 갱신한다.(lib/pages/bookmark/bookmark_page.dart:105)

## 그룹 상세 (`lib/pages/bookmark/group/group_article_list_page.dart`)
- 그룹 페이지는 `PageView`로 구성되어 3개 탭을 제공한다: 작품 목록, 아티스트 목록, 아티클 기반 아티스트 링크.(lib/pages/bookmark/group/group_article_list_page.dart:202)
- 헤더
  - `AnimatedOpacitySliver`가 그룹명 타이틀과 정렬/필터 버튼을 떠 있는 헤더로 보여 준다.(lib/pages/bookmark/group/group_article_list_page.dart:165)
  - 정렬 버튼 탭 시 `SearchType` 모달을 띄워 `SearchResultType`을 선택하고, 선택 값은 `SharedPreferences`에 `bookmark_<groupId>` 키로 저장된다.(lib/pages/bookmark/group/group_article_list_page.dart:246)
  - 버튼 롱프레스 시 `FilterPage` 모달을 열어 태그/속성 필터를 설정한다. 필터 적용 후 `FilterController.applyFilter()`를 이용해 결과를 즉시 재구성한다.(lib/pages/bookmark/group/group_article_list_page.dart:265)
- 데이터 로딩
  - `refresh()`는 `Bookmark.getInstance().getArticle()`에서 해당 그룹 항목을 모으고, `QueryManager.queryIds()`로 메타데이터를 채운 뒤 `queryResult`와 `filterResult`를 준비한다.(lib/pages/bookmark/group/group_article_list_page.dart:89)
  - 정렬과 필터 적용 시 `_shouldRebuild` 플래그로 `ResultPanelWidget`을 재생성하고, `sliverKey`를 새 `ObjectKey`로 바꿔 애니메이션/키 충돌을 방지한다.(lib/pages/bookmark/group/group_article_list_page.dart:121)
- 리스트 표현
  - `ResultPanelWidget`은 검색 페이지와 동일한 카드/그리드 레이아웃을 재사용하지만 `bookmarkMode: true`로 썸네일 하단 버튼과 북마크 체크 모드를 활성화한다.(lib/pages/bookmark/group/group_article_list_page.dart:138)
  - `Settings.bookmarkScrollbarPositionToLeft` 옵션에 따라 iPad 등에서 좌측 스크롤바를 지원한다.(lib/pages/bookmark/group/group_article_list_page.dart:187)
- 체크 모드 & 멀티 액션
  - 카드 롱프레스 → `checkMode`를 켜고 `checked` 목록에 첫 항목을 추가한다.(lib/pages/bookmark/group/group_article_list_page.dart:293)
  - 체크박스 토글은 `bookmarkCheckCallback`으로 연결되어 `checked` 목록을 유지하며, 선택이 모두 해제되면 애니메이션으로 checkMode를 종료한다.(lib/pages/bookmark/group/group_article_list_page.dart:300)
  - checkMode일 때 하단 `AnimatedFloatingActionButton`이 나타나며 “전체 선택”, “삭제”, “다른 그룹으로 이동” 세 가지 버튼을 제공한다.(lib/pages/bookmark/group/group_article_list_page.dart:213)
  - “삭제”는 `Bookmark.unbookmark()`를 순차 호출한다.(lib/pages/bookmark/group/group_article_list_page.dart:226)
  - “이동”은 그룹 선택 다이얼로그 후, 선택된 ID 순으로 삭제→다른 그룹에 재등록(`Bookmark.insertArticle`)을 수행한다.(lib/pages/bookmark/group/group_article_list_page.dart:323)

## 데이터 연동 요약
- 모든 UI 액션은 `Bookmark` 싱글턴 API(`getGroup`, `createGroup`, `positionSwap`, `deleteGroup`, `getArticle`, `insertArticle`, `unbookmark`)를 이용해 `user.db` 스키마를 업데이트한다.(lib/database/user/bookmark.dart:154)
- 예약 페이지
  - `RecordViewPage`는 `ArticleReadLog` 기반 열람 히스토리를 보여 주며, 북마크 탭에서 빠르게 접근할 수 있도록 그룹 리스트 상단에 고정돼 있다.(lib/pages/bookmark/bookmark_page.dart:125)
  - `CropBookmarkPage`는 `BookmarkCropImage` 테이블 조각 이미지를 표시해 뷰어에서 저장한 영역을 시각적으로 탐색하게 한다.

## UX Flow 요약
1. 사용자 진입 → 그룹 목록과 예약 페이지 카드가 로드된다.
2. SpeedDial로 새 그룹 생성 혹은 재정렬 모드를 활성화할 수 있다. 재정렬 중에는 카드가 흔들리고 드래그 이동만 허용된다.
3. 그룹 카드 탭 → 작품 목록/아티스트 탭으로 이동. 헤더에서 목록 레이아웃과 필터를 즉각 조정할 수 있다.
4. 카드 롱프레스 → 다중 선택 모드 전환. FAB로 선택 항목을 일괄 삭제하거나 다른 그룹으로 이동한다.
5. 예약 카드 선택 시 독자 기록(`RecordViewPage`)과 크롭 북마크(`CropBookmarkPage`)로 연결돼 과거 열람/저장 데이터를 빠르게 확인할 수 있다.
