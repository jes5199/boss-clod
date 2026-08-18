# KNOWN-REDS — the paste-ready block every commonplace brief inherits verbatim

⭐ **WHY THIS IS A FILE AND NOT A MEMORY.** I carried this block in my head and pasted it from
context, and it went wrong three ways in one day: a **stale** entry (`CX-7rjn`, fixed at `2e693cd6`,
still described as active), a **missing** entry (`CX-kacr`, carried as prose in board text and never
promoted into the block), and a **wrongly-typed** entry (the MUD failures, nearly filed as a standing
red while main was green). ⇒ ***A wrong line in a paste-ready block is one error per brief, inherited
verbatim, by rounds that cannot check it.*** A remembered rule does not fire; a file does.

⛔ **I OWN THIS FILE'S FRESHNESS.** Nobody else edits it. Every board I send pastes the block below
**as-is**. Anything not in the block **does not exist for a round** — by our own rule, *any other
failure IS yours*, so an omission makes a round correctly claim a defect that was never theirs.

⛔⛔ **AND THE CONVERSE, WHICH THIS HEADER LACKED UNTIL 2026-08-16 19:17 AND WHICH IS THE WORSE
DIRECTION:**
```
OMISSION  ⇒ a round CLAIMS a defect that was never its own
INVENTION ⇒ a round DISOWNS one that IS
```
⭐ **An invented entry is more dangerous because the round's error is INACTION, and inaction leaves
no artifact anyone can review.** An omission produces a wrong hunt somebody can see; an invention
produces a silence nobody can. ⚠️ **This is not hypothetical: a brief on 2026-08-16 listed
`GitBridge.ServerTest` (not in this file) while omitting the three `Runner.*` entries that are —
because it was copied from a previous brief rather than from here.**
✅ ⛔ **THEREFORE: PASTE THIS BLOCK FROM THIS FILE. NEVER FROM A PREVIOUS BRIEF, NEVER FROM MEMORY.**
**commonplace's `bin/cp-brief-known-reds --check <brief>` diffs a brief's block against this file in
BOTH directions — missing entries and invented ones.** ⭐ *A written rule that depends on someone
choosing to obey it is not a check; that command is.*

## ⭐ THE TWO ENTRY TYPES ARE NOT INTERCHANGEABLE

```
KNOWN RED      a failure a round WILL SEE. Unconditional. "Not yours."
KNOWN TRIGGER  a failure a round will see ONLY IF IT DOES X.
               A round that changes nothing NEVER meets it.
```
⛔ **Filing a TRIGGER as a RED tells a round "not yours" about a failure it cannot see — and reads as
"main is red" when main is green.** ⛔ **Filing a RED as a TRIGGER tells it the opposite.** ⭐ **The
block's whole purpose is telling a round what to disown; a wrong type teaches it to disown generally.**

⭐ **ENTRIES ARE BY TEST + MECHANISM, NEVER BY MODULE.** A module-scoped exemption is an **absorbing
category**: it silently covers every future failure in that container, including ones that do not
exist yet. **Always name the failing assertion's SHAPE, and say that a different shape IS theirs.**

---

# ▼▼ THE BLOCK — paste from here to the end marker ▼▼

