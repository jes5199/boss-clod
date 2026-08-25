# Goal: one Markdown workspace, one editor Cell, live browser editing

Status: proposed integration goal  
Date: 2026-08-24  
Scope: first usable Commonplace application slice

## 1. Purpose

This document defines the first end-to-end Commonplace product goal:

> A user opens a workspace containing text/Markdown Documents, receives an editor Cell with mirror Documents, edits one mirror live in a browser using Yjs, and sees those edits admitted into the canonical workspace Document without pressing Save or Commit.

The goal is deliberately larger than one library and smaller than a Notion clone. It exists to make the package architecture converge on one observable result.

It should prove that the following pieces compose:

- append-only logs;
- reducer projections;
- Merkle-CRDT content;
- selected Document heads;
- versioned Directories;
- distinct Cell ownership;
- commit-preserving mirror Documents;
- authorized Cell-to-Cell messages;
- browser Yjs projection;
- restart and replay.

## 2. User-visible outcome

From a browser, one authenticated user can:

1. see a small tree of Markdown files;
2. open one file;
3. see its current Markdown source;
4. type into a live editor;
5. see local edits immediately;
6. see a clear saving and synchronization status;
7. reload the page and retain the edits;
8. restart the server and retain the edits;
9. inspect the canonical workspace Document and observe the same accepted content.

There is no manual save button and no explicit user-facing commit operation in this slice. Merkle commits are the durable representation of live edits, not an extra editing ritual.

## 3. Topology

The MVP contains two server-side Cells in one BEAM Realm and one browser client:

```text
Workspace Cell W                 Editor Cell E                    Browser
────────────────                 ─────────────                    ───────
root Directory WD               root Directory ED
       │                                │
       │ tracking/direct                │ tracking/direct
       v                                v
canonical Markdown D             mirror Markdown M               ephemeral Y.Doc B
home_cell_id = W                 home_cell_id = E                 no Commonplace UUID
       ^                                │                               │
       │                                │                               │
       └────── DocSync M → D ───────────┘                               │
                                        ^                               │
                                        └── authenticated Yjs stream ───┘
```

The browser Y.Doc is a projection of the editor Cell's mirror. It is not a third durable Commonplace Document and does not receive a Document UUID.

The two durable Markdown Documents are:

- `D`, the canonical workspace Document;
- `M`, the editor Cell's mirror Document.

They have different UUIDs, different logs, different home Cells, and related Merkle-CRDT history.

## 4. Why the mirror exists

The browser could edit the canonical workspace Document directly, but doing so would avoid the architecture this goal needs to prove.

The mirror provides:

- a durable boundary between user editing and canonical admission;
- a place for locally accepted edits that the workspace may later reject;
- a distinct writer authority and append-only log;
- a future home for offline reconciliation and Yepoch repair;
- a natural unit for one-login-per-editor-Cell isolation;
- a way to keep the browser attached to one local editing authority while the workspace Cell remains independently deployable.

For this MVP, the mirror is not merely a cache. It is a real lineage Document whose edits remain inspectable even when synchronization is blocked.

## 5. Core rulings

This goal adopts the following rules:

1. The workspace and editor are distinct Cells.
2. Both Cells fit wholly inside one Realm for the MVP.
3. The workspace Cell owns the canonical Directory and canonical Markdown Documents.
4. The editor Cell owns its root Directory and mirror Documents.
5. A browser tab is not a Cell in this MVP.
6. A browser Y.Doc is ephemeral projection state, not a Commonplace Document.
7. Canonical and mirror Document UUIDs differ.
8. Canonical and mirror logs differ.
9. A mirror is created from one exact canonical `VersionRef`.
10. A commit-preserving mirror retains the canonical Document's Yepoch.
11. Browser edits become durable in the mirror before the editor reports them saved.
12. Mirror-to-canonical synchronization uses ordinary `commonplace-doc-sync` admission.
13. The workspace Cell alone decides whether mirror commits become canonical.
14. The workspace Directory tracks the canonical Document and checkpoints its version at an amortized cadence.
15. The browser never appends directly to any log.
16. The sync controller never appends directly to any log.
17. Capabilities are not copied by Document lineage.
18. A second simultaneous login is a later milestone, not accidental MVP behavior.

## 6. Durable and ephemeral state

