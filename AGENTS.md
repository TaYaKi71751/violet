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
