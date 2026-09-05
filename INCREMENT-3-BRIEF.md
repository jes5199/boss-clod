# BUILD-1 increment 3 — backfill the accepted-head index + retire SiblingMerger's scan

> Written for boss's read BEFORE the host-sensitive backfill runs (the
> gate-ahead-of-artifact order that made S2 work). The host-gated part is
> §3 (the live corpus backfill); §2 and §4 are pure code with no host
> risk. Nothing here runs a live backfill until boss clears §3.
>
> Prereq LANDED: increment 1 (accepted-head SET, `fad83125`) + 2a (durable
> index + head-update seam, `c70816d9`) + 2b (Hazard 3 invariant,
> `b5d6910d`). The index is maintained FORWARD; legacy docs are unindexed
> until this backfill.

## What increment 3 delivers

1. **Backfill** the accepted-head index for documents written before the
   2a seam existed (or otherwise unmaintained) — §3, HOST-GATED.
2. **SiblingMerger consumes the index** instead of computing
   `all_commit_ids_for_doc(doc) − reachable(:latest)` per call — §2.
3. **Retire SiblingMerger's hot-path scan** — §4, and see the scope
   finding below: this is NARROWER than "retire `all_commit_ids_for_doc`".

## ⭐ SCOPE FINDING (revises the Stage-B ruling's "retire the scan" wording)

The ruling said "`do_all_commit_ids_for_doc` retired or demoted to
backfill-only." Measured caller set on main (`grep all_commit_ids_for_doc`,
non-test, non-def):
- `sibling_merger.ex:119` — the pathological per-call-per-merge scan the
  ruling targets. ⇒ REMOVED here (consumes the head index).
- `sync/node_sync.ex:96,99` — the pull-federation differ ("what I possess"
  for catch-up sync). This LEGITIMATELY needs the FULL commit set, not the
  head frontier — you sync every missing commit, not just heads. ⇒ STAYS.
