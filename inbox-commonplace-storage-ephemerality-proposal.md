---
title: "Commonplace Storage Ephemerality Proposal"
date: 2026-08-16
status: proposal
scope: "Commonplace key-value and object storage architecture"
source_baseline:
  commonplace: 1070a929cecf8198473df702a7605cc956595a7e
repositories:
  - https://github.com/commonplace-systems/commonplace
  - https://github.com/commonplace-systems/commonplace-plan
---

# Commonplace Storage Ephemerality Proposal

## One logical object space, multiple retention and residency domains

## Executive summary

Commonplace should retain one logical commit space and one authoritative owner for mutable heads, while placing immutable bytes behind a storage router with several physical backends.

The central distinction is:

> Ephemerality is a retention obligation, not the name of the database in which an object currently resides.

A durable object may be cold. An ephemeral object may be hot. A cached object may also have a durable canonical copy elsewhere. Those properties must not collapse into a single `store` field or a proliferation of independent key-value databases with ambiguous authority.

The recommended architecture is:

- **CoreStore:** authoritative mutable state, security records, logical indexes, placement facts, and recently admitted immutable objects;
- **HistoryStore:** verified immutable cold segments;
- **LeaseStore:** time-bounded history that has not been promoted to a durable obligation;
- **ArtifactStore:** the existing content-addressed filesystem store for large binary values; and
- **CacheStore:** disposable derived values.

All reads go through a `Store.Router`. Only CoreStore owns heads and other authoritative mutable indexes. The other stores hold immutable payloads or rebuildable derivations.

The first implementation slice should not delete data. It should losslessly demote eligible compactable history from CoreStore into a verified cold segment, route reads transparently across both locations, and prove crash safety at every transition. Semantic expiry and tombstone production should come only after retention roots, reachability, promotion, replica acknowledgements, and recovery are explicit.

This turns the current store from “the one database containing everything” into:

> the authority that knows what must still exist, where verified copies live, and why an absence is legitimate.

## Why this change is needed

The current [CommitStore](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/commit_store.ex) is a singleton GenServer backed by one CubDB directory. One tuple-keyspace contains several different categories of state:

| Key family or value | Semantics | Mutation pattern | Desired treatment |
|---|---|---:|---|
| `{:commit, id}` | Content-addressed CRDT history | Immutable | Hot, cold, or leased according to obligation |
| `{:attestation, id}` | Signed evidence | Immutable | Durable core or durable history |
| `{:latest, doc_uuid}` | Authoritative document head | Mutable | CoreStore only |
| Merge pointers | Authoritative convergence state | Mutable | CoreStore only |
| `{:doc_commit, doc_uuid, id}` | Derived/logical lookup index | Append-oriented | CoreStore; rebuildable from canonical data where possible |
| Capability and revocation records | Security authority | Append-oriented | Durable CoreStore |
| SLA tombstones | Constitutional proof of legitimate absence | Append-only | Durable CoreStore |
| Eviction authority ledger | Ordering and authority | Append-only | Durable CoreStore |
| `execute_clean` results | Derived trust evaluation | Rebuildable | CacheStore |
| Pending imports | Retry queue | Intentionally volatile | Memory |
| Artifact bytes | Content-addressed binary payloads | Immutable | Existing ArtifactStore |

That layout provides useful atomicity: a newly built commit and its latest pointer can land together through `CubDB.put_multi`. It also creates one corruption, compaction, backup, recovery, and capacity domain for data with radically different durability requirements.

There are already signs that the logical boundary wants to be wider than one CubDB:

- [ArtifactStore](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/artifact_store.ex) is a separate filesystem content-addressed store.
- [PendingImports](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/pending_imports.ex) is deliberately in memory because loss is repaired by catch-up.
- [TrustSideStore](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/trust_side_store.ex) is logically separate, but still uses CommitStore's CubDB handle for both durable trust records and disposable `execute_clean` cache entries.
- [Store.GC](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/gc.ex) identifies and archives candidates but does not delete them.