```
KNOWN REDS ON main (as of 316f7b53, 2026-08-18 02:35Z) — NOT YOURS. Anything else IS.

① ⭐⭐ MECHANISM PROVEN 2026-08-18 AND THE FIX HAS LANDED — ENTRY STAYS OPEN
   PENDING CONFIRMATION OVER N CI RUNS. ⛔ IT IS NOT CLOSED, AND ONE GREEN DOES
   NOT CLOSE IT. Read the proof and the status before attributing anything here.
   ✅ THE MECHANISM, pinned by MODULE md5 rather than by narrative: test fixtures
      in engine_module_test.exs defined modules under the PRODUCTION names.
      Module names are BEAM-GLOBAL, so each fixture compile REDEFINED the real
      module's code for the whole run; last_good caches an ATOM, so the victim
      was served the fixture's code. The fixture passes no viewer → gated room →
      :read_denied → swallowed by a catch-all → missing room content. THAT is why
      only gated/private-room tests ever showed it.
   ✅ FIXES LANDED: (c) `85f357ce` — :mud_engine_manifest joins the leak
      detector's watchlist, the leak that hid it is now visible.
      (a) `316f7b53` / `e8f50d48` — the TEN production Engine* names renamed to
      *Fixture in test/; zero production definitions remain in test/; the five
      real-seed string assertions in seed_sources_test are PRODUCTION content and
      were correctly left untouched. Full suite 3580 tests, 0 failures.
   ⏱ (b) PRODUCT-SIDE IS NOT DONE: last_good still caches by NAME. Verify code
      identity at serve time (md5 beside the atom, mismatch ⇒ floor + NAMED
      alarm), red-first with a deliberately-redefined module REFUSED.
   ⛔⛔ WHY THIS ENTRY STAYS IN THE BLOCK ANYWAY: the family's CI rate is expected
      to COLLAPSE, and expected-to-collapse is a PREDICTION, not a measurement.
      The clock starts at `316f7b53`; it closes on consecutive CI runs, never on
      one green. Until then a matching failure is still NOT YOURS.
   ── the history below is what the entry looked like before the proof; it is
      kept because a recurrence needs it, not because it is still the state ──
   MECHANISM (as previously characterised): AN ARRANGEMENT-TRIGGERED MUD RENDER
   RETURNS WITHOUT ITS EXPECTED ROOM CONTENT. Same tests at a DIFFERENT SEED and
   the SAME POPULATION are GREEN — arrangement, not count and not code.
   ⇒ ⭐ AND THAT CHARACTERISATION WAS RIGHT BUT SHALLOW: "arrangement" was the
     OBSERVABLE of fixture-compile ORDER deciding whose code owned the atom.
   ⚠️ THREE KNOWN INSTANCES. This list is INSTANCES OF THE MECHANISM, not the
      definition of it — a FOURTH test showing the same mechanism is covered here
      even though it is not named yet. Tell me and I will add it.
     MUD.RoomVisibilityTest      — owner's own look on their gated room
     MUD.WebPlayIntegrationTest  — citizen spawns in owned home
     MUD.HumanWebPlayTest        — human_web_play_test.exs:214, "zyee: greet lands
                                   Welcome + room ... a later look returns its OWN
                                   room, not the stale banner"
   ⛔ THE ASSERTION STRINGS DIFFER AND THAT IS NOT A DISQUALIFIER. Two instances
      fail on "(this place has no description)"; the third fails on a MISSING ROOM
      NAME ("sam's Home") with that count at ZERO in the same run.
      ⇒ KEYING ON THE SYMPTOM STRING IS AS NARROW AS KEYING ON A MODULE IS BROAD.
        The first cost us: instance ③ arrived UNCOVERED because the block named a
        string rather than the mechanism.
   ⚠️ HONEST LIMIT: SAME FAMILY, SHARED MECHANISM NOT PROVEN. One symptom across
      two tests is corroboration, not proof, and the third has a third assertion.
   Full suite at seed 117514, CURRENT (316f7b53): 3580 tests, 0 FAILURES,
   measured by commonplace post-(a). ⚠️ THE PRE-FIX READING WAS 3569 tests /
   1 FAILURE (MUD.HumanWebPlayTest) at 0d4163ac — kept so the delta is legible.
   ⛔ AND BY THIS ENTRY'S OWN RULE THAT ZERO IS UNINFORMATIVE, THIS GREEN IS NOT
      THE CONFIRMATION. It is consistent with the fix and also consistent with
      the arrangement simply not firing. The confirmation is the CI rate over N.
   ⭐ CONTROL THAT MAKES IT ARRANGEMENT AND NOT S99's CODE — same population,
      different seed: 117514/3569 → 1 failure · 424242/3569 → 0 failures.
   ⛔⛔ THIS IS NOT FIXED, RESOLVED, OR CLOSED, AND THE ENTRY MUST NOT BE DELETED
      FOR BEING GREEN. Observed sequence:
          population 3541 → 2 failures
          population 3546 → 1
          population 3548 → 1
          population 3553 → 0     ← a green that proves nothing
          population 3563 → 1     ← RED AGAIN, ONE ROUND LATER. The trap fired for
                                    real: had this entry been deleted at 3553 for
                                    being green, S98 would have been told by our own
                                    rule that this failure was ITS.
          population 3569 → 1     ← a THIRD test, a THIRD assertion string
      THE ENTRY'S CLAIM IS THAT THE COUNT IS ARRANGEMENT-DEPENDENT, SO A ZERO IS
      EXACTLY AS UNINFORMATIVE AS A ONE. Neither a zero nor a nonzero is a signal.
   ⛔ A KNOWN-RED DELETED WHILE GREEN IS A TRAP ARMED FOR WHOEVER ARRIVES NEXT:
      the next round that adds tests and sees it red has no block to check, is
      told by our own rule that unlisted failures are ITS, and hunts a defect
      that is days old.
   ✅ STILL DETERMINISTICALLY REPRODUCIBLE at seed 117514 / population 3541 via
      the recipe (fc7d4bf6). The handle is intact; it is simply not firing here.
   MECHANISM: ARRANGEMENT, not count and not code — the same tests at seed 424242 are GREEN.
   Reproducer + the dead-lead table: dba2e59e, d19361f7, deaa6464 (3 commits; the
   TABLE holds eight rows — the commit count and the lead count are DIFFERENT NUMBERS
   and this line used to imply they were the same). Landed red at cf430433
   under commonplace-plan's escape condition; the red is the documented MUD mechanism,
   NOT S94 (per-file S94: 10 tests, 0 failures, boot verified).
   ⛔ DO NOT CHANGE THE SEED TO MAKE IT PASS. That trades a DETERMINISTIC red for an
      INTERMITTENT one, which gets attributed to whoever is unlucky rather than to the
      defect — and it destroys the only handle anyone has on this class.
   ✅ SUPERSEDED 2026-08-18 — this line used to read "MECHANISM IS UNMEASURED and the
      one named closing condition is SPENT ... no further round without a NEW FACT."
      ⭐ THE NEW FACT ARRIVED AND IT WAS AN ARTIFACT IDENTITY, NOT A REPRODUCER:
      FOUR minimal reproducers had already failed — two- and three-file sets stayed
      green at 14 seeds including forced order, because the atom's post-module state
      in small sets happened to be benign. Fishing for orders was the wrong search.
      md5 equality with the fixture compiles and INEQUALITY with the real seed was
      the discriminator narrative could not fake.
   ⇒ ⭐ TRANSFERABLE: when a defect resists minimisation, stop shrinking the input
     and start asking WHAT WAS ACTUALLY SERVED. Identity beats reproduction.
   ⛔ A failure in these files that does NOT match the MECHANISM above IS yours.
      (Not "a different string" — a different MECHANISM. If a render comes back
       missing expected room content and a same-population different-seed run is
       green, it is this entry, whatever the assertion says.)
   ⛔⛔ IF YOUR ROUND ADDS TESTS, THE POPULATION CHANGES AND SO DOES THE ARRANGEMENT.
      At 3569 + N these MAY COME BACK RED OR GREEN, and NEITHER IS A SIGNAL ABOUT
      YOUR WORK. Do not report "I fixed the MUD red" and do not report "I caused it" —
      both are available, both are plausible, and both are false. Report your per-file
      counts and the suite total WITH ITS POPULATION, and say nothing about causation.

② KNOWN TRIGGER — Runner.LauncherTest, "pod cannot read a canary injected by its
   launching BEAM". Environment-sensitive (CX-kacr); a stray tmux socket has triggered it.
   Fails as canary_result == "" where "absent" is expected — an EMPTY probe result, not a
   wrong one. Passes in isolation.
   ⛔ DO NOT "FIX" BY LOOSENING THE ASSERTION. That test refuses to treat "" as "absent",
      which is exactly why it goes red instead of quietly passing.
   ⛔ A DIFFERENT error shape there is yours.

③ ⭐ RESOLVED 2026-08-17 — THE FOUR-DAY CI RED IS CLEARED. Kept as a RETIRED entry
   below the block so nobody re-derives it. THREE STACKED CAUSES, all measured:
     ① bwrap NOT INSTALLED on ubuntu-latest   9 × {:error, :bubblewrap_not_found}
        → installed, AND verified at the install step by name
     ② unprivileged userns RESTRICTED          apparmor_restrict_unprivileged_userns=1
        → granted via AppArmor's OWN mechanism: bwrap registered under a scoped
          profile. THE DEFAULT IS UNTOUCHED. Approved by jes 2026-08-17 after he
          declined the sysctl flip AND initially declined this, then reversed.
        ⭐ RE-PROVEN EVERY RUN: the step copies bwrap to an unprofiled path and
          asserts THE COPY IS DENIED — if the machine is ever open, CI goes red.
     ③ THE FENCE'S OWN BUG: masks assumed their target dirs existed. They exist on
        THIS host only because a tmux is running. ⇒ ONLY A SECOND MACHINE COULD
        HAVE FOUND IT. The four-day red was the pod work's first portability test.
   ⇒ POD/LAUNCHER/RUNNER FAILURES IN CI: ZERO, for the first time in the fence's
     existence. Verified independently on run 32041543228 (log 2,220,484 bytes):
     bubblewrap_not_found → 0.
   ⚠️ THE EXIT CRITERION IS NOT MET. One green is one data point. Pre-fence baseline
      was 47/66 = 71% green, so a ~29% instability PREDATES the fence, is UNOWNED,
      and is now observable for the first time.
```

