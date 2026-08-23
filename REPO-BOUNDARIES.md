# Repo boundary rulings — the ledger new workers get handed

⭐ **WHY THIS FILE EXISTS.** Every spec so far has assigned work to a repo boundary jes had
already ruled differently. **Three instances in two days**, each caught by a different agent,
each corrected one at a time by me remembering. ⛔ **A remembered rule does not fire.** This is
the artifact; hand it to every new worker at launch and point spec readers at it.

> **jes, 2026-08-23:** *"the specs could easily be confused about repo boundaries"*

⚠️ **THE SPECS ARE NOT WRONG TO FIX — THEY ARE jes's PROSE AND THEY STATE INTENT.** Do not edit a
spec to match the code or to match this file. **Read the spec's ownership row as naming a
COMPONENT, and read this file for which REPO it lives in.** Where the two genuinely conflict on
intent, that is a question for jes, not a correction to make.

---

## The rulings

### 1. `commonplace-attribute-map` is NOT a repo — it lives inside `commonplace-log-reducer`

> **jes, 2026-08-23:** *"the idea is that this new library depends on commonplace-log. I want to
> include the relatively simple attributes plugin in the same repo"*

⛔ **Overrides the reducer's own spec §1, which described two libraries**, and
`commonplace-doc` spec **§24**, whose ownership table lists `commonplace-attribute-map` as a
separate owner for LWW key/value reduction. **There is no such repo. Do not create one.**

### 2. `commonplace-merkle-crdt` does not own the commit DAG or merge/commit-id verdicts

Two specs have now assigned it work it structurally cannot take:
- `yepochs` spec **§26**
- `commonplace-doc` spec **§7** — assigns it the commit DAG and materialization-by-ID, while
  forbidding it a head it **must** have, because the log-reducer engine hands it a **gapless
  single-writer log**.

⇒ **Route DAG, merges, and commit-id verdicts to `commonplace` (the historical Elixir CRDT
store).** merkle-crdt builds Yjs documents from merkle-wrapped Yjs edits; that is its mandate.

### 3. Realm reaches the log layer as CONTAINMENT, never AUTHORITY

Settled by `commonplace-log` 2026-08-23, and the profile doc states it twice
(§117, §310): *"physical containment MUST NOT be interpreted as logical ownership."*
⇒ **Nothing acquires an owner from where its bytes are stored.**

### 4. Logs and docs are SINGLE-REALM for v1 — ✅ RESOLVED 18:30Z: reading (a), MULTI-REALM DEPLOYMENT

> **jes, 2026-08-23T18:26Z:** *"right, we're keeping logs and docs single-realm for v1"*

⭐ **jes, 18:30Z, verbatim:** *"a log lives in a single realm. in fact, a cell lives in a single
realm. but I may have multiple realms per tenant"*

⇒ ✅ **READING (a), and STRONGER than (a) as posed.** Not merely many realms per deployment —
**many realms per TENANT.** ⛔ **Isolation is a genuine v1 requirement**, it is load-bearing, and
**verifying it requires at least two realms.** `commonplace-log` planned for exactly this and was
right to; **it fails safe, and here the safe guess was also the correct one.**

⚠️ **What "single-realm" actually constrains:** a **log** lives in one realm, and a **cell** lives
in one realm. **That is a containment statement about each object — never a claim that the
deployment has one realm.** I read it as the latter; that was the error.

■ *The two readings, kept because the resolution only means something against them:*

```
(a) a log lives in exactly ONE realm, but the deployment hosts MANY realms (multi-tenant)
    -> cross-tenant isolation IS a v1 requirement, and testing it REQUIRES two realms
(b) the v1 deployment has exactly ONE realm
    -> isolation not load-bearing in v1, and untestable by construction
```
⭐ **"logs and docs are single-realm" most naturally describes where a LOG LIVES, not how many
realms exist** — a customer-per-realm deployment satisfies the sentence exactly while still needing
isolation. ⇒ **`commonplace-log` is planning for (a) because it FAILS SAFE:** guessing toward (b)
ships a system whose isolation was never tested because someone decided it did not apply.

