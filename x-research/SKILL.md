---
name: x-research
description: Research X (formerly Twitter) using the grok CLI as a live research agent — real posts, @handles, URLs, dates, and engagement numbers, no X API key needed (runs on the user's Grok subscription). Use whenever the user wants to know what people are saying on X, find posts/threads/accounts, track sentiment or trends, or research a topic/person/launch on X. Triggers include "research on X", "search X", "search Twitter", "what's X saying about", "what are people posting about", "ask grok", "find tweets about", "who's talking about", "X sentiment on".
argument-hint: "<what to research on X>"
allowed-tools: Bash, Read
---

# X Research (via grok CLI)

Delegates X/Twitter research to the `grok` CLI in headless mode. Grok has native live X search (keyword + semantic, with date filters) and returns real posts with handles, URLs, timestamps, and engagement. This replaces X API workflows entirely.

## How to Use

Run the wrapper with a clear, self-contained research question:

```bash
bash ~/.claude/skills/x-research/scripts/xsearch.sh "<research question>"
```

**Always set a generous Bash timeout: 300000 (5 min).** A grok research run typically takes 1–3 minutes. For big multi-angle research, launch several calls in parallel with `run_in_background: true` and collect results as they finish.

## Writing Good Research Prompts

The wrapper already instructs grok to cite @handles, x.com URLs, dates, and engagement. Your job is to make the research question specific:

- **Scope the time window explicitly**: "in the last 7 days", "since June 1, 2026". Grok supports `since:`/`until:` operators. Include today's absolute date — "recent" alone is fuzzy.
- **Name the angle**: sentiment, top voices, criticism, launch reception, thread-hunting, account discovery.
- **Ask for structure when downstream work needs it**: "return a markdown table of @handle | post summary | URL | likes".
- **For person research**: "posts from @handle" vs "posts about <person>" — say which.
- **Engagement floors** help cut noise: "only posts with meaningful engagement (min ~50 likes)".

## Tuning (env vars)

| Variable | Default | When to use |
|---|---|---|
| `XR_MAX_TURNS` | 15 | Raise to 25–30 for deep multi-query research; lower to 6 for a quick lookup. |
| `XR_EFFORT` | grok default | `low` for quick lookups, `high`/`xhigh` for deep synthesis. |
| `XR_JSON` | off | `1` emits grok's JSON output format for programmatic parsing. |
| `XR_SCRATCH` | `~/.cache/x-research/scratch` | Grok's working directory (kept away from real projects). |

## Examples

```bash
# Quick pulse-check
bash ~/.claude/skills/x-research/scripts/xsearch.sh \
  "What are people saying about Claude Code on X in the last 48 hours? Top 5 posts by engagement."

# Deep research, multiple angles, higher effort
XR_EFFORT=high XR_MAX_TURNS=25 bash ~/.claude/skills/x-research/scripts/xsearch.sh \
  "Research the reception of <product launch> on X over the past 2 weeks: overall sentiment split, the 5 most influential posts, common criticisms, and notable accounts driving the conversation."

# Person/account research
bash ~/.claude/skills/x-research/scripts/xsearch.sh \
  "Summarize what @naval has posted in the last 30 days. Group by theme, link the top posts."

# Structured output for downstream use
bash ~/.claude/skills/x-research/scripts/xsearch.sh \
  "Find 10 accounts actively posting about productivity systems for executives. Return a markdown table: @handle | follower estimate | what they post | example post URL."
```

For broad research, fan out 2–4 parallel background calls with different angles (sentiment / top voices / criticism / adjacent topics), then synthesize.

## Notes for the Agent

- **Do not strip the wrapper's safety flags.** grok auto-loads all user skills from `~/.claude/skills` (it's Claude Code-compatible), including this one — without `--disallowed-tools Shell,Task,...` and `--no-subagents` it will recursively invoke this very skill and fan out runaway grok processes. (Grok's real tool IDs are `Shell`, `Task`, `Write`, `StrReplace` — NOT the `run_terminal_cmd`-style names in grok's own docs.) If a run ever hangs >5 min with no output, check `ps aux | grep grok` for a process explosion and `pkill -f "grok --cwd"`.
- **Auth**: runs on the user's Grok subscription via `grok login` OAuth — no API key. Ignore `grok models` saying "You are not authenticated"; that readout is unreliable. The real test is whether a `-p` prompt works. If a run actually fails with an auth error, the user must run `grok login` themselves (it's an interactive OAuth flow).
- **Verify surprising claims**: grok cites real x.com URLs — surface them so the user can click through. Don't strip citations.
- **Follow-ups**: each call is a fresh session. For an interactive follow-up on the same research, either re-ask with full context in a new call, or use `grok --cwd ~/.cache/x-research/scratch -c -p "<follow-up>"` to continue grok's most recent session in the scratch dir.
- **Not just X**: grok also has general web search. If a question mixes X + web, it handles both in one run — but for pure web research prefer a dedicated web-search tool if one is available.
- **Cost**: included in the Grok subscription; no per-call billing.
