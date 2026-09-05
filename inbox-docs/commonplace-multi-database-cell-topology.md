---
title: "Cells Can Live Anywhere"
subtitle: "A multi-database topology for Commonplace"
date: 2026-08-20
status: proposal
scope: "Cell placement, routing, replication, publication, retention, and migration"
companion_documents:
  - commonplace-cellular-architecture-pitch-and-roadmap.md
  - commonplace-mounted-tree-directory-design.md
  - commonplace-storage-ephemerality-proposal.md
  - commonplace-multiplayer-replication-proposal.md
---

# Cells Can Live Anywhere

## A multi-database topology for Commonplace

Commonplace should support cells living in different databases. But it should
not achieve that by sharding one global keyspace.

A sharded global key-value store still has one ontology: global keys, global
transactions, global indexes, global failure semantics, and a routing layer
that decides which fragment of the one database owns each key. That would move
the current monolith onto the network without dissolving it.

The cellular model gives Commonplace a cleaner topology:

> **A cell owns a local causal history. A store hosts replicas of cells. An
> assembly composes cells by stable reference. A router resolves those
> references without making physical location part of identity.**

One database may host ten thousand cells. One important cell may have replicas
in three databases. A cell may move from one database to another without
changing its `CellID`, mounted path, contract, or generation hashes. A checkout
may assemble cells from several databases into one ordinary directory tree.

This document specifies how to make that topology real without introducing
cross-database transactions, a mandatory global placement database, or a new
source-control format that ordinary coding agents cannot use.

## 1. The decision

Commonplace should adopt the following model:

1. **`CellID` is semantic identity.** It survives movement, replication,
   renaming, and release.
2. **`GenerationHash` is immutable version identity.** It names an exact cell
   generation and its reconstruction closure.
3. **`StoreID` is physical placement identity.** It names a database or storage
   service capable of hosting some part of a cell replica.
4. **Placement is many-to-many.** A store hosts many cells; a cell may occupy
   many stores.
5. **References name cells, not stores.** Database locations are replaceable
   resolution hints and signed placement facts.
6. **Transactions stop at the cell boundary.** A database transaction may
   atomically update one cell's records. It must not establish correctness
   across unrelated cells.
7. **Multi-cell atomicity means atomic selection.** Child generations are
   prepared independently; a parent assembly generation selects them together.
8. **Replication is cell-scoped.** Anti-entropy compares cell inventories and
   frontiers rather than enumerating an entire workspace.
9. **Authority is independent of placement.** Possessing database credentials
   or hosting bytes does not grant the capability to change a cell.
10. **The directory tree remains a projection.** Mount resolution may cross
    databases, but the resulting checkout remains a normal tree.

The foundational separation is:

| Question | Answered by |
| --- | --- |
| What is this thing? | `CellID` |
| Which exact version is this? | `GenerationHash` |
| Where can I currently retrieve it? | Placement index and receipts |
| Who may change it? | Cell authority policy and capabilities |
| Which version is published? | Cell-local branch or assembly ref |
| How long must it remain available? | Retention claims and cell policy |
| Where does it appear to a user? | Assembly mount path |

None of these identities should be smuggled into another.

## 2. The physical topology

A plausible Commonplace installation may look like this:

~~~text
Root assembly cell
  |
  +-- apps/commonplace_core  -- CellRef(core) ------> source-db-west
  |
  +-- apps/commonplace_sync  -- CellRef(sync) ------> source-db-east
  |                                                \-> source-db-west replica
  |
  +-- vendor/yepochs         -- Pinned(yepochs, G7) -> history-object-store
  |
  +-- customers/acme         -- CellRef(acme) ------> tenant-db-acme
  |
  +-- evidence               -- CellRef(evidence) --> evidence-db

Store.Router
  +-- local placement index
  +-- signed placement receipts
  +-- configured peers and seed locations
  +-- local cache
~~~

The root assembly may itself live in `source-db-west`. That does not make that
database the semantic root of every mounted child. The assembly contains
`CellRef`s; each child retains its own history, authority, retention policy, and
placement.