⛔ **AND THE FENCING EPOCH IS NOT DESCOPED EITHER WAY.** Single-realm removes one log being live in
two *different* realms. It does not remove what the epoch actually fences:
- revision §51 — *"a Container is one restartable BEAM-node INCARNATION"*
- SP-DP — a Realm is replaced on rollout, *"slept on idle and woken elsewhere, so handoff is an
  ordinary lifecycle event"*

⇒ **A single realm has many SUCCESSIVE incarnations, and a rollout can transiently have two
activations of the SAME realm — old draining, new starting.** An obsolete epoch failing at commit is
what makes that safe. ⭐⭐ **SINGLE-REALM IS NOT SINGLE-ACTIVATION-OVER-TIME, and the epoch was built
for the second.**

⚠️ **The near-miss on a different axis, from `yepochs`:** this ruling *pattern-matches* the
justification for `commonplace-doc`'s opaque **epoch discriminator** without answering it —
**Yepochs and Realms are different axes.** A history gets a new Yepoch whenever it is re-authored:
snapshot, fork, **divergent branch**, import. **None needs a second realm.** ⇒ **The epoch boundary
is reachable inside one realm, in v1, on day one**, and the retrofit is a migration over
already-admitted commits.

⭐ **THE META-LESSON, and it is the reason this section is this long:** my flag about the ruling
*itself carried an error, and the error ran in the direction of convenience* — **the reading that
descoped the most work is the one that arrived.** ⇒ *When a ruling could narrow scope, check which
reading you adopted before checking anything else.*

### 5. `commonplace-doc` COMPOSES BOTH reducer plugins; the head is an ATTRIBUTE

> **jes, 2026-08-23T18:32Z:** *"commonplace-doc should use both of the reducer plugins. head commit
> is an attribute stored in the attributes reducer"*

