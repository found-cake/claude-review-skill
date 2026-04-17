# claude-review

Ask the local Claude CLI for a second opinion from OpenCode or Codex.

[한국어 문서 보기](./README_KR.md)

---

## What this is

Because of Anthropic's policy, Claude cannot be used through OAuth from external clients.
This skill works around that by invoking the locally installed `claude` CLI and returning the result to the agent.

Typical use cases:

- review an implementation plan before coding
- review a diff or a full codebase
- double-check completed work
- validate a CTF exploit chain

Example requests:

- `Ask Claude to review this plan`
- `Have Claude review this diff`
- `Double-check this with Claude`
- `Ask Claude to review this exploit chain`

---

## Requirements

- `claude` CLI available in `PATH`
- `jq` installed for `stream-json` parsing
- `git` available when you want diff-based review

If you already use Claude Code locally, no separate API token is required for this skill flow.

---

## Repository layout

```text
.
├─ install.sh
└─ skill/
   └─ SKILL.md
```

---

## Install

### Recommended: raw installer

```bash
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/install.sh | bash
```

You can also clone or download the repository and run the installer locally:

```bash
chmod +x install.sh
./install.sh
```

---

## Installer behavior

The installer supports two modes.

### 1. Targeted mode

Use `--target opencode` or `--target codex`.

- If `--path` is omitted, the installer uses the target's global default path.
- If `--path` is provided, the installer treats it as a base path and appends the target-specific skill location.

Examples:

```bash
# Global OpenCode install
./install.sh --target opencode

# Global Codex install
./install.sh --target codex

# Install into the current project's OpenCode path
./install.sh --target opencode --path .

# Install into the current project's Codex path
./install.sh --target codex --path .
```

With `--path .`, the resulting locations are:

- OpenCode → `./.opencode/skills/claude-review`
- Codex → `./.agents/skills/claude-review`

### 2. Exact-path mode

If you omit `--target` and provide only `--path`, the installer copies `SKILL.md` directly into that exact directory.

In exact-path mode, installation is always a copy, even when you run `./install.sh` locally.

Example:

```bash
./install.sh --path /exact/install/directory
```

This creates:

```text
/exact/install/directory/SKILL.md
```

### Install mode by execution source

- Local execution (`./install.sh`) → installs by symlink, except exact-path mode
- `curl | bash` execution → installs by copy

This keeps local development convenient while still allowing raw installer usage.

---

## Installer usage

```bash
./install.sh [--target opencode|codex] [--path PATH] [--ref REF]
```

Examples:

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

## Manual install

### OpenCode global

```bash
mkdir -p ~/.config/opencode/skills/claude-review
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md \
  -o ~/.config/opencode/skills/claude-review/SKILL.md
```

If `XDG_CONFIG_HOME` is set, OpenCode uses that config root instead of `~/.config`.

### Codex global

```bash
mkdir -p ~/.agents/skills/claude-review
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md \
  -o ~/.agents/skills/claude-review/SKILL.md
```

### Exact-path manual install

```bash
mkdir -p /exact/install/directory
curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md \
  -o /exact/install/directory/SKILL.md
```

### Windows

WSL2 is recommended.

PowerShell example:

```powershell
$dest = "$env:USERPROFILE\.config\opencode\skills\claude-review"
New-Item -ItemType Directory -Force -Path $dest
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/found-cake/claude-review-skill/master/skill/SKILL.md" -OutFile "$dest\SKILL.md"
```

---

## Default install paths

| Target | Global path |
|---|---|
| OpenCode | `~/.config/opencode/skills/claude-review` |
| Codex | `~/.agents/skills/claude-review` |

---

## Verify installation

- OpenCode: restart the session and ask which skills are available
- Codex: run `/skills`

---

## How it works

```text
OpenCode / Codex
  -> claude-review skill
    -> local claude CLI
      -> Claude response
        -> summarized back to the agent
```

The skill uses Claude's `stream-json` output mode for stable parsing of long responses.
If the Claude CLI changes its `stream-json` schema in a future release, update the parsing guidance in `skill/SKILL.md` accordingly.

This repository installs the skill for OpenCode and Codex only.
It does not register anything on the Claude side.

Raw URLs in this repository assume the `master` branch.

---

## License

MIT
