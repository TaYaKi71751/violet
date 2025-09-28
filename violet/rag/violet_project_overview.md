# Violet 프로젝트 개요

## 프로젝트 요약
- Flutter 기반 멀티플랫폼 뷰어로, hitomi.la를 비롯한 여러 사이트의 만화 메타데이터와 이미지를 통합해 빠르게 탐색하고 감상할 수 있게 한다.
- 초기 실행 시 로컬 데이터베이스, 태그 인덱스, 번역 데이터를 로드하고 GitHub에 호스팅된 자바스크립트를 주기적으로 동기화해 Hitomi 이미지 라우팅을 해결한다.
- 검색/뷰어/다운로드/커뮤니티 기능을 통합하고, 사용자 설정 및 기기에 맞춘 환경 구성을 제공한다.

## 핵심 기능과 담당 파일
| 기능 | 경로 | 설명 |
| --- | --- | --- |
| 앱 부트스트랩과 글로벌 테마 | `lib/main.dart` | RustLib 초기화, Firebase 및 공용 설정을 준비하고 `GetMaterialApp`을 구성한다. |
| 첫 실행 준비 파이프라인 | `lib/pages/splash/splash_page.dart` | 설정, 사용자 데이터, 태그 인덱스, 스크립트 동기화까지 초기 작업을 일괄 수행한다. |
| 메타데이터 검색 엔진 | `lib/component/hentai.dart` | 로컬 DB와 웹 요청을 조합해 Hitomi/e-hentai의 작품을 검색하고 결과를 `QueryResult`로 정리한다. |
| Hitomi 자바스크립트 실행기 | `lib/script/script_manager.dart` | GitHub에서 스크립트를 내려받아 JS 런타임에 주입하고, 이미지 리스트/헤더를 계산한다. |
| 이미지 공급자 | `lib/component/hitomi/hitomi_provider.dart` | `ScriptManager`가 반환한 URL과 헤더를 이용해 뷰어/썸네일에 필요한 이미지를 제공한다. |
| 뷰어 UI와 제어 로직 | `lib/pages/viewer/viewer_page.dart`, `lib/pages/viewer/viewer_controller.dart` | 페이지 레이아웃을 구성하고 페이지 전환, 썸네일, 두 페이지 보기 등의 읽기 경험을 제어한다. |
| 검색 화면 | `lib/pages/search/search_page.dart`, `lib/pages/search/search_page_controller.dart` | 검색어 입력부터 결과 리스트, 무한 스크롤, 필터링까지 전체 검색 경험을 구축한다. |
| 다운로드 관리 | `lib/pages/download/download_page.dart` | 오프라인 저장 항목을 로드·필터링하고, 추가 다운로드 요청을 처리한다. |
| 로컬 데이터베이스 래퍼 | `lib/database/database.dart` | 플랫폼별 데이터베이스 위치를 설정하고 쿼리/트랜잭션을 안전하게 제공한다. |
| 사용자 설정 저장소 | `lib/settings/settings.dart` | 뷰어/검색/다운로드 옵션과 환경설정 값을 `SharedPreferences` 기반으로 관리한다. |
| HTTP 래퍼 및 캐시 | `lib/network/wrapper.dart` | Hitomi/e-hentai 요청을 위한 헤더, 타임아웃, 캐시, 쓰로틀링 정책을 캡슐화한다. |
| 태그/연관성 인덱스 | `lib/component/index.dart` | 태그 자동완성, 연관 태그 계산, 작가/시리즈 통계를 로드하고 제공한다. |
| Violet 서버 API 연동 | `lib/server/violet_v2.dart` | koromo.cc API에 HMAC 헤더를 붙여 조회/조회수 보고 등을 수행한다. |

## 구성 간 상호 작용
- `SplashPage`가 데이터베이스와 태그 정보를 준비한 뒤 `ScriptManager`를 초기화해 Hitomi 이미지 라우팅 정보를 최신 상태로 유지한다.
- 검색 단계에서 `HentaiManager`가 로컬 DB(`DataBaseManager`)를 우선 사용하고, 필요 시 `ScriptManager`/`HttpWrapper`를 통해 직접 웹 요청을 수행한다.
- 뷰어는 `ViewerPageProvider`가 전달한 `HitomiImageProvider`를 통해 이미지 URL과 헤더를 가져오며, `ViewerController`가 사용자 설정(`Settings`)을 반영해 레이아웃과 제스처를 제어한다.
- 다운로드 UI는 동일한 메타데이터를 기반으로 스크립트 동기화 상태를 검사하며, Violet 서버(`VioletServerV2`)와 사용자 기록(DB) 업데이트를 병행한다.

## 참고 문서 요약
- `rag/component_app_bootstrap.md`: `main()`과 `SplashPage`를 중심으로 앱 초기화 단계, 오류 처리, 초기 데이터 로딩 및 네비게이션 흐름을 해설한다.
- `rag/component_infrastructure.md`: `DataBaseManager`, `Settings`, `HttpWrapper`, `VioletServerV2` 등 공통 인프라 계층의 역할과 동기화 방식을 정리한다.
- `rag/component_hitomi_integration.md`: `HentaiManager`, `HitomiImageProvider`, `ScriptManager`가 협력해 Hitomi 메타데이터·이미지·헤더를 가져오는 과정을 상세화한다.
- `rag/component_search.md`: `SearchPage`와 `SearchPageController`의 상태 관리, 무한 스크롤, 필터 처리, 태그 자동완성 사용 흐름을 요약한다.
- `rag/component_viewer.md`: `ViewerPage`, `ViewerController`, `ViewerPageProvider` 및 오버레이 구성 요소가 읽기 경험을 제어하는 방식을 설명한다.
- `rag/component_download.md`: 다운로드 목록 UI, `DownloadPageManager` 스트림, 파일 경로 복구, 백그라운드 다운로드 협업 구조를 다룬다.
