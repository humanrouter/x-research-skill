#!/usr/bin/env bash
# X (Twitter) research via the grok CLI — runs on your Grok subscription, no X API key.
#
# IMPORTANT: grok is Claude Code-compatible and auto-loads ALL user skills from
# ~/.claude/skills — including this one — which can cause recursive self-invocation
# (grok sees the x-research skill and calls this script again, fanning out
# nested grok processes). The flags below close that loop:
#   --disallowed-tools Shell  -> no shell, so no skill execution
#   --disallowed-tools Task + --no-subagents -> no parallel subagent fan-out
# Do not remove them. (Tool names are grok's actual IDs: Shell, Task, Write,
# StrReplace, Delete — NOT the run_terminal_cmd-style names in grok's own docs.)
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: xsearch.sh <research question>" >&2
  exit 1
fi

QUERY="$*"

# Scratch cwd outside ~/.claude so grok never treats a real project as its workspace.
SCRATCH="${XR_SCRATCH:-$HOME/.cache/x-research/scratch}"
mkdir -p "$SCRATCH"

MAX_TURNS="${XR_MAX_TURNS:-15}"

PROMPT="You are acting as an X (Twitter) research agent. Research the task below using your native live search capability over X posts (keyword search supports operators like from:, since:, until:, min_faves:, min_retweets:, filter:links, lang:; semantic search also works). You have NO shell, file, or subagent tools in this session — do not attempt them; search directly and answer.

Rules:
- Cite every claim with the post's @handle, date, and full x.com URL.
- Include engagement numbers (likes/reposts/views) when available.
- Distinguish high-signal accounts from random replies; note follower counts for key voices.
- If results are thin, broaden the query and say you did so.
- Do NOT read or write any files. Respond with the research findings only.

RESEARCH TASK:
$QUERY"

ARGS=(
  --cwd "$SCRATCH"
  -p "$PROMPT"
  --max-turns "$MAX_TURNS"
  --no-subagents
  --no-memory
  --disallowed-tools "Shell,Task,Write,StrReplace,Delete,EditNotebook"
)
if [ -n "${XR_EFFORT:-}" ]; then
  ARGS+=(--effort "$XR_EFFORT")
fi
if [ "${XR_JSON:-0}" = "1" ]; then
  ARGS+=(--output-format json)
fi

exec grok "${ARGS[@]}"
