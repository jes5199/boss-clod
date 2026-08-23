# `commonplace-dir` and `commonplace-dir-host` specification

Status: proposed 0.1 architecture

Language: Elixir

Proposed repositories:

- `commonplace-systems/commonplace-dir`
- `commonplace-systems/commonplace-dir-host`

## 1. Purpose

This document specifies the current design of Commonplace directories and their live host runtime.

A Commonplace Directory is an ordinary Commonplace Document whose selected content is a Yjs `Y.Map`. Each root-map key is an entry name. Each value is an atomic, canonical record referring to an exact version of another Document.

`commonplace-dir` gives that Y.Map directory meaning. It is a pure library: it validates entries and paths, reads stable directory values, and constructs Yjs edits for structural operations and checkpoints.

`commonplace-dir-host` makes one Directory live. It composes a `commonplace-doc-host`, resolves referenced Documents, watches tracking children, maintains an ephemeral live overlay, amortizes child-version updates into periodic Directory commits, and coordinates lazy copy-on-write when a caller writes through a path inherited from a fork.

The two defining ideas are:

> Directory commits are amortized: many child commits may be represented by one later Directory checkpoint.

> Directory forks are amortized: initially only a new root Directory is created; descendants receive new UUIDs only along paths that are later written.

## 2. Decision status

### 2.1 Settled for version 0.1

- A Directory is a Document.
- Directory content uses the ordinary `commonplace-merkle-crdt` projection.
- The selected Directory content root is a Yjs `Y.Map`.
- No specialized Directory reducer is introduced.
- Root-map keys are entry names.
- Each entry value is an atomic canonical record in version 0.1.
- Persisted entry references identify exact child versions.
- Tracking is implemented by ephemeral DirHost watches plus durable checkpoints.
- Historical Directory state is always a stable, exact set of versioned references.
- Directory checkpoints batch multiple observed child advances into one Yjs update and one Directory content commit.
- Forking a Directory does not recursively fork its descendants.
- A write through an inherited path lazily forks only the directories and leaf on that path.
- Direct UUID writes do not participate in path copy-on-write.
- Entry policy and capability authority are distinct.

### 2.2 Proposed defaults

- Entries have separate reference and write policies.
- The reference policies are `:pinned` and `:tracking`.
- The write policies are `:direct`, `:copy_on_write`, and `:read_only`.
- An ordinary fork freezes tracking references at their observed versions.
- A formerly direct child becomes copy-on-write in the fork.
- Copy-on-write materialization proceeds child-first and updates parents bottom-up.
- Entry values use canonical JSON-shaped maps supported as Y.Map values.

### 2.3 Explicitly open

- The final wire representation of a whole-Document version reference.
- Whether stable checkpoints must eventually be causally closed across Documents.
- Alias and hardlink preservation when two paths name the same child UUID.
- The exact conflict policy for concurrent materialization of one inherited path.
- Fork behavior of live external mounts.
- Watch budgets and policies for extremely wide directories.
- Orphan discovery and garbage collection.

Open questions are collected in section 41. Implementations MUST NOT silently settle them by exposing accidental behavior as a stable public contract.

## 3. Normative vocabulary

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative where they describe settled 0.1 behavior.

### 3.1 Directory

A Document with the `commonplace.directory/v1` profile whose selected content materializes as a root `Y.Map` of Directory entries.

### 3.2 Directory entry

An atomic record stored under one root-map key. It identifies a target Document version, gives a target-kind hint, and declares reference and write policies.

### 3.3 Stable view

The exact Directory Y.Map materialized at the Directory Document's selected content head. Every child reference is the version persisted in that content commit.

### 3.4 Live view

A DirHost view made from the stable view plus newer child versions observed for tracking entries but not necessarily checkpointed into the Directory Document yet.

### 3.5 Dirty entry

A tracking entry whose most recently observed child version differs from the version stored in the stable Directory view.

### 3.6 Checkpoint

A Directory content edit that folds one or more dirty observed child versions into a new stable Y.Map value and selects the resulting Directory content commit.

This is distinct from a reducer checkpoint cache. A Directory checkpoint is canonical Document history.

### 3.7 Pinned entry

An entry whose persisted target version is used until an explicit structural command changes it. The DirHost does not automatically follow its target.

### 3.8 Tracking entry

An entry whose DirHost observes the target Document and may advance its persisted target version during a later Directory checkpoint.

### 3.9 Copy-on-write entry

An entry that may be read at its persisted target version but must be forked to a new Document UUID before a write addressed through that path is applied.

### 3.10 Materialized path

Within a forked tree, a path whose inherited copy-on-write Directory nodes and target leaf have been replaced with new lineage Documents belonging to that fork.

### 3.11 Version reference

A canonical `commonplace-doc` value identifying an exact observable prefix or snapshot of a Document, not merely its UUID.

## 4. Layering

```text
commonplace-log
        |
commonplace-log-reducer
        |
        +-- commonplace-attribute-map
        +-- commonplace-merkle-crdt
                    |
              commonplace-doc
                    |
          commonplace-doc-host
                    |
              commonplace-dir
                    |
          commonplace-dir-host
                    |
        future Environment / Cell integration
```

