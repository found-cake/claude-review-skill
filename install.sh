#!/usr/bin/env bash

set -euo pipefail

SKILL_NAME="claude-review"
GITHUB_OWNER="found-cake"
GITHUB_REPO="claude-review-skill"
DEFAULT_REF="master"

TARGET=""
INSTALL_PATH=""
REF="$DEFAULT_REF"
REMOTE_BASE=""
TEMP_DIR=""

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--target opencode|codex] [--path PATH] [--ref REF]

Examples:
  ./install.sh
  ./install.sh --target opencode
  ./install.sh --target codex --path /path/to/project
  ./install.sh --target opencode --path .
  ./install.sh --path /exact/install/directory
  curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/found-cake/claude-review-skill/master/install.sh | bash -s -- --target opencode

Notes:
  - Local execution installs by symlink for easy updates.
  - curl|sh execution installs by copy because there is no local skill directory to symlink.
  - If --path is omitted, the installer uses the target's global default location.
  - If --target and --path are both provided, --path is treated as a base path.
  - opencode base path -> <path>/.opencode/skills/<name>
  - codex base path    -> <path>/.agents/skills/<name>
  - If --target is omitted and --path is provided, exact-path mode copies SKILL.md into that exact directory.
  - OpenCode global path: ~/.config/opencode/skills/<name>
  - Codex global path:    ~/.agents/skills/<name>
EOF
}

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  CYAN="$(tput setaf 6)"
  RED="$(tput setaf 1)"
  RESET="$(tput sgr0)"
else
  BOLD=""
  GREEN=""
  YELLOW=""
  CYAN=""
  RED=""
  RESET=""
fi

info() { printf '%s\n' "${CYAN}[info]${RESET}  $*"; }
success() { printf '%s\n' "${GREEN}[ok]${RESET}    $*"; }
warn() { printf '%s\n' "${YELLOW}[warn]${RESET}  $*"; }
error() { printf '%s\n' "${RED}[error]${RESET} $*" >&2; }
header() {
  printf '\n%s\n' "${BOLD}$*${RESET}"
  printf '%s\n' '--------------------------------------------------'
}

prompt_choice() {
  local var_name="$1"
  local prompt_text="$2"
  local value

  printf '%s' "$prompt_text"
  read -r value
  printf -v "$var_name" '%s' "$value"
}

resolve_config_home() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    printf '%s\n' "$XDG_CONFIG_HOME"
  else
    printf '%s\n' "$HOME/.config"
  fi
}

absolute_path() {
  local input_path="$1"
  if [ -d "$input_path" ]; then
    (cd "$input_path" && pwd)
  else
    local parent_dir
    parent_dir="$(cd "$(dirname "$input_path")" && pwd)"
    printf '%s/%s\n' "$parent_dir" "$(basename "$input_path")"
  fi
}

validate_target() {
  case "$1" in
    opencode|codex) ;;
    *) error "Invalid target: $1"; usage; exit 1 ;;
  esac
}

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --path)
      INSTALL_PATH="${2:-}"
      shift 2
      ;;
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$REF" ]; then
  error '--ref cannot be empty'
  exit 1
fi

SCRIPT_PATH=""
if [ -n "${BASH_SOURCE[0]-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi

if [ -n "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  LOCAL_SKILL_SRC="$SCRIPT_DIR/skill/SKILL.md"
else
  SCRIPT_DIR=""
  LOCAL_SKILL_SRC=""
fi

REMOTE_BASE="https://raw.githubusercontent.com/$GITHUB_OWNER/$GITHUB_REPO/$REF/skill"

CONFIG_HOME="$(resolve_config_home)"

OPENCODE_GLOBAL_DIR="$CONFIG_HOME/opencode/skills/$SKILL_NAME"
AGENT_GLOBAL_DIR="$HOME/.agents/skills/$SKILL_NAME"

if [ -f "$LOCAL_SKILL_SRC" ]; then
  SOURCE_MODE="local"
  SOURCE_DIR="$SCRIPT_DIR/skill"
else
  SOURCE_MODE="remote"
  if ! command -v curl >/dev/null 2>&1; then
    error 'curl is required when running install.sh without local skill files'
    exit 1
  fi

  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-review-install.XXXXXX")"
  SOURCE_DIR="$TEMP_DIR/$SKILL_NAME"
  mkdir -p "$SOURCE_DIR"

  info "Fetching SKILL.md from $REMOTE_BASE/SKILL.md"
  curl -fsSL "$REMOTE_BASE/SKILL.md" -o "$SOURCE_DIR/SKILL.md"
fi

SKILL_SRC="$SOURCE_DIR/SKILL.md"

if [ ! -f "$SKILL_SRC" ]; then
  error "SKILL.md not found at $SKILL_SRC"
  exit 1
fi

if [ "$SOURCE_MODE" = "local" ]; then
  INSTALL_MODE="symlink"
else
  INSTALL_MODE="copy"
fi

header "claude-review installer"
info "Source mode: $SOURCE_MODE"
info "Skill source: $SOURCE_DIR"

if [ -z "$TARGET" ]; then
  if [ -z "$INSTALL_PATH" ]; then
    printf '%s\n' 'Install target:'
    printf '%s\n' '  1) opencode'
    printf '%s\n' '  2) codex'
    prompt_choice TARGET 'Enter choice [1-2]: '
    case "$TARGET" in
      1) TARGET="opencode" ;;
      2) TARGET="codex" ;;
      *) error "Invalid choice: $TARGET"; exit 1 ;;
    esac
  else
    TARGET_MODE='exact-path'
    info "Exact-path mode detected - SKILL.md will be copied directly into the provided directory."
  fi
