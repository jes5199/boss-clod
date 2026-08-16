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
KNOWN REDS ON main (as of e397021c, 2026-08-16 18:08Z) — NOT YOURS. Anything else IS.

① STANDING — MUD render defect. ⚠️ CURRENTLY NOT FIRING. THE ENTRY STAYS.
   MUD.RoomVisibilityTest     — owner's own look on their gated room
   MUD.WebPlayIntegrationTest — citizen spawns in owned home
   Symptom: "(this place has no description)".
   Full suite at seed 117514, CURRENT (e397021c): 5 doctests, 3553 tests,
   0 FAILURES, 12 excluded, 1 skipped — measured by commonplace, population
   predicted by hand (3548 + 5) BEFORE measuring and matched exactly.
   ⛔⛔ THIS IS NOT FIXED, RESOLVED, OR CLOSED, AND THE ENTRY MUST NOT BE DELETED
      FOR BEING GREEN. Observed sequence:
          population 3541 → 2 failures
          population 3546 → 1
          population 3548 → 1
          population 3553 → 0     ← a green that proves nothing
      THE ENTRY'S CLAIM IS THAT THE COUNT IS ARRANGEMENT-DEPENDENT, SO A ZERO IS
      EXACTLY AS UNINFORMATIVE AS A ONE. Neither a zero nor a nonzero is a signal.
   ⛔ A KNOWN-RED DELETED WHILE GREEN IS A TRAP ARMED FOR WHOEVER ARRIVES NEXT:
      the next round that adds tests and sees it red has no block to check, is
      told by our own rule that unlisted failures are ITS, and hunts a defect
      that is days old.
   ✅ STILL DETERMINISTICALLY REPRODUCIBLE at seed 117514 / population 3541 via
      the recipe (fc7d4bf6). The handle is intact; it is simply not firing here.
   MECHANISM: ARRANGEMENT, not count and not code — the same tests at seed 424242 are GREEN.
   Reproducer + eight dead leads: dba2e59e, d19361f7, deaa6464. Landed red at cf430433
   under commonplace-plan's escape condition; the red is the documented MUD mechanism,
   NOT S94 (per-file S94: 10 tests, 0 failures, boot verified).
   ⛔ DO NOT CHANGE THE SEED TO MAKE IT PASS. That trades a DETERMINISTIC red for an
      INTERMITTENT one, which gets attributed to whoever is unlucky rather than to the
      defect — and it destroys the only handle anyone has on this class.
   ⛔ MECHANISM IS UNMEASURED and the one named closing condition is SPENT (lead ⑧: the
      CX_LOOKDENY name=:look denial is fixture background — RED 117514 and GREEN 424242
      are IDENTICAL, 11 lookdeny / 2 name=:look / signer not in trusted set, both arms).
      No further round on this without a NEW FACT. A measurement is a fact; an idea is not.
   ⛔ A failure with a DIFFERENT symptom in these files IS yours.
   ⛔⛔ IF YOUR ROUND ADDS TESTS, THE POPULATION CHANGES AND SO DOES THE ARRANGEMENT.
      At 3553 + N this pair MAY COME BACK RED OR GREEN, and NEITHER IS A SIGNAL ABOUT
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

③ STANDING RED IN GITHUB CI ONLY — UNATTRIBUTED. GREEN ON HOST.
   ⚠️ SCOPE IS LOAD-BEARING: these fail in the GitHub Actions runner and PASS ON HOST.
      If you see them fail ON HOST, that is NEW and it IS yours — say so.
   GitHub CI on main: 100 of the last 100 runs failed. Last green 2026-08-13 08:54Z.
   Newest run: 3541 tests, 9 failures, seed 172334 (CI does NOT pin a seed).
     Commonplace.Runner.LauncherTest
       · pod holds its own signing key and not the durable key, proven by effect
       · wrong handle fails while captured handle reaps the process unit
       · live-process channels are unreachable behind containing-directory masks
       · executes by effect with its five-variable constructed environment
       · pod cannot read a canary injected by its launching BEAM      (= ② above)
     Commonplace.Runner.LauncherRecipeTest
       · recipe requires gates placement before launch, with a satisfying control
       · changing only recipe run changes the observed worker effect
       · recipe env names resolve only from the constructed placement allowlist
     Commonplace.Runner.TwoDeploymentPodProofTest
       · two deployments in separate pods: B resolves A's yield, and cannot without it
   ⛔ UNATTRIBUTED — NOBODY HAS EXPLAINED THESE. Recording them is NOT accepting them.
      An unexplained red RECORDED as unexplained cannot mis-blame the next round.
   ⛔ THE MUD PAIR (① above) IS ABSENT FROM CI — 0 occurrences, positive control:
      the same grep hits LauncherTest 9×. CI rolls a fresh arrangement every run and
      has never met ①. ⇒ FIXING ① WILL NOT TURN CI GREEN. They are different defects.
   ⚠️ TODAY'S NINE ARE NOT THE ORIGINAL SET. The first red run (31687219046,
      2026-08-13 09:34Z, seed 198228) was 3456 tests, 4 failures, ALL LauncherTest.
      The other suites did not exist yet. Do not brief a fix against today's list.
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