| State | Owner | Durable? | Source of truth |
| --- | --- | --- | --- |
| Workspace Cell descriptor | deployment configuration | yes | configured canonical descriptor |
| Workspace root Directory | Workspace Cell | yes | Directory Document log |
| Canonical Markdown Document | Workspace Cell | yes | canonical Document log |
| Editor Cell descriptor | login/session provisioner | yes for the login lifetime | configured or provisioned descriptor |
| Editor root Directory | Editor Cell | yes | Directory Document log |
| Mirror Markdown Document | Editor Cell | yes | mirror Document log |
| Mirror lineage | mirror Document | yes | immutable initialization data |
| DocSync relationship and receipts | sync controller | yes | durable relationship state |
| Browser Y.Doc | browser tab | no | rebuilt from mirror content plus unacknowledged local edits |
| Yjs awareness state | browser adapter | no | active connections only |
| Cell router registrations | Realm runtime | no | reconstructed when Cells start |
| DocHost and DirHost projections | Realm runtime | no | replayed from logs |
| Directory live dirty overlay | DirHost | no | reconstructed by watching children |

The editor Cell may be ephemeral in placement while its logs remain durable. Stopping its BEAM processes must not erase an acknowledged edit or a pending sync relationship.

## 7. Markdown Document profile

The goal requires a small profile:

```text
commonplace.text/markdown/v1
```

A conforming Markdown Document:

- is an ordinary `commonplace.document/v1` Document;
- uses the ordinary attributes, content, and verbs projections;
- materializes selected content as one Yjs `Y.Text` containing UTF-8 Markdown;
- uses one canonical root name, `content`, if the Yjs implementation requires named shared types;
- stores the selected Merkle commit in `commonplace.content.head`;
- stores presentation metadata such as title separately from Markdown content;
- does not persist rendered HTML as canonical content.

The smallest valid content is an empty `Y.Text`.

The profile package or module must define:

- profile validation;
- creation of an empty Markdown Y.Doc;
- extraction of the selected Markdown string;
- construction and application of Y.Text updates;
- browser interoperability fixtures.

The first implementation may live in the integration application. Extraction into `commonplace-markdown` or `commonplace-text` is a later repository decision.

## 8. Initial workspace

The demo begins with one workspace Cell `W`.

Its root Directory `WD` contains at least:

```text
welcome.md
notes/
  architecture.md
```

Each Directory entry:

- names a canonical workspace-owned Document UUID;
- contains an exact persisted `VersionRef`;
- uses `reference_policy: tracking`;
- uses `write_policy: direct` inside the workspace;
- identifies the target as a Markdown Document or nested Directory;
- is readable only through authorized workspace operations.

The initial `welcome.md` content is:

```markdown
# Welcome

This is a Commonplace document.
```

The workspace can be seeded by a deterministic development fixture. No general workspace-import feature is required.

## 9. Editor Cell provisioning

For the MVP, one authenticated development login maps to one editor Cell `E`.

Provisioning creates or reopens:

- one stable editor Cell ID;
- one editor-owned root Directory `ED`;
- one scoped authorization context for the browser session;
- one scoped editor-service authority for selected operations against `W`;
- durable storage for editor-owned mirror logs and sync relationships.

The MVP may use one configured login and one pre-provisioned editor Cell. It does not need account registration, password recovery, organization management, or production token issuance.

The provisioner MUST NOT create a new editor Cell on every page reload. The same active login reuses its Cell and mirror Documents.

## 10. Listing the workspace

The browser asks the editor Cell for the visible workspace tree.

The editor Cell sends an authorized Cell request to the workspace Cell. The workspace Cell:

1. authenticates the editor Cell delivery context;
2. authorizes a Directory read for the login;
3. reads the workspace root through its DirHost;
4. returns a portable listing containing names, kinds, and authorized current-version information;
5. omits protected history, attributes, capabilities, and storage details.

The request uses the same Cell envelope that could later cross a Realm. Because both Cells initially share one BEAM Realm, the router may use the local `Commonplace.Value` fast path.

The browser receives a web-facing projection of the listing. It does not receive PIDs, DocHost references, storage locations, or Cell root authority.

## 11. Opening a Markdown Document

When the user opens `welcome.md`, the editor Cell resolves the workspace path to an exact canonical Document version:

```text
source Cell:       W
source Document:   D
source VersionRef: V
source Yepoch:     Y
```

The editor Cell then finds or provisions one mirror relationship keyed logically by:

```text
(editor_cell_id, canonical_cell_id, canonical_document_id)
```

### 11.1 Reusing a mirror

If a healthy mirror relationship already exists, the editor Cell reuses its mirror UUID and durable relationship state.

It MUST NOT create a fresh mirror merely because:

- the browser reloaded;
- a WebSocket disconnected;
- a DocHost stopped for idleness;
- the Realm restarted.

If the existing relationship is blocked by canonical divergence or rejection, opening the file surfaces that state rather than silently discarding or replacing the mirror.

### 11.2 Creating a mirror

If no mirror exists, provisioning performs an interruption-safe operation:

1. authorize an exact read and fork from canonical version `V`;
2. allocate mirror Document UUID `M`;
3. initialize `M` with `home_cell_id = E`;
4. record immutable lineage from `D@V`;
5. import the reachable Merkle-CRDT closure without changing commit IDs;
6. preserve Yepoch `Y`;
7. select in `M` the same content head selected by `D@V`;
8. create the durable one-way relationship `M → D`;
9. add a tracking/direct entry for `M` to the editor root Directory;
10. return the mirror address and exact mirror VersionRef.

Every step uses stable operation IDs. A crash may leave recoverable intermediate facts, but retry must converge on the same logical mirror rather than create an unbounded series of children.

The editor Directory entry is for discovery and lifecycle. The DocSync relationship remains authoritative for synchronization state.

## 12. Browser projection

The browser connects to a Yjs-capable attachment endpoint owned by the editor Cell.

The endpoint:

- authenticates the browser session;
- authorizes content read and edit of mirror `M`;
- starts or attaches to `M` through the editor Cell host;
- obtains a race-free mirror snapshot and watch;
- materializes the selected Merkle head as a Y.Doc;
- exposes the Markdown `Y.Text` to the browser;
- synchronizes by Yjs state vector and update messages;
- keeps Yjs awareness separate from durable content.

The browser creates an ephemeral Y.Doc `B` and binds its `content` Y.Text to a Markdown source editor. CodeMirror with a Yjs binding is an appropriate first implementation, but the goal does not require a specific editor library.

The browser adapter may speak efficient binary Yjs frames. This is an authenticated client-attachment protocol terminating at the editor Cell; it is not a Cell-to-Cell message and does not place raw Yjs binary inside a `Commonplace.Value` envelope.

If the browser later becomes a durable offline Cell, that will be a different topology and must use the portable Cell boundary rules.

## 13. Applying a browser edit

The browser applies keystrokes to `B` immediately according to ordinary Yjs behavior.

For every outbound update batch, the browser adapter supplies or derives a stable update operation ID. The editor Cell then:

1. validates framing, size, session, mirror identity, and update operation ID;
2. verifies authorization to edit `M`;
3. submits the update through `M`'s DocHost;
4. constructs an ordinary Merkle-CRDT commit against the expected mirror head;
5. admits the commit into `M`'s content graph;
6. explicitly selects it through `commonplace.content.head`;
7. waits for the mirror log append to become durable;
8. publishes the applied update to attached browser projections;
9. acknowledges the update as saved in the editor Cell.

No WebSocket handler, Yjs provider, or browser process may append directly to the mirror log.

The browser may optimistically display its local edit before acknowledgement. Its status must distinguish:

```text
local      visible in this browser only
saving     submitted to the editor Cell
saved      durable in the mirror Document
syncing    offered to the workspace Cell
synced     durably accepted as canonical
blocked    rejection, conflict, or unavailable authority requires attention
```

“Saved” and “synced” are intentionally different states.

## 14. Mirror-to-canonical synchronization

The existing `commonplace-doc-sync` live-child protocol drives `M → D`.

After the mirror DocHost applies a new head, a watch wakes the mirror controller. The watch is only a liveness hint. The controller consults durable relationship state and:

1. identifies the last accepted merge base;
2. exports the reachable mirror commit closure needed for the proposed head;
3. constructs a stable offer with an operation ID;
4. addresses the offer to workspace Cell `W` through the Cell router;
5. presents the editor service's explicit synchronization capability;
6. asks the workspace Cell to import commits and select the proposed head under the expected-head guard;
7. receives a durable receipt;
8. advances the relationship's accepted merge base;
9. reports `synced` to the browser projection.

