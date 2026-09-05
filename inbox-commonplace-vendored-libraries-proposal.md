---
title: Commonplace Vendored-Library Decomposition Proposal
date: 2026-08-16
status: Proposed
source_baseline:
  commonplace: 75564d7b70bc1268c41c8b4ef1881d869ef7b7e6
---

# Commonplace Vendored-Library Decomposition Proposal

## Executive decision

Commonplace should become a small dependency graph of independently testable libraries, not a collection of one-module repositories.

The recommended sequence is:

1. Extract **Yepochs** next, but broaden its boundary from one late-edit translator into the complete pure epoch/rebase algebra.
2. Extract the closed-by-default Elixir AST validator as **Safe Elixir AST**.
3. Extract the native file-lock primitive as **Beam Flock**, leaving Commonplace's fail-open policy in Commonplace.
4. Make persisted values and wire formats pure, then extract **Commonplace Protocol** without renaming serialized structs.
5. Extract the filesystem CAS when the planned history store becomes its second real consumer.
6. Build **Commonplace History** on an injected reader after store routing exists.
7. Refactor before extracting the runner and filesystem-sync engines.
8. Add a client SDK only when it is time to move vertical applications out of the umbrella.

The target is roughly six durable libraries over the next several architecture arcs, plus two or three later candidates—not a repository for every pure-looking namespace.

| Candidate | Recommendation | Readiness | Main reason |
|---|---|---:|---|
| Yelixer | Already extracted; harden the consumption contract | Done | CRDT engine and lowest-level dependency |
| Yepochs | Extract next | High | Coherent pure epoch, derivation-map, and rebase algebra |
| Safe Elixir AST | Extract next | High | Security-sensitive, domain-agnostic mechanism |
| Beam Flock | Extract soon | High | Native/toolchain boundary with several consumers |
| Commonplace Protocol | Purify now; extract after codec work | Medium | Shared types for peers, pods, Git/chit tools, and future clients |
| Filesystem CAS | Extract with HistoryStore | High technically, low urgency | Clean mechanism, but currently too small and single-purpose |
| Commonplace History | Design now; extract after routed reads | Medium-low | Valuable reusable history engine; current tree code mixes effects and policy |
| Runner Core | Refactor first | Low | Pod execution is reusable, but provisioning is still product orchestration |
| YFS | Refactor later | Low | Useful sync engine, currently coupled to store, tree, identity, and signing |
| Commonplace SDK | Define after service boundaries settle | Low | Needed for app decomposition, not yet a stable library contract |

This proposal uses the repository spelling **Yelixer** for the existing package. The planning material has used `yepochal` as a working name; this document uses **Yepochs**, following the requested name.

## What “vendored library” should mean

For Commonplace, a vendored library should be:

- owned in a separate `commonplace-systems` repository;
- consumed as an immutable Mix dependency, pinned by a full commit identity or release tag and lockfile;
- independently buildable and testable from a fresh checkout;
- releasable on its own cadence;
- unable to import Commonplace application code; and
- replaceable by changing an adapter rather than rewriting the product.

It should not mean copying source directories back into the umbrella, using a Git submodule, or publishing every helper to Hex. Git dependencies are sufficient while the APIs are still moving. Hex publication can be a later product decision.

## The extraction test

A component earns a repository when most of the following are true:

1. **Coherent contract.** Its purpose can be explained without reciting Commonplace product policy.
2. **One-way dependency.** The library does not import Commonplace, read Commonplace application environment, or call a Commonplace process by registered name.
3. **Opaque internals.** Commonplace consumes public operations rather than constructing or destructuring implementation structs.
4. **Independent proof.** Tests, fixtures, property checks, CI, and a fresh-consumer compilation live with the code.
5. **Real reuse or isolation payoff.** There are at least two plausible consumers, or the split isolates a security boundary, native toolchain, or independently evolving protocol.
6. **Meaningful ownership.** Extracting it removes a dependency, build concern, or protocol responsibility from the host.
7. **No ambient authority.** Authorization, current trust configuration, retention policy, signing identity, and mutable store ownership remain in Commonplace.

Line count alone is not a reason to extract. A 150-line native boundary may deserve a repository; a 1,000-line product-specific subsystem may not.

## Recommended dependency graph

```text
commonplace
├──> yelixer
├──> yepochs ───────────────> yelixer
├──> commonplace_protocol
├──> commonplace_history ───> commonplace_protocol
│                         ├──> yepochs
│                         └──> yelixer
├──> safe_elixir_ast
├──> beam_flock
└──> commonplace_cas_fs

Internal adapters, initially:
commonplace ──> runner adapter / YFS adapter / app-client adapter
```