Likewise, the fact that `core` and the root assembly share a database is merely
physical co-location. It does not give them a shared transaction or causal
history.

## 3. A database hosts cell replicas

The storage API should never expose a database as one semantic map. Every
operation must be scoped to a cell:

~~~text
CellStore.fetch(cell_id, object_ref)
CellStore.append(cell_id, signed_operations)
CellStore.inventory(cell_id, frontier)
CellStore.install_generation(cell_id, generation)
CellStore.advance_ref(cell_id, ref_name, expected, next)
CellStore.retain(cell_id, generation, claim)
~~~

A physical backend may internally use keys such as:

~~~text
cell/<CellID>/manifest/...
cell/<CellID>/operations/...
cell/<CellID>/generations/...
cell/<CellID>/refs/...
cell/<CellID>/retention/...
cell/<CellID>/replication/...
~~~

That physical prefixing is an implementation detail. Application code must not
receive an API for scanning or mutating arbitrary prefixes. Administrative
inventory may enumerate cells in a store, but no product invariant may depend
on a global semantic scan.

A **cell replica** is the cell-local material a store promises to serve. Its
declared coverage may be:

- a writable live frontier and the history needed to reconcile it;
- the complete reconstruction closure of named generations;
- immutable history through a declared frontier;
- a leased working set;
- or a rebuildable cache with no durability promise.

This permits the physical storage tiers already planned for Commonplace:

| Store role | Cell-scoped responsibility |
| --- | --- |
| CoreStore | Mutable frontiers, branch refs, manifests, authority facts, and hot history |
| HistoryStore | Verified immutable cell segments and generation closure |
| LeaseStore | Time-bounded, promotable live or speculative history |
| ArtifactStore | Large immutable values addressed from cell generations |
| CacheStore | Rebuildable indexes, projections, and execution results |

A live cell may therefore use one CoreStore and one or more HistoryStores. That
does not violate the cell boundary: the cell is the semantic unit; the stores
are its physical substrate.

## 4. Placement is data, not identity

The router needs to know where cells can be found, but Commonplace should not
create a single authoritative `CellID -> database` table. That table would
become the new workspace database and a system-wide availability dependency.

Instead, placement should be represented by signed, expiring facts:

~~~text
PlacementReceipt {
  cell_id
  store_id
  replica_id
  coverage
  observed_frontier
  cell_epoch
  retain_until
  issued_at
  expires_at
  store_signature
  placement_authority_signature?
}
~~~

A placement receipt says, approximately:

> Store S attests that replica R currently contains this declared coverage of
> cell C and promises to retain it through time T.

The local `PlacementIndex` is a rebuildable projection of:

- locally hosted replicas;
- cached placement receipts;
- receipts exchanged through anti-entropy;
- configured work-instance peers;
- and optional assembly- or account-scoped topology directories.

Canonical `CellRef`s do not contain database endpoints:

~~~text
Live(CellID)
Compatible(CellID, ContractEpoch, AcceptancePolicy)
Pinned(CellID, GenerationHash)
~~~

Resolution envelopes may carry expiring locator hints, but those hints are not
part of cell identity or generation identity. Changing a database endpoint must
not require minting a new application release.

### 4.1 Bootstrap

There is still a finite bootstrap problem. A fresh replica must know where to
find at least one root.

A local workspace seed should contain:

~~~text
WorkspaceSeed {
  root_assembly_cell_id
  seed_locator_hints
  trusted_identity_roots
}
~~~

Once the root assembly is found, its reachable cells can be located through
cached receipts, configured peers, and topology exchange. This resembles DNS
delegation more than a globally sharded database: identity is stable, location
is refreshed, and caches may survive temporary control-plane failure.

## 5. Store.Router

`Store.Router` is the only component that should translate cell references into
physical database operations. It performs five distinct jobs:

1. **Authorize:** determine whether the requesting principal may read, write,
   publish, retain, or administer the cell.
2. **Locate:** obtain candidate replicas from the local placement index and
   peer discovery.
3. **Select:** choose replicas satisfying region, durability, freshness,
   residency, and cost policy.