`commonplace-dir` additionally depends on Yelixer data types or a narrow Merkle-CRDT/Yjs editing API sufficient to inspect and construct root Y.Map edits.

`commonplace-dir-host` depends on `commonplace-doc-sync` for lineage fork execution. `commonplace-dir` does not.

## 5. Package boundaries

### 5.1 `commonplace-dir`

Owns pure Directory semantics:

- profile declaration;
- entry representation and canonical encoding;
- name and path validation;
- stable listing and one-component lookup;
- add, remove, replace, and rename operations;
- batched entry-version checkpoint edits;
- entry policy transitions;
- copy-on-write path plans;
- validation of Directory Y.Map content;
- structural diff and, eventually, merge decision rules.

It performs no storage, process startup, endpoint resolution, watching, forking, authorization, or message delivery.

### 5.2 `commonplace-dir-host`

Owns live multi-Document coordination for one Directory:

- attachment to the Directory's DocHost;
- stable and live views;
- immediate-child resolution;
- ephemeral watches for tracking children;
- dirty-overlay maintenance;
- checkpoint scheduling and execution;
- path traversal across nested DirHosts or Directory endpoints;
- copy-on-write materialization;
- bottom-up parent updates;
- restart reconciliation;
- checkpoint barriers and receipts.

It does not own child logs or child writer processes.

### 5.3 Future Environment

Owns:

- UUID-to-endpoint resolution;
- local versus remote transport;
- authority and capability issuance;
- placement across Cells and Realms;
- lifecycle policy for populations of DocHosts and DirHosts.

## 6. Directory Document profile

A valid Directory MUST use the versioned profile:

```text
commonplace.directory/v1
```

The profile is a specialization of `commonplace.document/v1`. It requires the same projections:

| Projection | Reducer | Directory use |
| --- | --- | --- |
| `attributes` | `commonplace-attribute-map` | Document attributes and selected content head |
| `content` | `commonplace-merkle-crdt` | Y.Map Directory history |
| `verbs` | `commonplace-doc` verb-map | Optional mounted Directory behavior |

The Directory profile adds validation that the selected content root is a Y.Map whose keys and values satisfy this specification.

The profile identifier SHOULD live in Document genesis or a reserved Document attribute defined by `commonplace-doc`. It MUST NOT be inferred merely because content happens to look like a map.

## 7. Y.Map content representation

The selected Directory content is one root Y.Map:

```text
root Y.Map
  "notes.md"  -> entry record
  "projects"  -> entry record
  "logo.svg"  -> entry record
```

Entry names are the root-map keys. Version 0.1 does not introduce a nested `entries` map or reserved metadata keys inside the content map.

Directory metadata belongs in Document attributes or profile data. This keeps every root key available to the namespace of entry names.

Each entry record is stored as one atomic Y.Map value. A checkpoint replaces the whole entry record for a name. Version 0.1 does not use a nested shared Y.Map per entry.

Consequences:

- distinct names can change concurrently under Y.Map semantics;
- readers do not observe half of a version-and-policy transition;
- updating one field replaces the canonical record for that name;
- conflict behavior for simultaneous writes to the same name follows the pinned Yelixer/Yjs map semantics plus host preconditions.

## 8. Entry schema

A logical entry has the proposed shape:

```elixir
%Commonplace.Dir.Entry{
  document_id: document_id,
  version: Commonplace.Doc.VersionRef.t(),
  kind: :document | :directory,
  reference_policy: :pinned | :tracking,
  write_policy: :direct | :copy_on_write | :read_only,
  metadata: map
}
```

Its canonical Y.Map value is JSON-shaped:

```json
{
  "document_id": "019c...",
  "version": {
    "coordinate": "opaque-canonical-coordinate",
    "content_head": "bafy..."
  },
  "kind": "document",
  "reference_policy": "tracking",
  "write_policy": "direct",
  "metadata": {}
}
```

The exact internal fields of `version` remain owned by `commonplace-doc`; section 9 defines the required semantics.

Unknown required fields or enum values MUST make the entry invalid. Optional extension fields MUST follow a versioned extension rule rather than being silently interpreted.

## 9. Document version references

A Directory must pin more than a mutable Document UUID. Its entry version MUST identify an exact child state sufficient for historical materialization.

`commonplace-doc` SHOULD introduce:

```elixir
%Commonplace.Doc.VersionRef{
  document_id: document_id,
  coordinate: log_coordinate,
  content_head: commit_id | nil
}
```

The canonical wire representation MAY omit the repeated `document_id` inside `version` when the containing entry already carries it, but the logical value includes it.

Required semantics:

1. `coordinate` identifies the exact child log prefix from which attributes, verbs, and content-head selection are reduced.
2. `content_head` identifies or checks the content commit selected at that coordinate.
3. A host MUST reject a reference whose coordinate and content head disagree.
4. Materialization MUST NOT silently substitute the child's current coordinate or current head.
5. The value must remain serializable and stable across process and Realm movement.