fi

if [ -n "$TARGET" ]; then
  validate_target "$TARGET"
  TARGET_MODE='targeted'
fi

if [ -n "$INSTALL_PATH" ]; then
  PATH_DIR="$(absolute_path "$INSTALL_PATH")"
fi

if [ "$TARGET_MODE" = 'exact-path' ]; then
  DEST_DIR="$PATH_DIR"
  INSTALL_MODE='copy'
else
  if [ -n "$INSTALL_PATH" ]; then
    case "$TARGET" in
      opencode) DEST_DIR="$PATH_DIR/.opencode/skills/$SKILL_NAME" ;;
      codex) DEST_DIR="$PATH_DIR/.agents/skills/$SKILL_NAME" ;;
    esac
  else
    case "$TARGET" in
      opencode) DEST_DIR="$OPENCODE_GLOBAL_DIR" ;;
      codex) DEST_DIR="$AGENT_GLOBAL_DIR" ;;
    esac
  fi
fi

if [ -n "$INSTALL_PATH" ]; then
  if [ ! -d "$PATH_DIR" ]; then
    if [ "$TARGET_MODE" = 'exact-path' ]; then
      error "Exact path does not exist: $PATH_DIR"
    else
      error "Base path does not exist: $PATH_DIR"
    fi
    exit 1
  fi
fi

install_dir() {
  local source_dir="$1"
  local dest_dir="$2"
  local label="${3:-exact-path}"

  mkdir -p "$(dirname "$dest_dir")"

  if [ -e "$dest_dir" ] || [ -L "$dest_dir" ]; then
    rm -rf "$dest_dir"
  fi

  if [ "$INSTALL_MODE" = "symlink" ]; then
    ln -s "$source_dir" "$dest_dir"
    success "$label -> symlinked to $dest_dir"
  else
    mkdir -p "$dest_dir"
    cp "$source_dir/SKILL.md" "$dest_dir/SKILL.md"
    success "$label -> copied to $dest_dir/SKILL.md"
  fi
}

verify_dir() {
  local path="$1"
  local label="${2:-exact-path}"

  if [ -L "$path" ]; then
    success "$label present (symlink): $path"
  elif [ -f "$path/SKILL.md" ]; then
    success "$label present: $path/SKILL.md"
  else
    warn "$label missing: $path"
  fi
}

header 'Installing'
install_dir "$SOURCE_DIR" "$DEST_DIR" "$TARGET"

header 'Verification'
verify_dir "$DEST_DIR" "$TARGET"

header 'Notes'
printf '%s\n' "Install mode: $INSTALL_MODE"
printf '%s\n' "Destination: $DEST_DIR"
printf '%s\n' "Mode: $TARGET_MODE"
printf '%s\n' 'This installer only installs the skill for OpenCode and/or Codex.'
printf '%s\n' 'Claude CLI still needs to be available in PATH at runtime.'
printf '%s\n' 'Check with: which claude && claude --version'
printf '%s\n' "Raw source: $REMOTE_BASE/SKILL.md"

if ! command -v claude >/dev/null 2>&1; then
  warn 'claude CLI not found in PATH - the skill will not work until Claude CLI is installed.'
fi

if ! command -v jq >/dev/null 2>&1; then
  warn 'jq not found in PATH - it is required for stream-json parsing in this skill.'
fi

if ! command -v git >/dev/null 2>&1; then
  warn 'git not found in PATH - diff-based review workflows will not work.'
fi

if [ "$TARGET" = "opencode" ]; then
  printf '%s\n' 'OpenCode: restart the app/session after installing the skill.'
fi

if [ "$TARGET" = "codex" ]; then
  printf '%s\n' 'Codex: use /skills after restart to confirm the skill is available.'
fi

success 'Done.'
