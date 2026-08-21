# DEPLOY CEREMONY — 2026-08-21, window ≥20:00Z

**Status at filing (16:05Z): GO.** Both gates closed. This runbook exists because the ceremony is
**mine alone** — plan designated it and returned to its board, commonplace certified and stopped.
⛔ **If I drop it, nobody is holding it**, and a deploy deferred for a good reason is indistinguishable
hours later from a deploy quietly forgotten.

⚠️ **EVERY NUMBER BELOW IS A RECEIPT, NOT A FACT** (LESSONS 7x54). Each was true when read. **Re-derive
at ceremony time; do not act on this file's numbers.** That is what the commands are for.

---

## Span
**Deploy HEAD.** Span end at 16:07Z was **`b1d19ab8`** (moved from `798961ad` after certification).
⭐ **The two added commits are docs-only and I VERIFIED that rather than accepting it:** the range
`798961ad^..b1d19ab8` touches exactly **1 file**, `docs/plans/2026-08-21-doc-commit-backfill-brief.md`
(+105); filtering out `docs/`+`.md` leaves **nothing**. Control: the same filter on a known-code range
(`9c924071^..fb6282f8`) returns **11** `.ex` files, so the empty result is a real absence, not a broken
filter. ⇒ **Code content of the deploy span is identical to what commonplace certified.**
⚠️ **Re-check at ceremony time — HEAD may have moved again.** Same command, same control.

## Why 20:00Z
hermes trades until 20:00Z. The restart itself is cheap — **what is not cheap is troubleshooting a
restart next to live money** if the boot posture surprises me. The World-B run rides the same window
(stopped serve = quiescent store) and is memory-heavy on a host whose live-money BEAM has ~17 MB
swapped. **One window, three discharges, placed where the host can afford it.**

## Gates (both CLOSED at filing — RE-READ, do not trust)
| Gate | Status when read | How to re-check |
|---|---|---|
| [4] main-push CI green | `32499059147` success @16:00Z | `gh run view 32499059147 --json status,conclusion` |
| commonplace certifies span | full span certified @16:01Z (docs+[3]+[4]+[6]) | its message #14384 |

## ⛔ THE ONE CHECK THAT MUST BE RE-RUN AT CEREMONY TIME
commonplace's zero is **a reading of the mount AS MOUNTED at 15:5xZ — not a property of the code.**
A restart is exactly when [6]'s hard-fail becomes reachable if anything moved.

```
# 1. has the mount mapping changed since baseline?
sha256sum /home/jes/commonplace/workspace/.commonplace/git_bridges/git_bridges.json
#    baseline 16:05Z: 426cb75881cc508afe9366be191c53433096c878cd6a7340e967911db3e8425c
#    one mount uuid: 6fd72a7f-0f4c-4e31-8d2f-3b27312ecf4a  (matches mount_gate.exs line 14)
#    file mtime was Jul 16 — stable for a month
# ⛔ If the hash differs: read the file, update `mount =` in mount_gate.exs.
#    A SECOND mount needs a SECOND WALK — the probe walks one.

# 2. fresh store copy (~60s, itemised non-perturbation ledger built in)
#    commonplace deleted its 2.3G copy; ceremony takes its own — 4h fresher, which is better.
elixir backup.exs

# 3. the gate itself
elixir mount_gate.exs
```
**PASS = zero of the F2 116 under the mount.** ⭐ **A ZERO IS THE PERMISSIVE ANSWER — accept it only
because the probe carries its own control:** it re-derives the F2 population **in-probe** (not from a
stale constant), walks the mount as a **superset**, and **aborts if the walk finds <2 docs** (the
wrong-path-returns-zero case). At 15:5xZ it walked **5427 mount docs** and recomputed the population to
**exactly 116**. ⛔ **If the probe ever reports zero WITHOUT its control line, do not deploy on it.**
⇒ **NONZERO ⇒ [6] reverts from the deploy (plan-authored disposal), the other ~58 commits ship.**
⛔ I do **not** carve that branch on my own judgement — plan ruled it, which is what makes it legitimate.

