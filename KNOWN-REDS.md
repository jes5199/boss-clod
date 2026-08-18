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

## ⭐ THE THREE ENTRY TYPES ARE NOT INTERCHANGEABLE

```
KNOWN RED           a failure a round WILL SEE. Unconditional. "Not yours."
KNOWN TRIGGER       a failure a round will see ONLY IF IT DOES X.
                    A round that changes nothing NEVER meets it.
KNOWN INTERMITTENT  a failure a round MIGHT see, at a MEASURED RATE, with no
                    action of its own summoning it. Carries its rate or it is
                    not this type — "flaky" without a number is a shrug.
```
⛔⛔ **THE THIRD TYPE WAS ADDED 2026-08-18 BECAUSE ITS ABSENCE HAD A COST.** `CLI.SnapshotTest` is an
intermittent I MEASURED on 2026-08-16 (0 failures ×5, 1 failure ×2 over seven runs) and wrote into
this file's **changelog** — where it sat for two days while the **block** never mentioned it. It went
red again on 2026-08-18 and, by our own rule, would have been a round's to hunt.
⚠️ **AND THE ENTRY I THEN WROTE WAS ITSELF WRONG WITHIN THE HOUR — I keyed it on ONE assertion string,
and the very next red I read was a DIFFERENT test in the same module.** ⇒ ⭐ ***That is entry ①'s
instance-③ failure repeating in a new module: keying on the symptom string is as narrow as keying on a
module is broad, and I had the lesson written down twelve inches above where I made the mistake.***
Re-measured: ~30% of push runs, two assertions, mechanism unknown.
⭐ **The taxonomy was the reason: it is not STANDING (it passes most runs) and it is not a TRIGGER (no
action summons it), so there was no shelf to put it on and it stayed in prose.** ⚠️ ***A missing
CATEGORY is quieter than a missing entry — nobody notices the shelf that does not exist.***
⇒ ⛔ **AND THE CHANGELOG IS NOT THE BLOCK. Writing it down in this file is not the same as putting it
where it gets pasted** — which is the exact `CX-kacr` failure named at the top, recurring in the one
file that documents it.
⛔ **Filing a TRIGGER as a RED tells a round "not yours" about a failure it cannot see — and reads as
"main is red" when main is green.** ⛔ **Filing a RED as a TRIGGER tells it the opposite.** ⭐ **The
block's whole purpose is telling a round what to disown; a wrong type teaches it to disown generally.**

⭐ **ENTRIES ARE BY TEST + MECHANISM, NEVER BY MODULE.** A module-scoped exemption is an **absorbing
category**: it silently covers every future failure in that container, including ones that do not
exist yet. **Always name the failing assertion's SHAPE, and say that a different shape IS theirs.**

---

# ▼▼ THE BLOCK — paste from here to the end marker ▼▼