The exact encoding of a log coordinate or frontier remains open because the log layer may generalize beyond a single scalar coordinate. `commonplace-dir` MUST treat the coordinate as an opaque canonical value through a `commonplace-doc` API.

## 10. Target kind

`kind` is a resolution hint and validation expectation:

- `:document` means the target may be any non-Directory Document profile accepted by policy;
- `:directory` means the target must materialize under `commonplace.directory/v1`.

The hint allows path traversal to reject a non-Directory before treating its content as entries. It is not an independent source of truth. A resolved target whose profile disagrees with `kind` is invalid.

Future versions MAY support additional specialized kinds without changing the root Y.Map representation.

## 11. Reference policy

### 11.1 `:pinned`

The stable entry version is authoritative until an explicit Directory command changes it.

The DirHost:

- MAY resolve and read that exact version;
- MUST NOT advance it merely because the target's current state changes;
- need not maintain a watch on the target;
- may materialize it under copy-on-write policy before a path-addressed write.

### 11.2 `:tracking`

The stable entry still contains an exact persisted version. In addition, the DirHost:

- observes the target's current applied version;
- records a newer observed version in its live overlay;
- marks the entry dirty;
- may persist the observed version in a later checkpoint;
- keeps `reference_policy: :tracking` after checkpoint.

Tracking never means that a historical Directory snapshot dynamically follows the target. Only a live DirHost follows.

## 12. Write policy

### 12.1 `:direct`

A write addressed through the path may be submitted to the target Document without changing its UUID, subject to caller authority and preconditions.

### 12.2 `:copy_on_write`

A read uses the persisted target version. Before a write addressed through the path is applied, the DirHost must create a new lineage Document from that exact version and replace the entry to name the new child.

After successful materialization, the ordinary default is:

```text
reference_policy: tracking
write_policy: direct
```

### 12.3 `:read_only`

A write addressed through the path is refused. The policy does not grant or revoke direct UUID authority outside this path.

## 13. Policy combinations

Recommended combinations are:

| Use | Reference policy | Write policy |
| --- | --- | --- |
| Ordinary owned child | `:tracking` | `:direct` |
| Inherited branch child | `:pinned` | `:copy_on_write` |
| Fixed dependency | `:pinned` | `:read_only` |
| Live external mount | `:tracking` | `:read_only` |
| Editable vendored dependency | `:pinned` | `:copy_on_write` |

Unrecognized combinations MUST be rejected or explicitly defined. In particular, `:tracking` plus `:copy_on_write` is ambiguous unless a future version defines whether movement before first write changes the fork basis.

## 14. Entry-name rules

Version 0.1 entry names MUST:

- be non-empty UTF-8 strings;
- contain no `/` path separator;
- not equal `.` or `..`;
- satisfy configured byte and grapheme limits;
- have a deterministic normalization and equality rule;
- not use a reserved name namespace defined by the Directory profile.

The exact Unicode normalization form and case-sensitivity policy must be specified before cross-platform filesystem projection. The pure Directory model SHOULD default to case-sensitive names and canonical UTF-8 without pretending to reproduce macOS or Windows filesystem behavior.

## 15. Stable Directory operations

`commonplace-dir` SHOULD provide pure equivalents of:

```elixir
Commonplace.Dir.validate/1
Commonplace.Dir.entries/1
Commonplace.Dir.list/1
Commonplace.Dir.fetch/2
Commonplace.Dir.resolve_component/2

Commonplace.Dir.add/3
Commonplace.Dir.remove/2
Commonplace.Dir.replace/3
Commonplace.Dir.rename/3
Commonplace.Dir.set_policies/3
Commonplace.Dir.checkpoint_entries/2
Commonplace.Dir.plan_copy_on_write/3
```

Mutation functions return a proposed Yjs edit or command value. They do not append it.

Every mutation SHOULD accept an expected Directory content head or version precondition through its caller. The pure library validates the expected value against supplied state; the DirHost enforces it at persistence time.

## 16. Structural operation semantics

### 16.1 Add

Adding a name that exists in the supplied stable state returns `:entry_exists` unless the command explicitly requests replacement.

### 16.2 Remove

Removal deletes the root Y.Map key. It does not delete the target Document or its log.

### 16.3 Replace

Replacement atomically assigns a new canonical entry record to the existing key.

### 16.4 Rename

Rename is represented as one Yjs transaction containing a set of the destination key and deletion of the source key. The transaction produces one update and one Directory content commit.

Yjs transactions do not make rename indivisible with respect to all concurrent CRDT interpretations. Same-name concurrent structural edits require explicit conflict tests and policy.

### 16.5 Move across directories

A cross-Directory move affects two Document logs and is not atomic. It is outside the pure `commonplace-dir` mutation surface and requires DirHost-level coordination or a future transaction/saga layer.

## 17. Stable and live views

The DirHost MUST distinguish:

```elixir
snapshot(dir_host, consistency: :stable)
snapshot(dir_host, consistency: :live)
```

### 17.1 Stable view

Derived only from the selected Directory content commit. It includes:

- Directory Document version;
- exact persisted entries;
- no uncheckpointed child advances.

