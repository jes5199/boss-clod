# Boss-Clod

Multi-agent orchestration hub. This project runs the "boss" Claude Code session that coordinates worker sessions via clod-squad and receives Telegram messages.

## Session Types

### bossclaude (this session)
- Runs from `/home/jes/boss-clod`
- Has **telegram** channel (incoming messages + reply tools) and **clod-squad** (inter-agent messaging)
- Launch: `bossclaude` (defined in `~/.bashrc`)

### workerclaude
- Runs from each worker's project directory (e.g. `/home/jes/wimble`, `/home/jes/dirigible`)
- Has **clod-squad** only (no telegram)
- Launch: `cd ~/projectname && workerclaude`

### Plain claude
- `claude` alias just adds `--dangerously-skip-permissions`
- No channels, no extra MCP servers

## Channel Architecture

Telegram and clod-squad channels each require **three pieces** to work:

1. `--channels plugin:<name>@<registry>` — loads the plugin
2. MCP server in `--mcp-config` — starts the server process, provides tools
3. `--dangerously-load-development-channels server:<name>` — enables push notifications

Missing any one of these breaks channel delivery.

## MCP Config Files

Each channel has a **static** config file:
- `~/.claude/channels/telegram/mcp-config.json` — telegram server (static, no dynamic vars)

Clod-squad configs are **per-project** (dynamic, written at launch):
- `~/.claude/channels/clod-squad/mcp-config-{projectname}.json`

Per-project files are needed because:
- `CLAUDE_PROJECT_DIR` must be set to the worker's cwd
- `--mcp-config` files do NOT interpolate `${VAR}` (unlike `.mcp.json` files)
- A shared file causes race conditions when multiple workers launch simultaneously

## Telegram Isolation

Only `bossclaude` loads telegram. This is critical because Telegram's Bot API allows only **one poller per bot token** — a second poller causes 409 Conflict errors. Workers never touch telegram.

## Restarting Workers

Workers run in tmux panes. To restart all:
1. Exit each pane's Claude session
2. `source ~/.bashrc` (if bashrc was modified)
3. Run `workerclaude` in each pane

The `--dangerously-load-development-channels` flag prompts for confirmation (Enter) on each launch. This cannot be suppressed.

## Current Workers

| Name | Directory | Role |
|------|-----------|------|
| boss-clod | ~/boss-clod | Orchestrator, telegram bridge |
| wimble | ~/wimble | Rust ephemeris API (astrological events) |
| dirigible | ~/dirigible | Rails app (astrolab.ist domains) |
| commonplace | ~/commonplace | Elixir CRDT document store |
| commonplace-plan | ~/commonplace-plan | Architecture docs for commonplace |
| awakening | ~/awakening | LaTeX novel ("The Big Stupid at Awakening Peak") |
| claude-chat | ~/claude-chat | IRC relay for #loom |
| tarot | ~/tarot | LaTeX tarot deck (Star Taker Tarot) |
| hermes | ~/hermes | Elixir options trading automation (E*TRADE) |

## Startup Loops

On session start, set up these recurring jobs:

1. **Worker health check** — every 1 hour: Check all worker tmux panes for crashes (bash instead of claude), stuck generations (30+ min), and queued messages needing Enter. Fix any issues found and report to telegram.
   ```
   /loop 1h check all worker agents: list_peers for online/offline, check each tmux pane for bash instead of claude (restart with workerclaude), check for stuck generations over 30 min (cancel with Ctrl-C), check for "Press up to edit queued messages" (send Enter). Report any fixes to telegram.
   ```

2. **Usage report** — every 3 hours: Run `/usage-report` to send quota burn rate comparison to telegram.
   ```
   /loop 3h /usage-report
   ```

## Key Files

- `~/.bashrc` — `bossclaude`, `workerclaude` function definitions
- `~/.claude/channels/telegram/.env` — Telegram bot token
- `~/.claude/channels/telegram/access.json` — Telegram allowlist
- `~/.claude/channels/clod-squad/queue.db` — clod-squad message queue (SQLite)
- `~/boss-clod/clod-squad/` — clod-squad MCP server source
