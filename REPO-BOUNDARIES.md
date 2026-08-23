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

### 4. Logs and docs are SINGLE-REALM for v1

> **jes, 2026-08-23T18:26Z:** *"right, we're keeping logs and docs single-realm for v1"*

⚠️ **This is narrower than it looks and has already produced one near-miss.** It rules on
**Realms**. ⛔ **It does NOT discharge anything merely because a Realm is mentioned nearby.**

⭐ **The instance that nearly cost something:** `yepochs` had advised `commonplace-doc` to keep an
opaque **epoch discriminator** (equality comparison only). Single-realm *pattern-matches* that
justification without answering it — **Yepochs and Realms are different axes.** Two commits get
different Yepochs whenever a history is re-authored: snapshot, fork, **divergent branch**, import.
**None of that needs a second realm.** ⇒ **The epoch boundary is reachable inside one realm, in
v1, on day one** — and the retrofit is a migration over already-admitted commits.

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