The code also exposes a migration hazard. [CommitStoreClient](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/commit_store_client.ex) is a useful dispatch seam, but local callers can bypass it through `CommitStore.db_handle`; [CommitBuilder](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/commit_builder.ex) performs raw CubDB reads. A multi-store design cannot be correct while “not in this CubDB” is treated as “does not exist.”

## Design goals

The storage design should provide all of the following:

1. One logical namespace for commits and other content-addressed objects.
2. One authoritative owner for heads, pins, policy, and placement facts.
3. Different retention obligations without per-object policy sprawl.
4. Different physical cost and performance profiles without changing object identity.
5. Safe promotion when an ephemeral object becomes referenced by durable work.
6. Reversible hot-to-cold demotion before any irreversible deletion.
7. A verifiable explanation for every semantic absence.
8. Crash-safe movement that never creates a zero-copy interval.
9. Direct concurrent reads without serializing the entire workload through one GenServer mailbox.
10. Compatibility with future pod leases, chit pins, federation, and artifact garbage collection.

The design should not become a generic storage optimizer. Commonplace needs a small number of fixed tiers and one-way lifecycle transitions whose correctness can be audited.

## Four independent dimensions

The current discussion risks treating “ephemeral” as a bundle of unrelated properties. Four dimensions should be modeled independently.

| Dimension | Question | Examples |
|---|---|---|
| **Retention** | When may the last obligated copy disappear? | Forever; after a reconstructible snapshot; after a lease and grace period |
| **Residency** | Where are bytes currently available? | Core hot KV; cold segment; lease partition; local cache |
| **Replication** | Which verified copies and acknowledgements are required? | Local only; workspace quorum; federated durable witness |
| **Authority** | Who may lower the obligation or declare expiry? | Manifest policy; authorized eviction ledger; governed workspace action |

These dimensions lead to two important rules:

- Moving a durable object from hot KV to cold history changes residency, not retention.
- Deleting a local replica while another obligated replica exists changes replication, not semantic existence.

Only removal of the last copy required by policy is semantic expiry.

## Proposed architecture

```text
                  CommitStoreClient
                         |
                    Store.Router
                         |
       +-----------------+-------------------+
       |                 |                   |
   CoreStore       HistoryStore         LeaseStore
    (CubDB)      (immutable segments)   (lease cohorts)
       |                                     |
       +---------- ArtifactStore ------------+
                         |
                     CacheStore
                 (derived, disposable)
```

This is one logical store with multiple byte providers. It is not a collection of peer databases that independently claim authority.

### CoreStore

CoreStore should remain CubDB initially. It is the durable control plane and hot admission buffer.

It owns:

- current document heads and merge pointers;
- the logical object-to-document index;
- subtree manifests and normalized retention policies;
- retention roots and their provenance;
- store-assigned admission times;
- lease records;
- placement intents and verified placement receipts;
- capability, revocation, attestation, and trust authority records;
- eviction authority and completed semantic-expiry records;
- recently admitted commits; and
- any immutable object whose safety floor currently requires hot residency.

New commits should continue to land in CoreStore atomically with their head update. Introducing multiple stores must not weaken the current commit-plus-head write boundary.

### HistoryStore

HistoryStore holds immutable, durable, colder data. It should use append-only segments rather than a second mutable KV with an independent compaction regime.

A segment should be:

- immutable after sealing;
- self-describing and format-versioned;
- checksummed at both segment and record levels;
- indexed from object ID to byte offset;
- readable without loading the entire segment;
- verifiable by decoding each commit and running `Commit.verify_id`;
- recoverable without CoreStore by rebuilding a placement catalog from segment manifests; and
- organized by a stable cohort such as document plus snapshot epoch, not arbitrary per-object shuffling.

The [storage SLA reaction note](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/notes/2026-08-12-storage-sla-reaction.md) already favors hot KV plus cold append-only segments and a fixed-tier, one-way mover. This proposal makes that direction operational.

### LeaseStore

LeaseStore holds time-bounded history that has not acquired a durable reason to survive. Its primary partition should be a lease or retention cohort, not a signer identity.

