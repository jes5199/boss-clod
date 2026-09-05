# What Fossil SCM Has That Commonplace Does Not Yet Have

**Gap analysis of `commonplace` and `commonplace-plan`**  
**Repository state reviewed:** 2026-08-16

## Executive summary

Fossil's main advantage over Commonplace is not a more ambitious data model. It is **product closure**: source history, branches, tickets, wiki pages, discussion, attachments, identity, synchronization, search, timelines, administration, backup, and a web interface all belong to one coherent project system.

Commonplace already proposes—and in several areas implements—more powerful primitives: structured CRDT documents, live cross-repository references, signed principals and attenuated capabilities, agents, semantic invariants, graded durability, and Git as a derived compatibility view. The gap is that those primitives do not yet compose into a complete, dependable replacement for Git plus its surrounding forge and package ecosystem.

The highest-leverage work is therefore:

1. Finish the native **true-chit** source-control path.
2. Define a stable, signed envelope for durable project facts.
3. Make every derived index disposable and rebuildable from those facts.
4. Deliver whole-project clone, backup, restore, and a unified local web UI.
5. Close the native collaboration loop: tickets, durable discussion, technotes, attachments, search, notifications, and cross-object backlinks.
6. Add a package release and contract-epoch layer above chits; Fossil itself does not provide this missing answer.

## Scope and status terminology

This analysis compares Fossil's documented capabilities with the current implementation in [`commonplace`](https://github.com/commonplace-systems/commonplace) and the designs and roadmap in [`commonplace-plan`](https://github.com/commonplace-systems/commonplace-plan).

The distinction between implementation and intent matters:

- **Implemented** — present in the current Commonplace codebase.
- **Partial** — a usable primitive exists, but the end-to-end product behavior is incomplete.
- **Designed** — specified in `commonplace-plan`, but not yet the authoritative implementation.
- **Missing** — no complete implementation or sufficiently closed design was found.

Commonplace's own [README](https://github.com/commonplace-systems/commonplace/blob/main/README.md) already names Git bridging, issue tracking, chat, wiki, federation, artifact storage, and a web UI. The gaps below are therefore mostly gaps between those primitives or ambitions and Fossil's integrated, operational behavior—not claims that Commonplace has never considered the area.

## Gap matrix

| Capability Fossil already closes | Commonplace today | Status | What is still needed |
|---|---|---:|---|
| A canonical grammar for durable project artifacts | Generic UUID-addressed CRDT documents with per-document commit streams | Partial | A small stable artifact envelope, strict admission validation, explicit schema identity, and durable cross-object references |
| Immutable, atomic source check-ins and native branches/tags | Proto-chits, tree pins, Git import/export, and a true-chit design | Designed / partial | Authoritative native chits, refs, tags, amendments, checkout, log, diff, merge, and deterministic Git projection |
| Whole-project clone, push, pull, and sync | BEAM distribution, federation work, document sync, and GitBridge | Partial | One authorized operation that transfers every durable project fact and verifies convergence |
| One project-wide timeline with backlinks | Per-document red logs plus separate ticket, chat, wiki, and agent concepts | Missing | A rebuildable universal activity index and UI spanning every artifact kind |
| A complete local project website | Phoenix pages for selected surfaces such as wiki/tree/chat/outline/MUD | Partial | A coherent source, history, ticket, discussion, search, timeline, identity, and settings experience |
| Integrated tickets, wiki, forum, chat, technotes, attachments, moderation, and search | Several native subsystems and plans, but not a closed collaboration suite | Partial | Durable threaded discussion, complete ticket UX, generalized attachments, moderation, notifications, and unified search |
| Append-only administrative changes and explicit historical corrections | Append-only document commits and planned ref/control documents | Partial | Native control-artifact vocabulary for tags, property changes, cancellation, closure, supersession, and amendments |
| Portable repository, backup, integrity checking, and index rebuild | CubDB/document storage, content-addressed artifacts, Git archive/export, snapshots, and durability tiers | Partial | A documented full backup/restore/rebuild contract with verifiable completeness |
| Daily source-control porcelain | Filesystem synchronization, Git delegation, and partial CLIs | Partial | A dependable native `status`/`diff`/`commit`/`log`/`branch`/`merge`/`checkout` workflow |
| Mature project administration | Stronger cryptographic identity ideas, but incomplete operator workflows | Partial | Enrollment, revocation, role/capability inspection, recovery, audit, policy UI, and deployment guidance |
| An explicit boundary between ephemeral chat and durable project records | Generalized graded reachability and tombstone designs | Designed | A visible promotion path from transient conversation into a durable ticket, decision, note, or chit |
| A single executable and simple operational story | Multi-application Elixir system plus supporting services and bridges | Partial | A one-command local project experience and a clear minimum deployment profile |

