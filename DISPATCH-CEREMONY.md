# Sol dispatch ceremony

How to put a round in front of Sol. Written down for the same reason as `DEPLOY-CEREMONY.md`:
**a filed artifact fires where a remembered rule does not** (LESSONS 7av). Nine dispatches on
2026-08-12 ran entirely out of context; every step below is one that cost something.

Wrapper: `sol-egress-run.sh` (refuses `SOL_WORKDIR=/home/jes/commonplace`, exit 64)

---

## 1. Verify the brief before building a prompt on it
- Brief present at its sha, and **ABSENT at the prior sha** — a token true at both shas discriminates
  nothing.
- **Re-derive the brief's load-bearing cites at HEAD.** Twice a peer's message carried a path with a
  plausible-but-wrong directory prefix (`store/…`, `chit/…`). ⛔ **A grep against a nonexistent path
  returns 0 hits, which looks exactly like the confirmed absence you were asked to verify.** Use a
  known-member positive control every time.
- If an instruction in the brief is **underdetermined** (the registry that had two naming
  conventions), say so before dispatch. *An omitted warning costs TIME; a contradictory one costs
  JUDGMENT.*

## 2. Branch naming
```bash
git worktree add /home/jes/sol-<round>/wt -b sol/cx-<ticket>-<round> <sha>
```
⛔ **NEVER name a branch from the ticket id alone.** Ticket ids are STABLE, so a name derived from one
is stable too — it **will** collide the second time that ticket is worked. On 2026-08-12
`sol/cx-1mn4` already existed from an earlier round; `worktree add -b` refused loudly.
⚠️ **The loud failure was luck.** Had the branch existed but been checked out nowhere, a `worktree
add` *without* `-b` would have silently put Sol on the old round's commits.
⇒ A name carrying the **round** is unique per attempt. A ticket id can never be.

## 3. Ticket ids in the prompt
- **State the work's id and say "AND NO OTHER ID."**
- **Label every other id by its ROLE**, because they are not interchangeable decoys:
  | shape | example | risk |
  |---|---|---|
  | preamble/setup id | CX-z5rm | became the artifact's citation when it was the only id supplied |
  | precedent | CX-5983 | reads as the work if unlabelled |
  | sibling round | CX-brxx / CX-3shs | active in the work, still not its citation |
  | **closed BY this round** | CX-37d9 / CX-kmtq | pattern-imitated and defect-fixed — *roles*, not citations |
  | **a different ticket that NEEDS this one** | CX-fbah vs CX-1mn4 | ⛔ working the wrong one licenses what this round forbids |
  | **a commit sha where an id is expected** | e2a6e0e | not a ticket at all |
- ⭐ **Give Sol an escape hatch pointed at yourself**: *if you need an id and only have those, that is
  a bug in my prompt — use \<work id\> and say I under-specified.*

## 4. Launch + fence, verified on the RUNNING process
```bash
SOL_WORKDIR=… nohup sol-egress-run.sh "$(cat prompt.txt)" > run.log 2>&1 &
```
- **Prompt reached argv**, not just the flags: `tr '\0' '\n' < /proc/<codex-pid>/cmdline | grep -c <id>`
- `-C` points at the worktree.
- ⛔ **Masks are verified in the SANDBOX'S namespace, not bwrap's.** bwrap shares the launcher's
  namespace and shows **0** masks — which looks exactly like an unfenced run (LESSONS 7at). Read
  `/proc/<child-pid>/mountinfo`; expect 6 masked of ~31 mounts.

## 5. While it runs
- **codex at 0% CPU with a busy beam is a healthy WAIT, not a stall.** Check the subprocess before
  calling anything wedged.
- ⛔ **`pgrep -f 'codex exec'` typed inline MATCHES YOUR OWN SHELL.** The nudge scripts anchor
  (`(^|/)codex (exec|resume)`) and are right when they disagree with an inline check (LESSONS 7av).
- Turn markers advancing ⇒ progress. A distinct-line ratio is a **bad** oracle for diff-heavy output.

## 6. On completion
- **Anchored refusal check** over codex's own output region — an unanchored grep matches your own
  prompt text *and* the suite's log lines (`refusing to pick one`).
- ⛔ **`git diff` does not contain new files.** An empty result for a property that lives in an
  untracked test file is a method artifact, not a missing property.