A coding pod may have a local replica for latency and offline operation, but the node-level LeaseStore remains the storage abstraction. Routing by signer would be incorrect because identical content can be referenced across identities and because a later chit, pin, merge, or durable link can promote the same object.

LeaseStore must never be the sole copy of:

- a current head;
- the closure of a chit pin;
- a gold or otherwise retention-bearing attestation;
- data behind an explicit durable link;
- data awaiting a promotion acknowledgement;
- a reconstructible snapshot or required derivation map; or
- imported siblings that are still inside the merge and federation grace window.

### ArtifactStore

The existing ArtifactStore is the correct basic shape: a small, content-addressed filesystem store for large binary payloads. The [binary artifact reference design](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-11-binary-artifact-ref-design.md) explicitly favors that simplicity.

Artifact retention should be derived from references in retained commit closure. ArtifactStore does not need to become a general database, but it eventually needs the same placement receipts, reachability accounting, quarantine, and purge discipline as commit bytes.

### CacheStore

CacheStore holds values whose loss changes performance but not meaning. `execute_clean` results, materialized projections, decoded segment pages, and similar derivations belong here.

This is the safest first physical split because it establishes the adapter and lifecycle boundary without putting canonical state at risk. CacheStore may be memory-backed at first and gain bounded local persistence later.

## The Store.Router contract

All object reads should pass through a narrow routed-reader interface. The interface should describe semantic outcomes, not CubDB implementation details.

An illustrative contract is:

```elixir
@type lookup_result(value) ::
        {:ok, value, placement()}
        | {:expired, SlaTombstone.t()}
        | :not_found
        | {:unavailable, placement(), reason()}

@callback fetch_object(object_id(), read_options()) :: lookup_result(term())
@callback put_admitted(object(), admission_context()) :: {:ok, receipt()} | {:error, term()}
@callback ensure_durable(object_id(), retention_reason()) :: {:ok, receipt()} | {:error, term()}
```

The read order should be:

1. check CoreStore hot bytes;
2. consult placement facts and try every recorded immutable location;
3. check a completed semantic-expiry record;
4. otherwise return ordinary absence or temporary unavailability.

This order matters. [Projection](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/projection.ex) currently checks `get_commit` and then interprets a matching tombstone as `{:evicted_per_sla, ...}`. Once bytes can be cold or leased, a miss in CoreStore must not become evidence of eviction.

Cold reads may populate a hot cache. Rehydration changes residency only; it must not silently change retention.

### Preserve the local read fast path

Closing raw CubDB access should not force all reads through a GenServer process. Introduce a `Store.ReadView` or `CommitReader` whose local adapter can still perform direct concurrent reads against stable handles. The abstraction boundary is “all locations are resolved consistently,” not “all requests use one mailbox.”

Tests and source scans should make raw `CubDB.get` calls outside storage adapters a build failure.

## Retention policy and reachability

### A small policy grammar

[Cell.Manifest](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/cell/manifest.ex) already defines `durable`, `compactable`, and `ephemeral` SLA tiers. That vocabulary should remain. Its `retention` value, however, is currently only validated as a non-empty string for compactable and ephemeral cells.

Replace the free-form value with a small, versioned data grammar. For example:

```elixir
{:forever, version: 1}
{:after_snapshot, cold_after: "7d", expire_after: "180d", version: 1}
{:ttl, duration: "24h", grace: "6h", version: 1}
```

The exact durations are policy choices. The important constraint is that the grammar is normalized, deterministic, and auditable. Do not introduce an arbitrary policy DSL.

Legacy or unknown policy values must default to durable behavior during migration.

### Store-assigned time

TTL must start from a store-assigned admission time. A [Commit](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/commit.ex) contains a timestamp, but that timestamp is peer-provided and excluded from the content ID. It is unsuitable as the authority for deletion.

CoreStore should record an `admitted_at` fact when it first accepts an object into the local retention domain. Imported objects may also need `first_seen_at` and source information, but none of those facts should alter the content-addressed object itself.

### Effective obligation

The planner should calculate the strongest applicable obligation:

```text
effective_obligation(object) = max(
  subtree SLA floor,
  incoming strong-reference obligations,
  intrinsic safety floors
)
```

Candidate roots include:

- current tips and unresolved merge heads;
- chit and moment pins;
- gold or retention-bearing attestations;
- explicit durable links;
- active deployment promotions;
- unmerged imported siblings during their grace period;
- reconstructible snapshots and the derivation maps they require; and
- security proof objects whose validity depends on preserved ancestry.

The planner expands those roots into the closure necessary to preserve their meaning:

- commit parents back to a sufficient snapshot or genesis;
- merge parents where the data type requires both histories;
- capability proof chains and signer identity evidence;
- snapshot ancestors and derivation maps;
- referenced artifact content IDs; and
- any other typed, retention-bearing reference.

The snapshot plans already treat snapshots as self-contained read anchors and derivation maps as necessary evidence for correct late-edit handling: [snapshot compaction](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/snapshot-compaction.md) and [late edits and derivation maps](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/late-edits-and-derivation-map.md).

### Typed references

Commonplace needs an explicit distinction between:

- **strong references**, which promote the target or required closure to at least the source's obligation; and
- **weak references**, which may resolve to a legitimate tombstone or absence.

Until reference types are fully classified, unknown reference forms should be treated as strong. A boolean such as `pinned?` or `witnessed?` is not enough: retaining the pin row while deleting the history required to reconstruct its moment would preserve the label and destroy the meaning.

### `survives_sla?` is vocabulary, not proof

`Cell.Manifest.survives_sla?/2` currently accepts caller-supplied booleans such as `pinned?`, `snapshot?`, `tip?`, and `witnessed?`. It is useful as a compact description of intended rules. It must not be the final production deletion decision.

The storage system must derive those facts from a specific, versioned store view and retain enough evidence to reproduce the decision.

## Placement records

CoreStore should track physical placement without making it part of object identity. A minimal conceptual schema is:

```text
object_id
object_kind
logical_owner / doc_uuid
admitted_at
retention_class
retention_revision
locations[]:
  backend
  cohort_or_segment
  offset_or_key
  checksum
  verified_at
lease_id?
promotion_state?
```

This does not require one mutable row per object forever. Segment manifests can compact location facts for sealed cohorts, while CoreStore retains a concise catalog and any exceptional state. The first version may use straightforward rows; optimize only after measurements identify a real problem.

Placement metadata is operationally important but reconstructible. Segment manifests and on-disk lease manifests should be sufficient to rebuild it after loss.

## Safe state transitions

### Hot-to-cold demotion

```text
core_hot
    |
    v
cold_copy_written
    |
    v
cold_copy_verified
    |
    v
placement_recorded
    |
    v
hot_copy_dropped
```

The protocol is:

1. Select candidates against a named retention and reachability revision.
2. Write and fsync a new immutable segment.
3. Read it back, validate checksums, decode records, and verify content IDs.
4. Atomically record the verified placement receipt in CoreStore.
5. Remove hot payloads only after that receipt is durable.
6. Keep the logical document/object index so reads can route to the segment.

Every crash point produces either an orphan cold copy or duplicate copies. Neither outcome creates data loss. Recovery can discover an orphan segment from its manifest or resume cleanup from the receipt.

Demotion does not create a tombstone because the object still exists semantically.

### Lease promotion

An object in LeaseStore can acquire a stronger obligation when it becomes reachable from a chit, a durable link, a merge, an attestation, or a governed pin.

Promotion is a barrier, not a label update:

1. Record a promotion intent and retention reason.
2. Calculate the required closure at a named store revision.
3. Copy that closure into CoreStore or HistoryStore.
4. Verify the destination bytes.
5. Record durable placement receipts and the promoted retention root.
6. Acknowledge promotion to the caller.

A pod or lease may terminate only after all requested durable promotions and pending writes have crossed this barrier. This is particularly important for attenuated-identity coding pods: a successful chit commit must not point into storage that disappears with the container.

### Lease expiry

