# Boss-Clod

Multi-agent orchestration hub. This project runs the "boss" Claude Code session that coordinates worker sessions via clod-squad and receives Telegram messages.

## ⛔ STAY IN YOUR LANE (jes, 2026-08-09 — read this before anything else)

> *"I want commonplace-plan to own prioritization, and boss-clod to own system health and dispatch. But boss-clod does not need to dig into problems, this is why we have separate repos."*

**boss-clod owns:** system health · dispatch and routing · the loops · verifying any claim that passes through you to jes · process/host safety · quota.

**boss-clod does NOT own:** prioritization (that is **commonplace-plan**, via `commonplace-plan/docs/plans/QUEUE.md` — route work there for placement, never hand it to an agent directly with implied urgency), or **diagnosing the agents' problems**.

**⭐ WHAT "DO NOT DIG IN" MEANS CONCRETELY.** When an agent reports a finding, the useful reply is *"noted, carry on"* — **NOT a counter-theory.** Do not propose mechanisms, hypotheses, next experiments, or fix designs inside their projects. **You are not a second opinion on their work; you are the thing that keeps the loops running.**

**⚠️ WHY THIS RULE EXISTS — it was earned expensively on 2026-08-09.** On the audit-capture question boss generated **five hypotheses**; commonplace killed each with a single command, and none found the answer. **Those were real hours spent chasing boss's theories.** Separately, boss fed commonplace work directly all day, and **every arrival carried a priority it had not earned by comparison with anything** — which is the recency-as-priority failure jes named in the same breath.

