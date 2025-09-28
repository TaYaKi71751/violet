# Search Page UI/UX Walkthrough

## Overview (`lib/pages/search/search_page.dart`)
- 메인 검색 화면은 `SearchPage`와 `SearchPageController` 조합으로 구성되며, 상단 검색 카드 + 보조 아이콘 + 결과 패널 + 떠다니는 액션 버튼(FAB)으로 나뉜다.
- `SearchPage`는 탭 인덱스와 단독 페이지 두 모드(생성자 매개변수 `searchKeyWord`)를 지원한다. 외부에서 키워드를 넣으면 상단에 `CupertinoNavigationBar`가 나타나고, 기본 탭 모드에서는 슬리버 기반 헤더를 사용한다.

## 상단 검색 카드
- 구성 요소: 검색 입력 영역, 메시지 검색 버튼, 정렬/필터 버튼.
- 카드 전체는 `InkWell` 오버레이로 덮여 있어 **탭 시** `showSearchBar()`가 실행되고, 히어로 애니메이션으로 `SearchBarPage`(전용 검색 입력 화면)로 전환된다.
- **더블 탭**: 탭 모드에서만 동작하며, `random:<seed>` 쿼리를 자동 생성해 무작위 검색을 즉시 수행한다.

### 검색 입력 (`SearchBarPage`)
- `rag/component_search.md`가 데이터 흐름을 다루는 반면, 여기서는 UX에 집중한다.
- 전체 화면 카드(히어로 태그 `searchbar*`)가 열리며 상단 입력 필드 + 추천 태그 페이지 뷰 + 최근 검색 목록이 좌우 스와이프 페이지로 정렬된다.
- 텍스트를 입력하면 `searchProcess()`가 자동 완성(`HentaiIndex.queryAutoComplete`)과 관계 태그를 즉각 갱신하고, 추천 항목을 탭하면 입력 커서 위치에 삽입된다.
- 하단의 `Search` 버튼을 누르면 현재 문자열이 반환되어 `SearchLogDatabase.insertSearchLog()`로 기록되고, 플레어 애니메이션이 `close2search` → `search2close`로 전환되며 메인 페이지가 새로고침된다.

### 메시지 검색 버튼 (`msgsearch()`)
- 카드 우측 중앙에 위치하며, 말풍선 아이콘을 탭하면 `LabSearchMessage` 실험 화면으로 슬라이드 전환된다.
- 히어로 태그 `msgsearch*`을 사용해 부드러운 스케일/위치 전환이 일어난다.

### 정렬/필터 버튼 (`align()`)
- **단일 탭**: `SearchType` 카드가 페이드 인되어 `Settings.searchResultType` 값을 바꾸도록 한다. 사용자는 리스트/그리드/울트라 레이아웃 중 선택하며, 선택 시 메인 리스트가 즉시 재구성된다.
- **롱 프레스**: `FilterPage`가 열려 상세 필터 구성(태그 포함/제외 등)을 시각적으로 편집한다. 닫을 때 `c.applyFilter()`가 호출되어 결과가 필터링된 리스트로 재정렬되고 스크롤 포지션이 초기화된다.

## 검색 결과 패널 (`ResultPanelWidget`)
- `Settings.searchResultType`에 따라 다음 레이아웃으로 바뀐다:
  - `threeGrid`/`twoGrid`: `LiveSliverGrid`를 사용해 등장 애니메이션과 함께 썸네일 그리드가 나온다.
  - `bigLine`/`detail`/`ultra`: 슬리버 리스트 혹은 (태블릿/가로 모드) 2열 그리드가 사용되며, 상세 정보, 태그, 작가, 다운로드 버튼 등 추가 메타데이터가 함께 출력된다.
- 항목 카드(`ArticleListItemWidget`)는 탭 시 작품 상세 페이지(`ArticleInfoPage`)로 이동한다. 길게 누르면 즐겨찾기 등 모드에 따라 컨텍스트 메뉴가 떠오른다.
- 결과는 무한 스크롤: `ScrollController`가 뷰포트 하단 75%를 넘어설 때 `loadNextQuery()`가 호출되어 로딩 애니메이션과 함께 다음 페이지 결과가 자연스럽게 추가된다. 새 데이터가 오면 `AnimatedSwitcher`처럼 스무스하게 리스트가 확장되고, 화면 최상단의 FAB 카운터가 함께 업데이트된다.

## 스크롤 UX
- `scrollPositionListener()`가 스크롤 방향을 추적하며, 사용자가 빠르게 위로 올리면 `isExtended` 플래그가 켜져 FAB가 확장된 텍스트 모드(현재/총 결과 수 표시)로 변한다.
- 반대로 아래로 내리면 플래그가 꺼지고 아이콘만 남아 시야를 가리지 않는다.
- 키보드: 데스크톱 환경에서 WASD/방향키로 스크롤을 제어할 수 있으며, 키를 누르고 있으면 100ms 주기로 부드럽게 이동한다.

## Floating Action Button
- 기본 상태는 책 모양 아이콘 하나이며, `isExtended`가 true일 때 `AnimatedSwitcher`가 현재 페이지/총 결과 수/서버 카운트를 텍스트로 보여 준다.
- 탭하면 `SearchPageModifyPage` 다이얼로그가 떠서 원하는 검색 결과 인덱스로 점프할 수 있다. 확인 시 `c.doSearch(setPage)`를 호출해 해당 오프셋에서 재검색을 수행, 리스트와 스크롤 위치가 즉시 변경된다.

## 하단 시나리오 요약
1. **검색 시작**: 상단 카드를 탭하여 검색창을 연다 → 텍스트 입력/자동완성 선택 → 실행.
2. **결과 탐색**: 스크롤하며 카드 레이아웃을 감상. 그리드/리스트 전환은 정렬 버튼 탭으로 이루어지고, 필터는 롱 프레스 후 적용된다.
3. **빠른 이동**: FAB를 눌러 특정 인덱스로 이동하거나, 키보드 단축키(W/S)로 빠르게 스크롤.
4. **메시지 검색**: 말풍선 아이콘을 탭하여 별도 랩 페이지로 이동, 커뮤니티 메시지를 확인.
5. **무작위 감상**: 검색 카드 더블 탭으로 random 검색을 실행, 히어로 애니메이션과 함께 새로운 탐색 경험 제공.

이러한 상호작용 덕분에 사용자는 다양한 입력 방식(터치/키보드), 레이아웃 전환, 필터 조합을 통해 Hitomi 작품을 빠르게 찾고 탐색할 수 있다.