```text
lease_resident
      |\
      | +--> promoted --> durable hot or cold
      |
      +----> quarantine --> tombstoned --> purged
```

Expired lease data should first move into quarantine through an atomic filesystem operation such as a directory rename. Quarantine makes the decision reversible during a grace window and separates “not served normally” from “physically destroyed.”

## Three operations that must not be conflated

| Operation | Meaning | Record produced |
|---|---|---|
| Hot-to-cold demotion | Same obligated object, cheaper residency | Placement receipt |
| Local replica drop | Another obligated replica remains | Replica-eviction receipt |
| Last obligated copy expires | Object is no longer required to exist | SLA tombstone |

This distinction becomes mandatory under federation. A node cannot truthfully publish a semantic tombstone merely because it discarded its local copy.

## Semantic expiry and tombstones

[SlaTombstone](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/sla_tombstone.ex) supplies useful vocabulary and verification primitives, but the module explicitly has no production writer. Its constructor currently accepts the subtree, SLA, commit IDs, eviction time, and dropped hash from the caller.

Signature, shape, anchor, and ordering checks do not prove:

- that the objects were eligible under the current manifest;
- that they belonged to the declared subtree or contiguous range;
- that no strong pin or durable incoming reference existed;
- that required replicas acknowledged the operation;
- that the claimed bytes were actually deleted; or
- that the supplied dropped hash describes the removed bytes.

Before adding a production writer, introduce a store-created eviction transaction:

```text
EvictionIntent
  - authority-ledger position
  - manifest and policy revision
  - reachability-root digest
  - exact object range or segment identity
  - source placement receipts
  - required replica acknowledgements
  - quarantine location

EvictionCompletion
  - intent identity
  - observed bytes/segment hash
  - completed acknowledgements
  - completion time
  - tombstone identity
```

The [EvictionAuthorityLedger](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/store/eviction_authority_ledger.ex) already gives store-owned monotonic ordering for activation, registration, and retirement. It solves authorization ordering. It does not by itself prove eligibility or completion.

The existing tombstone format should be versioned before the first production writer if additional scope or evidence fields are required. That is inexpensive now and costly after tombstones federate.

At minimum, the tombstone must distinguish:

- local replica eviction; and
- semantic expiry for the workspace or federation retention domain.

Only the latter should cause Projection to return an SLA-expired verdict.

## Migration plan

### Phase 0: inventory and measurement

Classify every current key family as:

- authoritative mutable state;
- canonical immutable state;
- derived index;
- disposable cache;
- retry queue; or
- security and constitutional evidence.

Measure byte volume, write rate, point-read rate, scan patterns, and rebuild cost. Existing values default to durable until explicitly migrated.

Deliverables:

- a checked-in keyspace inventory;
- a repeatable store census command;
- size and access measurements from representative workspaces; and
- a list of every module that reads the CubDB handle directly.

### Phase 1: close the raw-handle escape hatch

Introduce `Store.ReadView` or `CommitReader` and migrate `CommitStoreClient`, `CommitBuilder`, Namespace code, trust ledgers, Projection, and tests.

Preserve concurrent direct reads inside the local adapter. Add a source-level guard that rejects raw CubDB reads outside storage implementation modules.

This phase changes no placement behavior.

### Phase 2: split the safe extremes

Move `execute_clean` and other explicitly rebuildable results into CacheStore. Keep PendingImports in memory. Keep capabilities, revocations, attestations, and authority records in CoreStore.

This proves multi-backend lifecycle and observability without moving canonical history.

### Phase 3: add the placement catalog and router

Add:

- store-assigned admission time;
- location facts;
- lease identity;
- placement intents and receipts;
- retention reasons and revisions; and
- router-level semantic outcomes.

Backfill every existing commit as `core_hot` and durable. Initially, route reads only to CoreStore and shadow-compare the new reader against the current path.

### Phase 4: add cold segments and lossless demotion

Implement one cold segment format and one constrained mover. The first eligible cohort should be compactable, pre-snapshot history that is unpinned and has no imported sibling ambiguity.