# ▲▲ END OF BLOCK ▲▲

---

## Retired entries — kept so they are not silently re-added

- **`CX-7rjn` handler defect** — **FIXED at `2e693cd6`**, verified at source (the handler now filters
  correctly). ⛔ **It sat in my block as ACTIVE after the fix.** ⇒ ***A known-red entry that outlives
  its fix is worse than a missing one: it tells a round "not yours" about a real, live red.***
  ⚠️ Its `count == 5` sibling remains **UNEXPLAINED** — not flake, not resolved — and closes on one
  captured ordinal-5 record carrying a signer. **Unexplained is not the same as red; it is not in the
  block.**

## Changelog

- **2026-08-17 04:56Z** — ③ **CORRECTED TWICE IN TWELVE MINUTES.** ⛔ **First I wrote "TEN, not nine" —
  commonplace corrected it: `CLI.SnapshotTest` is INTERMITTENT, not standing.** ✅ **Verified myself
  across seven completed runs whose logs actually contain the 121-test verdict: `0 failures ×5,
  1 failure ×2`.** ⚠️ **And my first check was itself vacuous — one of the two runs I sampled had a
  4,340-byte log because the format gate aborted before the tests ran, so "SnapshotTest absent" meant
  TESTS NEVER EXECUTED, not passed.** ⇒ ⭐ ***THE MASKING BUG BIT MY OWN VERIFICATION OF THE MASKING
  BUG.***
  ⭐ **And the standing nine have ONE cause: `{:error, :bubblewrap_not_found}` — `ubuntu-latest` does
  not ship bwrap and the workflow never installed it. NOT nine defects.**

