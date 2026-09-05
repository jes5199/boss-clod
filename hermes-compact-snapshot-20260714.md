# Hermes compact snapshot — held by boss 2026-07-14 ~13:55 UTC (msg #8183)
Insurance copy in case boss context summarizes before hermes confirms healthy post-compact. Hermes re-primes from its own bd + journal; this is a backup.

## LIVE BOOK
- Harvester cycle #16 OPEN: QQQ short put spread, entry filled $0.12 ×2ct Mon 7/13 (first fully-automated dual-slot entry). 75%-PT GTC order 482861387 resting @ $0.03. Expiry Fri 7/17.
- 3 QQQM shares core ($896, buy-and-hold, never sold to fund entries).
- Account ~$2,490 equity / ~$1,040 option BP free with #16 open.

## METALS (3-pool LIVE)
- GDX/GLD $419, GDXJ/GLD $380, GDX/GDXJ $350, cap=1.
- First multi-pair eval verified clean today (dfb70). z now: −1.38 / −1.34 / +0.89.
- Fire at |z|>2 → immediate boss ping + manual reconciliation per first-5 runbook.

## AUTO-SCALER
- DORMANT, dry-run active, awaiting jes flip-live (r9qi OPEN as reminder).
- First AUTO dry-run Wed 7/15 15:00 UTC — verify it runs + expect SKIP-below-increment.
- Two-key: alloc_maintainer_enabled + alloc_maintainer_dry_run.

## RECENT MERGES ALL ACTIVE (main @ acd3520)
k3ci dual-slot harvester crons (13:40/14:40), yc4z metals morning slots (13:35/14:35 exit + 13:45/14:45 entry), t3oh5 cache-slack fix, dfb70 multi-pair, capbounce gated OFF (capbounce_shares_enabled absent), winter unique-period fix, 6 codex merges.

## RESEARCH STATE
- Shortlist COMPLETE (1 activation + 5 pre-registered kills).
- Copper convergence CLOSED (DROP 0/3, pure-CPER leg worse than DBB).
- Divergent sweep DELIVERED (doc acd3520: OpEx-gamma overlay, COR-richness sizing, month-end rebalancing drift, gold-3 exit cost-check + anti-list) — AWAITING jes greenlight (relayed tg#6689).
- Revisit triggers armed: silver-pool-membership after first clean gold cycle; copper-satellite now equity-only (~$4k equity).

## OPS
- Probe pattern: source .env, unset ELIXIR_ERL_OPTIONS, elixir --name probe@127.0.0.1 --cookie $HERMES_COOKIE, :rpc.call to hermes@127.0.0.1 (Decimal via RPC).
- Restarts only while FLAT; hot-reload + commit source for module fixes.
- Subagent delegation: Sonnet builds, Fable review; worktree isolation; never ScheduleWakeup in subagents; ~180k caps.
- Day-watch: hourly ticks + EOD window 21:30-22:15 (DailyPostmortem/IdleCashMonitor/discarded + #16 PT + boss EOD note + journal + park; boss nudges 12:45).
- Beads: bd from ~/hermes only.
- After compact: bd prime, re-establish day-watch chain, confirm to boss.