Do not write tombstones and do not delete the final copy. The rollback operation is copying verified records back into CoreStore.

### Phase 5: implement retention roots, closure, and LeaseStore

Add explicit roots for chit pins, gold attestations, durable links, active tips, snapshots, and deployment promotion. Implement strong-reference closure and the pod teardown promotion barrier.

Begin admitting explicitly ephemeral subtrees into lease cohorts only after promotion tests prove that durable references cannot strand data.

### Phase 6: enable semantic eviction

Add store-created eviction intents, quarantine, required acknowledgements, completed tombstones, and delayed purge. Exercise recovery after every transition and federation behavior under partial availability.

Only this phase physically removes the final obligated copy.

## First buildable vertical slice

The first milestone should be:

> Losslessly demote one compactable snapshot epoch through the routed reader.

This is a narrower and safer target than “implement SLA deletion.” It validates the architecture while every operation remains reversible.

### Scope

- one local node;
- one document or subtree cohort;
- compactable history strictly before a verified reconstructible snapshot;
- no imported unresolved sibling heads;
- no pin, chit, gold attestation, or durable external reference into the candidate range;
- one immutable segment implementation;
- CoreStore as the only mutable authority; and
- no tombstone production.

### Acceptance criteria

1. Projection before and after demotion returns identical bytes and verdicts.
2. Every moved commit passes decode and `Commit.verify_id` after readback.
3. A pin or head change racing candidate selection invalidates the plan before hot removal.
4. Forced crashes after every protocol boundary leave at least one verified copy.
5. An orphan segment can be discovered and reconciled.
6. A placement receipt can drive idempotent hot cleanup after restart.
7. Ordinary absence remains distinguishable from cold residence, temporary unavailability, and semantic expiry.
8. Demotion creates no SLA tombstone.
9. Rollback restores the hot payload without changing logical identity or heads.
10. The read path remains concurrent rather than serializing through the CommitStore GenServer.
11. Required snapshots and derivation maps remain present.
12. Metrics expose hot bytes, cold bytes, duplicate bytes, unresolved intents, verification failures, and routed-read latency.

### Suggested work packages

1. `Store.Reader` protocol and CoreStore adapter.
2. Direct-handle call-site migration and enforcement test.
3. Placement schema with intents and receipts.
4. Versioned cold-segment writer, reader, verifier, and recovery scanner.
5. Conservative candidate planner for one snapshot epoch.
6. Crash-injection test harness around every state transition.
7. Shadow projection and operational metrics.

## Non-negotiable invariants

1. There is one logical DAG and one authoritative owner for heads.
2. A head, pin, chit, or durable reference never acknowledges success while its required closure is unavailable.
3. Moving bytes between stores never creates a semantic tombstone.
4. A local replica drop never impersonates global semantic expiry.
5. Source bytes are removed only after a durable, read-back-verified destination receipt.
6. Final deletion never depends on caller-supplied eligibility booleans or a commit's self-reported timestamp.
7. Semantic expiry uses a named manifest, retention, reachability, and authority revision.
8. Every incomplete movement or eviction is named, observable, idempotent, and recoverable.
9. Unknown legacy data and policy default to durable retention.
10. Rebuildable placement metadata can be recovered from self-describing immutable stores.
11. Security authority, revocations, and proof records do not silently inherit ephemeral treatment from nearby application data.
12. Commonplace exposes a small fixed lifecycle, not a generic per-object placement optimizer.

## Failure model and required tests

The architecture should be tested against concrete failure boundaries rather than only happy-path policy evaluation.

| Failure | Required result |
|---|---|
| Crash after cold write, before verification | Orphan segment is discoverable; Core copy remains |
| Crash after verification, before receipt | Duplicate survives; recovery may record or discard orphan |
| Crash after receipt, before hot removal | Duplicate survives; cleanup resumes idempotently |
| Crash after hot removal | Routed read resolves verified cold placement |
| Segment checksum mismatch | Core copy remains or object is reported unavailable; never silently absent |
| Pin arrives during demotion | Revision mismatch aborts source removal |
| Durable reference targets leased object | Reference acknowledgement waits for promotion barrier |
| Pod terminates during promotion | Lease cleanup waits or fails closed; intent resumes after restart |
| Eviction authority changes mid-plan | Plan invalidates before quarantine or completion |
| Replica acknowledgement is missing | Final semantic expiry does not complete |
| Placement catalog is lost | Segment and lease manifests rebuild it |
| Tombstone exists but bytes are found | Bytes win for retrieval; inconsistency is surfaced for repair |