- `accepted_heads.ex:51` — `AcceptedHeads.of/2`, the scan-based oracle.
  0 lib callers (tests + the backfill's verify reference only). ⇒ STAYS as
  the reference oracle.
- `mixed_plane_history_fixture.ex:42` — a test fixture. ⇒ irrelevant.

⇒ **`all_commit_ids_for_doc` is NOT retired; SiblingMerger's DEPENDENCE on
it is.** The "scan class gone structurally" the ruling wants = the
O(all-commits)-per-merge-check on the hot path, replaced by an
O(head-set) point-read. The function remains for federation, which is a
per-sync operation with a genuine need for the full set. Flagging because
"retire the scan" read as "delete the function"; the accurate acceptance
is "SiblingMerger no longer scans."

## §2 — SiblingMerger consumes the index (no host risk, but a BEHAVIOR CHANGE — its own cycle)

⚠️ CORRECTION to an earlier framing of this as "pure additive": it is NOT
a drop-in. `maybe_merge_siblings` currently: `covered =
dag_reachable_from(:latest)`, `all = all_commit_ids_for_doc(doc)`,
`siblings = all − covered` — which is EVERY non-reachable commit (interior
+ tips). The index gives `heads − {:latest}` = the non-dominated TIPS only.
So consuming the index changes SiblingMerger from merging non-reachable
commits (interior-first possible, multi-pass) to merging the frontier TIP
(folds a whole sibling branch in one merge). That is the INTENDED "consume
heads" behavior (the ruling's words) and is arguably better, but it is a
behavior change to a sensitive, historied path (CX-4qn1 / CX-xxav ordering
/ CX-obfb code-doc skip), so it gets its own careful cycle:
- **Trust distinguisher (self-checking):** use the index only when its head
  set CONTAINS `:latest` (a maintained/backfilled row always does; a legacy
  un-backfilled doc's row is absent → empty → does NOT contain `:latest`).
  If `:latest ∈ heads`, `siblings = heads − {:latest}`; else fall back to
  the scan. So §2 is safe to land BEFORE §3 (legacy docs scan until
  backfilled), and the fallback is removed in §4 once §3 is corpus-`:ready`.
- **Tests:** the SiblingMerger suite (8 on main) must stay green (its
  single-sibling fixtures have tip == whole-branch, so unaffected); ADD a
  sibling-CHAIN case proving tip-based merge folds the branch in one pass
  and converges to the same final state; and confirm CX-obfb code-doc skip
  + CX-xxav ordering are preserved. Determinism: the chosen sibling among
  multiple heads must stay explicit (sorted), not hash-order.

## §3 — the backfill (HOST-GATED; boss's clearance required)

⭐ **RUN MODEL — RULED (b) (boss #13561): SEPARATE PROCESS against a STOPPED
serve.** Why not the others (boss measured): the live :5199 serve runs in a
**tmux-spawn scope, not a service unit**, so an in-serve runaway (a) or a
scope-MemoryMax (c) arms an OOM charge under the WHOLE scope (the 2026-08-18
precedent) and a systemd-run wrapper's MemoryMax can't bound work inside
another process (① present-but-irrelevant). (b) is the only model where
①/⑤ mean what they say and a kill can't reach the live serve — it's down.
- ⛔ **No read-only co-opener (my-lane answer to boss):** `CommitStore.init/1`
  takes a non-blocking EXCLUSIVE flock (LOCK_EX) on `commits.lock` (CX-2479);
  `Flock` supports `:shared` but init uses `:exclusive`, excluding all
  co-openers, and CubDB has no read-only-open. ⇒ (b) needs a FULL serve stop;
  downtime = backfill duration, not shortenable.
- **Clean shape:** the backfill launches its OWN `CommitStore` against the
  stopped serve's `data_dir` (sole opener, since the serve released the
  flock), under `systemd-run --unit=<name> -p MemoryMax=6G` — the standalone
  IS the bounded process. Reuses `CommitStore.init`'s flock/open/index
  machinery rather than re-implementing it; testable exactly like the store
  suite (`start_supervised({CommitStore, ...})`).
- **CEREMONY (boss #13570, boss owns the run-steps; ask hermes at run time,
  don't recite):** ① ask hermes for the CURRENT windows (never recite) → ②
  pre-warn hermes → ③ enumerate :5199 established connections + non-loopback
  peers WITH a host-wide control (go/no-go, not auto-block) → ④ stop serve
  (RSS ~0.4GB, small restart; standing routine per jes) → ⑤ launch the
  backfill CommitStore under `systemd-run --unit=<name> -p MemoryMax=6G`,
  VERIFY WHILE THE UNIT IS ACTIVE: `LoadState=loaded` AND
  `MemoryMax=6442450944` → ⑥ run to `:ready` → ⑦ restart the live serve AND
  verify it is listening again → ⑧ report the observed-max depth ⑦ produced.
  ⚠️ Step ⑦ (boss's) is the most-likely-skipped: **the run is done when the
  serve is back and answering, not when the backfill finishes** — a backfill
  that completes and leaves :5199 down is a worse outcome than one that never
  ran.
- ⛔ **①'s CHECK HAS A DEADLINE (paravel #13573 + boss #13577, both
  reproduced): verify WHILE THE UNIT IS ACTIVE — it cannot be retried.**
  systemd GCs the transient unit on exit, so a unit that SUCCEEDED is
  byte-identical to a name that NEVER EXISTED (`MemoryMax=infinity,
  LoadState=not-found, ActiveState=inactive` for both) — three states, one
  observable, no field combination recovers it after exit. ⇒ **CODE
  IMPLICATION (mine): the run CAPTURES the verified triple (MemoryMax +
  LoadState + ActiveState) INTO ITS OWN LOG at launch**, so the evidence
  outlives the unit — composing with ⑦'s observed-max as "what only the run
  could know". A post-hoc "did it run under the ceiling?" returns a confident
  FALSE NEGATIVE; the log is the only durable trail.
- ⚠️ **PUBLIC-SERVE VISIBILITY (plan #13562):** :5199 is `0.0.0.0` — (b)'s
  downtime is an EXTERNALLY-visible maintenance window, not an internal
  pause. Priority-affordable (§3 non-urgent; §2's fallback keeps SiblingMerger
  correct meanwhile), but before the stop CHECK external deps on :5199
  (federation, the (D) work) — boss/jes's ops judgment at run time.

Mirror the EXISTING `rebuild_doc_commit_index` machinery (it already
survived production): a chunked, resumable rebuild with a state key.
- **Keyspace/state:** `{:accepted_head_index, :state}` with
  `{:dirty,v,doc} | {:rebuilding,v,prior} | {:ready,v}`, mirroring
  `@doc_commit_index_*`. Chunk = `@doc_commit_index_backfill_chunk` (1000)
  as the starting bounded-working-set number.
- **Derive + VERIFY per doc:** for each doc, compute the accepted-head set
  (the `AcceptedHeads.of/2` definition) AND verify it is an antichain as
  it derives (the raised acceptance — this is the SOLE corpus-wide
  antichain guard until the World-B standing audit exists). Stamped /
  3-way-verified / denominators (the S5/tix backfill pattern).
- **F5 fixture:** 2.2% of docs carry `:latest` at a FOREIGN doc_uuid
  (measured in chit sizing). Build increment 3's adversarial fixture FROM
  that 2.2% — a doc that gets a derived head set and may never advance, so
  scope-to-advanced never re-checks it. Do NOT discover it mid-run.

### The SEVEN host-safety criteria (boss #13350/#13354/#13356/#13416/#13424) — satisfied by construction

1. **Enforced ceiling:** run under `systemd-run --user --unit=<name> -p
   MemoryMax=6G -p OOMScoreAdjust=900` (explicit `--unit` — see ⑤, it makes
   the kill path name-scoped).
   ⛔ **OOMScoreAdjust=900 IS REQUIRED, not optional (boss #13622, a real ①
   defect):** a bare `systemd-run --user` unit inherits systemd's
   `DefaultOOMScoreAdjust=200` and comes up at oom_score 800 — TIED with
   hermes's live-money BEAM (adj 200 / score 808), a 6G cap inside ~7G
   headroom. The 2026-07-30 kill-order fix raised AGENTS to 300–350 for
   exactly this, but a systemd-run unit is not an agent and lands back in
   the inversion. `-p OOMScoreAdjust=900` makes the backfill FIRST to die —
   correct, because chunked+resumable means its death costs a restart, not
   the data (the cap protects the corpus from us; the adj decides who loses
   when neither is at fault). VERIFY BY EFFECT: `/proc/<pid>/oom_score_adj`
   reads 900 and the cgroup `memory.max` reads 6442450944 — NOT systemctl's
   echo of the request (a user unit declaring OOMScoreAdjust=0 is on record
   starting at adj 100). ⇒ **①'s logged record is a QUAD: MemoryMax +
   LoadState + ActiveState + oom_score_adj.**
   ⚠️ The landed run-task (`commonplace.backfill_accepted_heads`) logs the
   TRIPLE, not yet the quad — boss covers oom_score_adj by-effect for
   tonight's run; a follow-up should have the task read
   `/proc/self/oom_score_adj` so its own log is the full quad.
   ⭐ **TWO WAYS THE 6G CEILING CAN BE A FALSE GREEN — check both by effect
   (paravel #13633, measured clear on this host):** (i) `systemctl show`
   echoes the REQUEST; the cgroup `memory.max` is the ENFORCEMENT — they
   diverge if the memory controller is NOT delegated to the user slice
   (systemd accepts `-p MemoryMax=6G`, echoes 6442450944, and NOTHING
   enforces it). Confirm `memory` is in the parent's `cgroup.subtree_control`.
   (ii) the EFFECTIVE ceiling is the MINIMUM down the ancestor chain
   (user.slice → user@1000 → app.slice), not the unit's own value — a finite
   lower ancestor cap would kill the run early and make ⑦'s observed-max
   measure the ANCESTOR, not the workload (a wrong number that looks like
   evidence). Confirm no finite ancestor cap below 6G. Both measured clear
   here (`memory pids` delegated; all ancestors `max`), so 6G is the real
   effective ceiling — but re-check on any other host (method, not literal).
   PROVENANCE (known-worst-so-far, per ⑦): 6G is the
   established Sol-round ceiling this host runs every dispatched batch job
   under, without incident, all session (see the tmux-scope-OOM ledger).
   §3 is a comparable BEAM batch job (chunked, mirroring
   rebuild_doc_commit_index), and no per-batch MemoryMax exists for the
   in-serve rebuild to inherit — so the host's batch ceiling is the honest
   first-run bound. It CAN fire: a runaway (a pathological per-doc ancestor
   walk, or a leak) exceeds 6G, while a bounded 1000-row-chunk pass stays
   well under. ⑦'s observed-max instrumentation reports the real peak so
   run 2 tightens 6G to evidence.
   ⚠️ **VERIFY BY THE DISCRIMINATING VALUE, not the field's presence
   (paravel #13502, MEASURED on this host):** `systemctl --user show <unit>
   -p MemoryMax` returns `MemoryMax=infinity` for an UNLIMITED unit and
   `MemoryMax=6442450944` for `-p MemoryMax=6G`. ⇒ "the unit shows
   MemoryMax" PASSES on a unit with no ceiling (a check that cannot fail —
   the exact state ① exists to rule out); and grepping `6G` FALSE-REDS a
   correct unit (the value is bytes). **Assert `MemoryMax=6442450944`
   EXACTLY; treat `infinity` (or any other value) as the flag not having
   taken.** ⛔ **ALSO assert `LoadState=loaded` (boss #13561):** `systemctl
   --user show <NONEXISTENT-UNIT> -p MemoryMax` returns `MemoryMax=infinity`
   with rc=0 — a unit-name TYPO produces a plausible reading, so the byte
   check alone has two causes for one observable (flag-not-taken vs
   wrong-unit-name). A nonexistent unit reports `LoadState=not-found`; a
   real one `loaded`. Assert BOTH `LoadState=loaded` AND the byte value.
   The two probe units (one with the flag, one without) are the
   ready-made positive/negative pair for "demonstrate it can fire", one
   `/bin/sleep` each — the gate-you've-never-seen-fail, shown red then
   green. (General form: before trusting a field, check it DIFFERS between
   the two states you are telling apart — same as GitHub `startedAt`.
   Field-discrimination is UPSTREAM of the gate rule, not a replacement:
   pick a discriminating observable AND watch the gate go red.)
   ⚠️ **The DURABLE instruction is the METHOD, not the literal bytes**
   (paravel #13511): `infinity`/`6442450944` are what this host's systemd
   showed, not a documented cross-version guarantee. Run BOTH probe arms
   and confirm they DIFFER; assert the flagged arm's value. If §3 ever runs
   on another host, re-run the pair (two `/bin/sleep`s). ⭐ And the named
   unit (⑤) is BOUND-SAFE not UNREACHED-SAFE (hermes): a structural
   property costing one flag, vs a remembered rule that is safe only until
   the once it is skipped.
2. **Bounded working set as a NUMBER:** the chunk (start 1000 rows) +
   ⑦ below.
3. **Resumability:** the `:dirty/:rebuilding/:ready` state machine — a kill
   leaves `:rebuilding`, resume continues from the persisted frontier.
4. **Host memory figure at launch**, and boss's floor (~7–8GB available →
   not unless ①+② make it safe). ⚠️ **RE-READ AT RUN TIME — it moves on its
   own (paravel #13633):** measured available ~7G (total 15, used 8) at/near
   the floor. A 6G cap in ~7G available IS safe-by-construction — ① caps the
   backfill at 6G (it cannot consume "all remaining headroom"), ② chunks it,
   and OOMScoreAdjust=900 makes it first-to-die under any pressure, with
   resume making that death a restart not data loss. But the margin is ~1G,
   so re-read `free -g` at launch (not inherited from an earlier snapshot)
   and abort if available has dropped materially below the run's needs.
   ⭐ **TWO MECHANISMS, TWO FAILURES (paravel #13653, why ①+OOMScoreAdjust
   compose):** scenario A — the backfill runs away → the cgroup `memory.max`
   fires FIRST and the cgroup OOM killer kills WITHIN the unit's cgroup;
   hermes is never a candidate (① is structural here, not a race). scenario
   B — global pressure from elsewhere while the backfill holds memory → the
   cgroup limit does NOT fire (backfill under its own cap), the GLOBAL OOM
   killer chooses, and OOMScoreAdjust=900 makes the backfill first-to-die
   (the adj is the protection here, and ONLY here). ⑤'s kill-by-unit covers
   the human-intervention case; ③ makes all three a restart, not the corpus.
   ⇒ the ~1G margin only raises scenario-B's PROBABILITY (more restarts), a
   nuisance not a hazard; the ceiling alone leaves B open, the score alone
   leaves A unbounded — the pair is why the OOMScoreAdjust catch was real.
5. **PID/UNIT-SCOPED KILLS ONLY** if shedding fires — NEVER argv patterns
   (a `phx.server`-style selector reaches hermes across cgroups). ⭐ Because
   §3 launches with explicit `--unit=<name>` (①), the kill path IS
   `systemctl --user stop <name>` — name-scoped, so the argv selector never
   has to exist and the 2026-08-10 `phx.server`→hermes class is
   STRUCTURALLY unavailable rather than merely forbidden (paravel #13502,
   worked example: it stopped both probe units by name).
6. **Miss the four weekday windows (UTC):** `13:40–13:50` /`14:40–14:50` /
   `15:05–15:10` (single-order, retry-safe) and `19:50–20:00` RotationCheck
   (TWO-legged, a kill between legs strands a fill — the HARD one). Boss
   tells hermes before it starts if it lands in a window.
7. **Ceiling from KNOWN-WORST-SO-FAR + INSTRUMENT observed max:** don't
   pre-measure max DAG depth (that IS the corpus walk). First-run ceiling =
   the depth `SiblingMerger.dag_reachable_from` already walks without
   incident; instrument the run to REPORT the observed maximum depth. Run 1
   = educated bound, run 2 = evidence. A ceiling that can't fire isn't one.

⚠️ **RUN-TIME ESCALATION (boss #13449): ⑤ and ⑥ are worth MORE than when
written.** hermes's unit is `Restart=on-failure`, so a SIGTERM'd BEAM exits
0 and systemd does NOT bring it back — an interruption that reaches hermes
is INDEFINITE downtime, not a 5-second gap, until jes rules on the unit.
⇒ an argv-pattern kill during load-shedding (⑤) or a kill between
RotationCheck's two legs (⑥, 19:50–20:00) is now a much larger blast, not
retry-next-tick. This does not change the criteria; it raises what
violating them costs — treat ⑤/⑥ as hard, not advisory.

⭐ **BUT the Restart ruling is NOT a gate on §3 (hermes #13468):** it
addresses the COST of an interruption, not its LIKELIHOOD — and ⑤/⑥
already handle the likelihood. The two are separable. ⇒ **SCHEDULE §3
OFF-HOURS and the cost is moot too.** So an off-hours §3, with boss's
clearance + the ceremony, does NOT wait on jes's ruling. (Run stays
owed-not-done regardless; timing is mine + boss's.)

⚠️ **THE RUN WINDOW, CORRECTED to hermes's actual rule (#13488, via boss
#13490 — my earlier "off-hours is the safe slot" OVER-CONSTRAINED it, the
over-broad-precaution shape):**
- **HARD (the only requirement): miss the four ~10-min weekday windows —
  13:40–13:50 · 14:40–14:50 · 15:05–15:10 · 19:50–20:00 UTC (19:50 the
  two-legged RotationCheck, the hard one).** §3 may run at ANY time that
  misses these ~35 minutes; 15:30Z on a Tuesday is fine (hermes's words).
- **SOFT (cheaper if free, NOT required): the weekend (Sun nothing, Sat only
  a 22:00 tracker) or weekdays ~00:30Z–09:00Z.** Take it if convenient; do
  not treat it as a gate. ⚠️ Within the overnight frame, **WheelReconcile
  23:40** is not free (sets `wheel_halted`; a kill across it hides state
  drift till the next run — Monday for a Fri-night kill: recoverable, not
  free) — so if running overnight, prefer after 00:05.
⇒ ⑥ = miss the four HARD windows. `now`≈20:2xZ already misses them, so the
run is timing-flexible, gated on the ceremony + boss's pre-warning, not on
reaching a narrow slot.

### Resume-verified correctness (③ × the antichain verify)

Until the World-B standing audit exists, this backfill is the sole
corpus-wide antichain guard, so a resumed-after-kill run must NOT read as
verified when half-done. Structural: a "verified" read requires `:ready`,
which only a COMPLETE pass sets; a kill leaves `:rebuilding`. Resumability
③ and the not-half-verified guarantee are the SAME mechanism.

## §4 — retire SiblingMerger's scan (pure code)

Once §2 lands and §3 backfill reaches `:ready` corpus-wide, remove
SiblingMerger's `all_commit_ids_for_doc` call and the scan-fallback guard.
`all_commit_ids_for_doc` itself stays (federation). Test: SiblingMerger
suite (8 on main) stays green consuming the index.

## What increment 3 does NOT do / stops for gates

- No live backfill until boss clears §3 (host-gated).
- The World-B full-population `:commit` standing audit is SEPARATE (tracked
  LATER-class, plan #13417) — not increment 3.
- §2 and §4 are pure code; §3 is the only host-sensitive stage.