⇒ **Resolves `commonplace-doc`'s H1 three-way call.** Not *"extend merkle-crdt"*, not *"write a new
plugin"*, not *"re-point at `commonplace`"* — **compose the two that exist.** The selected content
head lives in the **attribute-map component** (repo: `commonplace-log-reducer`, see #1).
✅ Option (C)'s gating behind `commonplace`'s implementation hold stops mattering.

⚠️ **A ruling about composition does not conjure a DAG, and §7's factual gap is about a DAG.** Two
measured facts still have to meet, and **this is `commonplace-doc` + `commonplace-merkle-crdt`'s to
resolve, not boss-clod's:**
```
merkle-crdt   head_id is @enforce_keys; check_chain REJECTS parent != head
              -> a LINEAR engine over a gapless single-writer log
doc spec      head selection admits jumps to DIVERGENT BRANCHES (§9, §12)
```
⭐ **Practical consequence for whoever wires the deps:** the attribute component is **one repo, TWO
mix apps** — two dep entries with different `sparse:` paths. **Not three repos, and not one dep
either.**

### 6. `commonplace-merkle-crdt` must be aware of `yepochs`

> **jes, 2026-08-23T18:33Z:** *"merkle-crdt does need to be aware of yepochs"*

⭐ **Said twice, unprompted.** At merkle-crdt's launch: *"it does need to know about yelixir and
yepochs (which i think is two separate repos?)"* ⇒ **Repetition a fortnight apart is weight, not
redundancy** — and it arrived one minute after the composition ruling, in a context where #5 could
have been read as routing epochs elsewhere.

⚠️ **IT DID NOT ANSWER `commonplace-doc`'s ASK 2 — but jes ANSWERED IT SEPARATELY three minutes
later, at 18:36Z:** *"let's put an epoch id into the commit struct"* ⇒ ✅ **YES. The epoch id is
IN.** See #7. **The warning below stands on its own merits and is why the two were kept apart:**
the awareness ruling still did not answer the field question — **jes did, in a separate sentence.**

⭐⭐ **THE STANDING WARNING THIS SECTION EXISTS FOR** — named by `yepochs`, and it caught a live
instance the same hour:

> **A ruling can appear to DISCHARGE A PREMISE without answering it.** *"merkle-crdt should be aware
> of yepochs"* pattern-matches the discriminator question; one is about awareness, the other about a
> **field on every content commit** whose deferral becomes a **migration over already-admitted
> commits.**

⚠️ **This leaves LESS trace than ordinary staleness, because nothing anywhere becomes false.** The
sentence stays true; only its apparent necessity changes. ⛔ **No diff, no failing test, and
re-reading will not flag it either — it still reads as correct.**

⇒ ✅ **Test before treating a ruling as closing a question: does it answer the question, or does it
merely make the question feel already-handled?** ⭐ *Ask what would have to be true for the ruling to
answer it, and check whether the ruling says that.*

### 7. ✅ An EPOCH ID goes in the commit struct

> **jes, 2026-08-23T18:36Z:** *"let's put an epoch id into the commit struct"*

⇒ **Answers `commonplace-doc`'s ask 2 affirmatively.** The reasoning that made it urgent, from
`yepochs` via doc: ⭐ **deferring epoch POLICY is cheap; deferring the FIELD is a migration over
already-admitted commits.** ⇒ **It is in the 0.1 profile.**

⚠️ **WHICH commit struct is not stated, and I am not deciding it.** Doc's ask was about **content
commits**; `commonplace-merkle-crdt` has a concrete v1 commit shape in code. **Both readings are
available and they may be the same thing.** ⇒ **`commonplace-doc` + `commonplace-merkle-crdt` own
this; ask jes if it does not resolve between you.**
⛔ *Logged explicitly because I over-read a ruling once today (see #4) and the error ran toward less
work. A referent I cannot see from outside is not one to guess at.*

⭐ **Why the field is worth its cost even under single-realm-per-object (#4):** Yepochs and Realms
are **different axes**. A history acquires a new Yepoch on **snapshot, fork, divergent branch, or
import** — none of which needs a second realm, and doc's head selection admits divergent-branch
jumps. **The boundary is reachable in v1 on day one.**

### 8. `commonplace-doc-host` is built IN-REPO by `commonplace-doc` — no new repo, no new agent

> **jes, 2026-08-23T18:41Z:** *"i want commonplace-doc to build commonplace-doc-host in-repo for
> testing/debugging/proof-of-concept"*

⇒ **Spec filed byte-identical at `commonplace-doc/docs/proposals/2026-08-23-commonplace-doc-host-spec.md`**
(782 lines, sha256 `05e81989582bbee3`). ⭐ **Note the PURPOSE he gave it: testing, debugging,
proof-of-concept.** ⛔ **That is not the same as "the production host", and the distinction should
survive into whatever gets built** — a proof-of-concept that quietly becomes the reference
implementation is how a scoping word gets lost.

■ **The spec's own dependency direction** (§6):
```
commonplace-doc · commonplace-log · commonplace-log-reducer
        ^
commonplace-doc-host
        ^
future Environment / Realm adapters
```

### 9. ⚠️ `commonplace-doc-host` §16 BEARS ON THE OPEN CAS QUESTION — not yet confirmed as answering it

`commonplace-doc`'s **ask 2b** is that `commonplace-attribute-map` has **no CAS** (`put`/`delete`/
`patch`, all unconditional, verified by reading `attribute_map/v1.ex` — they are operation TYPES
dispatched through `apply/3`, not functions), so *"set the head to Y only if it is currently X"* is
inexpressible, and under the composition ruling **content merges while the pointer to it clobbers**.

**The host spec §16 offers, verbatim:**
```elixir
expected_coordinate: coordinate
expected_head: commit_id | nil
```
> *"`expected_head` provides the narrower content-edit compare-and-set defined by `commonplace-doc`."*
> *"Multiple clients may attach concurrently, but their mutations are SERIALIZED."*

⇒ ⭐ **That looks like the CAS landing at the HOST layer rather than in attribute-map.** ⛔ **I am
NOT recording it as answering ask 2b.** `commonplace-doc` owns that judgement; **the hazard it
described lives in the layer that can see both plugins, and whether a serializing host discharges it
is exactly the kind of thing I got wrong earlier today by over-reading.**
⚠️ **And note the direction the convenient reading runs, again: "the host handles it" retires an
open decision.** ⇒ *Ask, do not assume.*

### 10. ⏳ FUTURE: forked documents pushing changes back up — probably `commonplace-doc-sync`

> **jes, 2026-08-23T18:51Z:** *"eventually I want the ability for a forked document to push changes
> back up. actually that is probably a new repo, commonplace-doc-sync"*

⛔ **NOT CREATED, and deliberately so.** ⭐ **Compare his phrasing to the four repos he actually
started today** — *"new repo!"* · *"let's create a commonplace-doc repo"* · *"let's also start a
yepochs repo"* · *"i want commonplace-doc to build commonplace-doc-host in-repo"*. **Every one is an
instruction. This one is "eventually" and "probably".** ⇒ *Treating it as an instruction would
spend a repo and a sixth Opus worker on a thought.*

⚠️ **WHY IT IS RECORDED ANYWAY, AND WHY THE TIMING MATTERS: it is a FORECLOSURE RISK, live right
now.** `commonplace-doc` and `commonplace-merkle-crdt` are **this hour** deciding whether forks are
admissible at all — the linearity trap, `check_chain`, whether a head may move to a non-descendant.
⇒ ⭐ **A design that makes forks EXPRESSIBLE but push-back IMPOSSIBLE is the expensive outcome**, and
it is reachable without anyone deciding it.

✅ **What to do with it:** **do not design it, do not build it, do not let it be designed out.**
⇒ *"Could a fork ever be merged back?" is a question to keep answerable, not a feature to add.*

⛔ **And do not let it re-open settled scope.** §23 of the doc spec defers **import of commits across
Document lineage** and **multi-writer Document logs**; those deferrals stand. **This is a note about
what NOT to preclude, not a licence to un-defer anything.**

### 11. ⭐ STANDING: Sol does the code work

> **jes, 2026-08-23T18:52Z:** *"let's keep using Sol for code work"*
> (earlier, 18:22Z, on `commonplace-doc`: *"have them use Sol to implement"*)

⇒ **Standing policy for this cluster, not a per-task instruction.** ⭐ **Agents design, review, decide
and MEASURE; Sol types.** Same division as Fable: reserve the expensive judgement for judgement.

⚠️ **SCOPE I AM ASSUMING, stated so it can be corrected:** the doc/log cluster — `commonplace-doc`,
`commonplace-log`, `commonplace-log-reducer`, `commonplace-merkle-crdt`, `yepochs`.
⛔ **NOT `hermes`** — live money, and he did not say it. ⛔ **NOT `commonplace`** — under an
implementation hold. **Told jes this is my reading so he can widen it.**

**Mechanics** (`sol-egress-run.sh`):
```
SOL_WORKDIR=<isolated worktree>   SOL_MAX_PARALLEL default 2 (REFUSES a third, does not queue)
```
⛔ **The filename lies:** *"sol-egress-run"* = the runner **WITH** egress. **There is no egress fence.**
⭐⭐ **ANYTHING MEASURED INSIDE THE FENCE INHERITS THE FENCE AS A FACT** — masked paths and scrubbed
env return as ordinary negative findings with plausible mechanisms. **Name what is masked in the
brief.** ⚠️ **A content refusal looks like an empty diff with `rc=0` — i.e. exactly like
"nothing to do". Check the diff, never the exit code.**

⛔ **Sol writing the code does NOT authorise implementation. Build order is still jes's.**

⏳ **`commonplace-log` and `commonplace-log-reducer` are retired as of this ruling and have not been
sent it — include it when un-retiring them.**

### 12. ✅ CALLER-SUPPLIED PARENT — the linearity trap is ruled on

> **jes, 2026-08-23T18:53Z:** *"i think caller-supplied parent is correct"*

⇒ **Answers `commonplace-doc`'s HH2 and unblocks `commonplace-merkle-crdt`'s `check_chain`.** The
shape, as doc specified it: **parent is CALLER-SUPPLIED, defaulting to the current head, constrained
to a known admitted commit.**

⭐ **What it fixes is a FUSION, not a comparison.** Host §17 and `check_chain` both conflated two
questions that a linear history makes indistinguishable:
```
"what am I branching FROM?"              -> a PARENT.       Any known admitted commit.
"what do I expect the SELECTION to be?"  -> a PRECONDITION. The current head.
```
⛔ **Fused, forks are not mis-handled — they are INEXPRESSIBLE**, so the bug presents as a missing
feature rather than an error. **Four occurrences today** (`check_chain`, doc spec §7, host §17, and
the host's 21 acceptance tests exercising no non-forward head move).

⭐ **It is also the mechanism §10's future push-back would need.** ⚠️ **So a later reader tempted to
re-tighten the parent rule is not merely re-entering the trap — they are removing the thing
push-back runs on.** See `commonplace-doc/docs/LINEARITY-TRAP.md`.

⛔ **A design ruling, NOT an implementation authorisation.** Build order remains jes's.

### 13. ✅ HEAD SELECTION IS BOUND TO `document.select.head`

> **jes, 2026-08-23T19:47Z, verbatim:** *"a change to commonplace.content.head requires
> document.select.head — approved, yes"*

⇒ **Closes `commonplace-doc`'s W1 completely.** ⭐ **The earlier 19:07Z ruling (*"select.head is
good"*) gave the ACTION; this gives the BINDING** — and the binding was where the hole was, because
a purely additive action takes nothing away from `document.write.attributes`.

⭐ **The negative is ENTAILED, not separately stated.** *"Requires `document.select.head`"* means
`write.attributes` alone is insufficient. ⇒ **Spec text should state both halves** — the positive
because he ruled it, the negative because that is the half that closes the escalation, and a reader
who sees only a new name in a list will still authorize a rollback under the general action.

⚠️ **WHY IT MATTERED, so it is not re-litigated:** head selection is **physically an attribute
write** (the head lives in the attribute projection), and the attribute plugin enforces **no key
namespaces at all** — measured by `commonplace-log-reducer`: the complete key validator is five
rules (non-empty · valid UTF-8 · no null · ≤1024 bytes · `:ok`) **with no sixth branch.** ⇒ Without
this binding, **anyone able to set a display name could roll a document back to an arbitrary
ancestor without holding `write.content` — silent, instant, authorized.**

⛔ **AND ONE PART OF THE ASK HE DID NOT EXPLICITLY ANSWER: the merge-parent rider.** I asked whether
the action must also cover **choosing a merge parent**, not only the tip — because his
caller-supplied-parent ruling (#12) created that door, and an unconstrained merge base reaches the
same rollback through it. **He quoted and approved the head-change sentence; he did not address the
rider.** ⇒ ⚠️ **Treat it as OPEN, not as covered. Do not read the quoted sentence as wider than it
is** — *that is the direction my relays drift.*

### 14. ⭐ THE MONOLITH WAS RENAMED — `commonplace` ➜ `commonplace-monolith`

> **jes, 2026-08-23T19:49Z:** *"i want to rename commonplace repo to commonplace-monolith"*

```
GitHub    commonplace-systems/commonplace-monolith   (still PUBLIC, main intact)
remotes   ALL repointed off the redirect — 34 checkouts, 0 left on the old URL, fetch verified
local dir /home/jes/commonplace                      ⚠️ UNCHANGED — paths still resolve
```
⭐ **Why the remotes were repointed rather than left on the GitHub redirect: a redirect BREAKS the
moment anything claims the old name**, and this org is actively creating `commonplace-*` repos.
⛔ **The failure would have been SILENT — remotes pointing at a different repository, with nothing
announcing it.**

⚠️ **Counting note, because it looks wrong and is not:** one `git remote set-url` moved **34**
checkouts. **33 of them are worktrees sharing the parent's config.** *One write, many observers.*

■ ⛔ **STALE REFERENCES DELIBERATELY NOT REWRITTEN.** Six files in boss-clod name the old repo:
`LESSONS.md`, `KNOWN-REDS.md`, and four `inbox-*.md` documents. ⇒ **All six are HISTORICAL LEDGERS
or RECEIVED DOCUMENTS — records of what was said at a time, and the redirect still resolves them.**
⭐ *Rewriting a received document changes the record.* **Same reason `commonplace-log` left jes's
proposal byte-identical when the code disagreed with it.**

⛔⛔ **AND A PATTERN TRAP FOR WHOEVER DOES SWEEP THIS LATER:**
```
commonplace-systems/commonplace\b        ⛔ ALSO MATCHES commonplace-plan  (\b matches before "-")
commonplace-systems/commonplace($|[^-])   ✅ the stale ones only
```
⇒ **My first count included `commonplace-plan` URLs, which are NOT stale.** ⚠️ **A blind fix would
have rewritten them to `commonplace-monolith-plan`.** ⭐ *`\b` is a word boundary and a hyphen is a
word boundary — the exact place a sibling repo's name hides inside its parent's.*

### 15. ✅ IMPLEMENTATION AUTHORISED ON THE 20:33Z RULINGS

> **jes, 2026-08-23T20:37Z:** *"yes let's do it. we can revise later if needed"*

⇒ **In answer to my question of whether the four repos may build on the rulings document.**
⭐ **Sol does the code work** (#11). **Design settled by `docs/proposals/2026-08-23-open-questions-rulings.md`, sha256 `4d9d75b78d08fed1`.**

⚠️ **AMBIGUITY I RESOLVED AND STATED RATHER THAN HID: two questions were open when he answered** —
this one, and *"start `commonplace-dir` now or after the quota reset?"* ⇒ **I read "it" as the
authorisation** (his reply came 90 seconds after that message; *"we can revise later"* fits an
implementation, not a repo launch) **and told him so, with the alternative named.**
⛔ **`commonplace-dir` remains FILED AND UNSTARTED** — see `held-specs/`.

⭐⭐ **WORTH KEEPING: `commonplace-doc` argued AGAINST ITS OWN INTEREST ten minutes earlier.** I had
flagged that I might have been over-holding these repos on my own initiative rather than jes's word.
It said I had not been, and gave a **tell** rather than an opinion:

> *Every actual build instruction from jes tonight was imperative and named a deliverable —
> "new repo!", "let's create a commonplace-doc repo", "build commonplace-doc-host in-repo".
> This document is titled "**Proposed** design rulings", and its forward-looking sentence is
> "the first implementation **should demonstrate** at least these cases" — **a property of an
> implementation, not an instruction to start one.**"*

⇒ **Then: *"reading it as authorization is the reading that CREATES WORK, and it's the one I'd
benefit from — so I'm the wrong party to resolve the ambiguity in my own favour. Don't spend the
ask; he'll say so."*** ⭐ **He did, unprompted, ninety seconds later.**

### 16. ⭐ THE FLEET'S TERM IS `if_head_is` — and specs may be renamed

> **jes, 2026-08-23T20:42Z:** *"they have permission to rename in the specs if a new name is decided"*

⇒ **Two grants: the naming DECISION belongs to the repos, and editing his spec files for it is
authorised.** ✅ **`commonplace-doc` and `commonplace-doc-sync` converged on `expected_current_head`.**

⛔ **SCOPE LIMIT I imposed, because he granted a RENAME and not a licence: change the IDENTIFIER,
leave his reasoning alone.** ⇒ *If applying it reveals a sentence wrong for a reason other than the
name, FLAG it — do not fix it. A spec states intent.*

⛔⛔ **I RELAYED `expected_current_head` AS SETTLED AND IT WAS NOT. Both repos are on `if_head_is`
— MEASURED: `commonplace-doc` 9 files, `expected_current_head` 0 files.** *Corrected to jes.*

⭐ **THE MECHANISM SURVIVES; THE VERDICT DID NOT.**
> ✅ **KEEP:** *a name that INVITES a completion is worse than one you must actively disregard, and
> only the first failure is silent.* **That explains the five authors — one invitation accepted five
> times, not five mistakes.**
> ⛔ **DROP:** the scoring of `expected_current_head` against it. `commonplace-doc` refuted it —
> **`expected_current_head` is still a NOUN PHRASE, and a reader re-attaches `current` to the verb:
> *"the head I CURRENTLY EXPECT to be building on."*** ⇒ **The parent reading survives with EVERY
> WORD INTACT. English lets a modifier float; the test assumed it could not.**
✅ **`if_head_is` has no reattachment yielding *"my parent is A"* — the only candidate that CLOSES the
path rather than narrowing it.** *Structural row, not the checked row.*

⛔⛔ **AND THE SHAPE THAT ALMOST SHIPPED THE WEAKER NAME — MUTUAL DEFERENCE, TWICE:** each repo
conceded to the other's candidate, both times crossing, and **both concessions were to an argument
the other had ALREADY DEFEATED.** ⇒ ⭐ ***Two parties agreeing is not evidence when each is agreeing
to the other's ARGUMENT rather than to the evidence.*** ⚠️ **The Registry error arriving through
COURTESY instead of through a shared grep — and I ratified it, because two "we agree" messages that
crossed read exactly like a convergence.**
✅ **Fix: before relaying a convergence, MEASURE what each party actually landed.** *Two claims of
agreement are one claim, twice.*

■ ✅ **Blast radius is one COMMAND parameter, not a concept.** His recorded event
`%{type: "commonplace.document.select_head", from:, to:, operation_id:}` is the **transition**, not
the precondition, and is **untouched**. **The 338-line rulings document stays correct everywhere
except the command sketch in §1.**

⭐ **A second ambiguity it fixes that nobody had raised:** `expected_head: nil` reads as *"I expect no
head"* OR *"I am not specifying one."* ⇒ **`if_head_is: nil` means exactly one thing — *"only if nothing is currently selected"* — and absence
is a VALID precondition for an uninitialized Document, so the case is real.**

⚠️ **Why it matters more to `commonplace-doc-sync`:** in `commonplace-doc` the parent lives on the
**commit** and the precondition on the **selection** — different objects, so the fusion must cross a
boundary. ⛔ **In doc-sync, `merge_parent` sits in `requested_selection` BESIDE the precondition —
same object, no boundary.** ⇒ ***The layout protects one and the name protects the other.***

### 17. ⛔ SOURCE LAYOUT IS NOT UNIFORM — `<repo>/lib` DOES NOT EXIST IN HALF OF THEM

**MEASURED 2026-08-23T20:51Z:**
```
commonplace-log          NO top-level lib/   ->  commonplace_log/lib
commonplace-log-reducer  NO top-level lib/   ->  commonplace_log_reducer/lib  AND  commonplace_attribute_map/lib
commonplace-merkle-crdt  lib/ at top
yepochs                  lib/ at top
commonplace-doc          lib/ at top  ⚠️ CHANGED 20:58Z — was docs-only, now 3 .ex files
commonplace-doc-sync     no lib/ at all — docs only, 0 .ex files
```
⚠️ **THE DOCS-ONLY EXCEPTION EXPIRED SEVEN MINUTES AFTER I WROTE IT.** `commonplace-doc` landed
phase 1 at `681f6bc` and now has `lib/` at top. ⇒ ⭐ **The `.ex` control works there again and the
`.md` substitute NO LONGER APPLIES.** ⛔ **`commonplace-doc-sync` is still docs-only — the exception
survives for exactly one repo, and it will expire there too.**
⭐ **`commonplace-doc` caught this in my file, not me.** *An exception written against a state that is
actively changing is a stale entry that reads as measured — which is the whole §7x90 shape, in the
document that carries the warning about it.* ⇒ **Re-measure before trusting this table; the command
is two lines below.**

⛔⛔ **THIS HAS NOW CAUSED THREE SEPARATE FALSE ABSENCES IN ONE EVENING:**
- **mine, twice** — grepping `commonplace-log/lib` and `commonplace/lib`, both non-existent. **Every
  arm returned 0 and the two that mattered looked exactly like a confirmed finding.**
- **Sol's, once** — two `rg` misses on `../commonplace-log-reducer/lib`, correctly diagnosed by
  `commonplace-doc` as **real path errors, not fence artifacts.**

⚠️⚠️ **THE DANGEROUS PART IS THE SECOND READING.** *"No such file or directory"* from inside the Sol
sandbox **is exactly the shape a MASK produces.** ⇒ ⛔ **A wrong path there gets read as evidence
about the fence** — and the fence is real, so the misreading is plausible. ⭐ `bwrap --dev-bind / /`
leaves those trees readable; **only the NAMED masks are tmpfs.**

✅ **WHAT TO DO — the corpus count catches it every time, and it is one extra line:**
```
command grep -rl '' --include='*.ex' <path> | wc -l     # ⇒ 0 means WRONG REFERENT, not empty repo
```
⭐ **A repo with zero `.ex` files is a state these repos cannot be in** *(except `commonplace-doc`
and `-doc-sync`, which are docs-only BY DESIGN — so for those, zero is correct and the control must
be `.md` instead).*

⛔ **Do not "fix" this by guessing the nesting.** ⇒ **`find <repo> -maxdepth 2 -type d -name lib`
answers it in one command, and answers it correctly for both layouts.**

### 18. ⛔ SOL CANNOT COMMIT IN A LINKED GIT WORKTREE

**Found by `commonplace-doc` on its first Sol round, 2026-08-23T20:58Z.**
```
worktree /home/jes/commonplace-doc-sol-p1/.git  ->  "gitdir: /home/jes/commonplace-doc/.git/worktrees/..."
```
⇒ ⛔ **A linked worktree's git metadata lives OUTSIDE the sandbox's writable root**, so `index.lock`
fails with **"Read-only file system."** ⚠️ **The WORK survives uncommitted and Sol reported the
failure accurately** — *it did not silently drop anything* — **but the round cannot commit itself.**

✅ **Two fixes, either fine:** use a **CLONE** rather than `git worktree add`, **or** the dispatcher
commits on Sol's behalf (what `commonplace-doc` did). ⭐ **Decide before dispatch, not after.**

⚠️ **Why this is worth a boundary entry rather than a lesson: it will hit whoever dispatches next,
and the symptom is a WRITE failure inside a sandbox** — ⛔ **the exact shape that gets misread as
"the fence blocked my work"** when the fence is doing nothing of the kind. *Same family as §17's
path errors reading as masks.*

---

## The layering, in jes's words

```
log  ->  reducers  ->  commonplace-doc (document)  ->  directory  ->  cell
```
> *"a cell runs in a realm and contains a bunch of related documents. a realm is, like, a single
> server."*

## Ownership, as of the `commonplace-doc` spec §24 — with repo corrections applied

| Concern | Owner |
|---|---|
| Append-only bytes and log UUID | `commonplace-log` |
| Projection dispatch and epochs | `commonplace-log-reducer` |
| LWW key/value reduction | ⚠️ **component** `commonplace-attribute-map`, **repo** `commonplace-log-reducer` |
| Merkle commit graph, CRDT materialization by commit ID | `commonplace-merkle-crdt` — ⛔ **but not the DAG/merge/commit-id verdicts, see #2** |
| Meaning and validation of `commonplace.content.head` | `commonplace-doc` |
| Verb mount semantics and invocation plans | `commonplace-doc` |
| Persistence, routing, capabilities, runtime execution | Environment/host |
| Paths, directory snapshots, lineage copy-on-write | Directory/Cell layers |