Property-based state-machine tests are appropriate for the movement protocol: generate writes, head changes, pins, moves, crashes, restarts, and reads, then assert that obligated objects are always retrievable and that no semantic-expiry verdict appears without a completed authorized transition.

## Operational observability

Expose enough state to answer why an object is present, absent, or expensive:

- bytes and object counts by residency and retention class;
- lease cohorts by expiry and promotion state;
- open placement and eviction intents;
- duplicate and orphan segment bytes;
- verification failures and corrupt locations;
- routed read hit rate and latency by backend;
- rehydration count and cache pressure;
- objects retained by each root type;
- candidate bytes blocked by pins, tips, imported siblings, or derivation maps; and
- quarantine bytes awaiting purge.

An operator-facing explanation command should report, for an object ID:

```text
retained because: chit <id> pins moment <id>
required closure: snapshot <id> + derivation map <id>
locations: core_hot, history segment <id>
policy: compactable/v1
next eligible transition: hot -> cold after <time>
```

Without this explanation surface, retention bugs will be nearly impossible to distinguish from leaks or data-loss risks.

## Interaction with attenuated-identity pods and chits

The tiered store is the durability substrate for disposable coding environments:

- frequent edit-clock CRDT commits can be admitted under a deployment lease;
- the current working tip and recent unresolved history remain protected;
- an explicit chit commit creates a durable retention root and promotion barrier;
- the chit is acknowledged only after its exact reconstructible closure has a durable verified placement;
- failed experiments can age out after their lease and grace period; and
- the Git projection consumes durable chit moments without depending on a still-running pod.

This separation avoids two bad extremes: retaining every token-level experiment forever, or allowing a container teardown to erase history that a signed chit claims to preserve.

The storage identity of a commit remains unchanged across hot, cold, and leased locations. That lets CRDT synchronization, chits, and Git projection speak about one object graph even when nodes make different local residency choices.

## Decisions still required

1. The exact versioned grammar and default durations for `compactable` and `ephemeral` retention.
2. Which link types are strong, which are weak, and whether a durable link pins one moment or a live subtree.
3. The retention semantics of accepted but unmerged imported sibling heads.
4. The minimum durable replica or witness acknowledgement required before local and semantic eviction.
5. The scope encoded by a tombstone: node, workspace, trust domain, or federation.
6. Cold-segment cohort and packing rules, including maximum size and snapshot boundaries.
7. Whether placement rows remain per object or compact into sealed-segment catalog entries after stabilization.
8. Exactly which derivation maps and historical snapshots are required for late edits and merge correctness.
9. The closure a chit pins: content only, reconstruction history, capability evidence, artifacts, and/or attestations.
10. Grace periods and recovery behavior for pods that disappear without a clean teardown barrier.

These are constrained protocol decisions. They should not block phases 1 through 4, which are valuable and safe under a conservative durable default.

## Recommendation

Keep the current CubDB as CoreStore: the durable control plane, head authority, policy ledger, placement catalog, and hot admission buffer. Put immutable history behind a routed reader and add a self-describing cold segment store. Split disposable caches early. Add lease cohorts only after durable promotion is a real barrier.

Then make the first space-saving operation a reversible, verified hot-to-cold demotion. Do not treat “missing from CoreStore” as “evicted,” and do not create tombstones for storage movement. Implement final semantic expiry only after the system can derive retention closure from a versioned view, prove replica obligations, quarantine candidates, and record completion from store-observed evidence.

That sequence gets Commonplace to tiered ephemerality without putting its CRDT history, security evidence, or future chit guarantees at risk.