```
KNOWN REDS ON main (as of ff071567, 2026-08-18 07:45Z) — NOT YOURS. Anything else IS.

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
      were correctly left untouched. Full suite at (a): 3580 tests, 0 failures.
      (b) e66f706c — verify-at-serve: last_good stores {module, md5} and checks
      it at BOTH serve doors; mismatch ⇒ floor + named alarm, unloaded or
      unverifiable entries REFUSED rather than served. THE FIX SPACE IS CLOSED.
   ⛔ A LINE SAYING "(b) IS NOT DONE" STOOD HERE FOR ~40 MINUTES AFTER THE LINES
      ABOVE SAID IT HAD LANDED — TWO ADJACENT CLAIMS IN OPPOSITE DIRECTIONS, in
      the one file whose entire purpose is that a round can trust what it pastes.
      ⇒ IT CAME FROM EDITING THE NEW STATE IN WITHOUT DELETING THE OLD STATE OUT.
        An append is not an update, and a block is not a changelog: the changelog
        is below the end marker precisely so the BLOCK can hold one present tense.
      ⇒ ⭐ AFTER EVERY EDIT HERE, READ THE WHOLE ENTRY BACK — a diff shows what you
        added and CANNOT show what it now contradicts.
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
   Full suite CURRENT: 3582 tests, 0 FAILURES, 16 EXCLUDED — and the two halves
   of that line have DIFFERENT AS-OFS, which is the point of stating both:
       3582 tests   as of 80d6e962   (3581 + 1, the gc7q refusal test; delta
                    predicted by its author BEFORE the run, and CI agreed)
       16 excluded  as of 1d502586   (12 + four perf arms deliberately :scale)
   ⛔ AN EXCLUSION COUNT IS PART OF THE POPULATION, NOT A FOOTNOTE. A round that
      compares 3581 against a run with a different :scale posture is comparing
      two different suites and will read the gap as its own defect.
   ⚠️ EARLIER READINGS, kept so the deltas stay legible: 3580/0 at 316f7b53
      (post-(a)); 3569 tests / 1 FAILURE (MUD.HumanWebPlayTest) at 0d4163ac
      (pre-fix, seed 117514).
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

- **`CLI.SnapshotTest` ~30% intermittent — CLASS CLOSED at `ff071567`** (merge of `8cda4bf0`, verified on
  `origin/main`; 3 `Path.expand` additions across `application.ex` + `commit_store.ex`).
  ⛔⛔ **THE POLARITY FLIPPED, WHICH IS WHY THIS COULD NOT STAY IN THE BLOCK.** For four hours the entry said
  *"a lone snapshot-command red is NOT YOURS."* **After `ff071567` a red there is a REGRESSION and IS yours.**
  ⇒ ***An entry that outlives its fix does not merely go stale — it INVERTS, and it keeps telling rounds
  "not yours" about a live defect.*** That is `CX-7rjn` verbatim, named at the top of this file, and the
  only thing that stopped it repeating was that commonplace said the era had ended at that sha.
  **THE FIX:** `Path.expand` at both doors — `application.ex`'s two boot captures and `CommitStore.init`
  before join/lock/CubDB — each with a why-comment at the line citing `sol/s-snapshot-fresh-s3`, so the next
  reader who thinks the expand is gratuitous trips over the reason where they stand.
  **THE CLASS ARM, not just the crash arm:** post-fix 402 reps green **and** exactly one commits store exists
  at the boot-resolved path, with the app-dir store never appearing. ⭐ **Asserting the ABSENCE of the
  two-stores symptom is what proves the class died rather than this instance.**
  **Suites at land:** commonplace 3582/0 · cli 121/0. Scale lane's first real **cron** firing (run
  `32111305447`, `event=schedule`) came back **SUCCESS** — green in its true habitat, first try, ~45 min
  after the 06:43 slot (scheduler lag worth knowing before calling a future firing "missing").
  **THE ARC:** 1 observation not in the block → mis-blamed to the next CLI toucher → flake entry → 4 obs →
  rekeyed on module+shape after a same-module sibling → reproduced n=1 → bounded null that INVERTED my n=1
  rule → mechanism confirmed by watching the window close → fixed at both doors. **Four Sol rounds in one
  night, every verdict verified on raw bytes before relay.**

  <details><summary>the entry as it stood in the block at retirement</summary>

```
④ KNOWN INTERMITTENT — Commonplace.CLI.SnapshotTest (commonplace_cli, 121 tests).
   ⛔ TWO KNOWN ASSERTIONS, AND THE SECOND IS WHY THIS ENTRY WAS REWRITTEN WITHIN
      THE HOUR OF BEING WRITTEN:
        "snapshot command returns :path_not_found when the path does not resolve"
                                          ×2  (0bf50a30, a2efb172)
        "snapshot command writes a snapshot commit for the resolved doc"
                                          ×2  (bb086a53, 80d6e962)
   MEASURED RATE: 4 of the last 11 completed push runs (2026-08-18 06:00Z), and
   separately 2 of 7 on 2026-08-16 — call it ~30-35%, not a rarity.
   ⭐ ONE CAPTURED ERROR BODY (80d6e962, by commonplace — the first anyone has
      taken for this flake). ⛔ READ IT AS ONE OBSERVATION'S SHAPE, NOT AS THE
      MECHANISM: it is a single sample and the entry does NOT claim it explains
      the other three.
        ** (exit) exited in: GenServer.call(Commonplace.Store.CommitStore,
             {:create_commit, ...}, 5000)
           ** (MatchError) no match of right hand side value: {:error, :enoent}
               (cubdb 2.0.2) lib/cubdb.ex:1499: CubDB.trigger_compaction/1
      ⇒ CubDB COMPACTION crashed on :enoent inside the app-default CommitStore
        during the snapshot's create_commit — the store's files were missing when
        compaction fired.
      ⚠️ IF YOUR RED HERE HAS A DIFFERENT ERROR BODY, SAY SO — a second shape
         would mean this entry covers two things and needs splitting, and that
         is worth more than another sighting of the same one.
      ✅ ASKED AND ANSWERED 2026-08-18 06:10Z: the reproduction's inner crash is
         BYTE-IDENTICAL to the CI body above. The OUTER frame differs — CI crashed
         in Snapshot.do_run (test body), the repro in the file's SETUP at line 41 —
         and that is NOT a split: same store, same call, same CubDB failure at the
         same line, different phase. THE MODULE+LONE-RED KEY HOLDS.
   ✅✅ REPRODUCED 2026-08-18 (S-snapshot-repro-s1, in-sandbox, rep 4, seed 1745).
      THE HANDLE — a FRESH worktree (see the warning below), then:
        mix test <cli snapshot test file>:71 --repeat-until-failure 200
      → red within ~4 reps (n=1).
      ⛔⛔ THE HANDLE IS SINGLE-USE PER CHECKOUT — READ THIS BEFORE CONCLUDING
         "NOT REPRODUCIBLE". S-snapshot-mech-s2 ran 603 instrumented reps in the
         SAME worktree that fired at rep 4 and got ALL GREEN. The crash window
         CLOSES PERMANENTLY once any invocation boots at app cwd — the reproducer
         is SELF-EXTINGUISHING per checkout. (Read as a labeled guess at 06:10Z;
         CONFIRMED by s3 at 06:20Z — see below.)
         ⇒ ⭐ IF THAT READING HOLDS: use a FRESH worktree. Re-running the recipe
           on a worktree that has already been exercised produces a null that
           means "window closed", NOT "bug absent" — AND THOSE TWO ARE THE SAME
           OBSERVATION FROM OUTSIDE. This annotation exists so that a null here
           is not mistaken for a disconfirmation.
         ⇒ IT ALSO EXPLAINS THE ~30% CI RATE WITHOUT ANY NEW MECHANISM: every CI
           run is a fresh checkout, so the window is always open there.
      ✅✅ CONFIRMED 2026-08-18 06:20Z (S-snapshot-fresh-s3, artifacts 05475ffc on
         sol/s-snapshot-fresh-s3, verified on origin — 71 log files). THE LABEL
         ABOVE HAS GRADUATED: this is no longer a reading.
         OBSERVED, in a verified-FRESH worktree, the window closing LIVE:
             invocation 1  red at rep 7
             invocation 2  red at rep 1
             invocation 3  red at rep 1 — app-dir commits/ flips absent→present
             invocations 4-5  402 consecutive greens, zero compaction crashes
         MECHANISM: CubDB's State.data_dir is RELATIVE, and mix has a boot-vs-test
         CWD SPLIT. Compaction CREATES BY PATH. ⇒ NOTHING IS EVER DELETED — THE
         PATH'S MEANING MOVES. Once an invocation boots at app cwd the directory
         exists there, the window shuts, and that checkout never fires again.
         ⇒ ⭐ THE HARNESS IS NOW NEAR-DETERMINISTIC: fresh worktree ⇒ red by ~rep 7.
           A fix round has a red-first handle waiting for it.
         ⇒ ⛔ AND THIS RETROSPECTIVELY GROUNDS THE RETRACTION ABOVE: accumulation
           does not make it MORE likely — ACCUMULATION IS WHAT CLOSES THE WINDOW.
           My n=1 rule was not merely unsupported, it was backwards. Artifacts: branch sol/s-snapshot-repro-s1 @
      fcdd72da (stage logs + ACCEPTANCE.md + brief), verified present on origin.
      ⛔ DO NOT DELETE THAT BRANCH — it is the only durable copy of the REPORT.
      ⛔⛔ AND THE BRANCH DOES NOT PROTECT THE REPRODUCER. Measured 2026-08-18:
         the habitat is /home/jes/sol-snapshot-repro/wt/tmp/test_data (~1 MB of
         accumulated commits) and it is GIT-IGNORED (.gitignore:27 "tmp/").
         ⇒ IT IS IN NO COMMIT, ON NO BRANCH, AND ON NO REMOTE. A single
           `git clean -xfd` in that worktree destroys the precondition — and -x
           is exactly the flag someone reaches for to "tidy up a Sol worktree".
         ⇒ ⭐ THE ARTIFACT AND THE PRECONDITION HAVE DIFFERENT LIFETIMES AND
           DIFFERENT PROTECTIONS. Pushing the branch felt like durability and
           covered only half of what makes this reproducible.
         ⇒ IF THE HABITAT IS LOST: it is re-creatable (run the cli snapshot file
           a few times in a worktree to accumulate commits), just not free.
      WHAT IT NARROWS, as facts and not as a mechanism:
        · fired with ONE test in the BEAM ⇒ within-VM cross-test interference is
          EXCLUDED for the reproduced instance; what persists across reps is DISK
          state (tmp/test_data accumulating commits every rep).
        · 30× whole-cli-app runs ALL GREEN, zero trigger_compaction occurrences.
        · --repeat-until-failure does NOT hold the seed — every rep printed a new
          one, so seed is not the variable.
      ⚠️ STILL NOT THE MECHANISM, and the entry does not claim it. A handle that
         reproduces is not an explanation; it is what makes one affordable.
   ⛔ NOT "STANDING" AND NOT A TRIGGER. If your push goes red ONLY here, RE-RUN
      BEFORE INVESTIGATING: at ~30% a single red carries almost no information.
      ⚠️ THIS LINE HAS BEEN WRONG IN BOTH DIRECTIONS IN ONE HOUR, WHICH IS ITSELF
         THE WARNING. At 06:10Z I wrote that the bug was "driveable on a dirty
         worktree" — accumulated local state summons it. At 06:25Z a 603-rep run
         on that same dirty worktree came back ALL GREEN, and the current reading
         is closer to the OPPOSITE: a fresh checkout is what has the open window,
         and accumulation CLOSES it.
         ⇒ ⭐ I BUILT A RULE ON n=1 AND STATED IT AS A PROPERTY. The single
           reproduction was real; the generalisation from it was mine and it did
           not survive the second measurement.
         ⇒ WHAT SURVIVES BOTH READINGS: in CI it fires at ~30% and nothing a
           round does summons it, so the type is still INTERMITTENT and the
           re-run rule above still stands. THAT is the part a round needs.
   ⛔ A DIFFERENT ASSERTION IN THIS MODULE IS PROBABLY STILL THIS ENTRY. Two of
      the module's tests have now failed with no code between them touching the
      CLI — so the entry is keyed on the MODULE plus the shape "a snapshot-command
      test fails alone, everything else in the run green", NOT on either string.
      ⚠️ THIS IS A DELIBERATE, NARROW EXCEPTION TO "NEVER KEY BY MODULE", and it
      is bounded by the shape: a commonplace_cli failure that is NOT a snapshot
      command test, or one that arrives alongside other failures, IS YOURS.
   ✅ MECHANISM KNOWN as of 2026-08-18 06:20Z (above) and a fix round is plan's to
      rank — candidate is Path.expand at capture time. UNTIL THAT LANDS the entry
      stays: a known mechanism is not a fixed defect, and CI still fires at ~30%.
      ⛔ THE RE-RUN RULE IS WHAT A ROUND NEEDS FROM THIS ENTRY. Everything below
         the rate is for whoever fixes it, not for whoever trips over it.