4. **Verify:** validate signatures, hashes, frontiers, and placement coverage.
5. **Classify failure:** distinguish absence, temporary unavailability,
   legitimate expiry, denial, and corruption.

The router must never turn one failure class into another. In particular:

- a timed-out database is not evidence that a cell does not exist;
- an expired weak reference is not an infrastructure outage;
- a missing pinned generation must not silently resolve to a newer generation;
- a stale live replica must not claim to represent a complete current frontier;
- and a failed authorization check must not be retried against a less strict
  store.

The semantic read outcomes should remain explicit:

~~~text
Present(value, provenance)
Unavailable(known_placements, retry_policy)
Absent(proof_or_authoritative_observation)
Expired(tombstone_or_retention_fact)
Denied(authority_fact)
Corrupt(store_id, evidence)
~~~

## 6. Read resolution across databases

The three reference modes require different resolution behavior.

### 6.1 Pinned references

For `Pinned(CellID, GenerationHash)`, the router:

1. finds replicas claiming the named generation;
2. fetches its reconstruction closure from one or several stores;
3. verifies every immutable object against its content hash;
4. verifies that the closure belongs to the expected `CellID`;
5. records verified objects in the local cache;
6. returns the exact generation or an explicit failure.

Pinned generations are maximally portable. Any store with the verified closure
can serve them, and caches can retain them without participating in live cell
coordination.

### 6.2 Compatible references

For `Compatible(CellID, ContractEpoch, AcceptancePolicy)`, the router:

1. queries accepted generation records for the cell;
2. evaluates contract and evidence requirements;
3. deterministically chooses a satisfying generation;
4. records that resolution in the checkout or release lock;
5. proceeds as a pinned read.

A checkout must not repeatedly re-resolve a compatible reference underneath a
running build. It resolves once and becomes pinned for that view.

### 6.3 Live references

For `Live(CellID)`, the router negotiates cell-local frontiers with selected
replicas. There is no universal `latest` value. The result must state:

- which frontier was observed;
- which replicas contributed;
- whether known concurrent heads remain;
- and what freshness or quorum policy was satisfied.

Authorized offline edits may be appended to a local durable replica and
reconciled later. A release, however, is never made from the vague concept of
"whatever is latest." A chit freezes an explicit frontier first.

## 7. Writes and replication

Live edits should follow a local-first, signed, idempotent path:

1. Resolve the path through the assembly mount table to its owning `CellID`.
2. Check the actor's cell-scoped capability.
3. Create signed CRDT operations with stable operation IDs.
4. Append them durably to one authorized local replica.
5. Return a receipt naming the resulting cell frontier.
6. Replicate operations asynchronously to other required replicas.
7. Repair missed notifications through cell-scoped anti-entropy.

The router must not implement replication by opening simultaneous database
transactions and hoping they all commit. A signed operation is appended once
and may be delivered repeatedly. Stores deduplicate it by identity.

Different acts require different acknowledgement thresholds:

| Act | Minimum acknowledgement |
| --- | --- |
| Interactive live edit | One authorized durable local replica; replication debt is visible |
| Chit candidate | Complete reconstructible frontier on the candidate store |
| Published generation | Cell placement policy's durable-copy requirement |
| Release assembly | Durable child-generation and retention receipts plus parent publication |
| Irreversible external effect | Active claim or lease with fencing and durable result record |

This preserves offline collaboration without allowing an under-replicated
candidate to masquerade as a durable release.

## 8. Multi-cell publication without a distributed transaction

Suppose one coherent change modifies three mounted cells:

~~~text
core assembly      on database A
sync child cell    on database B
web child cell     on database C
~~~

The operation should use **prepare without rollback, then publish one parent
selection**:

1. Freeze the selected `sync` frontier and mint immutable generation `S2`.
2. Freeze the selected `web` frontier and mint immutable generation `W9`.
3. Verify both generation closures.
4. Place each generation on the number and kind of durable stores required by
   its cell policy.
5. Install target-local retention claims for the strong references the parent
   is about to create.
6. Collect durability and retention receipts for `S2` and `W9`.
7. Mint parent assembly generation `A6`, pinning `S2`, `W9`, and every unchanged
   child generation.
