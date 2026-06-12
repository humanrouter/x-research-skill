# x-research — X (Twitter) research for Claude Code, powered by the grok CLI

A [Claude Code skill](https://code.claude.com/docs/en/skills) that turns the **grok CLI** into a live X (Twitter) research agent. Ask Claude *"what's X saying about [topic]?"* and it delegates the search to grok, which has native, live X search — real posts, @handles, x.com URLs, timestamps, and engagement numbers.

**No X API key. No per-call billing.** If you have a paid Grok subscription, grok CLI's headless mode does live X research as part of it.

```
You: what are people saying about Claude Code on X this week?

Claude → grok -p "..." → live X keyword + semantic search →

  1. @vibecodeguild (Jun 12): "I Built My Own Video Editor with Claude Code"
     https://x.com/vibecodeguild/status/2065263188409720954 — 1.2K likes
  2. ...
```

## Why this exists

Researching X used to mean paying for X API access. But grok (the model) has live X search built in, and the grok CLI exposes it from the terminal:

```bash
grok -p "Search X for recent posts about <topic>. Cite @handles and URLs."
```

It supports keyword search in Latest mode with real operators (`from:`, `since:`, `until:`, `min_faves:`, `min_retweets:`, `filter:links`, `lang:`) **and** semantic search, and returns real x.com URLs you can click through to verify.

This repo wraps that in a Claude Code skill so your agent knows when and how to use it — with guardrails that turned out to be very necessary (see [findings](#findings-the-gotchas-we-hit-so-you-dont-have-to)).

## Install

1. **Install the grok CLI** (see xAI's install docs) and sign in with your Grok subscription (interactive OAuth):

   ```bash
   grok login
   ```

2. **Copy the skill into Claude Code's user skills folder:**

   ```bash
   git clone https://github.com/humanrouter/x-research-skill.git
   cp -r x-research-skill/x-research ~/.claude/skills/
   chmod +x ~/.claude/skills/x-research/scripts/xsearch.sh
   ```

3. **Use it.** In any Claude Code session: `/x-research <question>`, or just ask naturally — "research X for...", "what's X saying about...", "find tweets about...". You can also run the wrapper directly:

   ```bash
   bash ~/.claude/skills/x-research/scripts/xsearch.sh \
     "Top 5 posts about <topic> this week by engagement"
   ```

### Tuning

| Env var | Default | Purpose |
|---|---|---|
| `XR_MAX_TURNS` | 15 | Agent turns. 6 for quick lookups, 25–30 for deep dives. |
| `XR_EFFORT` | grok default | `low` / `medium` / `high` / `xhigh` / `max`. |
| `XR_JSON` | off | `1` for grok's JSON output format. |
| `XR_SCRATCH` | `~/.cache/x-research/scratch` | Grok's working directory. |

## Findings: the gotchas we hit (so you don't have to)

This skill looks trivial — it's one shell script. The first version fork-bombed the machine. Everything below was learned the hard way while building it, and the wrapper encodes all of it.

### 1. grok CLI reads YOUR `~/.claude/skills` folder — including this skill

grok is Claude Code–compatible: it auto-loads user skills from `~/.claude/skills`, your `settings.json` permissions, and Claude-style config — regardless of working directory (`grok inspect` shows everything it picks up).

So the first time we ran the skill, grok's opening line was *"I'll use the x-research skill"* — it found **this skill's own SKILL.md**, ran the wrapper script, which launched more grok processes, which loaded the skill again... Within minutes there were ~10 grok processes running increasingly elaborate rewrites of the original question.

**Fix:** deny grok shell access (`--disallowed-tools Shell` — no shell means no skill execution) and block subagent fan-out (`--no-subagents`).

Note: do **not** add `Task` to `--disallowed-tools` — on grok 0.2.50 that breaks session creation entirely (`auto_background_on_timeout requires enabled_background to be true`). `--no-subagents` covers it.

### 2. grok's own docs list the wrong tool names

grok's bundled docs (`~/.grok/docs/user-guide/14-headless-mode.md`) say the shell tool is `run_terminal_cmd` and file editing is `search_replace`. Those names are stale — passing them to `--disallowed-tools` silently does nothing.

The actual tool IDs (as of grok CLI 0.2.x) are CamelCase:

```
Shell, Grep, Delete, WebSearch, WebFetch, TodoWrite, StrReplace, Write,
Read, Glob, Task, SwitchMode, AskQuestion, Await, CallMcpTool,
ListMcpResources, FetchMcpResource, GenerateImage, EditNotebook
```

Don't trust the docs — ask grok itself:

```bash
grok -p "List the exact names of every tool you currently have available, one per line. Do not use any tools." --max-turns 2
```

### 3. X search is server-side — don't name tools in your prompt

Grok's live X search doesn't show up as a local tool call at all; it happens inside the model, server-side. Two consequences:

- If your prompt says "use your X keyword search **tool**", the model goes hunting for a tool by that name, guesses nonexistent MCP tool IDs (`x__keyword_search`, `x-search__keyword_search`), fails, and burns every turn. **Describe the research outcome you want, not the mechanism.**
- When you block tools (`Shell`, etc.) without telling the model, it keeps retrying the blocked tool until `--max-turns` kills the session. **Tell it in the prompt that it has no shell/file/subagent tools** — then it searches directly and answers fine.

### 4. Misc quirks

- **`grok models` lies about auth.** It can report "You are not authenticated" while `grok -p` works perfectly on your subscription. The only real auth test is running a prompt.
- **Headless runs print nothing until the end.** A 2-minute silent run is normal. Budget 1–3 minutes per research call (5-minute timeouts recommended).
- **Run grok in a scratch directory** (`--cwd ~/.cache/...`), never in a real project — it's a coding agent and will treat your cwd as its workspace.
- **`--no-memory`** keeps research sessions from polluting grok's cross-session memory.
- **Date-anchor your prompts.** Tell grok today's absolute date and an explicit window ("since:2026-06-08"); "recent" drifts.

## How the agent uses it well

- **Parallel fan-out:** for broad research, Claude launches 2–4 background grok calls with different angles (sentiment / top voices / criticism / adjacent topics) and synthesizes the results.
- **Structured output:** ask for markdown tables (`@handle | URL | likes | followers`) when feeding results into further work.
- **Verification:** grok returns real x.com URLs — keep them in the output so humans can click through.

## Files

```
x-research/
├── SKILL.md              # what Claude reads: triggers, usage, prompt guidance, warnings
└── scripts/
    └── xsearch.sh        # the hardened grok wrapper
```

## License

MIT
