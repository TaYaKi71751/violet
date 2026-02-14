# CropBookmarkPage: 데이터 → 화면 표시 흐름

## 1. 데이터 가져오기

```dart
// crop_bookmark.dart:80-83
FutureBuilder(
  future: widget.bookmarks != null
      ? Future.value(widget.bookmarks)
      : Bookmark.getInstance().then((value) => value.getCropImages()),
  ...
)
```

- 외부에서 `bookmarks`를 주입받으면 그대로 사용, 아니면 `Bookmark.getCropImages()`로 DB에서 전체 조회
- `getCropImages()`는 `SELECT * FROM BookmarkCropImage` → `BookmarkCropImage` 리스트 반환

## 2. BookmarkCropImage 데이터 구조

> 상세 스키마는 [user-data-spec.md](user-data-spec.md) 참조

```sql
CREATE TABLE BookmarkCropImage (
  Id          INTEGER PRIMARY KEY AUTOINCREMENT,
  Article     INTEGER,    -- 작품 ID
  Page        INTEGER,    -- 페이지 번호
  Area        TEXT,       -- "left,top,right,bottom" (0.0~1.0 정규화 좌표)
  AspectRatio DOUBLE,     -- 원본 이미지의 가로/세로 비율
  DateTime    TEXT
);
```

## 3. 각 아이템 렌더링 흐름

### 3-1. area 파싱 → Rect 변환 (`:106-118`)

```dart
final area = e.area().split(',').map((e) => double.parse(e)).toList();
// → Rect.fromLTRB(area[0], area[1], area[2], area[3])
```

### 3-2. 이미지 URL 가져오기 (`:172-181`)

```dart
final provider = await getImageProviderFromId(articleId);
final image = await provider.getImageUrl(page);
final header = await provider.getHeader(page);
```

articleId로 이미지 프로바이더를 얻고, 해당 page의 URL과 HTTP 헤더를 가져온다.

### 3-3. 표시 비율 계산 (`calculateCropRawAspectRatio`, `:467-476`)

```dart
double calculateCropRawAspectRatio(double width, double aspectRatio, Rect cropRect) {
  final height = width / aspectRatio;
  final cropSize = Size(cropRect.width * width, cropRect.height * height);
  return cropSize.width / cropSize.height;
}
```

셀 너비와 원본 비율로 가상의 원본 크기를 구한 뒤, 크롭 영역만의 비율을 계산한다. 이 값이 `AspectRatio` 위젯에 들어가서 각 셀의 높이가 결정된다.

## 4. CropImageWidget - 핵심 렌더링 (`:509-625`)

### 4-1. 원본 이미지 가상 크기 계산

```dart
final width = screenWidth / columnCount;  // 셀 너비
final height = width / aspectRatio;        // 원본 비율 기준 가상 높이
```

### 4-2. 크롭 영역을 픽셀 좌표로 변환

```dart
final cropSize = Size(rect.width * width, rect.height * height);
final cropRawRect = Rect.fromLTRB(
  rect.left * width, rect.top * height,
  rect.right * width, rect.bottom * height,
);
```

### 4-3. 뷰 사이즈 & translateRatio 결정 (`:533-543`)

크롭 비율이 원본보다 세로가 긴지/가로가 긴지에 따라 분기:

- `cropRawAspectRatio / rawAspectRatio <= 1.0` → 세로가 더 긴 크롭 → `viewRawSize = (width, 조정된 height)`
- 그 외 → 가로가 더 긴 크롭 → height 기준으로 계산 후 `translateRatio`로 보정

### 4-4. 최종 이미지 변환 - Scale → Translate → Clip

```dart
AspectRatio(
  aspectRatio: cropRawAspectRatio,        // 셀 비율 고정
  child: Transform.scale(
    scaleX: viewRawSize.width / cropRawRect.width,   // 크롭 영역이 셀을 채우도록 확대
    scaleY: viewRawSize.height / cropRawRect.height,
    alignment: Alignment.topLeft,
    child: Transform.translate(
      offset: Offset(
        -cropRawRect.left / translateRatio,  // 크롭 시작점으로 이동
        -cropRawRect.top / translateRatio,
      ),
      child: ClipRect(
        clipper: RectClipper(cropRect),      // 크롭 영역만 보이도록 잘라냄
        child: image,                        // ExtendedImage.network (전체 이미지)
      ),
    ),
  ),
)
```

핵심: **전체 이미지를 로드한 뒤, Scale로 확대 + Translate로 위치 이동 + ClipRect로 마스킹**해서 크롭 영역만 보여준다.

## 5. 레이아웃

`MasonryGridView.count`로 각 셀이 서로 다른 비율을 가진 벽돌형 그리드 배치. 컬럼 수는 설정에서 1~8 조절 가능.

## 한 줄 요약

> DB에서 `(articleId, page, area, aspectRatio)` → articleId/page로 이미지 URL 획득 → 전체 이미지 로드 후 area 좌표를 기반으로 `Scale + Translate + ClipRect` 변환하여 크롭 영역만 표시