8. Advance the parent assembly branch or release ref from `A5` to `A6` using
   the parent cell's own concurrency protocol.
9. Broadcast invalidation and replication hints asynchronously.

The critical distinction is:

> **The child generations are not created atomically. They are selected
> atomically by the parent assembly generation.**

Until step 8, readers continue to see `A5`. After step 8, readers resolving the
release see one exact set of child generations. No reader sees a half-updated
release merely because `S2` was written before `W9`.

The parent ref advancement is cell-local. It may use a compare-and-swap ref, an
accepted-head-set transition, or another cell-local concurrency protocol. It
does not hold locks in databases B and C.

### 8.1 Crash recovery

Every step is idempotent. Recovery depends on durable facts rather than a
coordinator remembering what it was doing.

| Crash point | Result | Recovery |
| --- | --- | --- |
| After one child generation | Invisible candidate | Resume preparation or collect after grace period |
| After all child generations | Invisible candidates | Recreate the parent generation deterministically |
| After retention claims | Extra safe retention | Reconcile against parent roots; release an unused durable claim only with proof, or let a non-release lease expire |
| After parent generation, before ref advancement | Unpublished parent | Retry the cell-local ref operation |
| After ref advancement, before notification | Release is published | Anti-entropy repairs missed hints |
| After publication, one child store fails | Release remains exact | Fetch another promised replica or return `Unavailable` |

The system never rolls back immutable child generations. It either publishes a
parent that references them or eventually collects them when they are no longer
rooted.

## 9. Retention across database boundaries

Cross-database references create obligations. If assembly `A6` in database A
strongly pins generation `S2` in database B, database B must not collect `S2`
merely because it has no local application root.

Commonplace should represent the obligation explicitly:

~~~text
RetentionClaim {
  claim_id
  source_cell_id
  source_generation
  target_cell_id
  target_generation
  strength
  mode: durable | leased
  required_closure
  retain_until?
  renewable_by?
  signature
}
~~~

Before publishing a strong parent reference, the publisher installs the claim
with the target cell or a store obligated to retain its closure. The target
returns a signed receipt. Publication may proceed only after the required
receipts exist.

A published release uses a **durable** claim. It remains until an explicit,
signed release-of-claim operation proves that the source generation is no
longer retained by any strong root. A live branch, preview, or speculative
assembly may use a **leased** claim with a conservative grace period and an
assigned renewer. Failure to renew becomes retention debt well before expiry;
it must never cause a still-published release to disappear.

This is intentionally asymmetric:

- installing an unused retention claim is a harmless storage leak; a leased
  claim may expire, while a durable claim is released only after proving its
  source generation is unrooted;
- publishing without a retention claim could create an unreconstructible
  release and is forbidden.

Garbage collection remains cell-local. A cell generation is retained by:

- its own live or release roots;
- durable or unexpired leased inbound strong retention claims;
- cell policy minimums;
- evidence or audit obligations;
- or explicit legal and administrative holds.

Weak references need not create durable claims. They may legitimately resolve
to `Expired`. Unknown legacy references remain strong and durable until
classified.

This turns distributed reachability from a global graph traversal into an
exchange of durable, auditable obligations.

## 10. Moving a cell between databases

Cell movement should be a copy-verify-advertise-drain protocol:

1. **Select the destination.** Confirm that it satisfies residency, encryption,
   durability, and store-capability policy.
2. **Copy closure.** Transfer the required immutable generations, live history,
   manifests, and accepted head set.
3. **Catch up.** Exchange cell-local inventory until the destination reaches
   the required frontier.
4. **Verify.** Check hashes, signatures, reconstruction, and retention claims.
5. **Advertise.** Issue a placement receipt for the destination and make it
   eligible for reads.
6. **Move coordination if necessary.** Transfer any effects lease, branch-ref
   coordinator lease, or preferred availability-anchor designation using a new
   fencing epoch.
7. **Observe.** Shadow reads and anti-entropy confirm that the destination
   behaves identically.
8. **Drain.** Stop routing new work to the old placement.
9. **Retire.** Remove the old copy only after policy, claims, grace periods, and
   failure-domain requirements permit it.

