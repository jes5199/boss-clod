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