## The central architectural gap: closure

Fossil treats a project as an enduring corpus of immutable artifacts. Check-ins, files, tags, tickets, wiki edits, forum posts, technotes, and other project records share a repository, synchronization model, web UI, timeline, and search surface. Fossil validates incoming artifacts and **crosslinks** them into relational indexes that can be rebuilt from the canonical artifact corpus. Its [data model](https://fossil-scm.org/home/doc/trunk/www/fossil-is-not-relational.md), [artifact formats](https://fossil-scm.org/home/doc/trunk/www/fileformat.wiki), and [sync protocol](https://fossil-scm.org/home/doc/trunk/www/sync.wiki) make that separation explicit.

Commonplace has many of the ingredients but not yet that closure:

- The per-document CommitStore is append-only.
- CRDT documents provide richer live state than Fossil's fixed artifact types.
- Content-addressed artifacts and tree pins can identify immutable content.
- Proto-chits and GitBridge can observe and project Git history.
- Tickets, chat, wiki, agents, and topology are represented or planned.

What remains missing is one answer to: **What exact set of signed facts constitutes a complete Commonplace project, and can every operational view be rebuilt from only those facts?**

Until that answer is executable, Commonplace is a collection of powerful subsystems rather than the self-contained project appliance that Fossil already is.

## Detailed gaps

### 1. A stable durable-artifact envelope

Fossil has a deliberately constrained set of enduring artifact formats. That constraint makes validation, synchronization, indexing, recovery, and long-term interpretation tractable.

Commonplace's generic documents are more extensible, but genericity alone does not establish a permanent project record. A durable Commonplace artifact needs enough common structure to be independently authenticated, traversed, synchronized, and re-indexed. A minimal envelope could be:

```text
ProjectArtifact {
  kind
  schema_cid
  payload_cid
  parents[]
  author
  authored_at
  signature
}
```

The payload schema should remain a first-class, versioned Commonplace object. The goal is not to freeze Fossil's fixed artifact vocabulary into Commonplace. It is to give extensible objects a stable admission and provenance boundary.

Required completion criteria:

- Canonical serialization and hashing.
- Schema identity and schema-version rules.
- Signature and capability validation at admission time.
- Explicit parent/reference semantics.
- Rules for unknown artifact kinds and unavailable schemas.
- Idempotent ingestion.
- A quarantine path for invalid or unauthorized artifacts.
- Deterministic projection into disposable indexes.

### 2. Authoritative native source history

The [proto-chit roadmap](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-07-proto-chit-roadmap.md) intentionally keeps Git authoritative through proto-chit and “true chit beside Git” stages. The [true-chit specification](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-05-git-work-alike-chit-spec.md) describes per-subtree tree pins, parents, author, message, signature, and branch refs, but that design is not yet the everyday source-control implementation.

The inbound Git bridge is real—see [`GitBridge.Inbound`](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/git_bridge/inbound.ex)—but the server-side projection currently commits exported snapshots per processing tick rather than guaranteeing a semantic one-chit-to-one-Git-commit mapping; see [`GitBridge.Server`](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/git_bridge/server.ex).

Fossil already provides the closed behavior Commonplace is designing:

- Immutable atomic check-ins.
- Native branch and tag history.
- Check-in manifests that can reconstruct project states.
- Timeline, diff, annotate, bisect, merge, and checkout workflows.
- Historical correction through new artifacts rather than rewritten ancestry.

Commonplace needs a vertical slice in which a true chit—not a Git commit—is authoritative from creation through browsing, sync, checkout, and Git rendering.

### 3. Whole-project synchronization

Fossil's sync transfers the project corpus through a single protocol. A clone is not merely source files: it includes the surrounding durable project record.

Commonplace currently has several transport and replication concepts, but the product-level contract is not yet equivalent. The missing operation is approximately:

```text
commonplace clone <project>
```

with a guarantee that the result contains, subject to authorization:

- Source chits, trees, refs, and tags.
- Document histories.
- Tickets and their transitions.
- Durable discussions and technotes.
- Attachments and referenced blobs.
- Principals, delegations, and relevant revocations.
- Schemas and invariant definitions needed to interpret the data.
- Enough metadata to rebuild search, timelines, backlinks, and Git views.

The operation should be resumable, idempotent, content-verified, authorization-aware, and capable of proving whether two replicas have converged on the same durable corpus.

### 4. Universal timeline and crosslinks

Fossil's timeline is more than a commit log. It is the common navigational spine for check-ins and project activity. Crosslinks connect artifacts into searchable relationships without making the derived SQL tables canonical.

Commonplace has per-document red logs and domain-specific views, but no equally complete project-wide activity surface. It needs a universal event projection that can answer:

- What changed across source, tickets, docs, discussion, releases, and policy?
- Which ticket, decision, review, or forum thread refers to this chit or subtree?
- Which source change closed this ticket?
- What facts did a principal or agent author, approve, revoke, or supersede?
- What was the complete project state at a selected durable point?

This should be a rebuildable interpretation of canonical facts, not a second source of truth.

### 5. One complete local web application

Fossil serves a project website directly from the repository. Its [all-in-one rationale](https://fossil-scm.org/home/doc/trunk/www/whyallinone.md) is operational as much as architectural: users do not need to assemble a separate forge, tracker, wiki, forum, and identity layer.

Commonplace's current router exposes selected native pages—see the [Phoenix router](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace_web/lib/commonplace_web_web/router.ex)—but it does not yet offer one coherent UI for:

- Source tree and file history.
- Chit timeline and diffs.
- Branches, tags, releases, and amendments.
- Tickets and queries.
- Durable threaded discussion.
- Wiki and technotes.
- Full-text and structural search.
- Backlinks and relationship navigation.
- Principal/capability inspection.
- Sync, storage, and integrity status.

The practical target should be a one-command local UI that remains useful offline and exposes the same project model as the CLI and sync protocol.

### 6. A closed collaboration suite

Fossil natively includes tickets, wiki, forum, chat, technotes, attachments, moderation facilities, search, and notification mechanisms. Its [forum](https://fossil-scm.org/home/doc/trunk/www/forum.wiki) and [chat](https://fossil-scm.org/home/doc/trunk/www/chat.md) intentionally serve different durability and conversational needs.

Commonplace has promising native models, but the missing pieces are the connective tissue and product workflows:

- Complete ticket creation, editing, state transitions, queries, and backlinks.
- Durable threaded discussions distinct from transient chat.
- Technotes or decision records attached to project time and source states.
- Attachments usable across tickets, posts, docs, chits, and releases.
- Moderation, redaction markers, spam controls, and administrative audit.
- Notifications and subscriptions.
- Unified full-text and structural search.
- Promotion of a chat exchange into a durable decision, ticket, note, or source amendment.

### 7. Explicit administrative and corrective history

Fossil's preference for “what actually happened” is implemented through additive control artifacts. Tags and properties can be added, canceled, or superseded without pretending the earlier event never occurred. Fossil also rejects rebase-centric workflow as a default cultural model; its rationale is documented in [Rebase Considered Harmful](https://fossil-scm.org/home/doc/trunk/www/rebaseharm.md).

Commonplace's append-only document histories are a strong base, but project-level semantics still need an explicit durable vocabulary, for example:

- `RefAdvanced`
- `TagApplied`
- `TagCancelled`
- `ArtifactSuperseded`
- `ChitAmended`
- `TicketTransitioned`
- `DecisionRatified`
- `CapabilityGranted`
- `CapabilityRevoked`
- `ReleasePublished`
- `ReleaseWithdrawn`

These facts should preserve the distinction between correcting a current interpretation and erasing the historical record.

### 8. Backup, restore, integrity, and rebuild

Fossil has a simple repository-level operational story and explicit [backup guidance](https://fossil-scm.org/home/doc/trunk/www/backup.md). Its canonical artifact corpus can reconstruct derived database state.

Commonplace has content-addressed artifacts, document storage, Git export/archive paths, snapshots, and a sophisticated durability direction. The [storage SLA reaction](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/notes/2026-08-12-storage-sla-reaction.md) describes durable, compactable, and ephemeral tiers with promotion through pins, links, and other reachability.

What is missing is a complete operator contract:

1. Identify every canonical durable root.
2. Traverse every required object and blob.
3. Export a portable, self-describing archive.
4. Verify hashes, signatures, schemas, reachability, and authorization metadata.
5. Restore without relying on old indexes.
6. Rebuild timelines, search, backlinks, Git projections, and caches deterministically.
7. Report missing, corrupt, compacted, or intentionally tombstoned material precisely.

“All indexes can be deleted and rebuilt” should become a tested invariant.

### 9. Native SCM porcelain

Fossil is already usable as a daily source-control tool. Commonplace currently relies on filesystem synchronization, Git interoperability, and partial CLIs while native chit semantics mature.

Before Commonplace can reasonably claim the SCM part of a Git successor, a developer should be able to perform the normal loop without treating Git as the authority:

```text
status → diff → commit/chit → log → branch → merge → checkout → sync
```

That includes conflict presentation, rename behavior, ignore rules, partial/subtree operation, detached historical inspection, bisect or equivalent diagnosis, and clear recovery from interrupted operations.

### 10. Administrative productization

Commonplace's signed-principal and capability direction is more expressive than Fossil's conventional project roles. But a stronger security model is not yet a stronger product until operators can understand and recover it.

The remaining gap includes:

- Principal enrollment and device addition.
- Delegation and attenuation inspection.
- Revocation propagation and historical interpretation.
- Lost-device and lost-key recovery.
- Project bootstrap and ownership transfer.
- Human-readable authorization explanations.
- Service identities and unattended agents.
- Audit views and policy debugging.
- Conservative deployment defaults.

This is an area where Commonplace should not copy Fossil's model; it should match Fossil's usability while retaining its own stronger cryptographic semantics.

### 11. A visible transient-to-durable path

Fossil distinguishes ephemeral chat from more durable forum and project artifacts. Commonplace's generalized ephemerality model is more powerful, but users still need an obvious workflow boundary.

A conversation should be promotable into a durable artifact with provenance, for example:

```text
chat selection → proposed decision → ratification → source/ticket/release backlinks
```

The UI should state what will persist, who can see it, what schema it uses, what signed fact was created, and whether the source conversation may later expire.

## Evaluating William Lubelski's claims

The screenshots make four substantive claims. They are mostly directionally right, with two important qualifications.

### “It is very append-only; no rebase”

**Mostly correct.** Fossil is built around immutable content-addressed artifacts and strongly discourages rewriting public history. It records later control artifacts to alter tags or interpretations. “No rebase” is best read as a workflow and history-integrity stance, not an absolute claim that Fossil has no administrative escape hatches or artifact-removal mechanisms.

This is relevant to Commonplace because its append-only per-document commit streams do not yet guarantee one immutable, project-wide history. True chits and durable control artifacts are needed to lift that property from individual documents to the complete project.

### “It includes the issue tracker and message board natively”

**Correct, and slightly understated.** Fossil integrates tickets, wiki, forum, chat, technotes, attachments, timeline, search, and the project web application with source control. The important feature is not merely bundling: these objects share project identity, synchronization, navigation, and operational lifecycle.

This is Fossil's clearest present advantage over Commonplace.

### “They care about what actually happened, not a polite fiction”

**Correct as a design philosophy.** Fossil favors additive history and visible merges over a rebased narrative. Commonplace's proposal that squash and rebase can be **render modes** is compatible with this philosophy: preserve the real chit graph internally, then generate a cleaner Git view when interoperability requires it.

The key rule should be: **presentation may simplify history; canonical storage must not silently replace it.**

### “You can go back to basically any version state”

**Correct for recorded project check-ins, with a boundary.** Fossil can reconstruct committed historical states. It does not record every uncommitted keystroke or every intermediate working-directory condition.

Commonplace can eventually exceed this by retaining structured edit histories as well as source checkpoints. It should nevertheless distinguish:

- An edit-level document state.
- A durable project fact.
- An atomic source/project checkpoint.
- A release or published compatibility boundary.

Without those distinctions, “any version state” becomes ambiguous and expensive.

### “A super-Git with an internally facing npm would be sweet”

**This identifies a real gap, but Fossil does not fill it.** Fossil's integrated project model does not solve package publication, semantic compatibility, contract versioning, or coordinated multi-package releases. Commonplace's [cross-repository live-dependency design](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-07-11-cross-repo-live-dependencies-design.md) deliberately favors live references, with optional content pins, rather than an npm-like publication system.

Live references solve a different problem from versioned contracts:

- **Capability scoping** answers what an agent may read or change.
- **Tree/subtree identity** answers what code or data is selected.
- **Release/version semantics** answer what independent consumers can safely rely on.
- **Contract epochs and migrations** answer what happens when compatibility breaks.

A monorepo can defer package versioning while every producer and consumer advances atomically. It cannot eliminate versioning once consumers advance independently, deploy on different schedules, or need old and new contracts simultaneously.

## The package and contract layer Commonplace still needs

Commonplace should support three explicit dependency modes:

| Mode | Meaning | Best use |
|---|---|---|
| `live` | Follow an authorized project/subtree reference as it advances | A coordinated workspace or tightly coupled monorepo |
| `release` | Depend on one immutable published release | Reproducible builds and independent deployment |
| `range` | Resolve a compatibility constraint, then record the exact result | Registry-style consumption with repeatability |

A package release can be modeled as a specialized durable chit:

```text
PackageRelease {
  package_id
  package_root
  version
  contract_epoch
  tree_pin
  parent_releases[]
  exported_contracts[]
  interface_digest
  dependencies[]
  migrations[]
  build_attestations[]
  test_attestations[]
  signer
}
```

A `ReleaseSet` should atomically name a coherent collection of package releases. This is the package equivalent of a project check-in: it records which versions were known to work together without forcing the source tree itself to become a conventional monorepo.

Recommended compatibility semantics:

1. Compatible changes remain within a contract epoch.
2. A breaking change creates a new contract epoch.
3. Old and new epochs may coexist.
4. Adapters and migrations are explicit artifacts.
5. The exact resolved dependency graph is recorded in every release/build attestation.
6. A coordinated breaking change across packages is published as a new `ReleaseSet`.
7. Agent capabilities may restrict package subtrees, but capabilities must not be mistaken for dependency compatibility.

This is a meaningful place for Commonplace to go beyond both Git and Fossil.

## A Commonplace-native synthesis

The cleanest architecture is three planes:

| Plane | Purpose | Commonplace representation |
|---|---|---|
| Live mutable world | Collaborative work in progress and fine-grained history | Merkle-CRDT documents and their edit/commit streams |
| Durable declared facts | Signed events the project promises to retain and interpret | Chits, tags, releases, ticket transitions, approvals, forum posts, technotes, ratifications, grants, and revocations |
| Rebuildable interpretation | Fast navigation and interoperability | Timeline, backlinks, search, SQL indexes, dashboards, Git repos, package registries, and caches |

The critical direction is one-way:

```text
live state → signed durable facts → rebuildable views
```

Derived views may never become the only place where project meaning survives. Git should be an interoperable projection, not the hidden canonical database. Search indexes and timelines should be disposable. A package registry should be reconstructable from signed release facts.

This adapts Fossil's strongest architectural lesson—immutable artifacts plus rebuildable crosslinks—without giving up Commonplace's extensible schemas or live structured state.

## What Commonplace already has that Fossil does not

The comparison should not be read as a recommendation to turn Commonplace into Fossil. Commonplace's differentiators include:

- Live, structured CRDT collaboration rather than file snapshots alone.
- Fine-grained signed principals and attenuated capabilities.
- Agents, pods, and topology as native project actors and structure.
- Dataflow and malleable-software ambitions.
- Semantic invariants and witness grades.
- Generalized durability, reachability, compaction, and ephemerality.
- Cross-repository live references.
- Git as a derived compatibility view, including the possibility of clean renderings that do not destroy canonical history.
- Extractable repository boundaries, as discussed in the [repo-extractability ruling](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-08-repo-extractability-ruling.md).

Fossil is the better benchmark for completeness and integrity; Commonplace remains the more ambitious model for live, structured, agent-mediated work.

## Recommended implementation sequence

### Phase 1 — Finish the true-chit vertical slice

Deliver:

- Native `status`, `diff`, `chit/commit`, `log`, `checkout`, and branch refs.
- Tags and additive amendments.
- Atomic tree/subtree pins.
- Deterministic one-chit-to-one-Git-commit rendering.
- Round-trip tests across native history and the Git projection.

**Exit test:** a small project can use Commonplace as the source-history authority for normal daily work, while Git remains a faithful derived view.

### Phase 2 — Establish the durable artifact and rebuild contract

Deliver:

- Canonical artifact envelope and serialization.
- Admission validation, signatures, schemas, and capability checks.
- Crosslink/index projection framework.
- Full index deletion and deterministic rebuild tests.
- Explicit control-artifact types for correction, supersession, and revocation.

**Exit test:** the project can destroy every derived database and reproduce the same navigational and interoperability views from durable artifacts alone.

### Phase 3 — Close project replication and operations

Deliver:

- Whole-project clone/pull/push/sync.
- Portable backup and verified restore.
- Reachability/integrity diagnostics.
- One-command local web UI.
- A documented single-node/offline operating profile.

**Exit test:** a fresh machine can receive an authorized project archive or clone, verify it, rebuild it, browse it, and resume work without the original server.

### Phase 4 — Close the collaboration surface

Deliver:

- Complete ticket UI and query model.
- Durable threaded forum/discussion.
- Technotes/decision records.
- Generalized attachments.
- Universal timeline, backlinks, and search.
- Notifications, moderation, and audit.
- Promotion from ephemeral chat to durable facts.

**Exit test:** a small team can run source, planning, discussion, decisions, and documentation without requiring a separate forge for the core workflow.

### Phase 5 — Add packages, contract epochs, and release sets

Deliver:

- Stable package identity.
- `live`, `release`, and `range` dependency declarations.
- Signed `PackageRelease` artifacts.
- Atomic `ReleaseSet` artifacts.
- Interface digests and compatibility validation.
- Migration/adaptor relationships.
- Rebuildable package-registry views.

**Exit test:** independent consumers can reproduce a build, remain on an old contract, adopt a new contract intentionally, and verify the exact signed dependency graph.

## What not to copy from Fossil

Commonplace should copy Fossil's closure, provenance, rebuildability, and operational simplicity—not all of its constraints.

Avoid:

- Replacing extensible schemas with a permanently fixed artifact taxonomy.
- Collapsing structured documents into file snapshots.
- Treating one SQLite database layout as the long-term public data model.
- Reducing capability-based identity to coarse project roles.
- Making Git-compatible history the canonical form.
- Treating every event as equally durable.
- Assuming package compatibility follows automatically from source history.

## Bottom line

Will Lubelski is right about the feature cluster that makes Fossil interesting: immutable history, additive correction, integrated project collaboration, and reliable access to recorded states. But Fossil's real lesson is broader: **a source-control successor must own the whole durable project story, not merely improve the commit graph.**

Commonplace has the primitives to go further than Fossil. Its current gap is turning them into one closed loop:

```text
author → validate → preserve → sync → crosslink → browse → rebuild
```

The package/versioning problem is an additional frontier, not something Fossil has already solved. Commonplace can address it cleanly if package releases, contract epochs, and coherent release sets are built as signed durable facts on top of true chits.

## Primary sources

### Commonplace

- [`commonplace` README](https://github.com/commonplace-systems/commonplace/blob/main/README.md)
- [`ProtoChit` implementation](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/proto_chit.ex)
- [Proto-chit event schema](https://github.com/commonplace-systems/commonplace/blob/main/docs/plans/2026-08-09-proto-chit-event-schema.md)
- [Proto-chit roadmap](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-07-proto-chit-roadmap.md)
- [Git work-alike / true-chit specification](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-05-git-work-alike-chit-spec.md)
- [`GitBridge.Inbound`](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/git_bridge/inbound.ex)
- [`GitBridge.Server`](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace/lib/commonplace/git_bridge/server.ex)
- [Phoenix web router](https://github.com/commonplace-systems/commonplace/blob/main/apps/commonplace_web/lib/commonplace_web_web/router.ex)
- [Cross-repository live dependencies design](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-07-11-cross-repo-live-dependencies-design.md)
- [Storage SLA reaction](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/notes/2026-08-12-storage-sla-reaction.md)
- [Repository extractability ruling](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-08-repo-extractability-ruling.md)
- [Topology proposal](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-16-topology-proposal.md)

### Fossil

- [Fossil's non-relational artifact model](https://fossil-scm.org/home/doc/trunk/www/fossil-is-not-relational.md)
- [File and artifact formats](https://fossil-scm.org/home/doc/trunk/www/fileformat.wiki)
- [Synchronization protocol](https://fossil-scm.org/home/doc/trunk/www/sync.wiki)
- [Why Fossil is all-in-one](https://fossil-scm.org/home/doc/trunk/www/whyallinone.md)
- [Core concepts](https://fossil-scm.org/home/doc/tip/www/concepts.wiki)
- [Forum](https://fossil-scm.org/home/doc/trunk/www/forum.wiki)
- [Chat](https://fossil-scm.org/home/doc/trunk/www/chat.md)
- [Rebase Considered Harmful](https://fossil-scm.org/home/doc/trunk/www/rebaseharm.md)
- [Backup guidance](https://fossil-scm.org/home/doc/trunk/www/backup.md)