The stable view is appropriate for:

- historical checkout;
- reproducible execution;
- lineage fork basis;
- Git export;
- signing or external references;
- recursive checkpoint receipts.

### 17.2 Live view

Derived from the stable entries plus the current dirty overlay. It includes, per tracking entry where known:

- persisted version;
- observed version;
- dirty status;
- watch status or freshness.

The live view is appropriate for interactive navigation and editing.

The host MUST NOT present an uncheckpointed live overlay as a stable Directory content head.

## 18. Dirty overlay

Representative runtime state is:

```elixir
%Commonplace.DirHost.DirtyEntry{
  name: "notes.md",
  persisted: persisted_version_ref,
  observed: observed_version_ref,
  observed_at: monotonic_runtime_time,
  watch_cursor: opaque_cursor
}
```

The overlay is ephemeral and rebuildable. It MUST NOT be treated as canonical Directory history.

A target moving back to an older content head or to a divergent known head is still an observable version change. The DirHost records the exact new child version; it does not assume all head movement is fast-forward.

## 19. Child watches

For each actively tracked immediate child, the DirHost may establish:

```elixir
snapshot_and_watch(child_endpoint, authority)
```

The watch is the ephemeral `commonplace-doc-host` watch defined in the DocHost specification. It is not a durable Directory subscription.

Watch notifications:

- wake the DirHost;
- identify an applied child coordinate or version;
- may be coalesced, duplicated, dropped, or disconnected;
- never replace a fresh child snapshot when a gap is detected.

The durable intent to track lives in the entry's `reference_policy`. On restart or watch loss, the DirHost compares the stable persisted reference with a fresh authorized child summary.

## 20. Amortized checkpointing

Suppose a child advances:

```text
A -> B -> C -> D -> E
```

The Directory need not record B, C, or D. A later checkpoint may change its entry directly from A to E.

For a dirty set:

```text
notes.md: A -> E
plan.md:  J -> K
logo.svg: unchanged
```

the DirHost MUST construct one Yjs transaction that replaces the `notes.md` and `plan.md` entry records, then use the ordinary Document editing protocol:

1. create one Directory content commit containing the Yjs update;
2. append that commit to the Directory content graph;
3. select it through `commonplace.content.head` with an expected-head precondition;
4. update the stable state;
5. clear only dirty entries whose exact observations were included;
6. notify Directory watchers.

If a child advances again while the checkpoint is being prepared, that newer observation remains dirty for a later checkpoint.

## 21. Checkpoint triggers

The DirHost SHOULD support:

- explicit checkpoint request;
- debounce after child activity;
- maximum dirty interval;
- dirty-entry count or byte threshold;
- pre-fork stability barrier;
- pre-export stability barrier;
- graceful shutdown flush according to policy.

Background debounce is an optimization. Correctness must not depend on a timer firing.

The default cadence is deployment policy and is not part of `commonplace-dir` semantics.

## 22. Checkpoint crash behavior

The ordinary Document two-step edit rule applies:

1. append Directory content commit;
2. select it with the head attribute.

If the host fails between these steps, the content commit remains a valid non-head candidate. Recovery replays the stable selected head, re-observes tracking children, and may construct or select an appropriate later checkpoint.

Child edits are already durable in child logs. Failure to checkpoint them into an ancestor never loses child content; it only leaves the ancestor's stable snapshot behind its live view.

## 23. Checkpoint propagation

When a child Directory checkpoints, its own Document version changes. A tracking parent observes that change like any other child advance:

```text
leaf changes many times
    -> child Directory checkpoints once
        -> parent Directory becomes dirty
            -> parent checkpoints once
```

Each level amortizes activity independently. The system does not rewrite every ancestor on every leaf edit.

## 24. Recursive checkpoint barrier

The DirHost SHOULD expose a barrier equivalent to:

```elixir
checkpoint(dir_host, recursive: true)
```

The intended algorithm is child-first:

1. enumerate or resolve tracking child Directories in the stable/live view;
2. recursively checkpoint dirty descendant Directories according to authority and policy;
3. refresh the immediate-child versions;
4. checkpoint the current Directory;
5. return the exact resulting root Directory version.

The result is a reproducible tree cut. Version 0.1 does not yet promise that the cut is causally closed across arbitrary inter-Document message dependencies.

The barrier MUST be bounded by depth, entry count, time, and cancellation options.

## 25. Forking a Directory

Forking stable Directory version `R@r17` creates a new root Directory Document `R2` through `commonplace-doc-sync`.

It does not immediately fork children.

The destination root content is derived from the exact source Y.Map. Under the proposed default fork policy:

- every tracking reference is frozen at the version observed in the fork basis;
- a direct writable entry becomes pinned and copy-on-write;
- an already pinned read-only entry remains pinned and read-only;
- capabilities or ambient authority are never copied as entry data.

Example:

```text
source R@r17
  projects -> D@d9  tracking/direct
  logo.svg -> L@l4  tracking/direct

fork R2
  projects -> D@d9  pinned/copy_on_write
  logo.svg -> L@l4  pinned/copy_on_write
```