Nothing in the assembly changes:

~~~text
before: CellRef(sync) -> placement index -> database B
after:  CellRef(sync) -> placement index -> database D
~~~

The `CellID`, generation hashes, directory mount, and Git projection remain the
same. If moving a cell changes any of those, physical placement has leaked into
semantic identity.

## 11. Replication, authority, and coordination are separate

Three concepts are easy to collapse accidentally:

### Replica

A replica possesses some declared coverage of a cell and participates in
anti-entropy. It can verify and serve content.

### Authority

An identity possesses a capability to perform a class of acts on a cell. The
right is established by cell policy and signed authority facts, not by network
location or database credentials.

### Coordination anchor

Some operations require a temporarily preferred online participant: advancing
a serialized release ref, claiming a work item, or issuing an external effect.
That participant holds a renewable lease with a fencing epoch. It is an
availability and effects anchor, not the sole source of content truth.

Therefore:

- copying a cell does not grant write authority;
- moving a writer does not create a new cell;
- losing an anchor does not erase accepted history;
- and hosting the root assembly does not authorize changes to mounted children.

For CRDT content, several authorized replicas may accept concurrent signed
edits. For irreversible effects, exactly one active fenced claim is required.
For release selection, conflicts must be serialized or exposed as concurrent
parent heads rather than silently resolved by database arrival order.

## 12. Consistency is chosen per operation

Commonplace should not advertise one global consistency model. Different cell
operations have different semantics:

| Operation | Consistency shape |
| --- | --- |
| Live CRDT editing | Available under partition; causal reconciliation |
| Immutable generation retrieval | Content-addressed and replica-independent |
| Compatible generation resolution | Policy-bounded; pinned once selected |
| Branch or release ref advancement | Cell-local serialization or visible concurrent heads |
| Assembly release | Atomic parent selection of immutable child generations |
| External effect | Fenced lease, idempotent request, durable result |
| Search and dashboards | Rebuildable, explicitly stale projections |

This avoids both false extremes: Commonplace need not run consensus for every
keystroke, and it need not pretend that publishing a release or charging a card
is merely another eventually consistent merge.

## 13. Directory checkout and Git

The multi-database topology is invisible to ordinary coding tools.

To construct a checkout, Commonplace:

1. resolves the root assembly generation;
2. walks its mount graph;
3. resolves every compatible reference to a pin;
4. groups required fetches by candidate `StoreID`;
5. retrieves and verifies cell generations concurrently;
6. materializes each cell beneath its mount point;
7. records a resolution lock and provenance map;
8. presents one ordinary directory tree.

If one mounted cell is unavailable, the checkout reports that mount as
unavailable. It must not materialize an empty directory or substitute another
generation.

Writable mounts route edits back to their owning cell. If the selected database
is remote or read-only, policy may create an authorized local live replica or a
copy-on-write branch override. The mount table, not the physical database,
decides which cell owns a changed file.

Git projection remains:

> mounted natively, flattened for filesystems, inlined for Git

A pinned assembly generation produces one deterministic Git tree with one root
`.git`. The fact that its files came from several databases is recorded in
provenance, not represented as Git submodules.

## 14. Placement policy

Cells should declare requirements, not hard-code database names:

~~~text
CellPlacementPolicy {
  required_durable_copies
  required_online_read_copies
  permitted_regions
  prohibited_failure_domain_overlap
  encryption_domain
  live_write_mode
  maximum_frontier_staleness
  immutable_history_class
  artifact_class
  cache_class
  retention_floor
}
~~~

A placement scheduler chooses stores satisfying those requirements and emits
auditable intents and receipts. The scheduler may optimize cost and locality,
but it cannot weaken cell policy.

Database boundaries should be introduced when one of these differs:

- tenant or security isolation;
- geographic residency;
- retention or deletion regime;
- durability and recovery objective;
- workload or noisy-neighbor profile;
- administrative ownership;
- encryption domain;
- or desired failure blast radius.

The default is not one database per cell. Tiny cells should remain cheap.
Thousands of cells may share a physical database while retaining independent
histories and policies.