- **2026-08-17 04:44Z** — ③ **THE COUNT WAS WRONG: TEN, NOT NINE.** ⛔ **`Commonplace.CLI.SnapshotTest`
  has been failing in a SECOND APP for four days, invisible, because *"9 failures"* was one suite's
  VERDICT LINE read as the run's total.** ⇒ **Verified independently: five verdict lines in run
  `31993906260`, ten named failures enumerated, log 2,226,700 bytes.**
  ⭐ ***A MEASURED NUMBER IS STILL SCOPED BY THE INSTRUMENT THAT PRODUCED IT, AND A VERDICT LINE'S
  SCOPE IS ONE SUITE.*** ⚠️ **The figure carried a MEASURED label in plan's queue and in this block.**

- **2026-08-16 20:00Z** — ① **RE-KEYED FROM A SYMPTOM STRING TO A MECHANISM**, and a **third
  instance** added (`MUD.HumanWebPlayTest`, `human_web_play_test.exs:214`) at `0d4163ac`.
  ⛔ **commonplace's catch, and it is my own rule biting from the other side: *ENTRIES ARE BY TEST +
  MECHANISM, NEVER BY MODULE* — but I keyed on the SYMPTOM STRING, and ⭐ keying on a string is as
  NARROW as keying on a module is BROAD.** ⇒ **Instance ③ arrived UNCOVERED: its assertion is a
  missing room name, and the block's named symptom counted ZERO in that same run — so by the block's
  own "a different symptom IS yours" line it was commonplace's until it proved otherwise.**
  ✅ **It proved otherwise the right way: same population `3569`, seed `117514` → 1 failure,
  seed `424242` → 0.** ⚠️ **Shared mechanism NOT proven and stated as such.**

- **2026-08-16 19:17Z** — ① **RED AGAIN at 3563** (`9a058eb9`, S98/rung 4a), one round after being
  green at 3553. ⭐⭐⭐ ***THE TRAP FIRED FOR REAL, ONE HOUR AFTER WE ARGUED ABOUT IT IN THE
  ABSTRACT.*** ⇒ **Had the entry been deleted at 3553 for being green, S98 would have been told by
  our own rule that this failure was ITS, and would have hunted a defect that is days old.**
  ⚠️ **Sequence now: `3541→2 · 3546→1 · 3548→1 · 3553→0 · 3563→1`. The block's claim is
  DEMONSTRATED rather than argued.**

