# claude-review

OpenCode 또는 Codex에서 로컬 Claude CLI를 호출해 Claude에게 2차 검토를 받는 skill입니다.

[Read in English](./README.md)

---

## 개요

일부 서드파티 코딩 에이전트는 자체 provider 연동만으로 Claude 모델을 직접 호출할 수 없습니다.
이 skill은 로컬에 설치된 `claude` CLI를 실행해서 그 결과를 에이전트에게 다시 전달하는 방식으로 동작합니다.

대표적인 용도:

- 구현 전에 plan 검토
- diff 또는 전체 코드 리뷰
- 완료된 작업 double-check
- CTF exploit chain 검토

예시 요청:

- `Claude한테 이 plan 검토 맡겨줘`
- `Claude로 diff 리뷰 해줘`
- `이 결과 Claude로 다시 확인해줘`
- `이 exploit chain Claude한테 검토 맡겨줘`

---

## 요구 사항

- `claude` CLI가 `PATH`에 있어야 함
- `stream-json` 파싱을 위해 `jq` 필요
- diff 기반 리뷰를 위해 `git` 필요

이미 로컬에서 Claude Code를 사용 중이라면 이 skill 흐름에서 별도 API 토큰은 필요 없습니다.

---

## 저장소 구조

```text
.
├─ install.sh
└─ skill/
   └─ SKILL.md
```

---

## 설치

### 권장: raw installer 사용

```bash
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/install.sh | bash
```

또는 저장소를 직접 받아서 로컬에서 실행할 수 있습니다.

```bash
chmod +x install.sh
./install.sh
```

---

## installer 동작 방식

installer는 두 가지 모드를 지원합니다.

### 1. Targeted mode

`--target opencode` 또는 `--target codex` 를 사용하는 방식입니다.

- `--path`를 생략하면 target의 글로벌 기본 경로에 설치합니다.
- `--path`를 주면 그 위치를 기준 경로(base path)로 보고 target 전용 skill 경로를 뒤에 자동으로 붙입니다.

예시:

```bash
# OpenCode 글로벌 설치
./install.sh --target opencode

# Codex 글로벌 설치
./install.sh --target codex

# 현재 프로젝트의 OpenCode 경로에 설치
./install.sh --target opencode --path .

# 현재 프로젝트의 Codex 경로에 설치
./install.sh --target codex --path .
```

`--path .` 를 사용하면 실제 설치 위치는 다음과 같습니다.

- OpenCode → `./.opencode/skills/claude-review`
- Codex → `./.agents/skills/claude-review`

### 2. Exact-path mode

`--target` 없이 `--path`만 주면, 지정한 정확한 디렉터리에 `SKILL.md`만 복사합니다.

Exact-path mode에서는 로컬에서 `./install.sh`로 실행하더라도 항상 copy 방식으로 동작합니다.

예시:

```bash
./install.sh --path /exact/install/directory
```

이 경우 생성되는 파일:

```text
/exact/install/directory/SKILL.md
```

### 실행 방식에 따른 설치 모드

- 로컬 실행 (`./install.sh`) → symlink 설치, 단 exact-path mode는 예외
- `curl | bash` 실행 → copy 설치

즉, 로컬 개발 중에는 수정 반영이 편하고, raw installer로도 바로 설치할 수 있습니다.

---

## installer 사용법

```bash
./install.sh [--target opencode|codex] [--path PATH] [--ref REF]
```

예시:

```bash
./install.sh
./install.sh --target opencode
./install.sh --target codex --path /path/to/project
./install.sh --target opencode --path .
./install.sh --path /exact/install/directory
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/install.sh | bash -s -- --target opencode
```

---

## 수동 설치

### OpenCode 글로벌

```bash
mkdir -p ~/.config/opencode/skills/claude-review
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md \
  -o ~/.config/opencode/skills/claude-review/SKILL.md
```

`XDG_CONFIG_HOME`가 설정되어 있으면 OpenCode는 `~/.config` 대신 그 경로를 사용합니다.

### Codex 글로벌

```bash
mkdir -p ~/.agents/skills/claude-review
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md \
  -o ~/.agents/skills/claude-review/SKILL.md
```

### Exact-path 수동 설치

```bash
mkdir -p /exact/install/directory
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md \
  -o /exact/install/directory/SKILL.md
```

### Windows

WSL2 사용을 권장합니다.

PowerShell 예시:

```powershell
$dest = "$env:USERPROFILE\.config\opencode\skills\claude-review"
New-Item -ItemType Directory -Force -Path $dest
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md" -OutFile "$dest\SKILL.md"
```

---

## 기본 설치 경로

| Target | 글로벌 경로 |
|---|---|
| OpenCode | `~/.config/opencode/skills/claude-review` |
| Codex | `~/.agents/skills/claude-review` |

---

## 설치 확인

- OpenCode: 세션을 재시작한 뒤 사용 가능한 skill을 확인
- Codex: `/skills` 실행

---

## 동작 방식

```text
OpenCode / Codex
  -> claude-review skill
    -> local claude CLI
      -> Claude response
        -> summarized back to the agent
```

이 skill은 긴 응답도 안정적으로 파싱할 수 있도록 Claude의 `stream-json` 출력 모드를 사용합니다.
향후 Claude CLI의 `stream-json` 스키마가 바뀌면 `skill/SKILL.md`의 파싱 가이드를 함께 갱신해야 합니다.

이 저장소는 OpenCode와 Codex용 skill 설치만 다룹니다.
Claude 쪽에 별도 등록은 하지 않습니다.

raw URL 예시는 `master` 브랜치를 기준으로 합니다.

---

## 라이선스

MIT
