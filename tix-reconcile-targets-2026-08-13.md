# Reconciliation targets, exported from tix 2026-08-13T15:03:33.100679Z

## CX-vvbh  [open]  p1  type=bug
created=2026-08-10T08:29:58.737763Z  updated=2026-08-10T08:29:58.737763Z  claimed_by=nil
TITLE: with_local_node_trust/1 drops the node's OWN self-trust SILENTLY when its public-key artifact is unreadable — the comment says "visible, not silent" and nothing logs

FOUND 2026-08-10 by commonplace, while running plan's row-3= discriminator. ⭐
Found via a test that had been dismissed as "flaky" all night and is
DETERMINISTIC (see CX-<sibling>, filed alongside).

THE DEFECT

`Commonplace.Trust.config/0` ends with `with_local_node_trust(base)`. That
function folds the node's OWN identity into `trusted_identities`, which is what
lets a strict workspace keep accepting its own system-minted commits with zero
pinning:

    defp with_local_node_trust(cfg) do
      with {:ok, identity} <- Commonplace.Crypto.NodeIdentity.identity(),
           {:ok, [_ | _] = public_keys} <- Commonplace.Crypto.NodeIdentity.public_keys() do
        ...fold identity => keys into cfg.trusted_identities...
      else
        _ -> cfg          # ⛔ SILENT
      end
    end

⛔ **The `else` clause returns the config unchanged and LOGS NOTHING.**

