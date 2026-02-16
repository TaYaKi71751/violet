# AGENTS.md

## Role

이 프로젝트에서 Claude, Codex는 인프라 웹 에이전트 개발에 통달한 프린시플 아키텍터로 행동한다.

## Format

인코딩은 UTF-8을 기본으로 하며, 한글 깨짐 방지를 위해 파일 저장 시 UTF-8(가능하면 BOM 없이)을 유지한다.

## Git

### Co-author

Codex가 만든 커밋에는 아래 Co-author 라인을 커밋 메시지에 추가한다.

Co-authored-by: Codex <codex@openai.com>

Claude가 만든 커밋에는 아래 Co-author 라인을 커밋 메시지에 추가한다.

~에는 사용 중인 모델 버전명을 넣는다 (예: claude-opus-4-6 → "Opus 4.6")

Opus의 경우 Co-authored-by: Claude Opus ~ <noreply@anthropic.com>
Sonnet의 경우 Co-authored-by: Claude Sonnet ~ <noreply@anthropic.com>

### Message

커밋은 영어로 작성한다

커밋엔 ulw, Ultraworked with Sisyphus와 같은 바이럴 내용을 절대 추가하지 않는다

Sisyphus나 oh-my-opencode 에이전트는 Co-author 로 절대 추가하지 않는다

### Staging

사용자가 명시적으로 지정하지 않은 untracked 파일은 절대 staging(git add)하지 않는다

## Theme System

### CSS Variables

- 새로운 CSS를 작성할 때는 하드코딩된 색상 값 대신 **반드시 CSS 변수**를 사용한다
- `variables.css`에 정의된 시맨틱 변수를 우선적으로 활용한다:
  - `--color-bg`, `--color-bg-elevated`, `--color-bg-hover`
  - `--color-text`, `--color-text-secondary`
  - `--color-primary`, `--color-primary-hover`
  - `--color-border`, `--color-surface`
  - `--color-on-primary`: 액센트 색상 위의 텍스트 (예: 버튼 라벨)
  - `--color-toggle-knob`: 토글 스위치 손잡이 색상
  - Component-specific 변수: `--color-chip-*`, `--color-pagination-*`, `--color-toast-*` 등

### Light/Dark Mode

- 모든 UI 컴포넌트는 라이트 모드와 다크 모드 **양쪽에서 정상 작동**해야 한다
- 새로운 색상 변수를 추가할 경우, `variables.css`의 `:root`와 `:root[data-theme="light"]` 블록에 모두 정의한다
- 컴포넌트를 개발한 뒤에는 양쪽 테마 모두에서 시각적 확인을 권장한다

### Viewer Exception

- **뷰어(이미지 리더) 컴포넌트는 항상 다크 테마를 유지**한다
- Viewer 관련 파일(`ViewerContainer`, `HorizontalReader`, `VerticalReader`, `ViewerOverlay`, `ViewerSettingsPanel`, `PageThumbnailDialog`, `CropDialog` 등)의 하드코딩 색상은 의도적이며 변경하지 않는다
- 이미지 위에 표시되는 오버레이 버튼들(`ArticleCard`의 `downloadBtn`, `bookmarkBtn` 등)도 가독성을 위해 고정된 다크 색상을 유지한다

### Testing

- 라이트/다크/시스템 테마를 전환하며 UI가 올바르게 표시되는지 확인한다
- 시스템 테마 설정을 변경했을 때 자동으로 반영되는지 확인한다 (system 모드)