Imported commit IDs remain unchanged. When synchronization succeeds, `M` and `D` select the same content commit even though they retain different Document UUIDs and logs.

The controller may debounce rapid mirror heads and offer the latest reachable closure rather than send one network request per keystroke. Debouncing must not lose durable mirror commits or make watches authoritative.

No source log event is copied into the canonical log. The canonical log records its own valid import, admission, head-selection, operation, and receipt facts according to the Document and sync specifications.

## 15. Workspace Directory advancement

The workspace Directory entry for `welcome.md` tracks canonical Document `D`.

After `D` accepts the new head:

1. the workspace DirHost observes `D`'s new VersionRef;
2. its live overlay marks `welcome.md` dirty;
3. live workspace readers may observe the new child version;
4. the DirHost later batches the new version into an ordinary Directory checkpoint;
5. the stable Directory snapshot then pins the accepted canonical version.

The Directory MUST NOT commit on every browser keystroke merely to make the edit durable. Mirror and canonical Document logs provide immediate durability; the Directory checkpoint provides a later stable tree cut.

The browser may show canonical synchronization complete before the containing Directory has checkpointed, but operational inspection must distinguish those states.

## 16. Authorization

The MVP may use a deterministic development authorizer instead of production Biscuit or macaroon cryptography, but it must exercise real scopes rather than grant ambient root everywhere.

At minimum, authority is divided as follows.

### 16.1 Browser session authority

The browser session may:

- list the authorized workspace subtree through the editor service;
- read the selected canonical Markdown content through the editor workflow;
- read and edit mirror `M`;
- receive content synchronization status.

It may not:

- append directly to `D` or `M`;
- read arbitrary Document history;
- inspect capability proofs;
- mount verbs;
- enumerate unrelated editor mirrors;
- obtain Cell root authority.

### 16.2 Editor service authority against the workspace

The editor Cell may receive explicit authority to:

- list an authorized workspace Directory subtree;
- read an exact canonical Document version;
- create a mirror lineage fork from that version;
- submit DocSync offers for the corresponding canonical Document;
- read only the receipt and status information needed by the relationship.

It does not automatically receive unrestricted direct canonical-write authority.

### 16.3 Workspace admission authority

The workspace Cell:

- authenticates the calling Cell context;
- verifies the supplied scope;
- validates imported commit closure and Yepoch compatibility;
- checks expected canonical head;
- decides whether to admit and select the proposal;
- returns a bounded portable receipt or error.

Cell co-residence, Directory references, lineage, and shared Yepoch identity grant no authority by themselves.

## 17. Realm and transport boundary

For the MVP:

- `W` and `E` run inside one BEAM Realm;
- they communicate through the Realm-local Cell router;
- Cell request arguments and results are `Commonplace.Value` values;
- the local fast path may avoid physical canonical JSON encoding;
- every target still applies Cell admission and authorization;
- native BEAM references remain inside the Realm.

The browser is an external network client attached to `E`. It does not participate in the BEAM router.

A later topology test may move `E` to a second Unix process and replace the local route with the canonical network envelope. Cell IDs, Document IDs, capabilities, sync offers, and application behavior must not change. That test is desirable but not required for the first visible editor.

No persistent `commonplace-realm` object or Realm library is required.

## 18. Watches, streams, and subscriptions

The goal uses ephemeral watches and streams:

- DocHost watches wake the mirror controller;
- DirHost watches update live Directory views;
- a browser WebSocket streams Yjs updates and awareness;
- connection-local status events update the editor UI.

None of these is a durable subscription.

After a missed notification or restart, each controller must recover by comparing durable coordinates, heads, VersionRefs, and relationship receipts. It must never infer completion from having observed a watch event.

Durable declarative subscriptions such as “when D changes, invoke a verb on X” remain outside this goal.

## 19. Failure and recovery behavior

### 19.1 Browser disconnect

The mirror remains durable. A reconnect performs Yjs state-vector synchronization against the mirror's selected content.

Acknowledged mirror edits survive. Unacknowledged browser-only edits may survive in the browser's active Y.Doc but are not claimed durable by Commonplace.