Fork cost is proportional to the immediate root Y.Map transformation, not the size of the reachable tree.

## 26. Lazy path copying

Given:

```text
R2
  projects -> D@d9       pinned/copy_on_write

D@d9
  notes.md -> N@n31      tracking/direct in the source snapshot
  plan.md  -> P@p12      tracking/direct in the source snapshot
```

a write to `projects/notes.md` produces:

```text
R2
  projects -> D2@d10     tracking/direct

D2@d10
  notes.md -> N2@n32     tracking/direct
  plan.md  -> P@p12      pinned/copy_on_write
```

Only the path's Directory nodes and target leaf receive new UUIDs. Untouched siblings remain exact inherited references.

## 27. Copy-on-write algorithm

For a path `a/b/file`, the DirHost coordinator SHOULD:

1. capture the stable root Directory version and command preconditions;
2. resolve `a` at the exact root version;
3. when `a` is copy-on-write, fork its target Directory at the stored version;
4. transform that new Directory's immediate inherited entries according to fork policy;
5. continue resolving `b` inside the new Directory;
6. repeat until reaching the leaf;
7. fork the leaf at its exact stored version;
8. apply the requested leaf command to the new leaf;
9. replace the leaf entry in its new parent with a tracking/direct reference;
10. checkpoint that parent;
11. propagate new child-Directory references upward, checkpointing bottom-up;
12. update the original root entry last;
13. return a receipt containing every created Document and resulting root version.

The actual Document fork is delegated to `commonplace-doc-sync`. The Y.Map policy transformation and parent entry changes use `commonplace-dir` commands submitted through DocHosts.

## 28. Cross-log ordering and failure

Copy-on-write touches several independent append-only logs and is not one atomic transaction.

The safe visibility rule is:

> A parent may refer to a newly forked child only after that child has been durably created and initialized at a valid selected version.

Therefore materialization proceeds child-first and publishes references bottom-up.

If an ancestor update loses a race:

- the visible ancestor remains unchanged;
- already-created children remain valid but may be unreachable;
- the operation is not acknowledged as fully successful;
- retry may reuse children identified by the operation receipt or deterministic IDs.

The system MUST NOT publish a parent reference to an absent or uninitialized child.

## 29. Operation IDs and idempotency

Every multi-Document path-copy operation SHOULD carry a stable operation ID.

New Document UUIDs SHOULD be supplied deterministically or recorded durably before creation so a retry can distinguish:

- a child already created by this operation;
- a coincidentally related child;
- a fresh child still required.

Content-addressed commits make repeated identical imports idempotent, but structural Y.Map updates and head selections still require preconditions.

Version 0.1 may leave harmless unreachable Documents. Exact orphan collection is deferred.

## 30. Path semantics

`commonplace-dir-host` SHOULD accept normalized relative paths represented internally as component lists:

```elixir
["projects", "commonplace", "README.md"]
```

String parsing is an adapter concern. The core path type MUST NOT inherit platform filesystem quirks accidentally.

Resolution at stable consistency follows every Directory entry's exact stored version. Resolution at live consistency may substitute the observed version of a tracking entry while preserving provenance in the result.

A resolution result SHOULD contain:

```elixir
%Commonplace.DirHost.Resolved{
  root_version: directory_version_ref,
  consistency: :stable | :live,
  path: [String.t()],
  traversed: [entry_and_directory_version],
  target: Commonplace.Dir.Entry.t(),
  target_version: Commonplace.Doc.VersionRef.t()
}
```

The full traversal proof allows a later write to detect which ancestor changed.

## 31. DirHost architecture

```text
client / path adapter
        |
        v
Commonplace.DirHost
        |
        +-- its Directory's Commonplace.DocHost
        +-- pure Commonplace.Dir operations
        +-- immediate-child watch registry
        +-- dirty overlay
        +-- checkpoint scheduler
        +-- DocumentAccess resolver
        +-- Commonplace.DocSync fork coordinator
```

A conventional implementation is one GenServer per live Directory, but the public contract requires semantics rather than a specific process shape.

The DirHost MUST NOT replay child logs or append directly to them.

## 32. DirHost lifecycle

On boot, the DirHost MUST:

1. start or attach to the configured Directory DocHost;
2. verify the Directory profile;
3. materialize the stable root Y.Map;
4. validate all entry records structurally;
5. establish watches for tracking children according to budget and policy;
6. compare watched child versions with persisted references;
7. reconstruct the dirty overlay;
8. enter ready state.

A malformed entry need not make unrelated names unreadable, but the stable snapshot MUST report invalid entries explicitly. Traversal through one returns an error.

The host lifecycle SHOULD mirror DocHost states with Directory-specific degraded states for unresolved or unauthorized children.

## 33. Document-access interface

The DirHost requires an injected interface equivalent to:

```elixir
defmodule Commonplace.DirHost.DocumentAccess do
  @callback summary(document_id, authority, options) :: result
  @callback snapshot(version_or_document_ref, authority, options) :: result
  @callback snapshot_and_watch(document_id, authority, options) :: result
  @callback command(document_id, command, authority, options) :: result
  @callback fork(version_ref, destination_options, authority, options) :: result
  @callback resolve_directory(document_id, authority, options) :: result
end
```

