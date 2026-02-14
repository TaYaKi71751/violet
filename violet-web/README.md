# violet-web

Violet Flutter 앱의 웹 버전. 개인용 이미지 만화 뷰어.

## 요구사항

- **Node.js** 18+
- **pnpm** (`npm install -g pnpm`)

## 설치

```bash
cd violet-web
pnpm install
```

## 데이터베이스 자동 동기화

**violet-web은 서버 시작 시 자동으로 `data.db`를 다운로드하고 동기화합니다.**

- 서버 최초 실행 시 `data.db`가 없으면 자동으로 전체 DB를 다운로드합니다.
- 이후 30분마다 자동으로 새로운 청크를 다운로드하여 DB를 업데이트합니다.
- 마지막 전체 동기화로부터 7일이 지나면 자동으로 전체 DB를 재다운로드합니다.

수동으로 동기화를 관리하려면:
- Settings 페이지에서 "Sync Now" 버튼으로 즉시 동기화
- "Re-download DB" 버튼으로 전체 DB 재다운로드
- `/api/sync/status` API로 동기화 상태 확인

유저 데이터(북마크, 히스토리)용 `user.db`는 서버 최초 실행 시 자동 생성된다.

## 실행

### 개발 모드 (백엔드 + 프론트엔드 동시 실행)

```bash
pnpm dev
```

- 백엔드: http://localhost:3001
- 프론트엔드: http://localhost:5173

프론트엔드 dev 서버가 `/api/*` 요청을 백엔드로 프록시하므로, 브라우저에서는 http://localhost:5173 만 열면 된다.

### 개별 실행

```bash
# 백엔드만
pnpm --filter @violet-web/backend dev

# 프론트엔드만
pnpm --filter @violet-web/frontend dev
```

### 프로덕션 빌드

```bash
pnpm build
```

## 환경변수

`packages/backend/.env` 파일을 만들어서 설정할 수 있다. (`.env.example` 참고)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `PORT` | `3001` | 백엔드 포트 |
| `DATA_DB_PATH` | `./data/data.db` | 콘텐츠 DB 경로 |
| `USER_DB_PATH` | `./data/user.db` | 유저 데이터 DB 경로 |
| `SYNC_ENABLED` | `true` | 자동 동기화 활성화 여부 |
| `SYNC_INTERVAL_MS` | `1800000` | 동기화 주기 (밀리초, 기본 30분) |
| `SYNC_LANGUAGE` | `global` | DB 언어 (global/ko/en/ja/zh) |

## 프로젝트 구조

```
violet-web/
├── packages/
│   ├── shared/      # 프론트/백엔드 공유 타입 & 유틸
│   ├── backend/     # Express 서버 (이미지 프록시, 검색, 데이터 저장)
│   └── frontend/    # React SPA (반응형 뷰어)
```

## API 엔드포인트

| Method | 경로 | 설명 |
|--------|------|------|
| GET | `/api/health` | 헬스체크 |
| GET | `/api/content/search?q=&page=&pageSize=` | 콘텐츠 검색 |
| GET | `/api/content/:id` | 단일 작품 조회 |
| GET | `/api/proxy/image?url=&referer=` | 이미지 프록시 |
| GET | `/api/proxy/gallery/:id` | 갤러리 이미지 URL 해석 |
| GET | `/api/bookmarks/groups` | 북마크 그룹 목록 |
| POST | `/api/bookmarks/groups` | 북마크 그룹 생성 |
| DELETE | `/api/bookmarks/groups/:id` | 북마크 그룹 삭제 |
| GET | `/api/bookmarks/articles` | 북마크 작품 목록 |
| POST | `/api/bookmarks/articles` | 북마크 추가 |
| DELETE | `/api/bookmarks/articles/:id` | 북마크 삭제 |
| GET | `/api/history` | 읽기 기록 |
| POST | `/api/history` | 읽기 기록 추가 |
| PATCH | `/api/history/:id` | 읽기 기록 업데이트 |
| GET | `/api/sync/status` | DB 동기화 상태 조회 |
| POST | `/api/sync/trigger` | 청크 동기화 트리거 (백그라운드 실행) |
| POST | `/api/sync/full` | 전체 DB 재다운로드 트리거 |

## 검색 쿼리 문법

Flutter 앱과 동일한 DSL을 지원한다.

```
artist:name          # 아티스트 검색
tag:tagname          # 태그 검색
male:tagname         # male 태그
female:tagname       # female 태그
series:name          # 시리즈
group:name           # 그룹
lang:korean          # 언어 필터
type:manga           # 타입 필터
page>20              # 페이지 수 필터
-artist:name         # 제외
query1 OR query2     # OR 연산
(a OR b) c           # 괄호 그룹
12345                # ID로 직접 검색
```
