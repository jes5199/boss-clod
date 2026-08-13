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

### A mask check that can only ever return zero
⚠️ **2026-08-13, S38 launch.** My fence check grepped `/proc/<pid>/mountinfo` for the literal string
`/dev/null` and returned **0 masks** — indistinguishable from an unfenced run. The masks were real.
**mountinfo renders a `/dev/null` bind as `0:5 /null` on devtmpfs**, so the string I searched for is
never present *no matter how well-fenced the sandbox is*.
⛔ **A CHECK THAT CANNOT RETURN NON-ZERO IS NOT A CHECK.** It is the false-zero family again, and here
the false zero pointed at a SECURITY property — the loudest possible place to be quietly wrong.
⇒ **PRINT THE LINES, DON'T COUNT THEM.** The correct form is `grep -E 'node_signing_key|\.ssh|cookie'
/proc/<pid>/mountinfo` and *read* the result:
```
0:5 /null  …/.commonplace/node_signing_key   ro  devtmpfs   ← masked
0:5 /null  /home/jes/.erlang.cookie          ro  devtmpfs   ← masked
0:47 /     /home/jes/.ssh                    rw  tmpfs      ← empty tmpfs, push impossible
```
⭐ The general rule this instance earns: **when you grep for a rendering rather than for a fact, you
are testing your own assumption about the format.** A control here is cheap — one known-masked path
whose line you have actually read once.

### ⛔ NEVER REQUIRE A COMMIT — THE SANDBOX MOUNTS `.git` READ-ONLY
**2026-08-13, S38.** I wrote *"This round is ONE COMMIT — commit it, because the atomicity IS the
deliverable."* **The fence makes that impossible**: `.git` is read-only by design, which is what makes
pushing structurally unavailable. `git rm` and `git commit` both failed; Sol adapted (deleted through
patches, unlinked binary fixtures) and reported the deviation correctly.
⭐ **THE FENCE WAS RIGHT AND MY INSTRUCTION WAS WRONG.** The read-only `.git` is load-bearing security;
the commit requirement was a convenience I invented. ⛔ **Never loosen a fence to satisfy a prompt.**
⇒ **THE STANDING RULE IS ALREADY IN §1 — I VIOLATED IT: *never give Sol an instruction it cannot
satisfy.* An omitted warning costs TIME; a contradictory one costs JUDGMENT.** Here it cost a round's
worth of framing: Sol spent its report explaining why the mandatory step was impossible.
⇒ **THE RIGHT ASK FOR AN ATOMIC ROUND: leave the work uncommitted as usual, and require the INTENDED
COMMIT MESSAGE as a deliverable.** Atomicity is a property of the tree — all halves present together,
no broken middle state on disk — and **a tree can demonstrate that without a commit object.** The
commit is made outside the sandbox by whoever lands it.
⚠️ Note the failure mode this *didn't* have: the tree was **complete-but-uncommitted**, not
half-applied. Worth checking explicitly, because those are different states with the same symptom
(`0 commits ahead`).

### The wrong baseline is caught by the instruction, not by the reviewer
⭐ **MY BRIEF STATED 4,263 TESTS ACROSS 6 APPS. THE MEASURED NUMBER WAS 4,527.** I also predicted
≈3,873 post-delete; the real figure is **4,137 = 4,527 − 390**. ⇒ Sol reported the measurement and
flagged the discrepancy **because the prompt said *report what you measure, not the arithmetic I gave
you***. Without that line, reconciling against my number would have required fudging 264 tests, and
the likeliest outcome is a report that quietly matches the expectation.
⭐ **AGREEMENT WITH THE DISPATCHER'S NUMBER IS WHEN EVERYONE STOPS LOOKING** — so the number you most
want independently measured is the one you already believe. **Always hand over baselines as
falsifiable claims, never as targets.**
⇒ And note what made the post-delete count meaningful: **it measured the PRE-delete scope too**
(3,449/0/12-excluded/1-skip, identical both sides). A single post-change number has no control.

### A deliberate pin looks exactly like a stale one
⚠️ **commonplace, 2026-08-13, carrying into the atomic landing:** once the dep is pinned at
`691a4f44`, CX-bx59 will move the published tip — expected and harmless, because our tree consumes the
pin, not the tip. ⛔ **But a pin that trails the remote's HEAD reads as neglect**, and the natural
tidy-up is to bump the ref to match. ⇒ **Re-pointing it silently swaps in a SHA the consumability gate
never proved**, discarding the assurance without anyone noticing they discarded anything.
⭐ **SO THE COMMIT MESSAGE MUST SAY THE PIN IS DELIBERATE AND STABLE.** A pin's *justification* has to
travel with it, or the next reader sees only a lagging number.
⇒ General form: **when correct state is indistinguishable from neglected state, the difference has to
be written down at the site**, because the tidier will not have your context.

### Distinguish "blocked by an un-landed commit" from "blocked by a standing conflict"
⭐ I framed bx59's timing problem as a conflict with the pin. commonplace's refinement: **it expires the
moment the atomic round lands** — once the pin is in the tree, the published tip can move freely.
⇒ **A block with an expiry is different from a constraint**, and saying which one it is stops people
planning around something about to evaporate. The capability leg (Sol's fence cannot push) *is*
permanent; the timing leg is not. **Two blockers on one ticket can have completely different
lifetimes — name each.**

### ⛔ IN A SOL WORKTREE, `git checkout --` DISCARDS THE ROUND
**2026-08-13, after S41.** A reviewer removed a mask line to prove the acceptance test could go red,
botched the reinsertion, and "cleanly fixed" the broken file with `git checkout -- provisioner.ex`.
⇒ **Sol's work on that file was uncommitted — BY DESIGN, because `.git` is read-only in the fence —
so checkout reverted it to base and discarded the entire round's contribution to it.**
⭐ **THIS IS A PROPERTY OF OUR ARRANGEMENT, NOT OF ANYONE'S ATTENTION.** `git checkout --` is safe in
every repo where work gets committed. **This is the one workflow where it never does.** ⇒ So the
whole family of *undo-my-edit* commands is **load-bearing-unsafe here and nowhere else**, and the
fence I built is what creates that.
⛔ **IN A SOL WORKTREE THE ONLY SAFE UNDO IS ONE THAT PRESERVES UNCOMMITTED WORK**: `git stash`, or
copy the file aside first. **Never `git checkout --`, never `git restore`, never `git reset --hard`.**
⚠️ And the tell that should fire: *"my edit is the only thing in this file"* is the assumption that
makes checkout look safe — **it is false in every Sol worktree by construction.**

### Recovery choice: re-dispatch beats reconstruction, and not because it is cheaper
⭐ The run log held 736 matching lines, so rebuilding the lost mask list from it was *possible*.
⛔ **It was the wrong kind of possible: reconstructing a security-critical list from log fragments is
RECALL, in the very round whose thesis is that hand-built lists fail** — three parties had already
produced three wrong lists that night, every one after reading the lesson.
⇒ **RE-DISPATCH IS NOT THE CHEAP OPTION, IT IS THE ONLY ONE CONSISTENT WITH THE ROUND'S OWN LAW.**
⭐ And dispatch **into the surviving worktree**, not a fresh one: ten reviewed files survived, and a
clean checkout would have discarded good work to repair one file. **Name the survivors individually
as untouchable, and say plainly that the previous output was accepted** — otherwise the builder reads
a re-dispatch as a rejection and "improves" what was already right.