## Riders (plan #14372 + commonplace #14384) — carry ALL into deploy notes
1. **Dispatcher now enumerates `:chit` per batch** — bounded range read, empty corpus.
2. ⚠️ **KNOWN LIMITATION:** 116 fork-lineage docs hard-fail the verified exporter. **None under the
   mount today — but ADDING A MOUNT, or moving a doc under one, re-opens this** until the backfill
   round lands (`@798961ad` brief, awaiting plan ratification). *A limitation with its trigger named.*
3. ⛔ **`COMMONPLACE_REFLOG_ON_BOOT` STAYS OFF** — jes's separate staging decision. `cp-serve-launch.sh`
   uses `env -i` and does not carry it, so it cannot arrive by inheritance. **VERIFY IN THE LAUNCHED
   ENVIRONMENT** (`tr '\0' '\n' < /proc/<newpid>/environ | grep -i reflog`) — **not by trusting the launcher.**
4. deploy-gate git-grep over the span · MUD re-verify · boot posture · `MemorySwapMax=0`.
5. **deploy-gap MEASURED post-restart.** Pre-reading @15:47Z: **30 newer beams** (`bin/cp-deploy-gap`).
   ⚠️ This is the **first live test of candidates 1/2/3** — never read against a fresh serve. **A
   surprising number here is more likely the instrument than the world.**

## World-B run (rides the same window)
⭐ **PRE-DECLARED EXPECTATION, falsifiable in BOTH directions — commonplace #14384:**
- `dangling_latest` **≥ 116** ⇒ the **KNOWN** population, **not an alarm** (116/116 verified to have
  zero own `{:doc_commit}` rows).
- ⛔ **BELOW 116 IS ITSELF A FINDING** — it means **my instrument is blind**, not the corpus clean.
- ⭐ **CHECK MEMBERSHIP, NOT JUST THE COUNT.** commonplace established the F2 116 by **byte-exact
  membership**; two populations of the same size are not thereby the same population. `membership_check.exs`.

Command shape: `mix commonplace.audit_commit_population --data-dir <PARENT> --unit <u> --out <path> --expected-oom-adj 900`
⚠️ `--data-dir` is the **PARENT** dir. Pointing it at `.../commits` creates an **empty store** that
reports `{:ready,1}` — a vacuous green I have shipped once already.

## After
Tell jes **what was deployed and what the post-restart deploy-gap read.** This one he hears about —
it is "what's getting done", not a near-miss. Include anything that went wrong.

## Probe provenance
Copied from commonplace's scratchpad @16:03Z **because a `/tmp` scratchpad is not where a thing I need
in four hours should live.** `SHA256SUMS` in this dir pins them. Authoritative source was
`/tmp/claude-1000/-home-jes-commonplace/b21bc109-.../scratchpad/chit-remeasure/`.

---

## PRE-FLIGHT @18:40Z (T-80min) — all four green, re-read not recalled

| check | result |
|---|---|
| span end still `b1d19ab8` | ✅ unchanged (fetched first) |
| mount mapping sha256 | ✅ `426cb758…` — **exact match** to the 16:05Z baseline, one uuid |
| gate 1: [4] main-push `32499059147` | ✅ `completed / success` |
| gate 2: commonplace span certification | ✅ held from 16:01Z |
| deploy-gap pre-reading | **30 newer beams** — unchanged since 15:47Z |

**Host, and it has IMPROVED since the window was chosen:**
```
serve  664985  RSS 250,232kB  VmSwap 17,188kB  adj 0
hermes 3985426 RSS 152,396kB  VmSwap 93,384kB  adj 200   ← was 109,756 @16:44Z, baseline 144,900
mcp    1328106 RSS  97,704kB  VmSwap      0kB  adj 0     ← ⚠️ NEW PID (was 1220084)
swap used 3,030 MB   ·   disk 83% used, 21G free
```
⭐ **hermes has paged back a further ~16 MB.** Memory pressure is easing, not building — the host is in
better shape for the World-B run than when I picked the window.