### 19.2 Duplicate browser update

Retry uses the same update operation ID. The mirror DocHost or adapter must not create duplicate durable effects for the same logical update.

Yjs idempotence alone is not a substitute for operation-level retry semantics because duplicate no-op commits would still be duplicate history.

### 19.3 Editor Cell process crash

The Realm supervisor restarts the editor Cell host. It reconstructs:

- Cell registration from configuration;
- mirror DocHosts from logs on demand;
- the editor Directory from its log;
- sync work from durable relationship state;
- browser projections from mirror selected heads.

No acknowledged mirror edit is lost.

### 19.4 Sync interruption

The mirror retains all edits. Retry reuses the same offer operation ID and body. Durable receipts decide whether work remains.

### 19.5 Canonical rejection

The relationship becomes visibly blocked. The browser must not report `synced`.

The MVP preserves the rejected edit in `M` and reports a bounded reason. It does not automatically undo the browser, discard mirror history, or cross a Yepoch boundary.

### 19.6 Unexpected canonical advancement

The existing one-way sync protocol stops rather than silently rebasing. The editor displays that the mirror needs reconciliation.

This condition should not occur during the single-editor happy path unless another canonical writer or manual test deliberately advances `D`.

### 19.7 Partial mirror provisioning

Stable operation IDs and durable lineage/relationship facts allow restart reconciliation. The provisioner may complete, reuse, or report an orphaned child. It must not silently create a different mirror on every retry.

### 19.8 Directory checkpoint delay

Canonical content may be synchronized while the stable workspace Directory still pins an earlier `VersionRef`. This is expected amortization, not data loss. The DirHost's live overlay and eventual checkpoint expose the distinction.

## 20. Minimal browser application

The browser application needs only:

- a fixed development-login entry point;
- a workspace tree pane;
- a Markdown source editor;
- optional derived Markdown preview;
- connection status;
- `local`, `saving`, `saved`, `syncing`, `synced`, and `blocked` state;
- visible errors with a retry or reload action;
- no administrative UI.

The UI should expose enough identity during development to debug the topology:

- canonical Document UUID;
- mirror Document UUID;
- editor Cell ID;
- canonical Cell ID;
- mirror selected head;
- canonical selected head;
- relationship status.

This diagnostic panel may be hidden outside development. It is valuable evidence that the browser is editing a mirror rather than accidentally mutating the canonical DocHost directly.

## 21. Component responsibilities

### 21.1 `commonplace-log`

- durable append-only logs for every Document UUID;
- replay coordinates and idempotent prepared append behavior.

### 21.2 `commonplace-log-reducer`

- deterministic projection replay;
- epoch-aware reducer dispatch.

### 21.3 `commonplace-attribute-map`

- selected content head and ordinary metadata projection.

### 21.4 `commonplace-merkle-crdt`

- Y.Text commit construction, admission, reachability, and materialization;
- exact commit IDs shared across the commit-preserving mirror relationship.

### 21.5 `yepochs`

- common Yepoch identity for direct transfer;
- no bridge or re-authoring is required in the happy path.

### 21.6 `commonplace-doc`

- Markdown Document profile integration;
- immutable `home_cell_id` initialization;
- `VersionRef`;
- commit admission and explicit guarded head selection;
- immutable mirror lineage.

### 21.7 `commonplace-doc-host`

- one serialized durable writer path per Document;
- snapshot-and-watch;
- authorized commands;
- operation ID retry;
- restart replay.

### 21.8 `commonplace-dir` and `commonplace-dir-host`

- workspace and editor namespaces;
- path resolution;
- tracking child watches;
- live overlays;
- amortized Directory checkpoints.

### 21.9 `commonplace-doc-sync`

- exact commit-preserving fork;
- durable one-way `M → D` relationship;
- offer, admission, expected-head guard, receipt, and retry.

### 21.10 `commonplace-value`

- portable Cell requests, responses, status, and errors;
- efficient composition of already constructed envelope parts;
- complete decoding if a later route crosses a Realm.

### 21.11 `commonplace-cell`

- Cell descriptors and addresses;
- Document home-Cell ownership;
- message envelopes;
- target admission;
- authorizer and resource-adapter contracts;
- local-versus-remote semantic equivalence.

### 21.12 Integration runtime