An early implementation may use a local Registry, DocHosts, DirHosts, and `commonplace-doc-sync` directly.

A future Environment implements the same semantics through local or cross-Cell routing. The DirHost must not branch on whether an endpoint is local.

## 34. Proposed DirHost API

Version 0.1 SHOULD provide equivalents of:

```elixir
Commonplace.DirHost.start_link/1
Commonplace.DirHost.attach/2
Commonplace.DirHost.status/1

Commonplace.DirHost.snapshot/2
Commonplace.DirHost.snapshot_and_watch/2
Commonplace.DirHost.list/2
Commonplace.DirHost.stat/3
Commonplace.DirHost.resolve_path/3
Commonplace.DirHost.read_path/3

Commonplace.DirHost.add/4
Commonplace.DirHost.remove/3
Commonplace.DirHost.rename/4
Commonplace.DirHost.replace/4
Commonplace.DirHost.set_policies/4

Commonplace.DirHost.command_path/4
Commonplace.DirHost.edit_path/4
Commonplace.DirHost.materialize_path/3

Commonplace.DirHost.dirty_entries/1
Commonplace.DirHost.checkpoint/2
Commonplace.DirHost.fork/3
```

Every response that depends on Directory state SHOULD identify the exact stable root version and whether live overlay data was used.

## 35. Authorization and copy-on-write

Entry policies describe path behavior. They are not capabilities.

A forked context normally receives:

- authority to read inherited Documents at their pinned versions;
- authority to request copy-on-write through its DirHost;
- no direct write authority to inherited source Documents;
- authority to write newly created fork Documents according to Cell policy.

If a caller possesses direct write authority for an inherited source UUID, it can bypass path copy-on-write by addressing that UUID. `commonplace-dir` cannot prevent this.

The DirHost MUST authorize separately:

- reading the Directory entry;
- reading the target version;
- changing Directory structure;
- creating a lineage fork;
- writing the new child;
- changing the Directory selected head.

A future Assembly or Cell authority may mint the required attenuated capabilities. Version 0.1 may use an explicit local-root policy for development.

## 36. Concurrent structural operations

DirHost mutations MUST use expected Directory version or head preconditions.

Two clients concurrently adding or replacing different names may be merged through Y.Map semantics if the host command model permits it. Two operations targeting the same name require deterministic conflict handling.

Two clients materializing the same copy-on-write path may create separate valid forks. At most one parent replacement can satisfy the same expected-parent precondition. The loser remains unreachable unless a later conflict policy preserves it.

Version 0.1 SHOULD return a structured materialization conflict with both operation and child identifiers where authorized. It MUST NOT silently discard knowledge of an already-created child.

## 37. Directory watches

A client may watch the Directory DocHost for stable Directory checkpoint changes. The DirHost may additionally expose a live-view watch that fires when its dirty overlay changes.

These must be distinguished:

```text
stable watch
    only after durable Directory head selection

live watch
    after child observation or stable checkpoint
```

A live-watch notification MUST state the stable Directory version on which the overlay is based. It is an ephemeral invalidation, not a new Directory version.

Client watch behavior follows the weak-but-recoverable coordinate semantics of `commonplace-doc-host`.

## 38. Errors

At minimum, the libraries SHOULD expose structured forms of:

```elixir
:not_a_directory
:invalid_directory_profile
:invalid_directory_content
:invalid_entry_name
:invalid_entry
:entry_not_found
:entry_exists
:kind_mismatch
:invalid_policy_combination
:invalid_version_ref
:version_mismatch
:path_not_found
:not_a_directory_component
:read_only_entry
:copy_on_write_required
:directory_advanced
:child_advanced
:materialization_conflict
:fork_failed
:checkpoint_conflict
:checkpoint_incomplete
:child_unavailable
:child_unauthorized
:watch_lagged
:resync_required
:operation_partially_applied
```

Errors MUST distinguish malformed state, authorization refusal, stale preconditions, and endpoint unavailability.

## 39. Effects on existing libraries

### 39.1 `commonplace-log`

Required changes: none to core semantics.

Directories use ordinary Document logs. The log layer remains ignorant of paths, Y.Map entries, tracking, and copy-on-write.

Potential integration work:

- ensure canonical coordinates/frontiers can be embedded in `Commonplace.Doc.VersionRef`;
- ensure exact-prefix reads remain available through the Document layer.

### 39.2 `commonplace-log-reducer`

Required changes: none expected.

Directory content and attributes use existing reducer plugins. The engine remains ignorant of Directory schema.

Potential integration work:

- expose the exact projection coordinate used to construct a whole-Document version reference;
- preserve opaque coordinate values through checkpoints and replay APIs.

### 39.3 `commonplace-attribute-map`

Required changes: none expected.

Directory identity/profile and selected content head use ordinary Document reserved attributes. Entry records do not live in the attribute map.

### 39.4 `commonplace-merkle-crdt`