```
  </details>

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
- **2026-08-18 04:05Z** — ① population **`3580` → `3581`, and `16 EXCLUDED` added**, flagged by commonplace.
  ⭐ **THE TWO HALVES CARRY DIFFERENT AS-OFS ON PURPOSE:** `3581` as of `e66f706c`, `16 excluded` as of
  `1d502586` (12 + four perf arms deliberately behind `:scale`). ⛔ **An exclusion count is part of the
  population, not a footnote** — a round comparing 3581 against a run with a different `:scale` posture
  is comparing two different suites and will read the gap as its own defect.
  ✅ (b) `e66f706c` recorded in the entry: verify-at-serve at **both** doors, mismatch ⇒ floor + named
  alarm, unverifiable entries refused. **The fix space is closed; the entry is not** — it closes on the
  CI rate from `316f7b53`, not on the fix landing.
- **2026-08-18 04:12Z** — ⛔ **SELF-CAUGHT: THE BLOCK CONTRADICTED ITSELF FOR ~40 MINUTES.** Lines saying
  *"(b) landed, the fix space is closed"* sat directly above a surviving *"⏱ (b) PRODUCT-SIDE IS NOT DONE."*
  ⭐ **Cause: I edited the new state IN without deleting the old state OUT — an append is not an update.**
  ⚠️ **And my verification could not have caught it:** I checked that the block still *extracts* and that
  `--check` *round-trips*, both of which pass happily on a self-contradictory block. **A gate on FORM cannot
  see a defect in CONTENT.** ⇒ ✅ **New habit, now in the entry itself: after every edit here, READ THE WHOLE
  ENTRY BACK — a diff shows what you added and cannot show what it now contradicts.** Header as-of also
  corrected `316f7b53` → `1d502586`.
- **2026-08-18 05:35Z** — ⛔ **A THIRD ENTRY TYPE, `KNOWN INTERMITTENT`, AND ENTRY ④ (`CLI.SnapshotTest`).**
  ⚠️ **The cost was already paid before I noticed:** I measured this flake on 2026-08-16 (0 failures ×5,
  1 failure ×2 over seven runs), wrote it into **this file's changelog**, and left the **block** silent
  about it for two days. It went red again today at `a2efb172` — and by our own *"anything else IS yours"*
  rule, that was a round's to hunt.
  ⭐ **THE TAXONOMY WAS THE CAUSE, NOT CARELESSNESS: it is not STANDING and it is not a TRIGGER, so there
  was no shelf to put it on and it stayed in prose.** ⇒ ***A missing CATEGORY is quieter than a missing
  entry — nobody notices the shelf that does not exist.***
  ⛔ **And the changelog is not the block:** writing it down *in this file* is not the same as putting it
  where it gets **pasted**. That is the `CX-kacr` failure named at the top of this very file, recurring
  inside the document that documents it.
  ✅ Type carries a **measured rate or it is not this type** — "flaky" without a number is a shrug.
  Block extracts rc=0, `--check` round-trips, must-fail arm rc=3.
- **2026-08-18 05:47Z** — ⛔⛔ **ENTRY ④ REWRITTEN WITHIN THE HOUR OF BEING WRITTEN, AND THE REASON IS THE
  LESSON PRINTED TWELVE INCHES ABOVE IT.** I keyed it on one assertion string; the next red I read was
  `"writes a snapshot commit for the resolved doc"` — **a different test in the same module** — so the
  entry I had just added to prevent a misattribution would have produced one.
  ⭐ ***This is entry ①'s instance-③ failure, verbatim, in a new module: keying on the SYMPTOM STRING is
  as narrow as keying on a MODULE is broad.*** The file says exactly that, in the section directly above.
  ⇒ ✅ Now keyed on **module + shape** (*a snapshot-command test fails ALONE, everything else green*),
  with the "never key by module" exception called out as deliberate and **bounded** — a commonplace_cli
  failure that is not a snapshot-command test, or one arriving alongside others, is still theirs.
  ✅ **Rate re-measured: 3 of the last 10 push runs (~30%), two assertions**, superseding the 2-of-7 read.
  ⚠️ **Instrument note:** the loop I wrote to measure this labelled an IN-PROGRESS run as `RED (no
  SnapshotTest)`, because `gh run view --log-failed` returns nothing for a run that has not failed yet.
  **Empty output read as a verdict — the empty-corpus family, in a tool sixty seconds old.** Row five's
  result was NOT recorded.
- **2026-08-18 06:00Z** — ④ **FOURTH SIGHTING + THE FIRST CAPTURED ERROR BODY**, and ⑤ population `3581 → 3582`.
  Rate now **4 of the last 11 push runs**; the `"writes a snapshot commit"` assertion is at ×2, so both
  known assertions have now recurred — **the module+shape rekey was load-bearing within one run of being made.**
  ⭐ **commonplace captured the error body — the first anyone has taken for this flake in its recorded
  life** — and offered it rather than editing my file, which is the second time tonight it has respected
  that boundary. ⇒ **`CubDB.trigger_compaction/1` matching `{:error, :enoent}` inside a 5000ms
  `GenServer.call` to the app-default CommitStore during the snapshot's create_commit.**
  ⛔ **Recorded as ONE OBSERVATION'S SHAPE, explicitly NOT as the mechanism** — it is a single sample and
  the entry says outright that it does not claim to explain the other three. ✅ **And the entry now ASKS
  for the disconfirming case: a red here with a DIFFERENT error body means this entry covers two things
  and needs splitting, which is worth more than another sighting of the same one.**
  ⚠️ Population `3582` as of `80d6e962` — **the +1 was predicted by its author before the run and CI agreed**,
  which is the only version of a count claim that costs nothing to trust.
- **2026-08-18 06:12Z** — ④ **REPRODUCED, AND THE DISCONFIRMING CASE I ASKED FOR CAME BACK NEGATIVE — which is
  the answer that makes the entry trustworthy rather than merely confident.** The entry asked *"if your red
  here has a DIFFERENT error body, say so."* commonplace checked against raw bytes: **inner crash BYTE-IDENTICAL
  to the CI body; only the OUTER frame differs** (CI in `Snapshot.do_run`, repro in the file's setup at line 41).
  ⇒ **Same store, same call, same CubDB line, different phase — not a split.** The module+lone-red key holds
  **because it was tested against the case that would have broken it**, not because nothing challenged it.
  ✅ **Handle filed in the block** (dirty `tmp/test_data` + `--repeat-until-failure 200` → red within ~4 reps, n=1),
  branch `sol/s-snapshot-repro-s1` @ `fcdd72da` **verified present on origin** — ⛔ **that branch is the only
  durable copy of the reproduction and must not be reaped.**
  ⚠️ **READ-BACK CAUGHT A CONTRADICTION MY OWN EDIT CREATED:** the entry still said *"no action of yours summons
  it"* while now carrying a recipe that summons it. ⇒ ⭐ **Resolved by naming the HABITAT rather than deleting
  either half: intermittent in CI where every run starts clean, driveable on a dirty worktree. The TYPE is a
  claim about the environment, not about the test.**
  ⭐ **And a `counted` lesson observed in the wild, not by me:** commonplace's first broad `enoent` grep hit
  **30/30 logs** — all unrelated ambient flock warnings. **It read the hits, killed the false lead, and re-grepped
  the specific string to get the real zero.** A count nobody reads is a count that agrees with you.
- **2026-08-18 06:15Z** — ⛔⛔ **MY OWN "DO NOT DELETE THAT BRANCH" LINE PROTECTED THE WRONG HALF.** I pushed the
  branch, verified it on origin, and wrote *"the only durable copy"* — ⚠️ **but the thing that makes this
  reproducible is the worktree's `tmp/test_data`, and it is GIT-IGNORED (`.gitignore:27 "tmp/"`).** It is in no
  commit, on no branch, on no remote. **~1 MB of accumulated commits that one `git clean -xfd` erases** — and
  `-x` is precisely the flag someone reaches for to tidy a Sol worktree.
  ⭐ ***THE ARTIFACT AND THE PRECONDITION HAVE DIFFERENT LIFETIMES AND NEED DIFFERENT PROTECTIONS.*** Pushing the
  branch **felt** like durability and covered the report while leaving the reproducer one careless command from
  gone. ⇒ **"It's committed" answers a different question than "can this be re-run."**
  ⚠️ **Note the shape: I found this only because I checked whether a claim I had WRITTEN MYSELF was true** — the
  do-not-delete line was mine, one commit old, and I had not asked what it actually covered.
- **2026-08-18 06:28Z** — ⛔⛔ **ENTRY ④'s HANDLE ANNOTATED AS POSSIBLY SINGLE-USE, AND A CLAIM OF MINE RETRACTED.**
  s2 ran **603 instrumented reps in the same worktree that fired at rep 4** and got **all green**. The labeled
  reading: the crash window **closes permanently** once any invocation boots at app cwd — the reproducer is
  **self-extinguishing per checkout** — which also explains the ~30% CI rate with **no new mechanism**, since
  every CI run is a fresh checkout.
  ⭐ **ANNOTATED NOW RATHER THAN AFTER CONFIRMATION, and the reason is the whole point of this file:** the block
  told a reader to use *"a worktree whose tmp/test_data has ACCUMULATED a few runs' commits."* ⇒ **On an
  already-exercised worktree that recipe yields a null that means WINDOW CLOSED — and "window closed" and "bug
  absent" are the same observation from outside.** ⚠️ **A misleading recipe costs more than an unconfirmed
  label, so the label goes in and says plainly it is not established.**
  ⛔ **AND I RETRACTED MY OWN LINE:** at 06:10Z I wrote the bug was *"driveable on a dirty worktree"*; at 06:25Z
  the opposite reading is the better-supported one. ⇒ ⭐ ***I BUILT A RULE ON n=1 AND STATED IT AS A PROPERTY.***
  The reproduction was real; the generalisation was mine and did not survive the second measurement. **What
  survives both readings — ~30% in CI, nothing a round does summons it, re-run before investigating — is what
  the entry now leads with, because that is the part a round actually needs.**
  ✅ **Durability verified, not accepted on report:** `a56b6fd7` on origin carries both habitat tarballs
  (149,909 + 567,285 bytes) — **artifact and precondition now share a lifetime**, which is #12873 applied.
- **2026-08-18 06:30Z** — ✅✅ **④ GRADUATES: MECHANISM CONFIRMED, LABEL RETIRED.** s3 watched the window close
  **live** in a verified-fresh worktree — red at inv1/rep7, inv2/rep1, inv3/rep1 with app-dir `commits/` flipping
  absent→present, then **402 consecutive greens**. Artifacts `05475ffc` verified on origin (**71 log files**).
  ⭐ **MECHANISM: CubDB's `State.data_dir` is RELATIVE and mix has a boot-vs-test CWD split; compaction CREATES
  BY PATH.** ⇒ ***Nothing is ever deleted — the path's MEANING moves.*** Once any invocation boots at app cwd the
  directory exists there, the window shuts, and that checkout never fires again.
  ⛔ **AND IT SHOWS MY 06:10Z RULE WAS NOT MERELY UNSUPPORTED — IT WAS BACKWARDS.** I wrote that accumulated state
  *summons* the bug; **accumulation is what CLOSES the window.** ⚠️ ***An n=1 generalisation is not a weak claim,
  it is an untested one, and untested claims are as likely to be inverted as vague.***
  ✅ **The annotation I added BEFORE confirmation held on both operational points** — use a fresh worktree, and a
  null on an exercised one means window-closed not bug-absent. ⇒ **Annotating an unconfirmed reading cost one
  sentence of hedging and bought a correct instruction fifteen minutes early.**
  ⚠️ **Entry STAYS despite a known mechanism: a mechanism is not a fix, and CI still fires at ~30%.** The entry now
  says explicitly that the re-run rule is what a ROUND needs and the rest is for whoever fixes it.
- **2026-08-18 07:45Z** — ✅✅✅ **④ RETIRED — CLASS CLOSED AT `ff071567`, VERIFIED ON `origin/main`.** Block now
  carries ①②③ only; `SnapshotTest` appears **0 times** in the pasted block and 8 times in the file's retired
  section, which is the split this file exists to maintain.
  ⛔⛔ **THE REASON IT COULD NOT WAIT FOR MORE DATA: THE ENTRY'S POLARITY INVERTED.** For four hours it told
  rounds *"a lone snapshot-command red is NOT YOURS."* From `ff071567` onward such a red is a **REGRESSION** and
  **IS** theirs. ⇒ ***A known-red that outlives its fix does not go stale, it INVERTS — it keeps actively
  asserting the opposite of the truth.*** That is `CX-7rjn`, named in this file's own header, and the only thing
  that caught it in time was commonplace saying the era ended at that sha.
  ⚠️ **NOT recorded: the push run at `ff071567`.** It is `in_progress`, and I labelled an in-progress run as red
  once already tonight. **The first ceiling row where a SnapshotTest red would mean regression is still pending.**
  ✅ **Cron lane green in its real habitat** (run `32111305447`, `event=schedule`) — first firing, first try,
  ~45 min after the 06:43 slot. **Scheduler lag noted so a late firing is not read as a missing one.**
