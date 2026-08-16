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
KNOWN REDS ON main (as of cf430433, 2026-08-16 16:30Z) — NOT YOURS. Anything else IS.

① STANDING RED — MUD render defect. Main is RED.
   MUD.RoomVisibilityTest     — owner's own look on their gated room
   MUD.WebPlayIntegrationTest — citizen spawns in owned home
   Symptom: "(this place has no description)" ×2.
   Full suite at seed 117514: 5 doctests, 3541 tests, 2 failures, 12 excluded, 1 skipped.
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

② KNOWN TRIGGER — Runner.LauncherTest, "pod cannot read a canary injected by its
   launching BEAM". Environment-sensitive (CX-kacr); a stray tmux socket has triggered it.
   Fails as canary_result == "" where "absent" is expected — an EMPTY probe result, not a
   wrong one. Passes in isolation.
   ⛔ DO NOT "FIX" BY LOOSENING THE ASSERTION. That test refuses to treat "" as "absent",
      which is exactly why it goes red instead of quietly passing.
   ⛔ A DIFFERENT error shape there is yours.
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

- **2026-08-16 16:30Z** — ① INVERTED from KNOWN TRIGGER to **STANDING RED** on commonplace's word:
  S94 landed red at `cf430433` under plan's escape condition, as flagged in advance. Transition
  **announced, not discovered.** Population is now **3541**, not 3540 — the landing configuration
  carried one extra test (the red-first ordering arm), and for a defect whose trigger IS the
  arrangement that is **a different experiment**, so the measurement was re-run rather than carried
  forward.
- **2026-08-16 08:34Z** — ② promoted from prose caveat into the block.
- **2026-08-16** — `CX-7rjn` retired.