## 15. Recommended initial deployment

The first multi-database Commonplace deployment should remain operationally
boring:

~~~text
legacy-core-db
  - compatibility root assembly
  - most existing entity cells
  - identity, contract, and branch-ref cells

source-cell-db
  - one carved implementation cell
  - its live CRDT history and accepted heads

history-store
  - immutable generation segments from both databases

artifact-store
  - large immutable values

local-cache
  - checkout materializations and rebuildable projections
~~~

Use the existing database technology for `legacy-core-db` and
`source-cell-db` initially. The point of the experiment is to prove semantic
and failure boundaries, not to introduce a second database engine.

The best first child is a coherent, low-risk source cell such as Yepochs:

1. mount a pinned Yepochs generation from the second database;
2. prove that checkout and Git projection are byte-identical;
3. permit a writable copy-on-write branch;
4. mint a Yepochs chit in the second database;
5. mint a parent Commonplace assembly chit in the first database;
6. inject failures between every step;
7. then repeat with a live, frequently edited cell such as
   `commonplace_sync`.

## 16. Migration roadmap

### Phase 0 — Scope every operation to a cell

- Add `CellID` to store reads, writes, events, observations, and audit facts.
- Introduce `CellStore` and close direct CubDB escape hatches.
- Treat the current database as `StoreID: legacy`.
- Prove per-cell replay and accepted-head reconstruction without moving bytes.

**Exit:** no new product code relies on a workspace-global key scan or
cross-cell transaction.

### Phase 1 — Introduce placement and routing in shadow

- Add stable `StoreID`, store descriptors, placement receipts, and a local
  placement index.
- Route all reads through `Store.Router`, initially back to the legacy store.
- Record explicit `Present`, `Unavailable`, `Absent`, and `Expired` outcomes.
- Compare routed reads with existing reads and report divergence.

**Exit:** changing a placement record can redirect a cell read without changing
its identity or caller.

### Phase 2 — Move one immutable cell generation

- Write one pinned child generation to a second database or HistoryStore.
- Remove its hot byte copy after verification while keeping safe fallback.
- Resolve it through an assembly mount.
- Produce the same directory checkout and Git tree.

**Exit:** a pinned cell can live outside the root assembly's database and remain
fully reproducible.

### Phase 3 — Move one live cell

- Create a complete live replica in the second database.
- Synchronize cell-local frontiers through anti-entropy.
- Shadow reads and then route writes to the new replica.
- Exercise offline edits, concurrent heads, restart, and missed notifications.
- Drain the original placement through the movement protocol.

**Exit:** the live cell can be edited, reconciled, chitted, and recovered without
the legacy database acting as its hidden authority.

### Phase 4 — Publish a multi-database assembly

- Implement durability receipts and target-local retention claims.
- Mint child chits on separate databases.
- Mint and publish one parent assembly chit.
- Make every step idempotent and resumable.
- Inject crashes before and after every durable fact.

**Exit:** readers observe either the old assembly or the new assembly, never a
partial combination, without two-phase commit.

### Phase 5 — Make replication policy-driven

- Add cell placement policies and a placement scheduler.
- Track durability debt, frontier lag, failure-domain overlap, and claim expiry.
- Automate copy-verify-advertise-drain movement.
- Add per-tenant, geographic, and hot/cold placement classes where justified.

**Exit:** placement changes are routine, observable operations rather than
bespoke migrations.

### Phase 6 — Flip authority

- Make cell-local histories, head sets, and assembly refs authoritative.
- Demote the global latest pointer and placement index to projections.
- Reject raw database writes outside adapters and migration tooling.
- Perform an explicit authority-flip ceremony with rollback conditions.

**Exit:** loss of the legacy global database does not erase the semantic model;
the system can reconstruct authorized assemblies from cell-local facts and
replicas.

## 17. Operational observability

The topology needs a derived operational view, but that view must never become
hidden authority. Operators should be able to ask:

- Which stores currently claim replicas of this cell?
- Which generation closures satisfy the cell's durability policy?
- Which replicas are behind which frontiers?
- Which published assemblies depend on this generation?
- Which retention claims are near expiry?
- Which cells have unresolved placement or replication debt?
- Which database failure would violate a cell's recovery objective?
- Which orphan generations are eligible for collection?
- Which mounts failed during a checkout, and why?
- Which effects anchors or writer leases are currently active?

Useful metrics include:

- resolution latency by cell and store;
- replica freshness and anti-entropy convergence time;
- bytes copied per cell movement;
- durable-copy deficit;
- retention-claim renewal failures;
- orphan-generation age;
- checkout fan-out and cache hit rate;
- unavailable versus absent resolution counts;
- and published generations lacking their required closure.

Every dashboard is rebuildable from cell facts, placement receipts, and audit
events. Deleting the dashboard database must be inconvenient, not
ontologically catastrophic.

## 18. Failure tests

The multi-database topology is not complete until these cases pass repeatedly:

1. Kill the child database during a pinned read; another replica serves the
   exact generation or the result is explicitly `Unavailable`.
2. Kill the parent database after child generation creation but before parent
   publication; the old assembly remains selected.
3. Kill the publisher after advancing the parent ref but before notification;
   anti-entropy discovers the release.
4. Duplicate every write and publication message; all operations remain
   idempotent.
5. Partition two writable CRDT replicas; their signed histories reconcile
   without database arrival order becoming authority.
6. Attempt a conflicting release-ref advance; it is rejected or represented as
   concurrent parent heads.
7. Move a live cell while edits continue; no acknowledged operation is lost.
8. Expire a weak reference; it returns `Expired`, not `Absent`.
9. Remove all placement hints while retaining one configured seed; discovery
   rebuilds the local index.
10. Publish a parent while a child retention receipt is unavailable;
    publication stops safely before advancing the parent ref.
11. Destroy the placement-index database; it rebuilds from receipts and peers.
12. Generate a filesystem checkout and Git tree before and after cell movement;
    their pinned content is identical.

## 19. Architectural invariants

The implementation should enforce these rules mechanically:

1. Every mutable record belongs to exactly one cell-local causal domain.
2. No canonical `CellRef` contains a database endpoint.
3. No database transaction establishes correctness across cells.
4. Every published assembly pins exact child generations.
5. Every strong cross-store reference has an acknowledged retention
   obligation before publication.
6. Physical placement never grants semantic authority.
7. A missed push notification is repairable through anti-entropy.
8. A store timeout never becomes an `Absent` result.
9. Moving or replicating a cell never changes its `CellID` or generation hashes.
10. Global placement, search, topology, and dashboard indexes are disposable
    projections.
11. A checkout never substitutes or omits a mounted generation silently.
12. External effects use claims, fencing, idempotency, and durable result facts.
13. Store adapters expose cell-scoped operations, not ambient keyspace access.
14. Published immutable generations are never modified in place.
15. Collection removes references; it does not impersonate deletion of the
    referenced cell.

## 20. What this architecture refuses

This proposal deliberately rejects:

- one database per cell as a general rule;
- a mandatory globally consistent placement service;
- database location embedded in cell identity;
- distributed transactions across cell databases;
- synchronous writes to every replica for interactive editing;
- "latest" as a globally meaningful scalar;
- database credentials as proof of cell authority;
- silent fallback from an unavailable generation to a different one;
- Git submodules as the native representation of remote cells;
- and global garbage collection as the only way to honor cross-cell retention.

## Conclusion

The multi-database version of Commonplace is not a bigger database system. It
is a federation of small causal systems.

Cells provide the semantic boundaries. Stores provide physical residence.
Placement receipts connect the two without confusing them. Anti-entropy moves
cell-local history. Retention claims preserve strong references across failure
domains. Chits turn fluid cell frontiers into immutable generations. Parent
assembly generations publish coherent combinations without distributed
transactions. Mount resolution turns the resulting graph back into the normal
directory tree expected by compilers, Git, and coding agents.

The result is a Commonplace installation that can begin as one CubDB, grow into
several databases, place selected cells by tenant or geography, and replicate
important cells across failure domains—without ever making the database the
identity of the thing it happens to store.