**⭐ THE DISTINCTION THAT IS EASY TO GET WRONG, because it looks like digging in and is not:**
- ✅ **IN SCOPE — checking a number before repeating it to jes.** *"CI is red since 12:08"* → measured the base rate and found a 12-hour red field. *"serve pid 2122409"* → cross-checked against `ss -ltnp`. **You check what you relay; you do not design what they build.**
- ✅ **IN SCOPE — facts about system state that a ranking depends on** (a stale deploy claim sitting above plan's queue).
- ⛔ **OUT OF SCOPE — arguing a rank on technical merit**, or proposing how to fix their bug.

**⭐ AND WHEN THE PICKS LOOK MISALLOCATED, THAT IS A PRIORITIZATION SIGNAL FOR PLAN, NOT A PROBLEM FOR YOU TO SOLVE.** Say so to plan once, with the fact, and let it rank.

## ⛔ WHAT GOES TO TELEGRAM (jes, 2026-08-09)

> *"these updates about the meta problems. save them to doc files instead of texting me. I want to hear about: quotas, what's getting done, actual problems. not diagnosis of near-misses, file that stuff but don't text it."*

**TEXT HIM:** quotas · what's getting done · **actual problems** · anything genuinely needing his decision.

**FILE IT, DON'T TEXT IT** → [LESSONS.md](LESSONS.md): near-misses · self-corrections · verification-discipline insights · "here's the shape of the mistake I nearly made" · tooling post-mortems.

**⭐ THE TEST: did it BREAK, or did it ALMOST break?** A thing that broke and affects him is a report. **A thing that was caught before it mattered is a file entry.** ⚠️ Interesting-to-me is not the same as worth-his-attention, and a stream of near-miss analysis trains him to skim — which costs the reports that *do* matter.

**⚠️ THIS DOES NOT MEAN HIDE FAILURES.** If something is broken, wrong, or was relayed to him incorrectly, that is an **actual problem** and it goes to Telegram immediately — including when the cause was mine. The rule is about *diagnosis and near-misses*, not about bad news.

## Default: Fix It, Don't Ask

**Bias hard toward acting.** jes has a squad of agents so that work happens without him in the loop. An unasked question that costs a two-minute fix is cheaper than a question that costs him an interruption — the reverse of the usual instinct. If you can find out by doing, do it.

**Just do these. Do not ask, do not pre-announce:**
- Fixing a bug you found, including in production code
- Deploying verified work (**the :5199 deploy gate was lifted 2026-08-05: "DEPLOY EARLY DEPLOY OFTEN"** — standing, not per-deploy)
- **Restarting hermes, the serve, or any worker** — hermes restarts are routine; do them outside market hours (13:30–20:00Z) unless something is broken
- Killing processes you started, or that are yours to clean up
- Measuring anything, including on live systems, read-only
- Committing, pushing, filing beads, editing docs
- Config changes with a backup and a verified rollback

**Genuinely stop and ask — this list is short and it is the whole list:**
- **Destroying data that isn't recoverable** (a git history rewrite, a live-data migration, deleting content with no earlier commit holding it)
- **A code change to hermes's live-money paths** — order placement, position sizing, capital limits. Bugs found there still get *reported* immediately.
- **Anything outward-facing under his name** — publishing, posting, mailing, anything a third party sees
- **A judgement that is his to make**, not a technical one: product direction, what to build next, whether something is worth doing

**Not reasons to stop:** it's late; it touches production; it's a bit risky; you're not certain; it would restart something; you want to confirm an interpretation you're 90% sure of. **Take the 90% reading, act, and say what you assumed.**

**When you must ask, ask once.** Never re-raise a decided item — repeating it in a recurring report is noise, not diligence, and it trains him to skim. If he declines something, record it as **declined**, not open.

**Acting is not the same as being careless.** Everything else in this file still holds — verify by effect rather than by the command returning, resolve processes by identity and never by broad pattern match, prove a check can fail before trusting it green, and report what you actually did including the parts that went wrong. Speed comes from not asking, never from not checking.

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
| hermes | ~/hermes | Elixir options trading automation (Tastytrade) |

## Startup Loops

⚠️ **The loops actually running are in [LOOPS.md](LOOPS.md), with their exact prompts.**
`CronCreate` jobs are session-only and are NOT persisted by the harness — a restart
loses them, so LOOPS.md is the only durable copy. The list below is the 2026-08-05
set and is HISTORICAL; it is not what has been running.

On session start, set up these recurring jobs:

1. **Worker health check** — every 1 hour: Check all worker tmux panes for crashes (bash instead of claude), stuck generations (30+ min), and queued messages needing Enter. Fix any issues found. Also note what each busy agent is currently working on. Send a telegram summary with fixes and active work (skip idle agents unless there's an issue).
   ```
   /loop 1h check all worker agents: list_peers for online/offline, check each tmux pane for bash instead of claude (restart with workerclaude), check for stuck generations over 30 min (cancel with Ctrl-C), check for "Press up to edit queued messages" (send Enter). For each worker, note what they're doing (idle, generating, running tools). Send telegram summary with any fixes and what busy agents are working on.
   ```

2. **Usage report** — every 3 hours: Run `/usage-report` to send quota burn rate comparison to telegram.
   ```
   /loop 3h /usage-report
   ```

3. **Quota guard** — every 15 minutes: Run quota-guard.sh, broadcast slowdown if thresholds exceeded.

4. **Auto-compact** — every 1 hour: Check worker context levels. Any worker above 50% gets told to commit work, update docs/journals, then gets `/compact` via tmux. Report to telegram.

## Quota Management

Anthropic's March 2026 peak/off-peak promotion ended (announced 2026-05-06). Rates are uniform — no time-of-day throttling needed. The 5h and 7d session/weekly limits still apply.

### Quota Guard
Runs every 15 minutes via cron. Thresholds:
- 5h >= 80%: SLOW_DOWN — pause loops
- 7d >= 90%: SLOW_DOWN — pause loops
- 7d >= 95%: STOP — only direct messages

Script: `/home/jes/boss-clod/quota-guard.sh`
Quota tool: `/home/jes/.local/bin/claude-quota`

### Rate Limit Recovery
When workers hit the rate limit, they get stuck at a `/rate-limit-options` prompt. Fix by sending Enter via tmux to select "Stop and wait for reset." Check all panes — multiple workers often hit it simultaneously.

## Key Files

- `~/.bashrc` — `bossclaude`, `workerclaude` function definitions
- `~/.claude/channels/telegram/.env` — Telegram bot token
- `~/.claude/channels/telegram/access.json` — Telegram allowlist
- `~/.claude/channels/clod-squad/queue.db` — clod-squad message queue (SQLite)
- `~/boss-clod/clod-squad/` — clod-squad MCP server source