Required behavior:

- materialize Y.Map content by exact commit ID;
- construct a Merkle commit from one Yjs transaction/update;
- preserve atomic JSON-shaped entry values;
- support exact historical Y.Map materialization;
- eventually cross snapshot/Yepoch boundaries correctly.

Directory batching needs no Directory-specific reducer behavior.

The current refusal of snapshots remains a blocking limitation for long-lived production directories, but not necessarily for the first short-lived vertical slice.

### 39.5 `yelixer`

Required behavior:

- stable Y.Map get, set, delete, enumerate, and transaction operations;
- canonical encoding support for the selected atomic entry-value subset;
- deterministic interoperability fixtures for concurrent same-key and different-key edits.

Potential additions should remain generic Yjs behavior rather than Directory-named APIs.

### 39.6 `yepochs`

Required changes: no Directory-specific concepts.

Directory Y.Map edits cross Yepoch bridges like other supported Y.Map edits. Conformance coverage SHOULD include atomic Directory-shaped values, but the library should not know they are Directory entries.

### 39.7 `commonplace-doc`

Required additions:

1. `Commonplace.Doc.VersionRef` with exact-prefix semantics.
2. A stable profile identifier mechanism supporting `commonplace.directory/v1`.
3. Exact-coordinate whole-Document materialization returning attributes, selected content head, content, and verbs consistently.
4. Validation that a VersionRef's coordinate and content head agree.
5. Public construction of version references from materialized Document state.
6. Directory profile registration or an extension hook that `commonplace-dir` can use without modifying core reducers.

The Document library should not learn path operations or Directory entry schema.

### 39.8 `commonplace-doc-host`

Required additions or confirmations:

1. Every snapshot and command receipt exposes a canonical `Commonplace.Doc.VersionRef`.
2. `snapshot_and_watch` atomically returns that version and registers after it.
3. Exact-version reads are authorized and supported.
4. Watch changes expose enough data to obtain the new VersionRef without trusting an unverified head alone.
5. Non-fast-forward head selection remains observable.
6. Directory commands can submit one batched Yjs update through the normal content-edit path.

No Directory-specific process behavior belongs in DocHost.

### 39.9 `commonplace-doc-sync`

Required behavior:

- fork an exact `Commonplace.Doc.VersionRef`, not merely a current UUID;
- accept a caller-supplied destination UUID or stable operation ID;
- return a fork receipt containing the initialized destination VersionRef;
- preserve or derive Yepoch lineage as required;
- never copy capabilities implicitly;
- permit a newly forked Directory to receive a post-fork Y.Map policy transformation before any parent publishes it.

The sync library should not interpret Directory entries. DirHost owns the transformation from inherited entries to pinned/copy-on-write entries.

### 39.10 Future capability library

It will need to express:

- exact-version read authority;
- current tracking-read authority where permitted;
- structural-write authority on a Directory;
- fork authority from a specified source version;
- write authority to newly created child Documents;
- attenuation across path traversal.

Lineage and entry policies remain non-authoritative facts.

### 39.11 Future Environment and Cell libraries

They will implement `DocumentAccess`:

- resolve UUIDs to endpoints;
- upgrade local BEAM calls to cross-Cell messages;
- transport explicit capabilities;
- choose where new forked Documents are placed;
- ensure a Cell's authority policy is applied when a path materializes.

The Directory algorithms must remain unchanged whether all endpoints are in one Cell or cross a Cell boundary.

## 40. Acceptance tests

### 40.1 `commonplace-dir`

A conforming implementation MUST test at least:

1. A valid Directory is an ordinary Document with a root Y.Map.
2. No specialized reducer is needed to materialize it.
3. Every stable entry contains an exact version reference.
4. Invalid names and malformed entry records are rejected.
5. Add, remove, replace, and rename produce valid Yjs updates.
6. Distinct-name edits merge according to pinned Yjs behavior.
7. Entry replacement is observed atomically as one value.
8. Tracking and write policy combinations validate correctly.
9. Batched checkpoint construction changes only named dirty entries.
10. Historical materialization returns the exact old entry versions.
11. A pinned entry never advances through a pure checkpoint operation unless explicitly supplied.
12. A copy-on-write plan names every path component requiring materialization.

### 40.2 `commonplace-dir-host`

A conforming implementation MUST test at least:

1. Boot validates the Directory profile and reconstructs stable state.
2. Tracking child advancement marks an entry dirty without changing the stable view.
3. Live view exposes persisted and observed versions distinctly.
4. Five child advances may be represented by one Directory checkpoint.
5. One checkpoint batches several dirty entries into one Yjs update and content commit.
6. A child advancing during checkpoint remains dirty afterward.
7. Restart reconstructs dirty state from tracking policy and child summaries.
8. Watch loss and gaps trigger resynchronization rather than silent continuity.
9. A child Directory checkpoint eventually dirties its tracking parent.
10. Recursive checkpoint proceeds child-first and returns an exact root version.
11. Forking a root does not fork any child target.
12. Reading an inherited path creates no new Documents.
13. First write forks only Directory nodes and the leaf along that path.
14. Untouched siblings retain their original UUIDs and pinned versions.
15. A second write to the materialized leaf does not fork it again.
16. A newly created child becomes reachable only after its initialization; the tested operation order is child creation followed by bottom-up parent publication.
17. Failure before parent replacement leaves the old visible path intact.
18. A stale parent precondition returns a materialization conflict and preserves created-child information.
19. Direct UUID writes do not invoke path copy-on-write.
20. Read-only path writes are refused before any fork.
21. Stable and live watches cannot be confused.
22. Local and encoded DocumentAccess adapters produce equivalent visible results.