The important directions are:

- `yepochs -> yelixer`;
- `commonplace_protocol` should remain below storage and ideally independent of Yelixer;
- `commonplace_history -> commonplace_protocol + yepochs + yelixer`;
- Commonplace may depend on every extracted library, but no extracted library may depend on Commonplace; and
- generic mechanisms such as flock, CAS, and AST validation should not depend on the Commonplace protocol packages.

Runner Core and YFS are omitted as firm nodes because their eventual dependency shape should emerge from the adapter work, not be guessed now.

## 1. Yepochs: extract the whole pure epoch algebra

### Decision

Proceed with Yepochs, but do not publish a package whose entire durable contract is the current 124-line late-edit translator. That code is a good seam, not a sufficient library identity.

The coherent package is the pure algebra needed to carry Yelixer updates across history epochs:

- derivation-map representation, normalization, inversion, and composition;
- late-edit reference translation;
- late-edit preflight validation;
- positional rebase primitives for arrays, maps, text, and XML; and
- the pure portion of the grapheme diff used by text rebasing.

The current candidates are already concentrated in:

- [`late_edit_translator.ex`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/store/late_edit_translator.ex), which imports only Yelixer types and encoding helpers;
- [`late_edit_preflight.ex`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/store/late_edit_preflight.ex);
- the [`document/rebase`](https://github.com/commonplace-systems/commonplace/tree/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/document/rebase) primitives; and
- the pure diff kernel in [`document/diff.ex`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/document/diff.ex).

Pure derivation-map operations currently embedded in `Commonplace.Store.Namespace` should move too. Store reads, commit lookup, and namespace persistence should not.

### Yepochs owns

- transformations from one epoch's Yelixer identifiers or materialized values to another;
- deterministic validation of whether references can be translated;
- data structures and errors intrinsic to those transformations;
- property tests for inversion, composition, identity, and translation; and
- fixture compatibility across Yelixer versions supported by the package.

### Commonplace retains

- deciding when an epoch transition is allowed;
- loading commits, snapshots, and derivation maps;
- choosing document content semantics;
- current head and namespace authority;
- author identity, signatures, and capability checks;
- writing translated updates or merge results; and
- observability and recovery policy.

`Store.Translator`, `Store.CrossEpochMerge`, snapshotters, and ancestry orchestration therefore stay in Commonplace. They are callers of Yepochs, not part of it.

### Boundary rule

Yepochs should accept values explicitly and return values or structured errors. It must never receive a store process, workspace, current identity, or application environment. Its only runtime dependency should be Yelixer, plus development and test dependencies.

An illustrative API—not a frozen naming decision—would be:

```elixir
Yepochs.DerivationMap.invert(dm)
Yepochs.DerivationMap.compose(left, right)
Yepochs.LateEdit.preflight(update, inverse_dm)
Yepochs.LateEdit.translate(update, inverse_dm)
Yepochs.Rebase.rebase(kind, old_value, new_value, update)
```

### Why this is the next extraction

It is already mostly pure, gives the existing proposal a defensible package identity, and establishes the desired graph `Commonplace -> Yepochs -> Yelixer`. It also prevents epoch semantics from remaining accidentally coupled to a particular store backend while the storage topology changes.

## 2. Safe Elixir AST: extract the security mechanism

### Decision

Extract `Commonplace.Code.Allowlist` and `Commonplace.Code.Allowlist.Profile` into a working package such as `safe_elixir_ast`.

The current implementation describes itself as a closed-by-default, domain-agnostic AST allowlist. Its structural bans and narrow extension profile form a coherent security mechanism. The core files are [`allowlist.ex`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/code/allowlist.ex) and [`profile.ex`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/code/allowlist/profile.ex).

### Library owns

- structural AST validation;
- the fixed set of non-overridable dangerous forms;
- the profile schema for narrowly permitted calls and literals;
- stable rejection reasons; and
- adversarial and regression corpora.

### Commonplace retains

- loading source documents;
- deciding which profile applies to a domain;
- trust and capability gates;
- compilation, process execution, timeouts, and resource controls;
- audit events; and
- all MUD-specific verb policy.

`Commonplace.Code.SourceDoc` should not move. It is coupled to content types, tree lookup, commit access, workspaces, and trust checks.

### Security statement

The package must say plainly that AST allowlisting is defense in depth. It is not an operating-system sandbox, a scheduler quota, a memory limit, or a substitute for container/process isolation. Extraction should make that contract clearer, not market the validator as a complete sandbox.

### Why extract it

This boundary isolates security review, makes the adversarial test suite travel with the validator, and permits runner- or agent-facing consumers to validate code without importing the Commonplace runtime. Its value comes from isolation even before a second product uses it.

## 3. Beam Flock: extract the strict native primitive

### Decision

Extract [`Commonplace.Sync.Flock`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/sync/flock.ex), [`flock_nif.c`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/c_src/flock_nif.c), and their build/test support into a small generic package such as `beam_flock`.

The package should expose strict primitives:

- open or acquire a scoped lock;
- non-blocking and bounded-wait acquisition;
- release;
- `with_lock` that returns an explicit error; and
- interoperability tests against a separate operating-system process.

Commonplace's current decision to continue without a lock after selected failures or timeouts is product policy. That behavior belongs in a Commonplace adapter and must not be the generic library default.

### Why extract it

The code is already used across CLI access, store exclusion, runner launch, and sync/export paths. The split removes NIF loading, `elixir_make`, C compiler concerns, and platform CI from the core application. This is a case where a small repository is justified by a distinct toolchain and failure domain.

### Required proof

Test supported Unix targets, NIF loading in releases and escripts, lock contention between BEAM and non-BEAM processes, abnormal owner exit, and explicit unsupported-platform behavior.

## 4. Commonplace Protocol: purify first, then extract

### Decision

Create a peer-neutral protocol package for stable values, canonical encodings, identifiers, signatures, and wire codecs. Do not extract it until storage calls and policy lookups have been separated from value construction and verification.

Good raw material includes:

- [`Commonplace.Store.Commit`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/store/commit.ex);
- trust revocations and Gold attestations;
- the pure certificate and attenuation portions of capabilities;
- the codec/value portion of federation envelopes;
- `Document.DocRef`; and
- stable pod profile and run-recipe schemas, if Runner Core does not become their sole owner.

This is not intended as a generic ecosystem library. It is Commonplace's shared constitution for independent peers, attenuated-identity pods, Git/chit tooling, federation bridges, and future clients.

### Protocol owns

- immutable value schemas and version tags;
- canonical byte encodings;
- content identifiers;
- local, context-free signature or hash verification;
- attenuation data structures and context-free validation;
- envelope encoding and decoding; and
- compatibility fixtures and test vectors.

### Commonplace retains

- resolving an identifier through a store;
- deciding whether a signer is currently trusted or revoked;
- selecting current capabilities and identities;
- enforcing read/write/admission policy;
- importing an envelope into a workspace;
- network and filesystem effects; and
- authoritative time, retention, and lifecycle decisions.

For example, a chain verifier in the library may accept an explicit resolver callback. The Commonplace adapter supplies the store-backed resolver and applies current trust policy.

### Persisted-struct migration hazard

Current storage serializes Elixir terms that include module-qualified structs. Moving `%Commonplace.Store.Commit{}` to another repository while retaining the same module name is compatible; renaming it to `%Commonplace.Protocol.Commit{}` is not automatically compatible.

The first extraction must therefore do one of two things:

1. preserve existing module names in the external package; or
2. first introduce versioned codecs and a backward decoder, migrate persisted data, and only then rename modules.

The safer first move is repository extraction without module renaming. Namespace cleanup can wait for an explicit storage-format migration.

### Canonical serialization

`GitBridge.CanonicalJson` and canonical XML support belong either in this protocol package or in an internal serialization namespace. They are too small and too tied to Commonplace's concrete representations to justify separate repositories today. The package should document the exact format it guarantees rather than implying compliance with a broader canonicalization standard it does not implement.

## 5. Filesystem CAS: extract when HistoryStore arrives

### Decision

[`Commonplace.Store.ArtifactStore`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/store/artifact_store.ex) is already a clean filesystem content-addressed store: streaming SHA-256, temporary-file publication, durability flush, atomic rename, concurrent publication, and streaming reads.

It is technically extractable now. It should probably wait until the proposed cold/history store becomes a second consumer; otherwise Commonplace would create a repository around a single 139-line implementation without yet proving the durable abstraction.

### Library owns

- streaming put/get by digest;
- atomic and idempotent publication;
- checksum and read-back verification;
- immutable segment/blob primitives; and
- backend conformance tests.

### Commonplace retains

- placement catalogs;
- hot/warm/cold routing;
- reachability and retention roots;
- leases, tombstones, and grace periods;
- garbage-collection decisions; and
- recovery policy.

The right trigger is: when both binary artifacts and immutable history segments use the same abstraction, extract `commonplace_cas_fs` and prove both consumers against it.

## 6. Commonplace History: design after routed reads

### Decision

Extract a pure or effect-parameterized history engine only after the storage work introduces a routed reader. Do not move `Tree.*` wholesale.

The eventual package can own:

- commit value traversal;
- replay over an ordered commit stream;
- ancestry and merge algorithms;
- snapshot/genesis trimming calculations;
- post-state hash-era validation; and
- fetcher interfaces that return protocol values by identifier.

Commonplace must retain head authority, store placement, trust gates, signing, snapshot scheduling, workspace semantics, and tree presentation.

Today `Tree.DocBuilder` performs history logic but also reads the commit store, writes lazy snapshots, consults application configuration, emits telemetry, and coordinates workers. The first task is not extraction; it is splitting a pure replay plan from those effects. The routed-reader work proposed for storage ephemerality creates the correct injection seam.

The intended dependency is:

```text
commonplace_history -> commonplace_protocol + yepochs + yelixer
commonplace         -> commonplace_history
```

## 7. Runner Core: refactor the plan compiler before extraction

### Decision

The runner is strategically worth extracting because pods and local agents are a second deployment context, but `Runner.Provisioner` is presently an orchestration boundary, not a library boundary.

The pure [`PodProfile`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/runner/pod_profile.ex) and [`RunRecipe`](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/apps/commonplace/lib/commonplace/runner/run_recipe.ex) schemas are good seeds. The extractable engine should eventually own:

- backend-neutral sandbox specifications;
- compilation of a specification into a Docker, Bubblewrap, or other backend plan;
- process/container handles;
- readiness probing;
- scoped termination; and
- cleanup/reaping.

Commonplace retains:

- manifest ratification and admission;
- capability and certificate minting;
- deployment identity;
- workspace attachment and CRDT synchronization;
- commit and promotion barriers;
- lifecycle records; and
- policy selection.

The immediate refactor is to turn “provision this Commonplace deployment” into two steps:

1. Commonplace evaluates policy and produces an explicit, serializable run specification.
2. Runner Core validates and executes that specification through a selected backend.

Only extract after that specification can be tested without a Commonplace store, tree, trust process, or node identity.

## 8. YFS: a later filesystem projection engine

### Decision

Commonplace's sync subsystem contains a reusable filesystem projection engine, but its agents currently combine watcher mechanics with tree lookup, commits, reflogs, identity, and signing. Extracting the directory now would only relocate coupling.

A future `yfs` or `yelixer_fs` package may own:

- filesystem watching;
- inode and rename tracking;
- write-back suppression;
- text/binary classification;
- deterministic reconciliation state machines; and
- projection through abstract document and artifact source/sink interfaces.

Commonplace supplies adapters for workspaces, tree structure, commits, heads, authorship, capabilities, and artifacts.

The trigger should be the pod architecture: once both the desktop/CLI sync path and an attenuated pod use the same projection engine through explicit interfaces, the second consumer proves the boundary. YFS may depend on Yelixer and Yepochs, but not on Commonplace.

The native flock primitive should be extracted independently first; YFS can consume it without owning it.

## 9. Commonplace SDK: enable application decomposition later

### Decision

The web, CLI, MCP, bots, MUD, BD, chat, and outline code are applications or product domains, not vendored libraries. Moving them out cleanly eventually requires a supported Commonplace client boundary.

A future SDK could own:

- protocol values and references, by dependency rather than duplication;
- client interfaces for read, edit, fork, pin, commit/chit, and subscribe operations;
- event schemas; and
- test adapters for application developers.

It should depend on `commonplace_protocol`, not on `commonplace` internals. Until the service/process boundary is stable, an SDK would merely freeze accidental APIs. Define it only as the first external application is moved.

## What should remain in Commonplace

### Store routing and authority

`Store.Router`, head ownership, placement, mutation serialization, retention, leases, and garbage-collection policy are the heart of the product. Individual backend mechanisms can be libraries; the authoritative topology should stay in Commonplace.

### Runtime trust enforcement

Protocol objects and context-free verification can move. Current trust roots, revocation state, code-document heuristics, read/write gates, admission decisions, and audits should remain centralized in the host.

### Dataflow and product semantics

The dataflow color model, RedLog integration, Gold policy, tree wiring, and PubSub behavior encode Commonplace semantics. They are not a generic dataflow package merely because the implementation has clear modules.

### Vertical applications

MUD, BD, chat, outline, bots, web, CLI, and MCP may eventually become separate applications. That is an application/SDK decomposition, not a vendored-library extraction. Do not force them through the library criteria.

### Small representation-specific helpers

Materialization, outline ordering, pull templates, canonical JSON/XML, and individual invariants should remain internal unless they join a coherent protocol package or acquire a real second consumer. A directory of utilities is not a library contract.

## Extraction mechanics learned from Yelixer

The Yelixer extraction established the correct standard. The [repo-extractability ruling](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-08-repo-extractability-ruling.md) requires zero executable forward references, public API consumption rather than representation coupling, self-contained tests, and a regression guard. The later [fresh-consumer proof](https://github.com/commonplace-systems/commonplace/blob/75564d7b70bc1268c41c8b4ef1881d869ef7b7e6/docs/notes/2026-08-13-cx-5kb4-yelixer-consumability-proof.md) also exposed an important Mix hazard: an umbrella app with the same name can silently satisfy a dependency and produce a false-green test.

Use the following runbook for every extraction:

1. **Write the ownership contract.** List what the library owns, what the host owns, allowed dependencies, and forbidden effects.
2. **Make the boundary true in-tree.** Prefer a temporary umbrella app or isolated Mix project with a narrow public facade.
3. **Move the proof with the code.** Tests, property suites, fixtures, conformance checks, CI, license, and documentation are part of the extraction.
4. **Add a forward-reference guard.** Executable source in the library may not reference Commonplace runtime modules or configuration.
5. **Stop representation leakage.** Host code may hold and pass library values, but should not match on private fields or fabricate internal structs.
6. **Preserve history.** Split or merge repository history through ordinary Git operations; do not require a force-push cutover.
7. **Prove the remote artifact.** In a fresh directory outside the umbrella, fetch the exact remote commit, compile, test, and execute a minimal consumer.
8. **Prove source identity.** Record the resolved dependency path and exact checkout SHA; do not accept a local path, umbrella override, or warm cache as evidence.
9. **Cut over atomically.** Remove the in-tree source and switch the dependency in the same Commonplace commit.
10. **Test the real release shapes.** Run umbrella tests plus any release, escript, NIF, and clean-build checks affected by the package.
11. **Pin intentionally.** Use a full SHA or immutable release tag in the declaration and retain the full identity in `mix.lock`.
12. **Document updates.** Assign release ownership, compatibility policy, security handling, and the process for advancing the pin.

For persisted structs or durable wire formats, add a thirteenth step: prove old bytes decode before and after the extraction.

## Sequenced implementation plan

### Phase 0 — Establish package governance

- Add a short package-boundary policy to Commonplace.
- Add a reusable source-boundary scanner and fresh-consumer script based on the Yelixer proof.
- Record the allowed dependency graph in CI.
- Require every external package to define supported Elixir/OTP versions, license, owners, and compatibility policy.
- Decide whether security-sensitive packages receive private advisories and coordinated releases.

### Phase 1 — Extract Yepochs

1. Move pure derivation-map operations behind a dedicated module.
2. Separate `Document.Diff.diff/2` from its Commonplace content-type adapter.
3. Move late-edit translation, preflight, and positional rebase modules into an isolated project.
4. Add algebraic/property tests and Yelixer compatibility fixtures.
5. Perform the remote fresh-consumer proof.
6. Atomically replace in-tree code with the pinned dependency and thin Commonplace adapters.

Exit condition: Yepochs depends on Yelixer only, and no Commonplace store or identity is visible in its API.

### Phase 2 — Extract Safe Elixir AST and Beam Flock

These are independent boundaries but should still be landed separately.

- Move the validator and adversarial corpus; leave trust/source loading in Commonplace.
- Move the NIF and strict primitive; leave fail-open behavior in a Commonplace adapter.
- Add security documentation for the validator and platform/release CI for flock.

Exit condition: the Commonplace core no longer owns the validator's security corpus or the C/NIF build.

### Phase 3 — Make protocol values effect-free

- Split envelope encoding from envelope import.
- Split certificate/value verification from store-backed chain resolution.
- Split tombstone schema/signature checks from current-authority checks.
- Inventory every persisted struct and encoding.
- Introduce versioned codecs where repository extraction alone cannot preserve compatibility.
- Add cross-version golden vectors.

Exit condition: protocol modules can compile and test without CubDB, GenServers, filesystem access, or Commonplace application configuration.

### Phase 4 — Extract Commonplace Protocol

- Preserve serialized module names initially.
- Prove old stored terms and wire fixtures decode from the external package.
- Convert pods, federation, and Git/chit adapters to consume the external contract.
- Keep storage resolution and policy in Commonplace.

Exit condition: an independent tool can parse and validate Commonplace protocol objects without booting Commonplace.

### Phase 5 — Extract CAS and History around routed storage

- Introduce the routed reader and cold/history store.
- Generalize ArtifactStore only as far as two real consumers require.
- Extract the filesystem CAS.
- Split history replay/ancestry from `Tree.DocBuilder` effects.
- Extract Commonplace History against an injected fetch interface.

Exit condition: history algorithms can run over an in-memory fixture or alternate backend, while Commonplace alone controls placement and authority.

### Phase 6 — Refactor runner and YFS behind ports

- Define an explicit sandbox/run specification and backend result.
- Isolate runner plan compilation, execution, readiness, and cleanup.
- Define document/artifact source and sink interfaces for filesystem projection.
- Prove both host and pod consumers before extracting either engine.

Exit condition: neither engine imports Store, Tree, Trust, NodeIdentity, or Workspace modules.

### Phase 7 — SDK and application repositories

- Stabilize the client/event interface.
- Extract one non-core application as the SDK's proof consumer.
- Move additional verticals only when doing so improves deployment or ownership.

## The first three concrete slices

To avoid turning the proposal into an indefinite architecture program, start with these bounded changes:

### Slice A: Yepochs boundary commit

- Create `Commonplace.Yepochs`-facing adapters in-tree.
- Move derivation-map algebra out of `Store.Namespace`.
- Remove Commonplace content-type dispatch from the pure diff/rebase path.
- Add a CI rule that the candidate source set may reference `Yelixer.*` but not other `Commonplace.*` modules.

### Slice B: Safe Elixir AST isolation commit

- Move allowlist tests and fixtures beside the allowlist.
- Replace any MUD-named test construction with profile inputs.
- Have Commonplace source/trust code call one public validation entry point.
- Add explicit documentation of the non-sandbox guarantee.

### Slice C: Strict flock adapter commit

- Define the strict generic locking API.
- Put fallback and timeout policy in a Commonplace adapter.
- Add an external-process contention test and release-path NIF test.
- Only then move the native code to its repository.

These slices create useful boundaries even if repository extraction pauses between them.

## Repository policy

Use one repository per durable package boundary, with names treated as working names until checked for ecosystem conflicts:

| Repository | Kind | Publication posture |
|---|---|---|
| `yelixer` | Generic CRDT implementation | Existing; Git pin now, Hex optional |
| `yepochs` | Yelixer epoch/rebase algebra | Git pin while API evolves |
| `safe_elixir_ast` | Generic security mechanism | Git pin; public publication only with explicit security/support policy |
| `beam_flock` | Generic native primitive | Git pin; Hex later if platform support is mature |
| `commonplace_protocol` | Commonplace protocol | Git pin; versioned compatibility required |
| `commonplace_cas_fs` | Generic storage mechanism | Create only with second consumer |
| `commonplace_history` | Commonplace/Yelixer history engine | Create after routed-reader seam |

Runner Core, YFS, and the SDK should remain candidate names, not pre-created empty repositories.

## Acceptance criteria for the decomposition

The program is successful when:

- the dependency graph is acyclic and enforced in CI;
- every package has a fresh, outside-the-umbrella consumer proof;
- no package reads Commonplace application environment or addresses Commonplace processes;
- Commonplace policy enters libraries only as explicit input data or callbacks;
- protocol and history fixtures remain compatible across pin upgrades;
- persisted values survive repository moves and any later namespace migration;
- native and security-sensitive code has package-local test ownership;
- pods, Git/chit tools, and future peers can depend on protocol/history pieces without importing the product runtime; and
- the number of repositories stays small enough that each one has a real owner and release story.

## Final recommendation

Treat Yelixer as the precedent, not as a command to extract every pure file. The best next boundary is Yepochs as a complete epoch algebra. Safe Elixir AST and Beam Flock follow because they are already coherent and isolate security or native concerns. Protocol is the most strategically important later extraction, but it needs a careful purity and durable-codec pass first. CAS, history, runner, YFS, and the SDK should be created only when their planned second consumers or effect-injection seams make the interfaces real.

The architectural rule is simple: **libraries own deterministic mechanisms and stable protocol; Commonplace owns authority, policy, placement, identity, and orchestration.**
