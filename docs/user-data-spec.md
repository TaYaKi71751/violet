# User Data Specification

Violet Flutter 앱에서 사용하는 로컬 SQLite 데이터베이스 스키마를 정리한다.

## 1. Overview

Violet은 두 개의 SQLite 데이터베이스를 사용한다.

| DB 파일 | 경로 (Android) | 용도 |
|---------|---------------|------|
| **user.db** | `{appDocDir}/user.db` | 사용자 데이터 — 북마크, 다운로드, 읽기 기록, 검색 기록 |
| **data.db** | `{appDocDir}/data/data.db` | 콘텐츠 인덱스 — 서버에서 다운로드한 작품 메타데이터 |

- iOS에서 `data.db`는 `{databasesPath}/data.db`에 저장된다.
- 두 DB 모두 `sqflite` 패키지를 통해 접근하며, `DataBaseManager` 클래스가 연결을 관리한다.

### 소스 파일 매핑

| 소스 파일 | 역할 |
|----------|------|
| `lib/database/user/user.dart` | `CommonUserDatabase` — user.db 싱글턴 |
| `lib/database/database.dart` | `DataBaseManager` — data.db 싱글턴 |
| `lib/database/user/bookmark.dart` | 북마크 관련 6개 테이블 CRUD |
| `lib/database/user/download.dart` | 다운로드 항목 CRUD |
| `lib/database/user/record.dart` | 읽기 기록 CRUD |
| `lib/database/user/search.dart` | 검색 기록 CRUD |
| `lib/database/query.dart` | `QueryResult` / `QueryManager` — data.db 조회 |

---

## 2. SQLite user.db

user.db는 앱 최초 실행 시 각 모듈의 `load()` 또는 `getInstance()`에서 테이블 존재 여부를 확인한 뒤 `CREATE TABLE`을 실행한다 (migration 없이 if-not-exists 패턴).

### 2.1 BookmarkGroup

북마크 폴더. 기본 그룹 `violet_default` (Id=1)이 자동 생성된다.

```sql
CREATE TABLE BookmarkGroup (
  Id          INTEGER PRIMARY KEY AUTOINCREMENT,
  Name        TEXT,
  DateTime    TEXT,
  Description TEXT,
  Color       INTEGER,
  Gorder      INTEGER          -- 정렬 순서
);
```

### 2.2 BookmarkArticle

작품(article) 북마크. `GroupId`로 `BookmarkGroup`에 소속된다.

```sql
CREATE TABLE BookmarkArticle (
  Id       INTEGER PRIMARY KEY AUTOINCREMENT,
  Article  TEXT,               -- 작품 ID (문자열)
  DateTime TEXT,
  GroupId  INTEGER,
  FOREIGN KEY (GroupId) REFERENCES BookmarkGroup(Id)
);
```

### 2.3 BookmarkArtist

작가/그룹/업로더/시리즈/캐릭터 북마크.

```sql
CREATE TABLE BookmarkArtist (
  Id       INTEGER PRIMARY KEY AUTOINCREMENT,
  Artist   TEXT,               -- 이름
  IsGroup  INTEGER,            -- 타입: 0=artist, 1=group, 2=uploader, 3=series, 4=character
  DateTime TEXT,
  GroupId  INTEGER,
  FOREIGN KEY (GroupId) REFERENCES BookmarkGroup(Id)
);
```

> `IsGroup` 컬럼명은 하위 호환성을 위해 유지된다. 실제로는 다섯 가지 타입을 표현한다.

### 2.4 BookmarkUser

사용자(업로더 등) 북마크.

```sql
CREATE TABLE BookmarkUser (
  Id       INTEGER PRIMARY KEY AUTOINCREMENT,
  User     TEXT,
  Title    TEXT,
  Subtitle TEXT,
  DateTime TEXT,
  GroupId  INTEGER,
  FOREIGN KEY (GroupId) REFERENCES BookmarkGroup(Id)
);
```

### 2.5 HistoryUser

방문한 사용자 기록.

```sql
CREATE TABLE HistoryUser (
  Id       INTEGER PRIMARY KEY AUTOINCREMENT,
  User     TEXT,
  DateTime TEXT
);
```

### 2.6 BookmarkCropImage

이미지 크롭 북마크.

