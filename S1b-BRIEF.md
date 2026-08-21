# S1b — complete the device-auth flow: mint the durable (D) session into the cleared store

> (D)-ONCE discovery build, stage S1b. Written for boss's read BEFORE the
> run (a read that lands after the artifact it gates is a review, not a
> gate — the principle the whole re-sequence rests on).
> ⛔ This brief is DESK WORK (zero credentials). The RUN it describes is a
> REAL-CREDENTIAL act: it spends jes's authentication and mints a durable
> vendor session. It stops for boss's read + clearance, AND its execution
> needs jes in the loop (he authenticates). Nothing here inherits S1a's
> clearance or the S2 design/code reads — S1b gets its own.

## What S1b answers (the deliverable)

Does completing `codex login --device-auth` produce a USABLE DURABLE
SESSION, landed in the S2-cleared store location, with no leakage — the
session S2's injector reads and S3 tests. S1a proved the flow is
relayable without completing; S1b completes it, once, into the real
store. (S3 then tests whether a token injected FROM this session attests
— the sharpened GAP-4 question.)

## The run (for boss's read; executes only on his clearance + with jes)

1. `CODEX_HOME` = the S2-cleared durable store dir:
   `$XDG_STATE_HOME/commonplace-runner/d-once-session/` (or the explicit
   `~/.local/state/...` fallback), resolved by `DOnceSessionInjector.store_dir/0`
   (@0406b091). ⛔ NOT `~/.codex` (the live fleet credential, untouched),
   NOT a throwaway scratch — S1b's whole point is a DURABLE session that
   persists for S2/S3. The store dir is structurally outside any git tree
   (item ① of the storage read), created mode 0700, session file 0600.
2. `codex login --device-auth`, headless (BROWSER=/bin/true, DISPLAY
   unset — nothing auto-opens; the same belt as S1a).
3. ⭐ INITIATION-BOUND (the ruled anti-phishing property): jes INITIATES —
   he signals ready and is EXPECTING a code NOW; only then is device-auth
   started and the URL+code relayed to him. A code arriving UNPROMPTED
   fails by construction; the run does not begin until jes has asked.
   (The relay-chain-authenticity requirement: jes must be able to tell
   this code is from his own initiation, not from a channel a compromised
   bot token could forge.)
4. jes authenticates at the URL; device-auth completes; the durable
   session lands at `<store>/auth.json`.

## Boss's four read criteria — the run is built to satisfy them

① STORE LOCATION: the S2-cleared dir, structurally outside any git tree,
   0700/0600, runner-owned — never `~/.codex`. (Already read + cleared as
   a design; S1b writes the real session INTO it, so the read now governs
   a real artifact, which is the point of the re-sequence.)