The initial integration application supplies:

- enough Cell hosting to supervise `W` and `E`;
- local Realm Cell registration and routing;
- DocHost and DirHost resource adapters;
- development authorization policy;
- editor Cell provisioning;
- mirror controller lifecycle;
- browser HTTP and WebSocket endpoints;
- the minimal editor UI.

This glue may later produce `commonplace-cell-host` and a reusable browser adapter. The goal does not require premature repository extraction.

## 22. Dependency shape

```text
commonplace-log
      |
commonplace-log-reducer
      |
      +-- commonplace-attribute-map
      +-- commonplace-merkle-crdt -- yepochs
                     |
               commonplace-doc
                     |
             commonplace-doc-host
                     |
          +----------+-----------+
          |                      |
commonplace-dir             commonplace-doc-sync
          |                      |
commonplace-dir-host              |
          +----------+-----------+
                     |
              commonplace-cell
                     |
            integration runtime
               /           \
      two Cell hosts       browser Yjs adapter
```

`commonplace-value` is a lower-level dependency of Cell envelopes and other portable protocol values but is omitted from some arrows for readability.

## 23. End-to-end acceptance scenario

The primary automated scenario begins from clean durable storage.

### 23.1 Arrange

1. Create workspace Cell `W` and editor Cell `E`.
2. Create root Directories `WD` and `ED` with the correct immutable home Cells.
3. Create canonical Markdown Document `D` in `W` containing the initial Welcome text.
4. Add `welcome.md → D@V0` to `WD` as tracking/direct.
5. Start both Cells in one BEAM Realm.
6. Authenticate the fixed development login.

### 23.2 Act

1. List the workspace through `E → W` Cell routing.
2. Open `welcome.md`.
3. Provision mirror `M` in `E` from exact version `D@V0`.
4. Attach browser Y.Doc `B` to `M`.
5. Verify that `B` displays the initial Markdown.
6. Change the sentence to:

```markdown
# Welcome

This is a live Commonplace document.
```

7. Wait for the mirror durable acknowledgement.
8. Wait for the canonical sync receipt.
9. Trigger or await the workspace Directory checkpoint.

### 23.3 Assert

1. `D`, `M`, and `B` display the edited Markdown.
2. `D.id != M.id`.
3. `D.home_cell_id == W.id`.
4. `M.home_cell_id == E.id`.
5. `M.lineage.parent_document_id == D.id`.
6. `M` and `D` retain separate logs.
7. `M` and `D` name the same Yepoch.
8. Successful sync leaves `M` and `D` selecting the same commit ID.
9. The DocSync relationship records the accepted merge base and receipt.
10. The stable workspace Directory eventually references the new canonical VersionRef.
11. No browser or sync path appended directly to either log.
12. Every Cell-to-Cell operation passed through target admission and authorization.
13. Reloading the browser reconstructs `B` with the edited text.
14. Restarting the BEAM application reconstructs both Cells and the edited text from durable state.
15. Opening the file again reuses `M` rather than creating a second mirror.

### 23.4 Negative assertions

The test suite also proves:

- an unauthorized workspace path is not listed or opened;
- a browser session cannot directly address the canonical writer operation;
- a malformed Yjs update is rejected without a mirror log append;
- a mirror update exceeding configured limits is rejected;
- a canonical expected-head conflict leaves mirror history intact and reports `blocked`;
- duplicate retry of one browser update does not duplicate durable effect;
- duplicate retry of one sync offer does not duplicate canonical effect;
- a Directory checkpoint delay does not make a synchronized canonical edit disappear.

## 24. Operational observability

The integration should expose bounded telemetry for:

- active Cells;
- active DocHosts and DirHosts by home Cell;
- browser attachment count;
- mirror provisioning outcomes;
- mirror update durability latency;
- sync offer and receipt latency;
- blocked relationships;
- Directory dirty-entry count and checkpoint latency;
- replay and restart duration;
- authorization rejection counts.

Telemetry must not include Markdown content, complete Yjs updates, session proofs, capability tokens, or unredacted internal errors by default.

## 25. Non-goals

This first goal does not include:

