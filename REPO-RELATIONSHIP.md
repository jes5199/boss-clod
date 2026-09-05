# ⭐ AN AGENT OWNS NO REPO — it owns a session and a set of permissions

**Written 2026-09-05T03:55Z. Proposed to jes in Telegram `11054`, agreed in `11055` ("uh okay legit").**
⚠️ **Taking that as agreement with the ANALYSIS and with writing it down. If he meant only the first,
this file is still true as a description of what the fleet actually did tonight.**

## The model that is written everywhere and is no longer how anything works
One agent per repo. It lives in `~/reponame`, that checkout is its home, and the name means both a
repo and a worker. ⇒ **The tmux windows, the peer names and half the docs still encode this.**

## What actually happened on 2026-09-04/05
**Four rounds ran in four disposable clones** — `astra-ci-1`, `astra-rsw3`, `codex-capture-psi-1`,
`codex-commonplace-landing` — each cloned from the ENDPOINT at a named commit, used once, left behind.
⇒ ⭐ **Nothing important lives in a working tree. It lives on a branch at the endpoint.** That is why
`REALM-REMOVE-1b` had to be rescued: it was real work existing ONLY as an uncommitted tree in a dead
door's checkout, one `git clean` from gone.

## ⛔ THE ONE RULE: A CHECKOUT HAS EXACTLY ONE WRITER
**Every mess of that night came from breaking it, in both directions:**
```
a codex door committed into /home/jes/boss-clod — MY live tree, 110 uncommitted paths in flight
I ran a pin gate in /home/jes/commonplace-next's PARKED checkout and got a 285-line variant of a
  352-line script, then reported it as "the gate" — two hours after telling that same door not to
  trust that directory (LESSONS 7x674)
```
⇒ ⭐ **Knowing a corpus is wrong does not stop you using it. Only checking AT THE MOMENT OF USE does.**

## ✅ THE FORM
```
clone fresh from the endpoint at a named sha  →  work  →  push a BRANCH  →  discard the directory
```
⛔ **`~/reponame` checkouts are NOT homes. They are stale scratch space** — several are parked on
months-old wip branches — **and a measurement taken in one is a measurement of the wrong corpus until
proven otherwise.** ⚠️ **`git -C <tree> branch --show-current` before quoting anything from a tree
you did not create.**

## ⚠️ UNRESOLVED: NAMING
**A worker called `commonplace-next` that clones `commonplace-next` into a temp dir is confusing, and
it is exactly what I misread twice on 2026-09-04.** ⇒ If agents are repo-agnostic they should be named
for what they ARE, not where they sit. **Not decided; flagged so the next reader does not think the
current names carry meaning they no longer carry.**