- Verify the round's **weighted** properties directly, and prefer proof over shape — see
  `DEPLOY-CEREMONY.md`'s appendix: *a forgery satisfies every equality check.*
- **Before trusting any zero, assert the corpus was non-empty.** `apps/*/lib` matches **0** files
  (git's `*` does not cross `/`); use `apps/**/lib/**` and count the matches first.

## 7. A failed dispatch is not a no-op
⭐ **"It didn't start" is a claim about the WRAPPER, not about what the shell already did.** A failed
`worktree add` still ran git. **Check the round's own fences before retrying, not after** — for S35
that meant confirming `git -C /home/jes/yelixer log origin/main -1` was unchanged and no remote refs
existed, since the round forbids pushing anything.

---

## Appendix — the pgrep self-match, six occurrences in one day

**2026-08-12.** The trap in §5 fired **six times across three agents**, and five of them were by
parties who already knew about it. Knowing it is demonstrably not enough; only the anchored form in a
FILE prevents it.

| # | who | shape |
|---|---|---|
| 1–3 | me, inline | `pgrep -f 'codex exec…'` matched my own shell three times: a Sol-in-flight check, a hermes BEAM check, and an S27-alive check that reported RUNNING after the run had exited |
| 4 | commonplace | ⭐ `until ! pgrep -f "mix test apps/yelixer"` — **the waiter's own argv contained the pattern, so it waited for itself and slept 1h52m** |
| 5 | commonplace | `pkill -f "until ! pgrep -f …"` matched its own shell for the same reason and **killed the command running the fix**, rc=144 |
| 6 | — | `sol-nudge.sh` did NOT self-match, every time, because its pattern is anchored `(^|/)codex (exec\|resume)` and lives in a file |

⭐ **THE VARIANT WORTH RECORDING SEPARATELY IS #4: THE SELF-WAITING POLLER.** When the pattern sits in
the argv of the shell *doing the waiting*, the loop is **structurally unable to terminate** — it is
not a flaky check, it is a guaranteed hang. And it fails silently: the poller looks busy, the pane
reports shells running, and the work it gates never starts.
⇒ **KILL AND WAIT BY CAPTURED PID. Never pattern-match a process whose pattern is in your own argv.**
⇒ And #5 is the same defect with teeth: a `pkill -f` whose pattern includes the earlier command
string will kill the shell issuing it.

⚠️ **THE DIAGNOSTIC THAT ACTUALLY RESOLVED IT** was not process inspection — it was reading the
ARTIFACT. Both output files were **empty**, which distinguishes *never ran* from *finished* and
*died*; process absence cannot. Same collapse as the transient systemd unit (LESSONS 7b0 addendum),
now observed in three carriers: a systemd unit, a backgrounded shell, and a poll loop.
**Absence of the process is not the verdict. The artifact is.**


---

## Appendix — the scope test: when is an out-of-brief change legitimate?

Three rounds in a row raised "the diff touches more than the brief described," and they resolved
**differently**, which is what makes the test worth stating.

| round | out-of-brief change | verdict |
|---|---|---|
| CX-1wt1 | moved the boundary checker into the app, repointed the test at `@app_root` | ✅ **REQUIRED** — a standalone checkout has no `scripts/` dir, so leaving it would have shipped a self-containment fix that isn't self-contained |
| CX-d71s | 15 files of line-rewrapping + a HEEx `<%= %>` → `{}` migration across wiki/outline/mud/tree LiveViews | ⛔ **CHURN** — ~200 lines, not one substantive change; stripped |

⛔ **"DID THE BRIEF LICENSE IT?" IS NOT THE TEST** — the first change wasn't licensed either, and was
correct.
⭐ **THE TEST IS: IS THE ROUND'S GOAL UNACHIEVABLE WITHOUT IT?** Required-by-the-goal survives;
everything else is blast radius bought for free.
⚠️ And check the cheap disconfirmer before stripping: **reverting formatting would be wrong if CI
enforced it.** commonplace checked — CI runs no format check — so the churn bought nothing. *A
plausible justification for churn (`the formatter wants it`) has to be tested, not assumed either way.*

⇒ **AS THE DISPATCHER I CAN SEE THE BLAST RADIUS BUT NOT THE INTENT.** Filenames tell me 22 files
were touched; only reading them says whether that was wiring or churn. **Flag the width, hand the
judgement to the reviewer** — both times that split produced the right answer, and the two answers
were opposite.


---

## Appendix — does the gate exercise the string that ships?

**2026-08-13, S37b.** The consumability gate would have fetched over `git@github.com:…` while the
shipped dep uses HTTPS. Everything inside the gate would have passed — **real fetch, real compile,
real convergence — against the wrong string.**

⚠️ **THIS IS A DISTINCT FAILURE FROM THE OTHERS IN THIS FILE.** Not a vacuous check (the corpus was
real), not a wrong referent (the repo was right), but **a completely valid proof of the wrong
proposition.** No amount of rigour *inside* the gate surfaces it, because every step genuinely passes.
⇒ **BEFORE TRUSTING A GATE, ASK WHETHER IT EXERCISES THE EXACT CONFIGURATION THAT SHIPS** — the same
URL string, the same ref, the same credentials posture, the same environment. A gate that proves a
neighbouring configuration certifies nothing about the real one.
⭐ The measurement that settled it was not an argument about which form was better: **CI has no SSH
setup at all**, so only one form ships. *A preference became a constraint the moment someone measured.*

### The pin travels with the proof
The gate proved HTTPS **at a pinned SHA**. ⇒ **The round it guards must use that URL AND that SHA**,
or it inherits none of the assurance. **If the published tip moves, the gate is stale and re-runs.**
⛔ **CHECK TIP-EQUALITY IMMEDIATELY BEFORE DISPATCHING THE GUARDED ROUND, AND REFUSE IF IT MOVED** —
assuming a newer tip is equally consumable is assuming the property survives a change nobody tested.
For the yelixer atomic round that means: `git ls-remote https://github.com/commonplace-systems/yelixer`
must still be `691a4f44…`.

⭐ **AND THE POSTURE THAT MAKES A GATE REAL** (commonplace's line): *a gate whose author wants it to
pass isn't a gate.* Its sibling: a guard nobody has seen fail is the defect wearing a fix's clothes.

### A pin is invalidated by ANY commit, not just a deliberate one
⚠️ The tip-equality rule above reads as a check against *someone re-cutting the release*. It is wider
than that: **any commit to the gated repo moves the tip**, including a change that has nothing to do
with the round. On 2026-08-13 the tempting one was moving a single 124-line file into yelixer — a
small diff by every measure a reviewer looks at, and it would have re-opened S37b's closed gate.
⇒ **WHILE A GATE'S PIN IS LIVE, THE GATED REPO IS FROZEN TO EVERYONE, not just to the round.** Say so
out loud when the arc starts, because the person who breaks it will be making an obviously-harmless
change. **Ask what is pinned to the state a change moves before calling that change small.**

### The run log is the ONLY substrate for the refusal check
⛔ **A ROUND THAT PRODUCES NO `sol-run.log` SILENTLY LOSES THE CONTENT-FILTER-REFUSAL CHECK**, and
nothing in the artifact can stand in for it. S37b (2026-08-13) finished with a 242-line report and no
run log anywhere under `$HOME` maxdepth 3. A large artifact argues strongly against a refusal — but
*argues against* is not *rules out*, and those are different evidentiary claims.
⇒ **CONFIRM THE LOG PATH EXISTS BEFORE THE ROUND STARTS, not after.** After is too late: the substrate
is gone and the check is unrecoverable no matter how good the result looks.
⭐ **AND REPORT THE GAP EVEN WHEN THE OUTCOME IS GREEN** — a good result is exactly the condition under
which a missing check goes unnoticed (LESSONS 7b4: *success is the condition under which an error
becomes undetectable*). commonplace recorded it in both the commit and the close rather than letting
the verdict paper over it.

### Reproduce, don't read, when the gate guards something irreversible
⭐ **S37b's verdict rested on TWO INDEPENDENT EXECUTIONS, not one agent's account.** commonplace
re-ran the consumability proof itself — different project, different text, **different client IDs
(7/99 vs Sol's 101/202)**, fresh `/tmp` dir, empty build path, fetched over HTTPS at the pin — and
converged. ⇒ **FOR A GATE GUARDING AN ACT WITH NO ABORT PATH BEHIND IT, READING THE REPORT IS NOT
ENOUGH.** Match the verification's independence to the irreversibility of what it releases (see
DEPLOY-CEREMONY's *gate strength should match reversibility*).
⚠️ Note what made the independence *visible rather than claimed*: **distinct fixed client IDs.** A
report that says "I used a separate document" is an assertion; one that shows non-overlapping IDs is
an artifact.