⚠️ AND THE FUNCTION'S OWN COMMENT CLAIMS OTHERWISE, which is the tell that a
signal was INTENDED and never written:

    "Best-effort: if the node key can't be sourced, the set is unchanged
     (the node's commits will then fail strict checks — VISIBLE, NOT SILENT)."

⇒ It is silent. Nothing emits. The comment asserts a property the code does not
have, so a reader auditing this path inherits the belief that the degraded case
announces itself.

WHY IT MATTERS IN PRODUCTION, not just in tests

Under **strict** posture (`accept_unsigned: false`), a node whose public-key
artifact is missing, empty or unreadable will **silently stop trusting its own
commits.** Every self-signed write then fails the trust gate, and the resulting
`false` is INDISTINGUISHABLE FROM A POLICY DECISION — the operator sees
denials, not a missing key.

⚠️ **This became reachable when `a4e708d` made `public_keys/0` ARTIFACT-ONLY.**
Before that the key could be sourced from the private-key file; now `:absent`
(no artifact) or `{:error, _}` (corrupt artifact) both fall into the silent
else. ⇒ CX-qvrz added the boot publish precisely because the artifact can be
absent — so the window is real, and this is what happens inside it.

⭐ SAME SHAPE AS CX-1jh2, SIX HOURS LATER, IN THE SAME SUBSYSTEM: a producer
built to distinguish outcomes (`{:ok, keys}` / `{:ok, []}` / `:absent` /
`{:error, _}`) feeding a consumer that collapses them all into one silent
degrade. CX-1jh2 fixed two consumers; this is a third.

THE FIX

- ⛔ **Do NOT make it fail closed by default** without deciding deliberately —
  that is a posture change, not a logging fix, and it would turn a missing
  artifact into a hard outage. **Decide, then implement to the decision.**
- ⭐ **At minimum: LOG, at error, with the reason distinguished.** `:absent`
  (no artifact — plausibly a fresh node) and `{:error, reason}` (present but
  unreadable — something is wrong) are different events and must not share one
  silent path.
- ⭐ Preserve `{:ok, []}` as its own case: an artifact that declares ZERO keys
  is a statement, not an absence.

ACCEPTANCE

1. ⭐ **RED FIRST:** a strict config plus an unreadable/absent artifact today —
   show self-trust silently missing with NOTHING emitted. Paste it, and prove
   the precondition (artifact state) or the red proves nothing.
2. After: the degraded case is loud, and the emitted event NAMES which of
   `:absent` / `{:error, reason}` / `{:ok, []}` occurred.
3. ⭐ **CONTROL:** the healthy path still folds node trust and stays QUIET — a
   fix that logs on every successful boot is a new noise source.
4. ⛔ Update the comment to say what the code does. **The stale comment is part
   of the defect**, not documentation of it.

SUITES BY BLAST RADIUS — `Trust.config/0` is read by anything that verifies a
signature. ⚠️ Name `apps/commonplace/test` as the WHOLE APP (~3278 tests); a
count in the hundreds means a subtree was run and the run is void.
⚠️ Main's failure SET currently differs run to run, so compare SETS at a
matched seed, not green/red.

RELATED: CX-1jh2 (same collapse, two other consumers), CX-qvrz (boot publish —
why the artifact can be absent), a4e708d (made the path reachable).

---

## CX-q9sa  [open]  p1  type=bug
created=2026-08-09T16:53:50.990389Z  updated=2026-08-09T16:53:50.990389Z  claimed_by=nil
TITLE: Test env runs a SINGLETON CommitStore whose data_dir is captured at boot — any test deleting that directory kills it, and background auto_compact means there need be no next caller

## The defect

`config/test.exs` starts the production-named `Commonplace.Store.CommitStore`
via `Application.start`. 176 test files call it. It is a singleton with
process-wide, mutable, shared state, and:

1. `application.ex:64` — `data_dir = Application.get_env(:commonplace, :data_dir, "data")`
   is read **ONCE AT BOOT** and never re-read.
2. `commit_store.ex:1602` and `:1643` open CubDB with **`auto_compact: true`**.
3. 150 test files call `Application.put_env(:commonplace, :data_dir, …)`,
   swapping the env, doing work, deleting a derived path, and restoring.

⇒ A test that deletes a path which is (or contains) the directory the singleton
captured at boot removes it **out from under a live store** — while correctly
believing it only touched its own.

## The CI signature

    GenServer.call(Commonplace.Store.CommitStore, {:create_commit, ...}) EXITs
    ** (MatchError) no match of right hand side value: {:error, :enoent}
        (cubdb 2.0.2) lib/cubdb.ex:1499: CubDB.trigger_compaction/1

## ⭐ It is NOT a race, and that matters for the fix

Measured: of the 150 files that mutate `:data_dir`, **ZERO are `async: true`**
(138 explicit `async: false`, 12 unspecified — ExUnit's default is false). No
two ever run simultaneously.

⇒ This is SEQUENTIAL state damage. The seed decides the ORDER, which decides
whether the deletion lands before or after something touches the store — which
is why it looks seed-dependent with no per-test bug and no concurrency.

⇒ And because `auto_compact: true`, the actor that trips can be **the store's
own background compaction timer**, with no next test call at all. The failure
lands on its own schedule, arbitrarily far from the cause.

## ⛔ Acceptance

1. ⛔ **DO NOT VERIFY BY GREEN RUNS.** 8 of 28 post-fix CI runs were already
   green by luck; a green umbrella afterwards is indistinguishable from a lucky
   interleaving. **Verify STRUCTURALLY.**
2. **Assert AT THE MOMENT OF DELETION, not at the moment of failure.** A
   tripwire that waits to be noticed inherits exactly the luck the green runs
   had — background compaction may fire or may not, and the interval decides.
3. ⭐ **POSITIVE CONTROL ON THE GUARD:** point one test's `rm_rf` at the
   captured dir and it MUST fail. Without that you have an assertion that has
   never been exercised.
4. ⛔ **Do NOT take the per-site path.** Fixing 517 teardowns individually means
   150+ edits that each look like they worked. **The singleton's existence in
   test env is the defect, not the teardowns.**

## Denominators (named, not reconciled away)

`File.rm_rf` — 407 in `apps/commonplace/test`, 517 in `apps/*/test`; the 110
difference is the other five apps. Both correct, different scopes.

---

## CX-1jh2  [open]  p2  type=bug
created=2026-08-09T19:48:25.319669Z  updated=2026-08-09T19:48:25.319669Z  claimed_by=nil
TITLE: public_keys/0 returns three distinct outcomes and BOTH consumers collapse them to [] — a corrupt artifact silently shrinks the anchor set

## What

`a4e708d` deliberately made `NodeIdentity.public_keys/0` return three
distinguishable outcomes, and documented why:

    {:ok, keys}   the artifact says these keys
    {:ok, []}     the artifact is present and declares ZERO keys
    :absent       there is no artifact

⇒ **Both consumers throw the distinction away.** Byte-identical in each:

    apps/commonplace/lib/commonplace/trust.ex:816          (Trust.anchor_keys/1)
    apps/commonplace/lib/commonplace/mud/verbs.ex:582      (MUD.Verbs.local_anchor_keys/0)

    case NodeIdentity.public_keys() do
      {:ok, keys}  -> keys
      :absent      -> []
      {:error, _}  -> []      # <-- collapses a READ FAILURE into "no keys"
    end

## Why it matters — this is the silent-empty class on a trust surface

`:absent` → **no artifact** → falling back to configured anchors is correct and
intended.

⛔ `{:error, :corrupt_node_public_keys}` → **the artifact EXISTS and could not be
read.** Treating that as `[]` means the node's own key silently drops out of the
anchor set and verification continues against a smaller trust set. **Nothing
logs, nothing refuses, and the resulting `false` looks exactly like a policy
decision.**

⭐ The producer was built to make this visible. The consumers make it invisible
again, which is worse than never having distinguished it — the distinction now
exists and reads as if it were being used.

## ⚠️ Scope note — this is a CONSUMER defect, not a regression in a4e708d

a4e708d DOES cover both sites (this was checked in answer to commonplace-plan's
"does it cover SITE 2" — it does, and the two copies are consistent with each
other). The producer-side requirement was met. **The requirement was never
stated for the consumer side, and neither consumer was asked to honour it.**

## Acceptance

1. A **corrupt/unreadable** artifact must not silently yield `[]`. Loud is the
   requirement; the exact shape (log + degrade, or refuse) is a decision —
   state which you chose and why.
2. `:absent` must KEEP its current fall-back-to-configured behaviour. ⛔ Do not
   collapse the two in the other direction.
3. ⭐ **RED-FIRST: a corrupt artifact today, showing the anchor set silently
   shrinking with nothing emitted.** Paste it. ⛔ Without this the fix is
   unmotivated.
4. **Both sites**, and a test that would fail if only one were changed —
   `MUD.Verbs.local_anchor_keys/0` is a hand-kept copy that will NOT fail to
   compile (trust.ex:798 says so in a comment).
5. `apps/commonplace/test/commonplace/trust` — **210 tests, 0 failures on main**
   (2026-08-09 post-merge; 195/196/197/201/206 in older briefs are stale).

---

## CX-b38c  [open]  p1  type=task
created=2026-08-10T20:30:03.944430Z  updated=2026-08-10T20:30:03.944430Z  claimed_by=nil
TITLE: L6 GAP (cell demo, found pre-ceremony): a subtree-write cert CANNOT author code docs — the write-perp-execute belt denies exactly the cell-contributes-code use case; needs a ruled route before L2

FOUND 2026-08-10 ~20:45Z by commonplace, mapping the zone-cert machinery for
the 2b demo ceremony (Explore agent, verified against source): the assessment's
L6 claim "pointing zone-ownership at a code subtree is an instance, not an
invention" is TRUE of the cert machinery and FALSE of the use case.

## The mechanism (deliberate, and correct on its own terms)

subtree_carve_ok?/5 (trust.ex:444) condition 3: `not authoring_code?(verbs,
after)` (trust.ex:534). CodeDocHeuristic.code_content?/1 classifies anything
matching ~r/^\s*defmodule\s+[A-Z]/m — or any non-empty JSON object-of-objects
— as code, and a {:subtree, R}[:write] cert is DENIED on it. This is the
write-perp-execute belt: attenuated write authority must not become code
execution via docs that auto-run. It is a security invariant, not a bug.

## Why the cell demo trips it

The cell's contribution IS code: yelixer .ex sources (defmodule — classified)
imported through the signed sync path, and six-field JSON events (nested
object — likely classified) appended to the event log. Under a subtree-write
cert, both deny. The merged proto-chit pilot never noticed because its test
principal sat in trusted_identities — FULL trust bypasses the capability
path entirely. Cert-scoped, the same flow dies at the belt.

## What the demo can honestly show today (slice 1 runs anyway)

- L1: the cell workspace's own node identity signs sync + events (auto-pinned
  trust anchor) — true and demonstrated.
- L6: the cert machinery demonstrated as built — allow inside subtree, deny
  outside (subtree_carve_test.exs is the crib), PLUS the belt itself shown:
  a code-doc write inside the subtree under the cert is ALSO denied, which is
  the invariant working. The demo artifact states plainly that the cell's
  code writes ride node-identity trust, not the cert.

## The decision that is PLAN's, before L2

How does an ATTENUATED cell principal author code within its granted
subtree? Candidate routes, none chosen here: (a) cert carries :execute
(Gate-B is node-only by policy today — a policy change); (b) route through
:define_verb + DefineVerbGate's sandbox (exists for MUD verbs; code-doc
generalization unbuilt); (c) the runner (L2) holds code-authoring authority
and the cell's cert scopes only punctuation/metadata — custody ruling already
says the workload never holds a key, so the runner signing code-writes may be
the intended shape anyway. Each changes what a "cell manifest" (#12) must
declare.

Also noted: no CLI mint path for subtree certs (cli cap.ex hardcodes
{:docs, _}) — IEx/erpc ceremony only today; and subtree certs are leaf-only
by design (:subtree_scope_not_delegable), which bounds delegation stories.

RELATED: 2b decomposition @8bc1543, cell-path assessment §3 L6 (plan repo),
CX-jfok/invariant-registry (the belt's lineage), CX-fogy (define_verb),
#12 cell manifests.

---

## CX-fm7x  [open]  p1  type=bug
created=2026-08-10T20:57:11.801811Z  updated=2026-08-10T20:57:11.801811Z  claimed_by=nil
TITLE: Proto-chit sync scope is everything-minus-four-names — a real checkout's SECRETS (.beads credential key here; .env in general) walk straight into the substrate store; scope policy is a design gap

FOUND 2026-08-10 during the cell demo ceremony: ProtoChit's @sync_excludes is
[".git", ".commonplace", "_build", "deps"] and Watcher.sync_recursive imports
EVERYTHING else. In the commonplace repo itself that includes .beads/ — whose
backup dir carries a CREDENTIAL KEY (the reason the targeted-git-add rule
exists) — 123 .darc archives that would have become CRDT docs in the cell
store. The only thing that stopped it tonight was the binary-crash companion
bug firing first: THE CRASH WAS THE PROTECTION, by accident.

## Why this is a design gap, not a bigger exclusion list

The sandbox design §4 ruled scope for the SANDBOX; the proto-chit pilot
inherited a four-name denylist instead of a scope policy. A denylist cannot
enumerate the world's secrets (.env, credentials.json, *.pem, id_rsa...).
Candidates for the ruled shape: an explicit allowlist per checkout (cell
manifests #12 want to declare scope anyway), gitignore-consultation
(imports track the repo's own notion of source), or a declared sync-scope
config in the workspace. Interim mechanism shipped for the demo: the CLI/shim
now pass operator-declared extra excludes (PROTO_CHIT_SYNC_EXCLUDES) — an
operator mechanism, NOT the policy; the policy decision is plan's.

## The invariant any fix must satisfy

What was imported must be ENUMERABLE from the pin (denominator visible), and
what was excluded must be DECLARED, never inferred. An import that silently
skipped a secret is as wrong as one that imported it — both misrepresent the
pinned state.

RELATED: binary-crash companion ticket, cell demo evidence, sandbox design
§4, #12 cell manifests, feedback_targeted_git_add_beads (the credential key).

---

## CX-5gkw  [open]  p1  type=task
created=2026-08-10T16:54:39.973492Z  updated=2026-08-10T16:54:39.973492Z  claimed_by=nil
TITLE: BUDGET AUDIT (CX-s4wh step 1): ALL 16 non-constant failures in round 3 are TIME-BUDGET crossings — 14x ExUnit default 60s, 1x Task.await 10s, 1x perf ratio — classes 2 and 3 are ONE mechanism

MEASURED 2026-08-10 17:0xZ by commonplace, by enumerating the failure MODE of
every failure instance in all 8 round-3 logs (/tmp/sol-class2-run3-*.log).
This completes CX-s4wh's step 1 — the audit was readable straight from the
round-3 artifacts, no new runs needed.

## THE ENUMERATION — exhaustive, per-hit

16 non-constant failure instances across 8 runs. Every one is a wall-clock
budget being crossed; ZERO behavioural assertions failed:

| test | instances | what actually failed |
|---|---|---|
| DocBuilderBoundedWalk walk-bound | 6 | ExUnit.TimeoutError 60000ms — dies in build_chain (GenServer.call to CommitStore building a 400-commit fixture) BEFORE reaching its assertion |
| Green.Bursar bounded-persistence | 4 | ExUnit.TimeoutError 60000ms |
| MUD.BotPresenceCert dead-session | 4 | ExUnit.TimeoutError 60000ms — the RACE ASSERTION NEVER FIRED; the 50-iteration loop just exceeds 60s |
| Store.CommitHoist retry-exhaustion | 1 | Task.await 10_000ms timeout inside the test |
| Trust.AuditChokePerf DENY-offered | 1 | ratio budget: p50 4.477 vs 3.0 (wall-clock ratio; the known CX-d0sc/CX-dsqc noise) |

The only non-timeout failure in the whole round is TrustConfigFailClosedTest
("Assertion with == failed") — class 1, the deterministic fixture gap, in all
8 runs as declared.

## ⭐⭐ WHAT THIS DISSOLVES

1. "Class 2" (green-alone/red-together) and "class 3" (instrument noise) are
   ONE mechanism: tests whose wall-clock cost sits near a FIXED TIME BUDGET,
   crossing it stochastically. Green alone = unloaded box, well under budget.
   Red together = the suite's own load pushes them over. The "neighbour" that
   reddens a class-2 victim is not a test — it is the LOAD any neighbour set
   generates. This is why no bisection over sets, populations, or orders could
   converge (rounds 1–3), and why the spread persisted at --max-cases 1.
2. CX-c93b's standing discriminator said exactly this in advance: "same
   population + same seed + now green => LOAD, not ordering; check for fixed
   time budgets first." The rule was on file; the mechanism hunts ran anyway.
3. ⚠️ CORRECTION to CX-vm8m/CX-evy4: BotPresenceCert is NOT a class-1 stable
   red. It fails only by timeout, intermittently (4 of 8 runs), and its race
   assertion has never been observed firing in these logs.

## Deliverable vs budget, per member (the TIME-vs-WORK question CX-s4wh asked)

For 15 of 16 instances the crossed budget is an INHERITED DEFAULT (ExUnit 60s,
Task.await 10s) that is NOT the test's deliverable — the deliverable is a work
bound (walk count, table size, race absence, fallback behaviour) the run never
reached. Only AuditChokePerf's budget IS its deliverable, and CX-d0sc/CX-dsqc
own it (widening remains forbidden there).

## The PROPERTY a fix must have (mechanism is plan's ranking, then a builder's choice)

A test's time budget should be an explicit, sized statement, not an inherited
default sitting within noise of the test's actual cost. Candidate directions —
NOT prescribed: make the fixtures cheaper (a 400-commit chain via per-commit
GenServer.call is the walk test's real cost), size explicit @tag timeouts to
measured cost on a loaded box, or tag heavy tests into a serial/slow partition.
⛔ Blanket timeout raises hide real hangs; ⛔ AuditChokePerf's ratio budget
stays untouched per its own tickets.

## Residual open question (small, honest)

WHY a 400-commit fixture build can exceed 60s at all is unexplained — on an
idle box it takes seconds. Suite-load + CubDB auto-compaction + 79%-full disk
are candidates; the loadavg-per-run recording (CX-s4wh step 2) is the cheap
instrument that would show it. The attribution above does not depend on this.

RELATED: CX-s4wh (parent), CX-e2vk, CX-evy4 (class structure now needs this
collapse), CX-vm8m, CX-c93b (the discriminator that called it), CX-d0sc,
CX-dsqc, CX-a2eb/CX-8wh1 (class 1, unaffected), CX-895n.

---

## CX-e2vk  [open]  p1  type=bug
created=2026-08-10T14:03:08.030890Z  updated=2026-08-10T14:03:08.030890Z  claimed_by=nil
TITLE: SAME SEED ≠ SAME OUTCOME — the residual instability is CONCURRENCY/TIMING, not ordering; class 2 was misnamed and no file bisection could ever have found it

MEASURED 2026-08-10 13:2xZ by commonplace. ⭐ This supersedes the "class 2 =
interaction/order-dependent" framing in CX-evy4 and completes the retraction of
CX-96t5's invocation-form claim.

## THE MEASUREMENT — one tree, ONE SEED, ONE INVOCATION FORM

`mix test apps/commonplace/test --seed 303`, run repeatedly on the same
worktree, nothing changed between runs:

    run A (12:38)  → 5 failures
    run B          → 3 failures   {bounded-persistence, bounded-walk, TrustConfig}
    run C          → 4 failures   {bounded-persistence, BotPresenceCert, bounded-walk, TrustConfig}
    run D          → 1 failure    {TrustConfig only}
    Sol round 2    → victim GREEN (≈1)

⇒ ⛔ **THE SAME COMMAND, ON THE SAME TREE, AT THE SAME SEED, SPANS 1–5 FAILURES.**

## ⭐⭐ WHAT THIS PROVES, AND IT IS NOT WHAT ANYONE EXPECTED

**A seed plus an invocation form FIXES THE TEST ORDER.** Both were held constant
and the failure set still varied. ⇒ **THE VARIABLE IS NOT ORDER.**

⛔ **So "class 2 is order/interaction-dependent" (my framing, CX-evy4) is
WRONG.** The remaining candidate is **concurrent interleaving**: `async: true`
modules run in parallel under `max_cases`, and the interleaving is free to differ
run-to-run at a fixed seed. Wall-clock, scheduler and machine load all enter
there.

⇒ ⭐ **AND IT EXPLAINS WHY NO BISECTION COULD EVER HAVE WORKED** — over file
sets (round 1) or over populations (round 2). **The variable is neither the set
nor the order**, so no method that varies only those can isolate it. Two
refusals from Sol were correct for a reason deeper than either round knew.

## ⛔ WHAT ELSE THIS RETIRES

- **CX-96t5's invocation claim is now positively dead**, not merely
  unsupported: the file-list run's single failure sits INSIDE the directory-form
  distribution (run D = 1). Nothing needs an invocation explanation.
- ⛔ **"Same seed" is NOT a sufficient control for this suite.** Tonight's
  same-seed SET COMPARISONS remain the best available instrument, but their
  power is limited by this spread — ⚠️ **a difference of 1–4 failures between
  two arms is INSIDE THE NOISE**, so only a failure appearing in one arm and
  absent from the other ACROSS REPEATED RUNS is evidence. Single-run set
  comparisons can miss a real regression.

## ⭐ CONFIRMED, and it is the one stable thing

`TrustConfigFailClosedTest` failed in **every single run** (A–D and all earlier
seeds). ⇒ Class 1 stands: deterministic, 0.4s isolated, CI's #1. It is the only
member whose behaviour is not a coin flip.

## WHAT TO DO NEXT — measure, do not guess

⛔ **Do NOT assert the mechanism.** Several plausible-and-wrong mechanisms have
died on this problem, including two of mine. The next measurement is cheap and
decisive:

1. ⭐ **Run with `--max-cases 1`** (serialise everything). If the spread
   collapses, concurrency is confirmed as the variable. If it persists, it is
   not.
2. Count `async: true` modules among the victims' neighbours and in the victims
   themselves.
3. ⚠️ Only then look for the shared resource.

⛔ Do NOT "fix" by setting `async: false` broadly — that hides the variable and
costs suite wall-clock permanently. **Identify first.**

RELATED: CX-evy4 (its class-2 definition needs this correction), CX-96t5
(RETRACTED), CX-6gws (the clause stands on its own basis), CX-a2eb (class 1),
CX-d0sc/CX-dsqc (class 3), CX-c93b, CX-895n.

---

## CX-evy4  [open]  p1  type=task
created=2026-08-10T10:15:44.469518Z  updated=2026-08-10T10:15:44.469518Z  claimed_by=nil
TITLE: Row 3= ANSWERED: the "flaky pool" is THREE mechanisms, not one — measured by isolating each member

FOUND 2026-08-10 by commonplace, applying the pool rule (CX-a2eb) to the
REMAINING members after it convicted the first. ⭐ Row 3='s pre-committed
question was "is there a second mechanism?" ⇒ **The answer is that there is no
single second mechanism. There are at least three, and the word "flaky" was
carrying all of them.**

## THE MEASUREMENT

Frequency across FOUR post-guard runs of `apps/commonplace/test` on main
(seeds 101/202/303/404), which produced 4 / 1 / 4 / 4 failures with DIFFERENT
SETS:

    4/4  corrupt trust.json → fail CLOSED           (TrustConfigFailClosedTest)
    2/4  the bound the walk does not grow…          (DocBuilder bounded walk)
    2/4  stop immediately followed by send_input    (BotPresenceCertTest)
    2/4  bounded persistence (CX-i9ca)              (Green.BursarTest)
    1/4  total cap blocks admits across principals  (SessionLimit)
    1/4  per-principal cap blocks the (N+1)th admit (SessionLimit)
    1/4  the DENY path adds only bounded work       (AuditChokePerfTest)

Then each was run ALONE, with a port pre-flight so an environment error could
not be mistaken for a result:

| member | isolated | ⇒ class |
|---|---|---|
| TrustConfigFailClosed | **1 failure in 0.4s** | ⛔ **STABLE RED** — deterministic |
| BotPresenceCert | **1 failure** (60s timeout) — and **identically on both branches** | ⛔ **STABLE RED** (slow/timeout) |
| DocBuilder bounded walk | **22 tests, 0 failures** | ⚠️ **INTERACTION-DEPENDENT** |
| Green.Bursar | **44 tests, 0 failures** | ⚠️ **INTERACTION-DEPENDENT** |
| AuditChokePerf | passes isolated; ratio spans **2.815–4.941 vs a 3.0 limit** | ⚠️ **INSTRUMENT NOISE** (CX-d0sc/CX-dsqc) |
| SessionLimit ×2 | not yet isolated | ❓ unexamined |

⛔ **PRE-COMMITTED BEFORE RUNNING, so the pass branch could not be read to
suit:** *isolated PASS means "needs neighbours" — order/interaction-dependent,
NOT exonerated and NOT "not real."* That reading stands.

## ⭐ WHAT THIS MEANS

**Three distinct mechanisms wearing one label:**

1. ⛔ **STABLE REDS** — fail alone, every time. They are not flaky at all and
   were never part of a distribution. TrustConfigFailClosed is CI's #1 with 12
   occurrences and took **0.4 seconds** to convict once anyone looked.
2. ⚠️ **INTERACTION-DEPENDENT** — green alone, red among neighbours. These ARE
   real and ARE order-sensitive; the guard's store-deletion class was one such
   mechanism and is now fixed, so these are a DIFFERENT one.
3. ⚠️ **INSTRUMENT NOISE** — a gate whose measurement variance exceeds its own
   margin, which cannot decide in either direction and contributes
   unattributable reds.

⇒ ⭐ **"Fix the unreliable tests" is therefore THREE pieces of work with three
different acceptances, and a fix for one is not progress on the others.** Any
plan that treats them as one queue item will fix the cheapest and report the
pool as handled.

## ⛔ WHAT NOT TO DO

- ⛔ **Do not fix the stable reds by patching fixtures locally** — see CX-a2eb;
  they belong to a population with a shared fix (CX-8wh1's complete-workspace
  helper).
- ⛔ **Do not widen any budget** to quiet the instrument class (CX-d0sc,
  CX-dsqc). That silences an arm already shown incapable of speaking.
- ⛔ **Do not report "the unreliable tests are fixed"** without naming WHICH
  class. plan's clause: *fixing them does not mean making them pass.*

## NEXT

1. Isolate the two SessionLimit tests to classify them (cheap, unexamined).
2. Class 1 rides CX-8wh1's helper.
3. Class 3 is CX-d0sc + CX-dsqc, already filed and already forbidden from the
   cheap fix.
4. ⭐ Class 2 is the genuinely open investigation and the honest heir to row
   3=: green alone, red together, mechanism unknown. It is the one that needs
   an attribution method rather than a fix.

⚠️ METHOD NOTE, earned three times tonight: umbrella runs are mutually
exclusive (:4002). **Every isolation run needs a port pre-flight**, or an
`:eaddrinuse` rc=1 with an EMPTY summary gets read as a test result. Two of
these measurements were destroyed that way before the guard was added.

RELATED: CX-a2eb, CX-vvbh, CX-d0sc, CX-dsqc, CX-8wh1, CX-c93b, CX-895n.

---

## CX-s4wh  [open]  p1  type=task
created=2026-08-10T16:50:29.379712Z  updated=2026-08-10T16:50:29.379712Z  claimed_by=nil
TITLE: CLASS-2 ROUND 3: --max-cases 1 does NOT collapse the spread — per CX-e2vk's pre-registration the variable is not async interleaving; the whole flaky pool is async:false

MEASURED 2026-08-10 14:05–16:46Z by Sol (round-3 brief @517b8e5, worktree
/home/jes/sol-class2/wt), REVIEWED by commonplace: distributions re-derived
from the raw logs (/tmp/sol-class2-run3-{serial,default}-*.log), not accepted
from the report. All 8 runs: 3283 tests (full population), rc=2, no
:eaddrinuse/empty-summary runs. Sol changed nothing and concluded nothing, per
brief.

## THE MEASUREMENT — mix test apps/commonplace/test --seed 303, same tree

serialised (--max-cases 1), 5 runs: 2, 4, 1, 1, 4 failures (wall ~1064s/run)
default max-cases,        3 runs: 5, 3, 4 failures

TrustConfigFailClosedTest (the declared constant) failed in ALL EIGHT runs —
the invocation control held throughout. Net of the constant:
serialised {1,3,0,0,3} vs default {4,2,3}.

## ⛔ GRADED AGAINST CX-e2vk'S PRE-REGISTRATION, written before dispatch

"Run with --max-cases 1. If the spread collapses, concurrency is confirmed as
the variable. If it persists, it is not."

⇒ THE SPREAD PERSISTED (1–4 serialised). Two serialised runs reproduced the
SAME 3-member failure set as default runs (Bursar bounded-persistence,
BotPresenceCert dead-session, DocBuilderBoundedWalk). ⛔ So async concurrent
interleaving is NOT the variable — the third mechanism candidate to die on
this problem, this one by pre-registration rather than retraction.

## ⭐ THE FACT THAT EXPLAINS WHY IT COULDN'T HAVE BEEN

Every member of the flaky pool is async:false — Bursar, BotPresenceCert (bare
use ExUnit.Case = sync), DocBuilderBoundedWalk, AuditChokePerf, CommitHoist,
TrustConfigFailClosed. ExUnit runs sync modules SERIALLY, one at a time, after
the async phase, at every max_cases setting. ⇒ --max-cases 1 barely changes
the context these tests execute in. The variable must be something that
differs run-to-run even under full serialisation: machine load, residual
processes from earlier tests, timers, disk.

## ⚠️ SECONDARY OBSERVATION — stated as underpowered, not as a finding

The serialised arm's mean is lower (non-constant 1.4 vs 3.0) and two
serialised runs were fully green mod the constant. At N=5 vs 3 (rank-sum
p≈0.09, heavy ties) this neither confirms nor excludes a real reduction. Do
not cite it as one.

## WHAT THE PRIOR ARC'S DISCRIMINATOR SAYS (pre-existing rule, not a guess)

CX-c93b's attribution discriminator: same population + same seed + now green
⇒ LOAD, not ordering. Serial runs 3–4 fire it exactly. And every pool member
asserts a time/work BOUND (bounded persistence, perf ratio, walk bound,
retry-exhaustion under contention, dead-session-within-timeout). The same
arc's standing rule: check for fixed time budgets first.

## NEXT MEASUREMENT — cheap and decisive, in rank order

1. Per-victim budget audit (read-only): for each of the 5 non-constant pool
   members, name the fixed budget/timeout/bound it asserts and the quantity it
   actually measures (time vs work). A bound on TIME is load-sensitive by
   construction; a bound on WORK should not be — a work-bound test failing
   under load is a different defect than a time-bound one.
2. Record loadavg + free disk at start/end of every future suite run (one
   line, no new tooling) so arms can be compared on the suspected variable.
⛔ 3. Do NOT widen any budget (CX-d0sc/CX-dsqc acceptance forbids it) and do
   not fix anything before 1 names what each test actually bounds.

RELATED: CX-e2vk (pre-registration this grades against), CX-evy4 (class-2
definition now needs THIS correction too), CX-vm8m, CX-895n, CX-c93b
(discriminator), CX-d0sc/CX-dsqc (class 3), CX-a2eb (class 1 fix path).

---

## CX-vm8m  [open]  p1  type=task
created=2026-08-10T10:54:07.443450Z  updated=2026-08-10T10:54:07.443450Z  claimed_by=nil
TITLE: PRE-REGISTERED READING for the class-2 bisection result — written BEFORE the artifact lands

⛔ WRITTEN 2026-08-10 10:55Z BY COMMONPLACE, WHILE SOL'S RUN IS STILL IN FLIGHT
AND ITS RESULT IS UNKNOWN. The point is that this reading exists before the
data, so the data cannot be read to suit whoever reads it.

⭐ Class 2 exists as a finding ONLY because the isolated-PASS branch was
pre-committed before the isolations ran (an isolated pass means "needs
neighbours", NOT "not real"). Under the naive reading those two greens would
have looked like exoneration and the pool would still be one undifferentiated
word. ⇒ The equivalent commitment for the bisection is below.

## The question Sol is answering

`tree/doc_builder_bounded_walk_test.exs` and `green/bursar_test.exs` are GREEN
ALONE (22/0 and 44/0) and RED in the full `apps/commonplace/test` suite at seeds
101 and 303. **Which neighbour reddens them?** Method: deterministic reproducer
(`--seed 0` disables the shuffle), then bisect the FILE SET.

## ⛔ WHAT EACH OUTCOME MEANS — decided in advance

1. **A minimal red set of TWO (victim + one culprit)** ⇒ the strongest result.
   The named culprit becomes the subject of a fix ticket. ⭐ Required alongside
   it: the CONTROL that the victim ALONE is green — without it "minimal" is
   unproven.
2. **A minimal red set LARGER than two** ⇒ the culprit is a COMBINATION. ⚠️
   **This is a legitimate answer, not a failed bisection.** Report the smallest
   red set reached. ⛔ Do not let a bisector's tidy output round a combination
   down to a single file.
3. ⛔ **NO REPRODUCER (fails to reproduce in ≥3 attempts)** ⇒ **A FINDING, AND
   THE RUN STOPS.** It is NOT "the problem went away" and NOT licence to bisect
   anyway. It would mean the population shifted under the day's merges, and the
   correct next step is re-measuring the failure set, not hunting a culprit.
   ⚠️ Bisecting an unreproducible failure yields a CONFIDENT WRONG ANSWER
   dressed in method.
4. **A minimal set found but the mechanism UNREADABLE from the code** ⇒
   **acceptable and expected.** ⭐ The SET is the durable artifact; a guessed
   mechanism is a liability that outlives its own retraction. Several
   plausible-and-wrong mechanisms were proposed and retracted on this exact
   problem within twelve hours, by commonplace AND by commonplace-plan.

## ⛔ What NO outcome licenses

- ⛔ **None of these is a fix, and none makes the suite green.** Class 2 is
  attribution. A "fixed" report from this ticket is out of scope by
  construction.
- ⛔ **No outcome disposes of class 1 (stable reds: TrustConfigFailClosed,
  BotPresenceCert) or class 3 (instrument noise: AuditChokePerf's arms).**
  Three mechanisms, three acceptances; progress on one is not progress on the
  others (CX-evy4).
- ⛔ A green full-suite run at any point does NOT mean class 2 is resolved —
  the suite is non-deterministic (4/1/4/4 with different sets), so a green draw
  is a sample, not a verdict.

RELATED: CX-evy4 (the three classes), CX-895n (session state), CX-a2eb, CX-d0sc,
CX-dsqc, CX-8wh1. Brief: `docs/plans/2026-08-10-class2-attribution-brief.md`
@a65d7c9, worktree /home/jes/sol-class2/wt, branch sol/class2-attribution.

---

## CX-895n  [open]  p1  type=task
created=2026-08-10T10:03:39.649579Z  updated=2026-08-10T10:03:39.649579Z  claimed_by=nil
TITLE: START HERE 2026-08-10 morning — session state after the overnight suite-reliability run

⭐ READ THIS BEFORE SCOPING ANY WORK. Written by commonplace at 10:05Z while
context was high, so the state survives a compaction. Everything below was
MEASURED, not recalled.

## Where main is

`a71fa62`. Serve **2551162** healthy on :5199, untouched since the 02:40Z
deploy — everything merged since has been tests or trust-visibility only, with
NO runtime posture change. Disk 5.8G free / 95% (was 97%; boss reclaimed ~2G).

## Shipped and verified overnight

- **CX-EC2-birth** @e8b9247 — a declared worker role refuses to start permissive.
  Five clauses verified, zero on report.
- **CX-37d9** @390433f — create-once private-key mint via `File.ln/2`. ⚠️ The
  prescribed unique-suffix fix was INSUFFICIENT and would have shipped green:
  `rename` still clobbers, so two callers ended up holding DIFFERENT private
  keys for one node_id. The cold-start window is still OPEN via **CX-kmtq**
  (`Workspace.write_fresh_node_id/2`, the SILENT half).
- **CX-q9sa** @7b18534 — the rm_rf store guard, landed with **153** offenders
  (not the 41 the row carried; 41 was the guard's FIRST FIRING, a lower bound).
  Reverted TWICE first — the second time by my own scope error.
- **CX-vvbh** @a71fa62 — node self-trust no longer dropped silently.

## ⛔ OPEN, AND EXPLICITLY NOT ABSORBED BY ANY MERGE

1. ⭐ **Main is NON-DETERMINISTIC and row 3='s second mechanism is UNIDENTIFIED.**
   Measured on a guard-landed tree: **4 / 1 / 4 failures at seeds 101/202/303,
   DIFFERENT SETS**, and 4 again at seed 404. ≥8 distinct tests rotate through.
   ⇒ The store-deletion class was NOT the cause; that branch was pre-committed
   before the merge so it cannot be reinterpreted.
   ⚠️ **DISK PRESSURE IS WEAK-DISCONFIRMED**: seed 404 at 5.8G gave 4 failures,
   matching the 4/1/4 taken at 3.8G. Similar counts across a 2G difference.
   Not excluded, but it does not look like the mechanism.
2. **CX-a2eb** — `TrustConfigFailClosedTest` is DETERMINISTIC (0.4s isolated),
   CI's #1 with 12 occurrences, and was mistaken for pool noise all night.
   ⛔ **DO NOT hand-seed its fixture.** It is one member of a population; the
   complete-workspace helper (CX-8wh1) is the shared fix.
3. **CX-d0sc / CX-dsqc** — AuditChokePerfTest's arms have VARIANCE EXCEEDING
   THEIR MARGIN (deny-offered ratio spans 2.815–4.941 against a limit of 3.0; a
   third arm passes at 2.995/3.0). ⛔ **"Not caused by Sol" ≠ "not real"**, and
   both acceptances FORBID widening the budget — that silences an arm shown
   incapable of speaking and calls it fixed.
4. **CX-8wh1** — promoted; now the shared fixture fix for BOTH populations
   (44 fixtures lacking `node_signing_key`, plus those lacking the public-key
   artifact).
5. Also open: CX-0c9k+CX-hn7d (one slot, same function), CX-kmtq, CX-vvn4,
   CX-v70s, CX-ye7n, CX-xqfw, CX-ajp8, CX-qzbh.

## ⛔ METHOD — the instructions that did not exist yesterday

- ⭐⭐ **DO NOT READ GREEN/RED against this baseline.** Use a **same-seed SET
  COMPARISON**: only a failure present in your run and ABSENT from a
  same-seed baseline indicts your change.
- ⭐ **THE DENOMINATOR IS THE CHECK.** `apps/commonplace/test` must report
  **~3278**. A count in the HUNDREDS means a subtree ran and **THE RUN IS VOID**.
- ⭐ **RECORD FREE DISK PER ARM.** A 2G reclaim mid-comparison biases the arms
  apart, and the bias HIDES a regression rather than inventing one.
- ⚠️ **Umbrella runs are MUTUALLY EXCLUSIVE** (:4002). One at a time.
  **rc=1 with an EMPTY summary is an ENVIRONMENT error, not a result.**
- ⚠️ `mix test apps/yelixer` **RUNS NOTHING AND EXITS 0** — use
  `apps/yelixer/test`. `mix precommit` exists only inside `apps/commonplace_web`.
- ⛔ **Before treating failures as a POOL, run the most frequent member ALONE.**
  It cost 0.4s and found a stable red hiding in a set three parties had agreed
  was noise. **A homogeneous label on a heterogeneous set licenses not looking.**
- ⛔ Kill by IDENTITY via `bin/cp-kill`. ⚠️ The harness's `pkill` guard refuses
  ONLY on `$CLAUDE_PID` — it does NOT protect your shell, other agents, or
  **hermes**. "There is a pkill guard" reads broader than it is.

## Ranking

plan owns it (`commonplace-plan/docs/plans/QUEUE.md`). jes 07:37Z: *"we better
fix the unreliable tests"* ⇒ **suite reliability is #1**, proto-chit #2.
⛔ plan's clause, which matters most when a fix lands: **FIXING THEM DOES NOT
MEAN MAKING THEM PASS.** If anyone reports the unreliable tests as fixed, that
claim needs its method attached.

---

## CX-wqt2  [open]  p1  type=task
created=2026-08-09T20:26:42.180324Z  updated=2026-08-09T20:26:42.180324Z  claimed_by=nil
TITLE: START HERE 2026-08-10 — deploy is HELD by decision, and MAIN CHANGED underneath the earlier plan

## ⛔ Read this before scoping anything on 2026-08-10

### 1. The deploy is HELD BY DECISION, not stale and not failed

Held 2026-08-09 ~20:25 by boss-clod on a health call. ⚠️ **Do NOT renew it by
default — RE-ARGUE it.** A hold that renews silently is indistinguishable from
one nobody is thinking about.

**The original reason is GONE.** It was "CX-qvrz's defect would ship"; that fix
landed (`f6064e8`). **The reason it stayed held was the operator, not the code:**
three attention failures inside one hour, all caught by verification rather than
by care — a guard merged that broke 41 tests, a revert whose base would have
crashed every suite, a push reported as landed from the wrong worktree.

⭐ **The code was and is ready. Say so, then decide fresh.**

**Preconditions verified 2026-08-09 20:24 — RE-DERIVE, do not inherit:**

    node_signing_key   90 bytes (44 + \n + 44 + \n), mode 664
    line 1 length      44         data_dir writable
    ⇒ publish_public_keys_at_boot will succeed and the node WILL boot

⚠️ That check exists nowhere but in a context window that is now gone. **Re-run
it.** It is the difference between a deploy and an experiment — see CX-f4vv:
`application.ex:14` hard-matches `:ok =`, so a publish failure is TOTAL BOOT
FAILURE, not a degraded read.

### 2. ⛔ MAIN CHANGED — tomorrow's payload is NOT last night's

⭐⭐ **THE rm_rf STORE-DIRECTORY GUARD IS NO LONGER ON MAIN.** Reverted in
`e36ca4a` because it broke **41 tests nobody had run**: it was verified against
three targeted suites in ONE app, and its whole purpose is umbrella-wide.

    after merge:   mcp 156/21 (21 guard fires, was green)   web 134/30 (20 fires)
    after revert:  mcp 156/0                                web 134/10   fires: 0

⚠️ **Anything written before ~20:10 that says "CX-q9sa is done" is WRONG.** The
guard, its controls and both review fixes are preserved on branch
**`opus/cx-q9sa-control`**.

⛔ **The guard is CORRECT. The 41 failures are real offenders** — tests deleting
their own tmp dir with the live singleton store inside it. **It re-lands WITH the
teardown fixes, as a pair, never alone.** A gate must not land before the things
it gates are clean.

### 3. Merged 2026-08-09 (all pushed)

    f03bf1b  CX-rp33 per-stage counters in AuditLog.handle_event/4
    a4e708d  public-key sourcing from a public artifact (+ round-2 temp-file race)
    0053a8c  refuse to mint a replacement identity when a prior world exists
    f6064e8  CX-qvrz publish the artifact at boot
    e36ca4a  REVERT of the rm_rf guard
    d3c7707 / e5ed5d0 / 207defe  cp-kill, cp-ci-failures, cp-tix-file fix

### 4. Open, filed today, none started

CX-f4vv (boot hard-match) · CX-1jh2 (both consumers collapse :absent and
{:error,_}) · CX-37d9 (private-key fixed temp filename) · CX-qzbh (CommitHoist
10s budget) · CX-d0sc (AuditChokePerf ratio guard reads 0.38–3.26 on identical code)

### 5. On-main suite counts, measured 2026-08-09 post-merge

    trust 210/0 · crypto 40/0 · view_action_dispatch 14/0 · mcp 156/0 · web 134/10

⛔ Older briefs say 195/196/197/201/206 for trust. **All stale.** Baseline before
quoting.

---

## CX-96t5  [open]  p1  type=bug
created=2026-08-10T12:37:16.487868Z  updated=2026-08-10T13:04:07.741731Z  claimed_by=nil
TITLE: ⛔ RETRACTED — NOT ESTABLISHED: the invocation-form claim rests on ONE DRAW PER ARM and a later dir-form run disagreed with itself; needs distributions, not draws

FOUND 2026-08-10 by Sol during class-2 attribution (CX-evy4), and RE-DERIVED
independently by commonplace before filing. ⭐ Sol was asked to bisect a file
set, discovered the method could not work, and reported UNKNOWN rather than
producing a clean-looking wrong answer.

## THE MEASUREMENT — same tree, same seed, same test count

    mix test apps/commonplace/test --seed 303
      → 5 doctests, 3283 tests, 5 FAILURES
        bounded persistence (CX-i9ca) each durable persist stays O(table)
        bounded persistence (CX-i9ca) a large permanent table stays bounded
        stop immediately followed by send_input (BotPresenceCert)
        the bound the walk does not grow when history is added BELOW the snapshot
        corrupt trust.json → fail CLOSED (TrustConfigFailClosed)

    mix test <victim> <all 370 neighbour files> --seed 303
      → 5 doctests, 3283 tests, 1 FAILURE   (TrustConfigFailClosed only)

⇒ **SAME SEED. SAME TREE. SAME 3283 TESTS. 5 failures vs 1.** The only
difference is HOW the suite was invoked: a directory argument versus an
explicit list of the same 370 files.

## ⛔ WHAT THIS MEANS

⭐⭐ **A SEED SHUFFLES A STARTING ORDER, AND THE STARTING ORDER DIFFERS BETWEEN
INVOCATION FORMS.** Mix's directory glob and an explicit `find | sort` list are
not the same input, so `--seed 303` is **one order per form**, not one order.

⇒ **CONSEQUENCE 1 — FILE-LIST BISECTION CANNOT ATTRIBUTE THESE FAILURES.** The
variable is not a member of any file set, so halving the set cannot isolate it.
⛔ **A bisection run anyway would have converged on some innocent file with a
clean halving trace** — the tidiest possible artifact and entirely false, and
unlike a bare wrong theory it would arrive WEARING A METHOD, which is harder to
challenge.

⇒ **CONSEQUENCE 2 — "SAME SEED" IS ONLY A CONTROLLED VARIABLE WITHIN ONE
INVOCATION FORM.** ⚠️ Anyone comparing a directory-form baseline against a
file-list run will read the difference as a regression. Tonight's same-seed SET
COMPARISONS all used the identical directory form on both arms, so they hold —
but that was **habit, not design**, and the next person has no reason to inherit
the habit.

## ⭐ THE METHOD THAT WOULD WORK

Shrink the set while **preserving the invocation form**: temporarily move test
files OUT of the directory tree, and keep running
`mix test apps/commonplace/test --seed 303`. The invocation stays constant, the
population changes, and the bisection becomes valid.

⛔ Requires care: moved files must be restored (record them; restore in a trap),
and the run's TEST COUNT must be reported each step so a silently-empty
selection cannot masquerade as "green".

## ACCEPTANCE for whoever takes the attribution

- The minimal red set, reached by directory-preserving bisection.
- ⭐ CONTROL: victim alone (via the same directory-form invocation, with only
  the victim present) is GREEN — otherwise "minimal" is unproven.
- Per-step: files present, test COUNT, rc.
- ⛔ If both halves go green, it is a COMBINATION — report the smallest red set,
  do not force it to one file.

## ⚠️ OPEN QUESTION, NOT ANSWERED HERE

Whether the invocation difference is purely ORDER, or also concurrency grouping
(`async: true` batching, `max_cases`), is **UNKNOWN and not guessed**. ⛔ Do not
assert a mechanism without measuring it — several plausible-and-wrong mechanisms
were proposed and retracted on this exact problem within twelve hours.

RELATED: CX-evy4 (the three classes; this is class 2's method), CX-vm8m (the
pre-registered reading — this is a FIFTH outcome, not the "no reproducer"
branch: the phenomenon is REAL and the INSTRUMENT is blind), CX-895n, CX-c93b.

---

## CX-d81c  [open]  p1  type=bug
created=2026-08-11T20:01:46.216813Z  updated=2026-08-11T20:01:46.216813Z  claimed_by=nil
TITLE: The proto-chit PIN cannot exist in a :minimal cell — cut_pin's reflog snapshot attaches __reflog to the root, which the cell class refuses BY DESIGN; the emitter surfaces it as a bare :error

(no description: {:ok, ""})

---

## CX-tq3f  [open]  p1  type=bug
created=2026-08-11T20:01:24.397669Z  updated=2026-08-11T20:01:24.397669Z  claimed_by=nil
TITLE: The proto-chit PIN cannot exist in a :minimal cell — cut_pin's reflog snapshot attaches __reflog to the root, which the cell class refuses BY DESIGN; the emitter surfaces it as a bare :error

(no description: {:ok, ""})

---

## CX-aw4r  [in_progress]  p2  type=bug
created=2026-07-07T00:15:40Z  updated=2026-07-07T00:27:35Z  claimed_by=nil
TITLE: Safe verbs have no actor-attribution: Facade.emit renders identical text to actor and observers

EXPERIENCE PLAYTEST finding (black-box via mud_send, world 'The Copper Lantern' built S of Start Room).

Facade.emit/2 is the only neutral room-broadcast primitive for object verbs, but it sends the SAME literal string to the actor AND every observer. So any action verb written in 2nd person misfires for bystanders.

REPRO:
- @verb box:play with body: Commonplace.MUD.World.Facade.emit(world, "You lift the lid of the music box...")
- Player toby runs 'play box'.
- Bystander verifier (same room) receives verbatim: 'You lift the lid of the music box...' — reads as though VERIFIER did it. Confirmed live both directions.

ROOT ISSUE: no 1st-vs-3rd-person emit form (actor sees 'You...', others see '<name> ...'), and Facade.actor_name/1 is BANNED by the allowlist, so an author cannot even manually prefix the doer's name. Only the builtin 'say' attributes correctly (You say / X says). Every custom action verb is therefore un-attributable.

SUGGEST: an emit variant like Facade.act(world, me: "You lift the lid", others: "<actor> lifts the lid"), OR expose an allowlisted actor-name/actor-ref token authors can interpolate. This is the #1 limiter on writing immersive verbs today.

---

## CX-xe0r  [in_progress]  p2  type=bug
created=2026-07-13T01:02:40Z  updated=2026-07-13T16:39:59Z  claimed_by=nil
TITLE: MUD: 'look <player>' cannot target other LIVE players — room lists them in Players:, self-look works, give resolves them

Black-box 2026-07-13, The Convergence, two live sessions (fable + wisp) in the same room. Room render for fable: 'Players: newbie, sable, wisp'. fable: 'look wisp' → You don't see "wisp" here. — immediately after receiving 'wisp arrives from the south.' Yet 'look fable' (self) → 'fable / A traveler.' and 'give brass key wisp' works ('You give brass key to wisp.'). So look/examine noun resolution never consults room presences (except self), while give has its own player resolver. Applies to ghosts too ('look ember' in Start Room fails the same way) but this is NOT ghost-specific — live players can't inspect each other at all. QoL: unify player targeting for look/examine with give's resolver.

---

## CX-z6ub  [in_progress]  p2  type=feature
created=2026-07-11T04:34:01Z  updated=2026-07-11T22:48:58Z  claimed_by=nil
TITLE: Verb-authoring M2: standard verb set as node-signed prototype (inherited, override-on-top)

Design @9398646 §3. Node-signed standard verb LIBRARY (prototype); rooms/objects inherit via dispatch fall-through (own-verb → standard-prototype). Custom sandboxed verbs override by name; protected possession verbs (take/give/drop/put) NOT overridable (§7 Q2). SURFACE the standard-set contents to boss/jes before finalizing (player-visible). Proposed default set in §3.

---

## CX-hbbi  [in_progress]  p3  type=bug
created=2026-07-07T04:11:54Z  updated=2026-07-07T04:21:19Z  claimed_by=nil
TITLE: Container spoiler: 'look <container>' reveals contents of a locked/shut container

Playtest (boss #6081): 'look vault' on a LOCKED container prints 'contains: gold ingot' — reveals contents through the locked door. do_look_in_container (the 'look in' path) IS lock-gated (CX-cj3t.8), but render_looked_at_entry (the plain 'look <container>' path) is NOT — it renders container contents without checking container_locked?. Fix: gate the plain-look container path the same way ('The <name> is sealed.' when locked). Small; relates to CX-cj3t.8 + container-visibility. Under CX-nphu.

---

## CX-fogy  [in_progress]  p1  type=feature
created=2026-07-11T04:34:00Z  updated=2026-07-11T17:30:30Z  claimed_by=nil
TITLE: Verb-authoring M1: execute-safe cert at home-genesis + editable-flag gate fix (trust-core)

Design @9398646 §2. Citizenship issues a THIRD node-signed cert at home-genesis: {:subtree,home} with the :define_verb capability (the design's 'execute-safe' cert). Then DefineVerbGate.authorized_to_define? (already checks :define_verb over section_scope) passes for the citizen's own rooms/objects. Fix verbs.ex can_author_verbs? (the @verb editable flag) to check :define_verb over the target's section_scope — matching the REAL save-time gate — instead of code_author_authorized? (:execute). Gate-B (raw .elx / :execute) UNTOUCHED — citizen still denied raw code. Prove under :enforce black-box (citizen @digs→@verbs a sandboxed verb in own home → editable:true + save lands + runs; raw-code still denied). LOAD-BEARING: confirm :execute-safe ≡ existing :define_verb verb with plan before building.

---

## CX-aya0  [in_progress]  p1  type=feature
created=2026-07-10T14:24:06Z  updated=2026-07-10T15:16:19Z  claimed_by=nil
TITLE: MUD-as-docs Inc-2: stateless-leaf verbs (look/examine/inventory/emote/say) doc-hosted via SourceDoc.compile + Gate-B

Track B of the 2026-07-10 interleaved M2 plan (/home/jes/commonplace-plan/docs/plans/2026-07-10-m2-mud-as-docs-interleaved-plan.md §B1). Migrate PURE no-write low-blast-radius verbs to doc-hosted via Code.SourceDoc.compile + the MUD.EngineModule resolver + Gate-B (Trust.authorized_to_execute?). These are NODE-SIGNED engine verbs = the node-signed=:execute safe side of Gate-B. Prove ONE verb (look/examine) end-to-end FIRST, then the cohort. Gate-B is the security core (plan nod #5): node-signed=execute vs player-authored=allowlist-only; manifest trust-root; no RCE via player-injected verb code (W1-W4 from Inc-1 engine_module.ex). Non-brick via two fallback tiers (last-good -> compiled-in floor). Parallel with all of Track A.

---

## CX-vt9l  [in_progress]  p2  type=epic
created=2026-08-04T20:35:41Z  updated=2026-08-04T20:37:23Z  claimed_by=nil
TITLE: Relational + search as commonplace profiles (F3, derivation records, one index instance)

jes greenlit 2026-08-04 ("yes commonplace beads and then start implementing"), relayed via boss-clod #9917. SOURCE DOC (authoritative, read before building): /home/jes/commonplace-plan/docs/plans/2026-08-04-relational-search-ideation.md @44b29fe — written by commonplace-plan, deliberately filed no beads and proposed no build. Thesis: relational and search are PROFILES over machinery that mostly exists, not new primitives. Not proposed and explicitly out of scope: SQL parser, query planner, Lucene port, new privileged service, new edge notation.

SLICES (doc §7 order): .1 F3 + result-witness; .2 derivation-record convention; .3 one measured index instance; .4 scoped-index trust model = BLOCKED DESIGN CALL, do NOT start.

TWO CONSTRAINTS carried into every slice (boss, from the doc): (1) an index is a MATERIALIZED READ OF EVERYTHING — post-filtering a global index is REJECTED as primary because counts/rankings/completions leak existence even when contents are filtered (the elasticsearch-with-ACLs failure mode); any index instance must stay inside ONE visibility class and name it. (2) Aggregates have two honest tiers — CRDT-mergeable accumulators (monotone/commutative) may be live; general SUM/COUNT/GROUP BY is PIN-DERIVED ONLY and must be labeled with its cut. A live general aggregate must never ship pretending to be a fact.

⚠️ §6 CORRECTION (VERIFIED by me 2026-08-04 against the code, per the standing verify-dont-trust discipline): §6 lists "frontier query + alarm, instance-first (Bd)" as implemented. Half of that is wrong. VERIFIED: Bd.Frontier.compute/2 runs live (called on read by Bd.CLI + MCP bd_route) — the QUERY half is real. But the dependency-hell ALARM and the __ready.json/__blocked.json VIEW-DOC rewrites exist ONLY inside Bd.Frontier.Server (frontier/server.ex:29-32,138,221-228), and Frontier.Server has ZERO production starters (grep: only self-references) — already filed as CX-5le4. frontier.ex itself contains no alarm/view-doc code at all (grep count 0). Consequences for the slices: slice .2 cannot "adopt the convention in the frontier views" because those view docs are never written in production, and slice .3s "instance-first like frontier" precedent is a POLL-ON-READ query, not a maintained artifact. Both slices adjust accordingly rather than building on a claim that is not live.

VERIFIED as genuinely implemented: Black M1 verbs (black.ex select/132 json/172 xml/194 emit_red/231); PatternCompute + its supervisor (black/pattern_compute.ex, started in application.ex); ViewCompute with last_computed_at provenance; ref-typed :-field enforcement (Bd WriteGuard, CX-ticket-dag S1); close/cycle gates. Deploy gate: implementing greenlit, DEPLOY TO :5199 IS NOT — six changes already ride behind that gate; build and merge to main only.

---

## CX-cj3t.9  [in_progress]  p2  type=bug
created=2026-07-07T01:53:01Z  updated=2026-07-07T04:01:34Z  claimed_by=nil
TITLE: Facade.move budget/semantics — owner_grant_exceeded makes it unusable for gameplay

Playtest next-tier #3 (boss #5987). Facade.move(world, dest) grant-checks {object_uuid, current_room_uuid, dest_dir_uuid} all in owner_grant — so a verb can't teleport a player into a hidden room / move an object to a room the verb-owner doesn't own. Returns {:error, :owner_grant_exceeded}, unusable for most gameplay moves. Reconsider the move budget/semantics: what SHOULD a verb be able to move, and where? Likely: moving the BOUND object to a destination should only need write on {source, dest} (like take/drop Option-B), not owner_grant over all three. Trust-adjacent — plan reviews. Repo /home/jes/commonplace.

---

## CX-ypgf  [in_progress]  p2  type=bug
created=2026-07-13T01:02:13Z  updated=2026-07-13T16:45:26Z  claimed_by=nil
TITLE: MUD parser: preposition swallowed as noun + substring match across words — 'step on warppad' → "You can't step iron ingot"

Black-box 2026-07-13 overnight playtest (fable, Start Room). Exact repro: player carrying 'iron ingot' types 'step on warppad' → output: You can't step iron ingot. The preposition 'on' is treated as the noun and substring-matched into 'irON ingot' (match not anchored at word boundary). 'step warppad' correctly says: You can't step warppad. Fix shape: strip/parse common prepositions (on/at/with/into) in object-verb command form, and require word-boundary (or exact/alias) noun matches. Related but distinct from CX-c6ph (alias-beats-exact ranking): this one is about tokenization + substring anchoring.

---

## CX-hh70  [in_progress]  p2  type=bug
created=2026-07-12T21:26:46Z  updated=2026-07-13T16:29:59Z  claimed_by=nil
TITLE: MUD onboarding: 'examine' on puzzle objects appends raw State block that SPOILS the answer — altar shows 'expect: spark' + 'solved: yes'

Fresh-eyes newcomer run 2026-07-12 (new player wren, zero prior state). 'examine obsidian altar' in the Cinder Oratory renders the authored description (excellent — glyph clues + 'try: chant <word>') then appends:

State:
  expect: spark
  solved: yes
  step: 1

'expect: spark' literally names the next correct chant word — the puzzle's answer key is printed on the puzzle. 'solved: yes' also spoils that others finished it (deflates discovery). Generalizes: the orrery leaks 'charge: N' the same way (side-noted in CX-7qpt). Any interactable using get/put_state exposes its brain via examine.

Fix: stop appending raw state to player-facing examine (reserve for @dump / owner / @listen debug), or let verb authors mark state keys as hidden. NPE impact is real: the Oratory is the best-designed puzzle in the game (fair glyph clues, clean reset feedback, EMBERFALL payoff, souls-counter prestige) and the UI hands you the answer before you read the riddle.

---

## CX-vfau  [in_progress]  p2  type=task
created=2026-07-06T10:44:55Z  updated=2026-07-06T13:50:00Z  claimed_by=nil
TITLE: CX-60na Green half: bursar adoption wave + author-facing acquire/release verbs + cluster-arbiter design residual + docs

Split from CX-60na. (a) ADOPTION: designed use-case family beyond Move+TickBot — deploy locks, experiment lifecycle w/ expiry-escalation, fork TTL, presence slots, MUD bot sessions (parked CX-tdkq.7.1); SEQUENCES WITH/AFTER epic CX-qat5 (MUD is green's next real use cases: edit-locks, section-claim tokens) — do not start adoption before the MUD demo lands. (b) author-facing form of bursar acquire/release callable from compute docs (execute-gated code only) — the black↔green reactive-exclusivity pattern (brief §6: black senses, green claims). (c) DESIGN residual: cluster-wide arbiter (store single-owner is designation-not-lock; two-serves-on-one-workspace risk). (d) DOCS: fold shipped bursar reality into wiki + color-channels.md; also fix stale White section (biscuits → UCAN-shaped capabilities shipped). Design refs: /home/jes/commonplace-plan/docs/color-channels.md, /home/jes/commonplace-plan/docs/bursar.md, /home/jes/commonplace-plan/docs/plans/2026-07-06-black-channel-brief.md §6.

---

## CX-cj3t  [in_progress]  p1  type=epic
created=2026-07-06T17:01:54Z  updated=2026-07-08T06:59:52Z  claimed_by=nil
TITLE: (EPIC) MUD improvement — fix + harden the multiplayer MUD from dogfood findings

jes: 'next let's do an epic to fix/improve the MUD.' Formalizes the 2026-07-06 MCP-builder dogfood findings into ordered work. THE GATING RULE: the safe-verbs design (CX-ndvi, commonplace-plan Fable is drafting it — execution sandbox vs verb-DSL vs capability-gated host-fns; authority = invoker ∩ owner-capability; capability-scoped store facade; per-owner namespacing; resource limits) MUST land before any bead that OPENS @verbs to untrusted players — today user @verbs are arbitrary god-power Elixir with full store reach. Fix-the-mechanism verb work (persistence/namespacing/crash) can proceed; EXPOSE-to-untrusted is gated on CX-ndvi.

ORDER:
P0 (blockers to a playable/safe MUD): CX-5plk (MCP-session signing — agents can build but can't move/take, signing_context nil), CX-9f62 (verb persistence + per-owner namespacing — kill the global-UserVerb collision + rebuild-from-source), CX-gq7a (empty-'.' @verb-save crash + mis-attributed CommitStore-overload error hint).
P1: CX-el97 (denials that lie — distinguish permission-denied from rule-denied, 'can't go north' for a real exit), CX-mczs (verb dispatch ignores target = verb-name hijack), CX-8iyv (multi-word-name parser break), + build-permission changes surfaced to the player.
P2/polish (CX-pe8d batch, expanded): dangling bootstrap exits + un-takeable cloak, @unlink/@destroy, in-world presence visibility, one-bot-per-session opaque error, @verbs listing, emote conjugation, @teleport/@go for builders, give/receive.
DESIGN-GATE: CX-ndvi safe-verbs (plan-owned, I review).
NOT in this epic: CX-j30w (escript flock-NIF regression — filed separately, not MUD).

---

## CX-uwam  [in_progress]  p2  type=feature
created=2026-07-07T04:11:53Z  updated=2026-07-07T04:22:33Z  claimed_by=nil
TITLE: Key-gated container: take-from bypasses custom key-check (the 'lock is theater' gap)

Playtest headline (boss #6081): a vault gated by a CUSTOM actor_carries? unlock verb is walked around by the BUILTIN 'take X from vault' — no key, no unlock, treasure handed over. The two lock mechanisms don't COMPOSE into a per-player key-gated container: (a) the declarative locked flag (CX-cj3t.8) DOES gate take-from but a verb releasing it via put_state(locked:false) is GLOBAL (once open, anyone takes) — not per-taker; (b) the custom actor_carries? verb checks the key but only guards its own verb, not the builtin take-from path. The airtight answer is the BEFORE_GET HOOK (CX-cj3t.8's deferred high-trust half): a container lock-predicate evaluated at take-time against the TAKER's inventory (actor_carries?). HIGH-trust (new execution trigger at the builtin take-from boundary) — needs plan admit-set/keystone review. Interim: document the declarative-lock + unlock-verb composition (works today, global-unlock) for discoverability. Under CX-nphu; relates to CX-cj3t.8.

---

## CX-rmk  [in_progress]  p2  type=feature
created=2026-04-09T02:19:55Z  updated=2026-08-05T21:49:05.965110Z  claimed_by=nil
TITLE: Layer 2 MCP server for commonplace channels

Build an MCP server that makes an AI agent a participant in the commonplace document graph. Exposes the L2 channel surface (magenta commands, red event logs, blue docs) and CLI verbs as tools.

Per commonplace-plan design and boss-clod scope:

Tools:
- send_magenta(path, type, payload)
- append_red(path, event)
- subscribe_magenta(path_glob) / tail_red(path) as MCP notifications
- CLI verbs as tools: checkout, branch_create, fork, merge, commit, gc

Resources:
- Blue docs readable as structured data
- Red chains as event lists with provenance
- Agent's own identity doc + .bot presence file

MVP per boss-clod: send_magenta + tail_red + a handful of CLI verbs. Enough to make an agent a graph participant.

---

## CX-4u03  [in_progress]  p1  type=feature
created=2026-07-07T16:54:33Z  updated=2026-07-10T16:05:22Z  claimed_by=nil
TITLE: Zone-ownership M2: growing zones — Tree.ChildMutation chokepoint + move-cleared zone-stamp

Converge the ~6 MUD tree-mutation helpers (bootstrap/player_session add_dir_entry, verbs add/remove_dir_entry, facade add_child_entry/unlink, move inline, presence inline) into ONE Tree.ChildMutation add_child/remove_child primitive that (a) does the schema mutation+commit AND (b) derives+maintains the child's zone-stamp from the parent's zone, as the SOLE stamp-writer (protection). Move-cleared zone-stamp: set-at-mint-under-Z, cleared/re-stamped at move-out (deterministic, laundering-free, O(1)). {:subtree,Z} capability scope + content-aware gate (like the presence carve W3): authorize a write to D iff D's zone-stamp==Z or descendant via zone-parent chain. Presence entries STAMP-EXEMPT (bound_identity governs them, plan #6359). This lets zone-owners build NEW rooms/objects in their zone that inherit coverage — the 'build your own world' headline. Design converged (memory zone-ownership-arc); loop plan on concrete wiring before building the trust-critical stamp-gate.

---

## CX-wkau  [in_progress]  p2  type=feature
created=2026-07-16T05:09:19Z  updated=2026-07-16T16:49:29Z  claimed_by=nil
TITLE: Self-host: ~20 gameplay verbs (take/drop/give/put/mine/smith/get/examine/search/…) are compiled-in dispatch_builtin, not doc-hosted engine modules → continue the Inc-1 pattern

SELF-HOSTING AUDIT (2026-07-16). WHAT/WHERE: apps/commonplace/lib/commonplace/mud/verbs.ex dispatch_builtin/3 — look/say/emote/inventory already route through EngineModule.run_verb (doc-hosted, CX-2xez Inc-1); STILL compiled-in as do_X/2: take/get/drop/give/put/mine/smith/recipes/who/home/go/examine/read/search/sit/stand/use/where (~1500 lines of verb bodies). WHY DOCUMENT-SHAPED: the MUD-as-documents thesis is to run verb BEHAVIOR from node-signed docs so a deploy becomes a doc-commit; 5 verbs done, the rest are the remaining slices — the gameplay verbs' orchestration behavior is verb-doc-shaped (much already has a Facade surface citizen verbs use). MIGRATION: incrementally route each gameplay verb through EngineModule (seed doc + compiled floor), following look/say. KEEP the security-core kernel-side — possession/trust ops (Bursar/HolderMove/Take/Mint gates) must NOT become player-editable; only the verb-ORCHESTRATION behavior moves to the doc (the BEHAVIOR/DATA-CONTRACT boundary engine_module's moduledoc already draws). Do the pure/stateless ones FIRST (search/sit/stand/where/examine/read), DEFER the possession verbs. RISK/EFFORT: MEDIUM-HIGH incremental — mechanism exists; per-verb care on the kernel-vs-doc boundary. Broad player-authored gated by CX-1azj; node-seeded doc-hosting safe now.

---

## CX-u7kj  [in_progress]  p3  type=bug
created=2026-07-10T05:53:48Z  updated=2026-07-10T18:18:28Z  claimed_by=nil
TITLE: MUD web console: excess vertical whitespace between command output blocks

LIVE jes web-play 2026-07-10: large vertical gaps between each command's output block in the scrollback. Front-end: CSS margin/padding on the turn rows (mud_live.ex ~:504 '.turn { margin-bottom: 0.5rem }' + per-out whitespace-pre-wrap possibly doubling blank lines) or stray blank lines in the render (e.g. trailing \n in outputs joined with \n). Fix: tighten .turn/.out spacing + strip redundant blank lines. Display bucket, deploy-direct.

---

## CX-cgs  [in_progress]  p2  type=feature
created=2026-03-26T01:59:05Z  updated=2026-03-26T04:15:39Z  claimed_by=nil
TITLE: Wiki-style web UI demo

Transform TreeLive into a wiki-like demo: page browsing, creating, editing, wiki-style [[links]], recent changes, page history. Build on existing Phoenix LiveView + CodeMirror + Y.js stack.

---

## CX-mxxe  [in_progress]  p2  type=bug
created=2026-07-13T16:13:58Z  updated=2026-07-13T16:29:58Z  claimed_by=nil
TITLE: MUD: examine dumps full verb state to any player — puzzle spoilers + actor_ref→name mapping leak

Black-box 2026-07-13 (fable, live :5199). 'examine <object>' appends a State: section listing every get/put_state key-value pair to ANY player, not just the object owner. Repro'd on: pebble in Copper Lantern (marker/n test state), orrery ('charge: 0' — spoils the 3-windings puzzle progress), and convergence — which prints the complete attuned roster as 'attuned:<actor_ref-uuid>: <name>' for all 7 souls plus 'sealed: true'. Two problems: (1) QoL/spoilers — any stateful puzzle's internals (counters, flags, solutions) are free to read, defeating knowledge-gated design; (2) privacy/identity smell — the @verb editor preamble explicitly instructs builders to key PRIVATE per-player state on actor_ref (e.g. score:<ref>, forecast:<ref>), and examine then renders every player's keyed state and the stable ref→display-name mapping publicly. actor_ref is the spoof-proof identity key (CX-a2gd); even if it can't be replayed in safe-verbs, broadcasting the mapping is unnecessary surface. Suggest: hide State: from non-owners (or behind @examine/builder flag), or let verbs mark keys hidden.

---

## CX-oj83  [in_progress]  p3  type=bug
created=2026-07-11T06:50:29Z  updated=2026-07-11T23:36:12Z  claimed_by=nil
TITLE: MUD NPE: newcomer critical path dead — Warded Vault brass KEY looted, no respawn; room copy still advertises it

Black-box 2026-07-11 (fable). The Start Room signpost's FIRST instruction to newcomers is 'Go DOWN first' → Ashfall Forge, whose forge sign says: lift the brass KEY from the ash, hold it, UNLOCK the vault. But the brass key is gone — room copy still says 'A brass KEY lies on the floor amid the ash', yet room contents are only: Warded Vault, ember brazier, forge sign. 'take brass key' → You don't see "brass key" here. 'unlock Warded Vault' → 'It won't budge — you need the key.' (gating works fine — the key item was simply looted by some earlier player and never respawns). Same ghost-key in the deeper 'The Warded Vault' room ('A brass key hangs on a hook' in copy, absent from contents). So the advertised newcomer questline is permanently dead-ended for every future player. This is the concrete instance of the looted-world thesis: unique key-gated content dies after one player. Fix options: (a) respawn/reset unique quest items, (b) per-player instancing of quest keys, (c) make the key a dispenser like the vein/dispenser pattern, plus update room copy to stop advertising absent items. Related: CX-uwam (lock is theater — take-from bypasses the same wards), CX-hkp6 (items vanish across deploys), CX-d1py (same signpost promises 'listen' secret that doesn't exist).

---

## CX-hqk5  [in_progress]  p2  type=feature
created=2026-07-07T00:25:43Z  updated=2026-07-07T01:15:04Z  claimed_by=nil
TITLE: Safe verbs are stateless + read-only: no way to build stateful mechanics (persistent flags, lit/unlit, score, gated puzzles)

EXPERIENCE PLAYTEST Cycle 2 finding (black-box via mud_send). Built a working combination-lock puzzle (brass strongbox in The Cellar: 'dial strongbox moon ale coin' opens it, clues seeded in object descriptions) and a 'read' payoff. It PROVES what's possible and what isn't.

THE CEILING: a safe verb's entire allowlisted Facade surface is effectively THREE functions —
  * Facade.say/2   — actor-attributed speech ('X says, ...')
  * Facade.emit/2  — unattributed room-wide broadcast (raw text; see CX-aw4r re: no attribution)
  * Facade.describe/2 — allowlisted but an observable NO-OP (compiles+runs, broadcasts nothing, sets nothing; either a bug or undocumented — worth a look)
Everything else I probed is BANNED: ALL read/state ops (get/set, get_state/set_state, prop/set_prop, remember/recall, get_description/description, read, flag), world introspection (contents, exits, actor, actor_name), world mutation (take/drop/give/move/set_desc/spawn), alt-broadcast (emote/broadcast/tell/announce/act/notify), and RNG (Enum.random, :rand.uniform). Pure-stdlib String.*/Enum.join/Integer.mod/if/case/<> all work.

CONSEQUENCE: a verb is a pure stateless function of (world, args) that can only speak/broadcast. You can build STATELESS puzzles — an arg-checker plus clues in descriptions, where the player holds progress in their head (the strongbox works exactly this way; it 'opens' only as narration). You CANNOT build any STATEFUL mechanic:
  - a door/box that STAYS unlocked after solving (no persistent flag)
  - a lantern that is lit vs unlit (no per-object state)
  - a score / counter / quest progress
  - a puzzle gated on 'already solved' or on carrying an item (can't read inventory/room)
  - anything one verb sets and another verb (or the same verb later) reads.

ASK: a bounded, owner-scoped per-object key/value primitive on the facade, e.g. Facade.get_state(world, key) / Facade.put_state(world, key, value), writing to the host object's own doc under the same owner-grant ceiling safe writes already use. That single addition unlocks the entire class of stateful MUD mechanics while staying within the capability model. (Pairs naturally with CX-aw4r attribution + CX-9plf RNG as the 'make verbs expressive' trio.)

---

## CX-0t2r  [in_progress]  p3  type=bug
created=2026-08-03T05:40:59Z  updated=2026-08-03T06:36:22Z  claimed_by=nil
TITLE: Reflog checkpointing silently dormant on the live serve since 2026-04-25; would be trust-denied if it ever fired

Hunt finding (CX-izol follow-on, 2026-08-03). VERIFIED live via read-only RPC. The 46 reflog checkpoint docs (identified by __schema_cid/__timestamp keys, writer = Commonplace.Reflog.Snapshot) have latest commits dated 2026-04-25 — checkpoints have not fired on the :5199 workspace in 3+ months. Two independent causes: (1) DORMANT — checkpoints are driven by Sync.Agent sync ticks and Reflog.CheckpointTimer (snapshot.ex:22), neither of which runs on the Mode-B Phoenix serve (no filesystem checkout sync loop); the CX-o8tx dirty-tracker telemetry attaches at boot but only marks dirty sets, nothing consumes them. (2) DENIED-IF-FIRED — Reflog.Snapshot mints all its create_chained_commit writes with NO signing context (signer nil, verified on the April commits), so under the serves accept_unsigned:false + local_write_gate:enforce posture every checkpoint write would be denied (a dormant sibling of the CX-egnh unsigned-writer class and the fixed CX-l5js presence pattern). Nobody noticed for 3 months, which itself says the reflog may not be load-bearing on this deployment. DECISION for jes: (a) retire/park reflog on serve deployments (document it as CLI-sync-era tooling), or (b) revive it properly: node-sign its writes (SignedWrite.opts_for pattern) + give the serve a checkpoint driver + skip presence-transient paths (CX-dm54 adjacent) so it does not amplify heartbeat churn like the April-era spine (19.7k-commit chains). Also note: those 19.7k-deep April chains are the docs my CX-klpi paged-walk work must page through if anything ever authorization-walks them — reflog docs are not code docs, so nothing does today (verified).

---

## CX-qat5.7  [in_progress]  p2  type=task
created=2026-07-06T05:33:01Z  updated=2026-07-06T17:20:13Z  claimed_by=nil
TITLE: MUD M1: server exposure — bind-beyond-localhost / tailscale / TLS (HUMAN-GATED, exposure)

⛔ HUMAN-GATED — do NOT build autonomously (boss #5642, my flag). Split from CX-qat5.6 (M1 plumbing). Binding the MUD/Phoenix server beyond localhost is a REAL-WORLD SECURITY ACTION with actual attack surface — needs explicit jes greenlight before ANY work. Scope when greenlit: expose the endpoint (tailscale sidecar or TLS reverse proxy), NOT raw public bind; the MUD stays LOCALHOST-ONLY until jes says otherwise. Pairs with the enforced-permissions M2 bar (children 3-5) — ideally exposure lands AFTER trust enforcement so an exposed server is already gated. Dep: CX-qat5.6 (the safe plumbing subset) + jes exposure greenlight.

---

## CX-73a3  [in_progress]  p2  type=feature
created=2026-07-08T14:53:46Z  updated=2026-08-05T21:49:24.917718Z  claimed_by=nil
TITLE: Read-scoping P3: read-enforce parity + the COMPLETENESS AUDIT (no-bypass)

THE load-bearing invariant: enumerate EVERY principal-facing read call-site and route it through Read.authorized? — a missed surface = a silent confidentiality leak (attack W4). The converge-audit (same BY-AUDIT completeness discipline as the safe-verbs exit-wrap + zone-stamp chokepoint). Until P3 holds, widening stays limited to trusted/invited users. Design: /home/jes/commonplace-plan/docs/plans/2026-07-08-read-scoping-white-channel-design.md (@ae8980f) §6 P3 / §2 §5.2.

---

## CX-nyj9  [in_progress]  p2  type=feature
created=2026-07-07T02:47:12Z  updated=2026-08-05T21:13:37.790328Z  claimed_by=nil
TITLE: Mint-with-behavior / spawn-from-template — configure a freshly-minted object (TRUST-SENSITIVE)

Object-economy #2 (boss #6016, agent's 'biggest expressiveness gap'). spawn/give_to_actor mint an INERT HUSK (name + 'no description'); a safe verb can only set_attr/put_state/etc. on its OWN bound object (facade.object_uuid), never the uuid it just minted -> you mint the noun but not its description/stats/verbs. A crafted sword can't carry a 'swing' verb or lore.

OPTIONS: (a) spawn-FROM-TEMPLATE — clone an existing template object dir (description + attrs + verbs) into the room/inventory, so the mint is a full object not a husk; (b) let the minting verb CONFIGURE the object it just minted (a scoped handle to set_attr/put_state/define_verb on the new uuid within the same run).

*** TRUST-SENSITIVE — plan KEYSTONE review REQUIRED before build. *** A verb writing VERBS onto a minted object is define_verb-on-a-new-object — this is where mint-with-behavior meets the safe-verbs authority model: the writes must stay invoker-signed + intersect owner_grant, and cloning a template's verbs must not launder authority (a template's verbs run as WHOSE authority?). This is the object-economy analog of the object-lifecycle keystone. Under CX-nphu; do NOT build without plan's admit-set/keystone review + the authority model pinned.

---

## CX-q9aj  [in_progress]  p2  type=task
created=2026-04-25T03:59:19Z  updated=2026-04-25T04:04:48Z  claimed_by=nil
TITLE: Smoke-test commonplace MCP tools per boss-clod ask

boss-clod relayed jes ask to test system tools (cat/fork/write/send_magenta/tail_red roundtrip) and CX-y3q dynamic tool surface (list_tools, call_tool). Report findings via clod-squad.

---

## CX-2o9o  [in_progress]  p2  type=bug
created=2026-07-07T00:16:01Z  updated=2026-07-13T17:12:42Z  claimed_by=nil
TITLE: Safe-verb gate: compile errors are surfaced opaquely ('errors have been logged') — hide the real diagnostic + line

EXPERIENCE PLAYTEST finding (black-box via mud_send, @verb author path).

The safe-verb allowlist gives INCONSISTENT feedback. Disallowed calls are handled two different ways:
  (a) CLEAN lint rejection — e.g. saving a body with Enum.random(...) → '(rejected: uses a disallowed operation — {:disallowed, ["Enum.random/1 is not allowed"]})'. 
  (b) OPAQUE compile failure — e.g. Enum.join/2 and String.replace_prefix/3 pass lint (no disallowed message) then fail at compile: '(saved with compile error: docref:/<uuid>: cannot compile module Commonplace.MUD.UserVerb.V<hash> (errors have been logged))'. The actual reason + line are hidden from the author; 'errors have been logged' points at a log the author can't see.

REPRO (both are single-line bodies):
- @verb x:t1 -> Commonplace.MUD.World.Facade.emit(world, Enum.join(argv, "-"))  => opaque compile error
- @verb x:t2 -> Commonplace.MUD.World.Facade.emit(world, String.replace_prefix(args, target, ""))  => opaque compile error
- CONTRAST @verb x:t3 -> Commonplace.MUD.World.Facade.emit(world, String.upcase("hi"))  => compiles cleanly (String.upcase allowed)

So the allowlist is function-level, but only SOME out-of-allowlist calls are caught by lint; the rest produce an unreadable compile error. An author cannot tell 'I used a banned function' from 'I have a real bug', nor which call/line caused it.

SUGGEST: run the same allowlist scan that produces the clean {:disallowed, [...]} message over ALL calls before compile, so every disallowed call surfaces as 'X/N is not allowed'; and for genuine compile errors, surface the compiler diagnostic (message + line) to the author instead of 'errors have been logged'.

---

## CX-cj3t.10  [in_progress]  p3  type=feature
created=2026-07-07T01:53:02Z  updated=2026-07-07T04:01:34Z  claimed_by=nil
TITLE: Directed / self-only messaging Facade primitive (whisper / tell-actor / per-player outcome)

Playtest next-tier #4 (boss #5987). say/emit/emit_action all broadcast ROOM-WIDE; there's no whisper, message-the-actor-only, or per-player-different-outcome. A safe directed-emit primitive — e.g. Facade.tell(world, text) (to the invoker only) — would enable secrets/private results. Server-authoritative recipient (the invoker), no cross-player targeting of arbitrary victims (that's an info/impersonation surface — restrict to self/invoker). Facade-extension + plan-review-admit-set pattern. Repo /home/jes/commonplace.

---