```sql
CREATE TABLE BookmarkCropImage (
  Id          INTEGER PRIMARY KEY AUTOINCREMENT,
  Article     INTEGER,         -- 작품 ID
  Page        INTEGER,         -- 페이지 번호
  Area        TEXT,            -- 크롭 영역 (JSON 또는 좌표 문자열)
  AspectRatio DOUBLE,          -- 크롭 비율
  DateTime    TEXT
);
```

### 2.7 DownloadItem

다운로드 큐 및 이력.

```sql
CREATE TABLE DownloadItem (
  Id              INTEGER PRIMARY KEY AUTOINCREMENT,
  State           INTEGER,     -- 상태 코드 (아래 참조)
  Path            TEXT,        -- 저장 디렉터리
  Files           TEXT,        -- 파일 경로 목록 (JSON 배열)
  Info            TEXT,
  DateTime        TEXT,
  Extractor       TEXT,        -- 추출기 이름
  URL             TEXT,        -- 원본 URL 또는 작품 ID
  ErrorMsg        TEXT,
  Thumbnail       TEXT,        -- 썸네일 파일 경로
  ThumbnailHeader TEXT         -- 썸네일 HTTP 헤더
);
```

**State 값:**

| 값 | 의미 |
|----|------|
| 0 | Complete |
| 1 | Pending |
| 2 | Extracting |
| 3 | Downloading |
| 4 | Post Processing |
| 5 | Fail |
| 6 | Stop |
| 7 | Error-Unknown |
| 8 | Error-Not Support |
| 9 | Error-Login |
| 10 | Error |
| 11 | Nothing to download |

### 2.8 ArticleReadLog

작품 열람 기록.

```sql
CREATE TABLE ArticleReadLog (
  Id            INTEGER PRIMARY KEY AUTOINCREMENT,
  Article       TEXT,          -- 작품 ID (문자열)
  DateTimeStart TEXT,
  DateTimeEnd   TEXT,
  LastPage      INTEGER,       -- 마지막으로 읽은 페이지
  Type          INTEGER        -- 0=검색에서 열람, 1=북마크에서 열람
);
```

### 2.9 SearchLog

검색 기록.

```sql
CREATE TABLE SearchLog (
  Id         INTEGER PRIMARY KEY AUTOINCREMENT,
  SearchWhat TEXT,             -- 검색어
  DateTime   TEXT
);
```

---

## 3. SQLite data.db

콘텐츠 메타데이터 인덱스. 서버에서 사전 생성된 DB 파일을 다운로드하거나, JSON 청크를 받아 증분 동기화(`SyncManager`)한다.

### 3.1 HitomiColumnModel

```sql
-- 서버에서 생성되어 배포됨. 앱에서는 읽기·삭제만 수행.
CREATE TABLE HitomiColumnModel (
  Id          INTEGER PRIMARY KEY,
  Title       TEXT,
  EHash       TEXT,
  Type        TEXT,
  Artists     TEXT,            -- 쉼표 구분
  Characters  TEXT,
  Groups      TEXT,
  Language    TEXT,
  Series      TEXT,
  Tags        TEXT,            -- 쉼표 구분
  Uploader    TEXT,
  Published   INTEGER/TEXT,    -- .NET Ticks 또는 ISO 8601 문자열
  Files       INTEGER,         -- 파일(페이지) 수
  Class       TEXT,
  PublishedEH TEXT,            -- E/ExHentai 게시 일시
  Thumbnail   TEXT,
  URL         TEXT,
  ExistOnHitomi INTEGER        -- 1이면 Hitomi에 존재, 필터링에 사용
);
```

`QueryResult` 클래스(`lib/database/query.dart`)가 이 테이블의 한 행을 래핑한다.

#### Published 필드 변환

`Published` 값이 정수인 경우 .NET DateTime Ticks 형식이다:

```
epochTicks         = 621355968000000000
ticksPerMillisecond = 10000
msSinceEpoch       = (Published - epochTicks) / ticksPerMillisecond
```

문자열이면 ISO 8601로 파싱하고, `PublishedEH`는 E/ExHentai 출처의 날짜로 폴백에 사용된다.

#### ExistOnHitomi 필터

기본 검색에서는 `ExistOnHitomi=1` 조건이 붙어 삭제된 작품을 제외한다. `Settings.searchPure`가 `true`이면 이 필터를 무시한다.