⚠️ **THE MCP ESCRIPT PID CHANGED** (1220084 → 1328106). Not a fault — it restarts on its own. **But it
matters for the MUD re-verify rider:** MUD `PlayerSession`s run on **the MCP escript, not the serve**, so
**a serve restart does NOT deploy new code to them.** ⇒ Verifying MUD *after* the restart proves the
serve is fine and says **nothing** about whether the sessions picked anything up. If the MUD rider is
meant to prove deployed behaviour rather than liveness, it needs the escript rebuilt + relaunched — a
separate act. **Named here so it is a decision, not a discovery at 20:15Z.**

⛔ **STILL TO DO AT THE WINDOW (deliberately not done early — these are readings of a live thing):**
fresh `backup.exs` store copy · `mount_gate.exs` (the zero that must carry its own control) · the stop ·
`env -i` launch · `/proc/<newpid>/environ` reflog check · post-restart deploy-gap · World-B · MUD.

## MUD RIDER — RULED BY COMMONPLACE @18:46Z: **LIVENESS-ONLY**, and say so in the notes

⭐ **commonplace corrected its OWN assumption to reach this**, which is why I trust the ruling: *"the
chit epic has no MUD surface"* was **true of the epic and FALSE of the span.** I verified rather than
relayed:
```
span 1f7a66e..b1d19ab8
  apps/commonplace/lib/commonplace/mud/ ....... 23 files  (verbs.ex +344, world/facade.ex +94, player_session.ex)
  apps/commonplace_mcp/ ....................... 26 files
  total files in span ......................... 1039
  control (nonexistent app path) ..............    0     ⇒ the filter discriminates
```
⚠️ Note 1039 changed **files** vs 30 newer **beams** — different quantities (source vs compiled modules
newer than serve start), not a contradiction.

**⇒ THE SPLIT: the serve restart deploys the span's MUD changes to the WEB surface (MudLive) ONLY.**
MCP-driven `PlayerSession`s reach them **only** via escript rebuild + relaunch.

**Why liveness-only is right tonight (commonplace's reasoning, which I am recording because it is the
justification for a deferral and deferrals need one):**
1. **Nothing the ceremony certifies has an escript surface** — chit deploy, World-B, §3 are all
   serve-side. The rider's job here is *"the live world still plays after the restart"* and it does that
   job fully.
2. **The escript's staleness is the STATUS QUO, not a state the restart creates** — those sessions have
   run pre-span code against post-span store data for up to two weeks (store format unchanged, chit keys
   additive). ⭐ **The restart adds no new hazard on that surface.**
3. **Rebuild+relaunch kills registered MCP sessions** (MCP registers at session start only — including
   commonplace's own). ⛔ Folding it in risks the ceremony's own tooling mid-window.
4. ⭐ **USEFUL DIFFERENTIAL PROPERTY: the escript is an UNCHANGED INSTRUMENT across the restart.** So if
   the liveness run shows a behaviour delta, **it attributes to the serve side by construction.**

**⛔ TWO THINGS OWED IN THE DEPLOY NOTES so this is a NAMED deferral, not a silent one:**
- **(a)** take a `bin/check-mcp-fresh` reading **during the window** (verified present, executable) and
  record the **stale-module count as a fact with its trigger**: *"escript rebuild+relaunch is a separate
  staged act, due at the next natural session boundary, at which point the span's MUD/MCP changes reach
  the escript surface."*
- **(b)** the rider line must read: **"MUD re-verify (liveness + web-surface only; escript surface
  deliberately deferred, see (a))."**

⭐ **The point of (a) and (b): a check whose scope is narrower than the claim it will be quoted for is
how a green gets laundered.** *"MUD re-verified"* in a deploy note would be read as *"MUD works on the
new code"* — which is false for the escript surface. **The note has to carry the scope or the scope is
lost the first time someone quotes it.**
