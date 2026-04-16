---
name: claude-review
description: >
  Ask the local Claude CLI to review plans, diffs, full codebases,
  completed work, and exploit chains when the user explicitly wants
  a Claude second opinion.
allowedTools:
  - Bash(*)
  - Read
  - Grep
---

# Claude Review

Use this skill when the user explicitly asks to:

- confirm or review a plan before implementation
- review code (changed diff or full codebase)
- double-check or verify completed work
- validate a CTF exploit chain or attack logic

Examples:

- "ask Claude to confirm this plan"
- "have Claude review the diff"
- "Claude로 전체 코드 리뷰 해줘"
- "double-check this with Claude"
- "Claude한테 이 exploit chain 검토 맡겨줘"

## Core behavior

You must compose the Claude prompt yourself from the user's request.

Do **not** ask the user to write the final Claude prompt unless they explicitly want to control the wording.

1. Infer the task type: plan / code-review / double-check / CTF chain
2. Choose the right context collection strategy (see below)
3. Build a concise but sufficient Claude prompt in Korean or English to match the user
4. Choose the Claude effort level before execution
5. Run Claude non-interactively via the local CLI
6. Summarize the result for the user
7. If Claude raises questions/ambiguities, report those clearly

---

## Effort selection

Choose `--effort` from `medium`, `high`, or `max`.

- Use the user's requested effort if they explicitly specify one.
- Otherwise choose it yourself based on task complexity.

Recommended defaults:

- `medium` — narrow plan confirmation, single-file double-check
- `high` — normal code review, multi-file diff, CTF chain review
- `max` — broad architectural review, full repo review, complex exploit chain

---

## Context collection strategy

### Code review — diff mode (default)

Use when reviewing recent local changes. For PR review, choose the appropriate base/ref explicitly.

```bash
# local unstaged/staged changes vs current HEAD
git diff HEAD
# or for staged only:
git diff --cached
# or for a branch/PR style comparison:
# git diff origin/main...HEAD
```

### Code review — full mode

Use when the user asks for a holistic review, architecture check,
or when the diff alone lacks enough context.

```bash
COUNT=$(git ls-files '*.go' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.rb' '*.rs' | wc -l)
[ "$COUNT" -ge 60 ] && echo "warning: limiting full review context to at most 60 files" >&2

git ls-files '*.go' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.rb' '*.rs' \
  | awk 'NR<=60 { print }' \
  | while IFS= read -r file; do
      printf '\n===== %s =====\n' "$file"
      cat "$file"
    done
```

> Adjust the extension list to match the repo language.
> For large repos, narrow by directory or package before collecting context.

### Plan confirmation

Include the written plan (from file or conversation) + relevant existing code for context.

### Double-check

Include the output/result being verified + the original task description.

### CTF chain

Include the full exploit chain steps, target binary/service info, and constraints.

---

## Prompt construction rules

### Plan confirmation

```text
Review the following implementation plan and confirm whether the approach is sound.
Point out any logical gaps, missing edge cases, or better alternatives.

[PLAN]
<plan content>

[CONTEXT]
<relevant existing code or constraints>
```

### Code review — diff mode

```text
Review the following git diff. Focus on bugs, code quality, and improvement opportunities.
Distinguish real bugs from nits.

[DIFF]
<git diff output>

[CONTEXT]
<what this change implements, any known deferred work>
```

### Code review — full mode

```text
Review the overall code quality and architecture of this codebase.
Focus on structural issues, anti-patterns, and high-risk areas.
Distinguish critical issues from minor nits.

[CODE]
<collected source files>

[CONTEXT]
<what to focus on, known constraints>
```

### Double-check

```text
Double-check the following result against the original task.
Identify any mistakes, missing cases, or incorrect assumptions.

[TASK]
<original task description>

[RESULT]
<output or code to verify>
```

### CTF exploit chain

```text
Review the following exploit chain for logical correctness and feasibility.
For each step, confirm whether it is achievable given the constraints.
Point out any broken links, wrong assumptions, or missed primitives.

[TARGET]
<binary/service info, mitigations>

[CHAIN]
<step-by-step exploit plan>

[CONSTRAINTS]
<environment, known offsets, available gadgets, etc.>
```

---

## Execution command

Before relying on the parsing filter below, quickly inspect the current CLI schema:

```bash
claude --output-format stream-json --verbose --print "hello" | head -5
```

### Primary

```bash
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for reliable stream-json parsing. Install jq first." >&2
  exit 1
fi

PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/claude-prompt.XXXXXX")"
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" << 'PROMPT_EOF'
Review the following diff and identify real bugs first, then quality issues.

[DIFF]
<paste git diff output here>

[CONTEXT]
<paste task summary or known constraints here>
PROMPT_EOF

claude --model claude-sonnet-4-6 --effort <medium|high|max> \
  --output-format stream-json \
  --verbose \
  --print "$(cat "$PROMPT_FILE")" \
  | jq -r '
      if .type == "assistant" then
        .message.content[]? | select(.type == "text") | .text
      elif .type == "text" then
        .text
      else
        empty
      end
    '
```

> Keep the composed prompt scoped. Very large prompts can still be awkward to pass via CLI arguments.
> Re-check the `stream-json` schema after Claude CLI upgrades - this jq filter assumes the current assistant/text event structure.

---

## Important constraints

- Only use this skill when the user explicitly wants Claude involved.
- Do not claim Claude reviewed something unless you actually executed the CLI command.
- If Claude CLI is unavailable, report that clearly and include the exact failure.
- Do not commit or modify git history as part of this skill.
- For full repo review, warn the user if file count is large (>60 files) and confirm scope before running.

## Response summary format

Return findings structured by task type:

**Plan / Double-check / CTF:**
- ✅ Confirmed valid points
- ⚠️ Issues or gaps found
- ❌ Blockers or incorrect assumptions
- 💡 Recommendations

**Code review:**
- ✅ Positives
- 🐛 Real bugs (must fix)
- 🔧 Nits (optional)
- 💡 Your recommendation on what to act on
