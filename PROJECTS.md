# Project Inventory

All projects on this box, what they do, and how they relate.

## Active Workers (tmux sessions)

| Window | Project | Lang | Description |
|--------|---------|------|-------------|
| 0 | weechat | — | IRC client for #loom |
| 1 | **boss-clod** | — | Multi-agent orchestrator, telegram bridge, quota management |
| 2 | **claude-chat** | Python | IRC relay for Claude Code sessions on #loom |
| 3 | **commonplace** | Elixir | CRDT document store (Yjs-compatible, tree-structured, branching, merging, filesystem sync) |
| 4 | **commonplace-plan** | — | Architecture docs and planning workspace for commonplace |
| 5 | **hermes** | Elixir | Automated trading system — backtesting framework, regime scanner, paper trading, 100+ strategies |
| 6 | **dirigible** | Rails | Multi-domain Rails app (astrolab.ist, planets.at backend). Daily astro-weather, bound ingresses |
| 7 | **wimble** | Rust | GraphQL API for astrology events. Ephemeris calculations, planetary positions |
| 8 | **awakening** | LaTeX | Novel: "The Big Stupid at Awakening Peak" |
| 9 | **tarot** | LaTeX | Star Taker Tarot deck |
| 10 | **substacker** | Elixir | Newsletter downloader — Substack RSS + NewsletterHunt scraper (Money Stuff, Doomberg, Construction Physics) |
| 11 | **paravel** | JS/TS (Astro) | SPA frontend for planets.at. Deploys to Cloudflare Pages |

## Astrology Pipeline

Data flows through these projects in order:

```
wimble (Rust) → generates raw ephemeris data (planetary positions, aspects, ingresses)
    ↓
starloom26 (Python) → transforms wimble JSON into JSONL event files
    ↓
dirigible (Rails) → imports CSVs into database, serves daily astro-weather
    ↓
paravel (Astro) → frontend SPA on planets.at, proxies /daily to dirigible
```

Supporting:
- **distaff** (Python) — CLI for creating/querying .weft ephemeris files from NASA JPL Horizons data
- **weft_ios** (Swift) — iOS weft file reader
- **chebyshev** — weft Chebyshev polynomial files (data format)

## Trading System (Hermes)

```
hermes (Elixir/Phoenix)
├── Backtesting framework (100+ strategies, 1400+ tests)
├── 8 data sources: Yahoo, FRED, Theta Data, SEC EDGAR, Open-Meteo, NASA POWER, Tiingo, Finnhub
├── Regime scanner (9 tickers, daily classification)
├── Paper portfolio ($2,500 virtual, micro futures MES)
├── Tastytrade broker integration (OAuth2, futures orders)
├── 7 Oban cron jobs (trading lifecycle)
└── 7 Claude /loop crons (brainstorm, backtest, data sources, validation, scoreboard, code review, bug bash)
```

## Document System (Commonplace)

```
commonplace (Elixir) — CRDT document store, main BEAM node
commonplace-plan — architecture docs, spec evaluation
commonplace-rs (Rust) — alternative implementation (experimental)
commonplaced-2025 (JS) — earlier version
```

## Newsletter Pipeline (Substacker)

```
substacker (Elixir)
├── Substack RSS (free content, cookie auth for paid)
├── NewsletterHunt scraper (Money Stuff archive — 1,686 articles)
├── Sources: Construction Physics, Doomberg, The Diff, Money Stuff
└── 6-hour sync cron
```

## Infrastructure / Tools

| Project | Lang | Description |
|---------|------|-------------|
| boss-clod/clod-squad | JS/TS (Bun) | Inter-agent messaging MCP server (SQLite queue) |
| claude-chat/irc-channel | JS/TS (Bun) | IRC channel plugin for Claude Code sessions |
| friendly-claude-message-alerts | — | Legacy watchfile-based session nudging (replaced by IRC channel) |
| file-tmux-file | Python | Tmux monitoring/control bridge |
| text-to-telegram | Python | Telegram bot ↔ text file bridge |
| beads | — | Git-backed issue tracker for AI workflows (`bd` CLI) |
| chief-wiggum | — | Claude Code plugin for iterative code review |
| codex-review | — | Claude Code plugin for Codex-powered code review |
| claude-subconscious | JS/TS | Letta agent providing async guidance to Claude sessions |

## Other Projects

| Project | Lang | Description |
|---------|------|-------------|
| bartleby | Python | Autonomous Claude agent with prompt queue |
| cave-diver | Python | Context-aware Claude agent harness |
| gastown | — | Earlier multi-agent orchestration system |
| substrate | JS/TS | Coherence management system (experimental) |
| turingtest | JS/TS | Quiz site: human or AI? |
| worm.bas | JS/TS | Browser port of WORM.BAS (Zenith Z-100 BASIC game) |
| beepboopyoucad | Python | "Eat Poop You Cat" game with AI players |
| beepboopyoucad.com | Rails | Web frontend for beepboopyoucad |
| grimoire | — | Text/card collection |
| yelixer | Elixir | (No description — experimental?) |

## GitHub Repos

All under github.com/jes5199/. Key ones:
- jes5199/wimble — public, Rust ephemeris API
- jes5199/hermes — private, trading system
- jes5199/paravel — private, planets.at frontend
- jes5199/substacker — private, newsletter downloader
- jes5199/distaff — public, weft CLI tool
- jes5199/starloom26 — private, event transforms
- jes5199/starloom — public, earlier version