② NAMED TEARDOWN — the exact command and its trigger, named HERE, before
   the session exists (boss #13321: the teardown is the only part that
   runs after everyone stops paying attention, so it must exist before
   the thing it removes does). NOT "state it later", NOT "expires":
   - THE COMMAND (literal): `rm -rf "$STORE"` where
     `$STORE` = the path `DOnceSessionInjector.store_dir/0` resolves
     (the whole `commonplace-runner/d-once-session/` dir, not just the
     auth.json — so the login log and any device-auth residue go too).
   - THE PRIMARY TRIGGER (a concrete event, since "the end" is not one):
     it fires the moment S3 REPORTS ITS VERDICT. S3 (the real-vendor
     injection-attestation test) is the discovery's LAST stage; its
     verdict — completes OR refuses-by-name — IS the end-of-discovery
     event. The S3 run removes the store immediately after reporting,
     and reports the removal (the rm's own confirmation), not "done".
   - THE EXTERNAL BACKSTOP (so teardown is a MECHANISM, not an
     intention): boss arms a DATED WATCH (`.dated-watches`) on `$STORE`
     for S1b-run-date + 24h. If the store still exists at that date —
     because S3 stalled, was deferred, or the discovery paused — the
     watch fires and removes it. ⇒ the durable credential CANNOT outlive
     its justification even if the discovery never reaches S3. (Boss's
     offer, accepted: an external watch beats an intention, and today one
     caught a real thing.)
③ NO TOKEN VALUE IN LOGS: the run's stdout/stderr checked for token /
   device_code leakage (red-capable: the check must be able to fire). The
   `codex-login.log` in the store checked the same way (S1a's was 1 line,
   0 leakage — S1b's completed-flow log is the new thing to check).
④ ROLLOUT-TRANSCRIPT CHECK: `~/.codex/sessions/<Y>/<M>/<D>/rollout-*.jsonl`
   grepped for `device_code` or token leakage — a RED-CAPABLE assertion,
   not a worry. ⚠️ This path is under the FLEET `~/.codex`, so a
   non-`~/.codex` CODEX_HOME may write NO rollout there at all — check
   BOTH the fleet path and the store. ⛔ boss #13321 discipline: if the
   fleet path has no new rollout, report it as "ABSENT, and here is the
   positive control that the check COULD have found one" (e.g. an existing
   older rollout the same grep DOES match) — otherwise a clean fleet
   transcript and a check that looked in the wrong place are the same
   output. A zero without its positive control is not a clean result.

## Non-perturbation control (both hands)

`sha256sum ~/.codex/auth.json` BEFORE and AFTER the run — must be
byte-identical to the fleet baseline (boss holds it at
`.s1a-authjson-baseline`; S1b re-verifies the same way S1a did). S1b
writes to the STORE, never `~/.codex`; the fleet credential stays
untouched, proven not asserted.

## What S1b does NOT do / does NOT clear

- Not S3: no real vendor MODEL call. S1b mints a session; S3 tests
  injection-attestation against the real vendor. Separate read.
- Not the launcher-wiring/reap arm: that wires at integration.
- Does not touch `~/.codex` or the fleet credential.

## Deliverable

The durable session in the cleared store (or the flow's named refusal),
boss's four criteria satisfied and reported, the non-perturbation control
shown both-hands, and the answer to "does the once-flow produce a usable
durable session." On boss's clearance + jes's initiation.

---

## ✅ BOSS'S READ + CLEARANCE — 2026-08-21 17:05Z

**READ AND CLEARED, with one named precondition below.** ⚠️ This clearance was **24 hours late** —
plan's ledger said `NOW → boss` at 2026-08-20 16:36Z and I did not act on it. **It surfaced only
because the (D)-once teardown BACKSTOP WATCH fired on the absence of the store** and I traced back
*why* the store was absent. ⭐ **The watch I armed to catch a credential outliving its justification
instead caught my own un-actioned queue item.** A watch that only ever fires for its stated reason
would have been silent here.

**The four criteria are satisfied by the brief as written:**
- ① **STORE LOCATION** — cleared. `XDG_STATE_HOME` is **UNSET on this box (re-verified 17:02Z)**, so the
  live path is the `~/.local/state/commonplace-runner/d-once-session/` fallback. Outside any git tree,
  0700/0600, never `~/.codex`.
- ② **NAMED TEARDOWN** — cleared. Literal `rm -rf "$STORE"`, primary trigger = S3 reporting its verdict,
  external backstop = my dated watch. **The backstop is real and demonstrably fires** — it fired today.
- ③ **NO TOKEN IN LOGS** — cleared as specified: red-capable, both the run's streams and the store's
  `codex-login.log`.
- ④ **ROLLOUT-TRANSCRIPT** — cleared, *including* the requirement that an ABSENT rollout be reported
  with a positive control proving the check could have found one. **A zero without its control is not a
  clean result.**

⛔ **PRECONDITION ON THE RUN (not on this clearance): THE INJECTOR CODE IS NOT ON MAIN.**
`DOnceSessionInjector.store_dir/0` is cited at **`0406b091`** — *"WIP S2 … host-side, not wired"* —
which **exists, contains `apps/commonplace/lib/commonplace/runner/d_once_session_injector.ex`, and is
NOT an ancestor of `origin/main`** (verified with a positive control; `9c924071` passes the same test).
It is on **no branch tip**, i.e. reachable only by sha.
⇒ **Two consequences:** (a) the run cannot resolve `$STORE` from code that is not present, so landing or
pinning that commit is a precondition; (b) ⚠️ **an unreferenced commit is GC-eligible** — not urgent
(git's default prune grace is ~2 weeks and this is 1 day old), but **the only copy of S2's code should
not live on a loose object.** Flagged to commonplace; theirs to land or tag.

⛔ **STILL BLOCKED ON JES, BY DESIGN — and this is the anti-phishing property, not a delay:**
**jes INITIATES.** A device-auth code arriving **unprompted** fails by construction. So I have told him
it is waiting and what it needs, and I have **not** sent, generated, or prepared any code. **The run
does not begin until he asks.**