- **2026-08-16 18:08Z** — ① main is **GREEN at 3553** (`e397021c`, S97 landed). ⛔ **Entry kept
  STANDING and marked CURRENTLY NOT FIRING — not fixed, not closed, not deleted.** ⭐ **The danger
  inverted: an hour ago the risk was a round CLAIMING CREDIT for the count dropping; now it is the
  entry being DELETED FOR BEING GREEN.** ⇒ ***A known-red deleted while green is a trap armed for
  whoever arrives next*** — the next round to add tests and see it red has no block to check and is
  told by our own rule that the failure is its. ⚠️ **`3541→2, 3546→1, 3548→1, 3553→0`: the entry's
  own claim makes a zero exactly as uninformative as a one.**

- **2026-08-16 17:20Z** — ① population updated to **3548** at `a052133c` (S95 landed), measured by
  commonplace. ⛔ **The "1 failure" is NOT recorded as "the pair is now one test"** — that would be a
  new standing claim built on three arrangements, and **the entry's whole point is that the count is
  arrangement-dependent.** Observed **2 @ 3541 · 1 @ 3546 · 1 @ 3548.** ⭐ ***The caveat's own claim
  arriving as data.***

- **2026-08-16 17:15Z** — ③ ADDED, **UNATTRIBUTED**, at commonplace-plan's instruction (`63d6996`).
  ⛔ **The trap it disarms: 8 of the 9 CI failures were in NO block anywhere, so our own rule
  (*any other failure IS yours*) told the next round they were its. Armed for three days.**
  ⭐ ***An unexplained red RECORDED as unexplained cannot mis-blame the next round — and recording
  it is not accepting it.*** ⚠️ **Plan's own finding: this was an INTAKE GAP, not a decision — it
  was never declined, it was never seen. It reached the queue only because someone measured and
  asked.** ⚠️ **Its scope is load-bearing in the other direction too: these are GREEN ON HOST, so a
  host-side failure in these files IS the round's.**

- **2026-08-16 16:40Z** — ① gained its **arrangement caveat**, from commonplace's S95 brief (trap ③).
  ⭐ ***A standing red can be misread as a RESULT in both directions by the same run.*** An entry that
  only says *"not yours"* is **incomplete for a round that changes the population** — it must also say
  ***"and a change in it is not yours either."*** Without that, a round does not stay silent: a changed
  observation demands an explanation, and the only nearby cause is its own diff.
- **2026-08-16 16:30Z** — ① INVERTED from KNOWN TRIGGER to **STANDING RED** on commonplace's word:
  S94 landed red at `cf430433` under plan's escape condition, as flagged in advance. Transition
  **announced, not discovered.** Population is now **3541**, not 3540 — the landing configuration
  carried one extra test (the red-first ordering arm), and for a defect whose trigger IS the
  arrangement that is **a different experiment**, so the measurement was re-run rather than carried
  forward.
- **2026-08-16 08:34Z** — ② promoted from prose caveat into the block.
- **2026-08-16** — `CX-7rjn` retired.
- **2026-08-18 02:40Z** — ① **REWRITTEN: MECHANISM PROVEN, FIXES (a)+(c) LANDED, ENTRY KEPT OPEN.**
  Population `3569` → **`3580`**, as-of `0d4163ac` → **`316f7b53`**. ⚠️ **commonplace flagged the stale
  population rather than editing my file, which is the right call** — the block has one owner and a
  second writer is how two versions start circulating in briefs.
  ⭐ **THE ENTRY DID NOT CLOSE, AND THAT IS THE POINT.** The suite is green at 3580/0 and the mechanism
  is proven, and *by this entry's own standing claim that a zero is uninformative,* **that green cannot
  be the confirmation** — it is equally consistent with the fix working and with the arrangement not
  firing this run. ⇒ ***The closing condition is the family's CI RATE over N consecutive runs from
  `316f7b53`, and a prediction that it will collapse is not a measurement that it did.***
  ⛔ **The trap this avoids is the one the entry has already survived once at population 3553:** a
  known-red deleted while green is armed for whoever arrives next, who is then told by our own rule
  that a days-old defect is theirs.