- a second simultaneous login;
- canonical-to-mirror synchronization of unrelated changes;
- automatic reconciliation after canonical divergence;
- multi-writer admission to one Document UUID;
- browser-offline persistence across browser restarts;
- browser-as-Cell topology;
- Yepoch bridge construction after rejected edits;
- automatic local undo after canonical rejection;
- rich-text blocks or Notion-compatible schemas;
- comments, mentions, databases, or backlinks;
- Directory copy-on-write UI;
- branches or environment selection in the UI;
- production Biscuit or macaroon issuance;
- Cell forking or Assembly orchestration;
- cross-Realm placement of the two server Cells;
- live migration or failover leases;
- durable subscriptions;
- mirror retention and garbage-collection policy;
- general workspace import/export;
- Git interoperability;
- mobile applications;
- polished product design.

## 26. The second-login seam

The next product milestone creates a second editor Cell for a second login:

```text
Editor Cell E1 / mirror M1 ──┐
                             ├── canonical D in Workspace Cell W
Editor Cell E2 / mirror M2 ──┘
```

`E2` and `M2` must have identities distinct from `E1` and `M1`. The system must not run two Cell hosts over one mirror UUID or make two writers append to one mirror log.

The current one-way live-child protocol is intentionally insufficient by itself. When an edit from `M1` advances `D`, the relationship from `M2` sees unexpected canonical advancement.

Supporting the second login requires:

1. canonical-to-mirror propagation of newly accepted commit closures;
2. durable knowledge of what each mirror has observed;
3. reconciliation when a mirror has pending local edits;
4. guarded construction or selection of a merged head;
5. clear rejection and retry semantics;
6. Yepoch bridging only when histories can no longer transfer directly;
7. fanout so an accepted edit reaches both browser projections.

This remains semantic synchronization among three distinct Documents. It does not require multi-writer logs or one distributed Document process.

The first goal should leave this extension possible by:

- never baking “the only editor” into Document identity;
- keeping relationship state durable and explicit;
- preserving commit IDs and Yepoch identity;
- separating browser projection from mirror identity;
- detecting canonical advancement rather than silently overwriting it.

## 27. Suggested delivery phases

### Phase 1: profile and seeded workspace

- implement the Markdown Y.Text profile;
- seed `W`, `WD`, `D`, and the initial Directory tree;
- inspect and edit `D` through existing host APIs without a browser.

### Phase 2: two Cells in one Realm

- implement the minimal Cell-host integration runtime;
- register `W` and `E`;
- list and read workspace resources through authorized Cell requests;
- prove home-Cell ownership checks.

### Phase 3: mirror provisioning

- open one workspace path;
- create `M` through exact commit-preserving fork;
- persist relationship state;
- add `M` to `ED`;
- prove idempotent reuse after restart.

### Phase 4: browser projection

- materialize `M` into a server-side Yjs attachment;
- connect an ephemeral browser Y.Doc;
- bind it to the Markdown editor;
- synchronize initial state, updates, reconnect, and awareness.

### Phase 5: durable mirror editing

- turn browser updates into ordinary mirror commits;
- acknowledge only after durable append;
- expose `local`, `saving`, and `saved` status;
- prove duplicate update retry.

### Phase 6: canonical synchronization

- run the watch-driven `M → D` controller;
- route offers through Cell admission;
- show `syncing`, `synced`, and `blocked` status;
- checkpoint the workspace Directory.

### Phase 7: recovery proof

- disconnect and reconnect the browser;
- stop and restart mirror hosts;
- restart the Realm application;
- recover the same mirror and relationship;
- replay the complete acceptance scenario in CI.

## 28. Definition of done

This goal is complete when a fresh checkout can run one documented command, open one local browser URL, edit `welcome.md`, and demonstrate all of the following without manual repair:

- the browser edits an ephemeral Yjs projection;
- the projection writes through the editor Cell into a distinct durable mirror Document;
- the mirror synchronizes through an authorized Cell request into the canonical workspace Document;
- the workspace Directory eventually checkpoints the canonical version;
- browser reload preserves the edit;
- server restart preserves the edit;
- development inspection shows two Cells, two Document UUIDs, two logs, one shared Yepoch, and one accepted content head;
- no layer bypasses the ordinary Document host writer path.

At that point Commonplace has crossed an important line: its small libraries no longer merely describe a plausible architecture. Together they implement a recognizable live collaborative document system with the correct seam for the second editor Cell.