Property tests SHOULD generate trees, edit paths, checkpoint schedules, crashes, and retries. At every visible root version, all references must resolve to initialized exact child versions.

## 41. Open questions

### 41.1 Version-ref encoding

Should the canonical coordinate be a scalar sequence, a per-writer frontier, a reducer checkpoint identifier, or another log-defined value? The Directory contract needs an exact opaque version, but should not prematurely freeze log internals.

### 41.2 Causal closure

An exact tree checkpoint may combine child versions observed at different moments. Is reproducibility sufficient, or must a future checkpoint algorithm follow inter-Document message dependencies to construct a causally closed cut?

Proposed 0.1 ruling: reproducible exact cut is sufficient.

### 41.3 Aliases and shared children

If two entries refer to the same source Document and one path is materialized, should both paths follow the same fork? Preserving aliases requires a durable or reconstructable source-to-fork map.

Proposed 0.1 ruling: tree-shaped directories do not promise alias-preserving copy-on-write; shared-target semantics are deferred.

### 41.4 Concurrent materialization

When two operations fork the same inherited entry concurrently, should the losing child remain only as an orphan, be conflict-renamed into the Directory, or be exposed for explicit resolution?

Proposed 0.1 ruling: return a conflict receipt naming the losing child; do not insert it automatically.

### 41.5 External mounts

Should a live read-only tracking mount remain tracking when its containing Directory is forked, or freeze to the fork-time version?

Proposed 0.1 default: freeze all tracking references unless an explicit mount-specific fork policy says otherwise.

### 41.6 Wide directories

Should every tracking entry receive a live watch, or should the host watch only active/recent entries and reconcile others at barriers? This is an operational policy but affects freshness guarantees.

### 41.7 Orphans

How are Documents created by failed copy-on-write operations discovered, retained for debugging, adopted, or garbage-collected?

### 41.8 Unicode and filesystem projection

The pure Directory namespace can be case-sensitive while projected filesystems are not. The projection layer needs reversible escaping and collision policy without contaminating core names.

## 42. Non-goals for version 0.1

- Hardlinks or alias-preserving lazy forks.
- Cross-Directory atomic moves.
- Automatic recursive watching of an entire subtree from one process.
- Multi-writer Directory logs.
- Distributed transactions.
- Causally closed global snapshots.
- Filesystem-specific case folding.
- Garbage collection of orphaned fork Documents.
- A specialized Directory reducer.
- Capability token encoding.
- Realm placement policy.

## 43. Implementation phases

### Phase 1: pure Directory

- profile and entry structs;
- Y.Map validation;
- canonical entry values;
- name/path types;
- list/fetch/add/remove/replace/rename;
- version-ref integration with `commonplace-doc`;
- in-memory fixtures.

### Phase 2: basic DirHost

- compose one DocHost;
- stable list and path-component resolution;
- local DocumentAccess adapter;
- structural commands;
- stable Directory watches.

### Phase 3: amortized checkpoints

- tracking-child watches;
- dirty overlay;
- stable/live views;
- explicit checkpoint;
- debounce policy;
- restart reconciliation;
- ancestor propagation tests.

### Phase 4: root fork

- exact-version Directory fork through DocSync;
- immediate-entry policy transformation;
- fork receipt;
- proof that no descendant is created.

### Phase 5: lazy path copying

- path-copy plan;
- deterministic operation IDs;
- child-first forks;
- bottom-up checkpoints;
- race and partial-failure receipts;
- recursive checkpoint barrier.

### Phase 6: integration boundary

- encoded loopback DocumentAccess adapter;
- capability hook points;
- proof that local and cross-boundary-shaped calls have equivalent semantics;
- one editable wiki tree vertical slice.

## 44. Ownership summary

| Concern | Owner |
| --- | --- |
| Append-only events | `commonplace-log` |
| Projection replay | `commonplace-log-reducer` |
| Y.Map CRDT and Merkle history | `commonplace-merkle-crdt` plus Yelixer |
| Whole-Document version reference | `commonplace-doc` |
| One live Document writer | `commonplace-doc-host` |
| Directory schema and pure Y.Map edits | `commonplace-dir` |
| Dirty overlays and amortized checkpoints | `commonplace-dir-host` |
| Exact lineage fork | `commonplace-doc-sync` |
| Lazy path-copy coordination | `commonplace-dir-host` |
| Endpoint resolution and authority | future Environment/Cell layer |
| Historical tree state | stable Directory commits containing exact child VersionRefs |
