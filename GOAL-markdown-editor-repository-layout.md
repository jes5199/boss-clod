# Repository layout for the Commonplace Markdown editor

Status: accepted MVP ownership decision  
Date: 2026-08-24  
Applies to: the one-workspace, one-editor-Cell browser goal

## 1. Decision

The Markdown editor is an application composition root, not a primitive of `commonplace-cell` or `commonplace-doc`.

For the MVP:

> Put the working editor, editor Cell, browser attachment, and two-Cell integration in the top-level `commonplace` repository. Extract only the durable Markdown Document profile into a new `commonplace-markdown` library.

Do not create `commonplace-yjs-web`, `commonplace-editor-cell`, `commonplace-mirror-host`, or `commonplace-realm` repositories yet. Their possible abstractions should first be discovered in the working application.

## 2. Repository map

| Repository | Kind | Responsibility |
| --- | --- | --- |
| `commonplace-markdown` | reusable Elixir library | Durable `commonplace.text/markdown/v1` profile semantics |
| `commonplace` | application and composition root | Workspace/editor topology, editor Cell runtime, browser UI, mirror orchestration, and end-to-end tests |
| `commonplace-cell` | reusable protocol library | Cell identity, ownership, addresses, envelopes, admission, and adapter behaviours |
| `commonplace-doc-sync` | reusable semantic library | Generic Document fork, mirror relationship, offers, receipts, and retry |
| `commonplace-dir` / `commonplace-dir-host` | reusable libraries | Directory values, traversal, tracking, checkpoints, and copy-on-write |
| `commonplace-doc` / `commonplace-doc-host` | reusable libraries | Document semantics and one-Document live hosting |
| `commonplace-merkle-crdt` | reusable library | Generic Merkle-CRDT commit graph and Yjs content operations |
| `yelixer` | reusable library | Generic Elixir Yjs representation and operations |
| `commonplace-value` | reusable library | Portable values and Cell envelope composition |

The dependency direction is downward from `commonplace` into the libraries. No lower-level library may depend on the application repository.

## 3. Why the editor belongs in `commonplace`

The browser editor combines concerns from many levels:

- login and session lifecycle;
- Cell provisioning;
- workspace navigation;
- mirror creation and reuse;
- DocSync controller lifecycle;
- browser WebSocket attachment;
- Yjs update acknowledgement;
- Markdown editing and preview;
- user-visible `saving`, `saved`, `syncing`, and `blocked` state;
- operational diagnostics;
- an end-to-end deployment.

That combination is product behavior. It is not a stable reusable semantic layer yet.

The top-level `commonplace` repository should be the place where extracted libraries are composed into a working system. Using it as the composition root does not mean restoring the old monolith's internal coupling. The application must depend on public package APIs and contribute fixes back to the package that owns each invariant.

The desired shape is:

```text
small semantic libraries
          |
          v
top-level Commonplace application
          |
          +-- Workspace Cell
          +-- Editor Cell
          +-- browser adapter
          +-- Markdown UI
          +-- integration tests
```

## 4. `commonplace-markdown`

Proposed repository:

```text
commonplace-systems/commonplace-markdown
```

Proposed Hex package:

```text
commonplace_markdown
```

### 4.1 What it owns

`commonplace-markdown` owns the durable, runtime-independent meaning of:

```text
commonplace.text/markdown/v1
```

The profile defines:

- an ordinary Commonplace Document profile specialization;
- one canonical Yjs `Y.Text` shared type;
- the canonical shared-type name `content` when a name is required;
- UTF-8 Markdown as the selected textual value;
- empty-document construction;
- profile validation;
- extraction of Markdown source from materialized selected content;
- construction of generic Y.Text edits through lower-level APIs;
- language-neutral profile fixtures;
- interoperability tests between Elixir materialization and browser Yjs.

Representative API:

```elixir
Commonplace.Markdown.profile/0
Commonplace.Markdown.new_content/0
Commonplace.Markdown.validate/1
Commonplace.Markdown.text/1
Commonplace.Markdown.edit/3
```

Exact names may change. Operations must delegate generic Yjs behavior to `commonplace-merkle-crdt` and `yelixer` rather than implement another Y.Text engine.

### 4.2 What it does not own

`commonplace-markdown` does not own:

- DocHosts;
- Cell identities or routing;
- mirror creation;
- DocSync relationships;
- browser sessions;
- WebSockets;
- the Yjs sync wire protocol;
- CodeMirror;
- Markdown rendering UI;
- HTML sanitization policy;
- login permissions;
- saving or synchronization status;
- Realm placement;
- product navigation.

It must remain usable by a CLI, agent, test harness, server, or future non-browser editor.

### 4.3 Dependency direction

The intended dependency shape is:

```text
yelixer
   |
commonplace-merkle-crdt
   |
commonplace-doc
   |
commonplace-markdown
```

The actual package may depend on the narrowest stable APIs sufficient to declare and validate the profile. It must not depend on `commonplace`, `commonplace-cell`, `commonplace-doc-host`, Phoenix, Plug, or JavaScript tooling.

## 5. Top-level `commonplace` application

The `commonplace` repository owns the first actual application of the package stack.

For the Markdown editor goal, it owns four application areas:

```text
commonplace
├── Workspace Cell runtime
├── Editor Cell runtime
├── browser attachment and UI
└── integration and deployment
```

### 5.1 Workspace Cell runtime

The application owns the concrete configuration and supervision that make the demo workspace Cell live:

- Workspace Cell descriptor;
- root Directory provisioning;
- seeded Markdown Documents;
- local Cell registration;
- DocHost and DirHost activation;
- development authorization policy;
- resource adapters connecting Cell verbs to DocHost and DirHost operations.

The application does not redefine Document, Directory, or Cell semantics. It uses the relevant libraries.

### 5.2 Editor Cell runtime

The application owns the BEAM realization of the editor Cell:

- editor Cell descriptor provisioning;
- one editor Cell per configured active login in the eventual topology;
- editor-owned root Directory;
- mirror lookup, creation, and reuse;
- DocSync relationship controller supervision;
- browser-session attachment;
- editor-specific status aggregation;
- restart and recovery orchestration.

The first MVP may provision exactly one login and one editor Cell.

### 5.3 Browser attachment

The application initially owns the Yjs browser attachment:

- authenticated WebSocket lifecycle;
- mirror snapshot-and-watch attachment;
- Yjs state-vector exchange;
- inbound update framing and limits;
- stable browser-update operation IDs;
- durable-before-acknowledgement behavior;
- reconnect and resynchronization;
- ephemeral awareness;
- conversion between browser messages and ordinary mirror DocHost commands.

This adapter is intentionally kept close to the product until another content profile proves which pieces are generic.

### 5.4 Browser UI

The application owns:

- workspace tree navigation;
- CodeMirror or another Markdown source editor;
- browser-side Y.Doc construction;
- Y.Text editor binding;
- optional Markdown preview;
- connection and authorization errors;
- `local`, `saving`, `saved`, `syncing`, `synced`, and `blocked` state;
- development identity diagnostics.

No lower Elixir library should learn about DOM state, browser components, CSS, CodeMirror, or product navigation.

### 5.5 Integration and deployment

The application owns:

- booting both Cells in one BEAM Realm;
- application configuration and development secrets;
- HTTP and WebSocket endpoints;
- storage adapter selection;
- supervision order;
- seed data;
- the complete browser-to-canonical acceptance test;
- release configuration and deployment.

## 6. Suggested source layout

The exact build layout may follow the existing repository, but the conceptual boundaries should be visible in source.

A non-umbrella layout could look like:

```text
commonplace/
├── lib/commonplace/application.ex
├── lib/commonplace/workspace_cell/
│   ├── supervisor.ex
│   ├── provisioner.ex
│   └── resource_adapters.ex
├── lib/commonplace/editor_cell/
│   ├── supervisor.ex
│   ├── provisioner.ex
│   ├── mirror_registry.ex
│   ├── mirror_controller.ex
│   └── session_authorizer.ex
├── lib/commonplace/web/
│   ├── router.ex
│   ├── yjs_socket.ex
│   └── session.ex
├── assets/
│   ├── src/editor/
│   ├── src/workspace_tree/
│   └── src/sync_status/
├── test/integration/
│   └── markdown_editor_goal_test.exs
└── test/browser/
    └── markdown_editor.spec.ts
```

If `commonplace` is or becomes an Elixir umbrella, the same concepts may be expressed as child applications:

```text
commonplace/apps/
├── commonplace_runtime/
├── commonplace_web/
└── commonplace_demo/
```

The umbrella form is optional. Repository structure must not become part of the Cell protocol.

## 7. The editor Cell and OTP

In the BEAM implementation, the editor Cell should have one identifiable OTP supervision subtree. It may be packaged as an OTP application when that improves configuration, startup, supervision, or release composition.

However:

> A Cell is not universally defined as an OTP application.

The portable Cell concept also needs to admit WASM, browser, JVM, ESP32, and other realizations. OTP is the natural implementation substrate for a Cell hosted in a BEAM Realm, not the definition of Cell identity.

The important BEAM invariant is:

- one editor Cell has one supervised runtime root;
- every owned DocHost and DirHost is attributable to that Cell;
- stopping the subtree stops the Cell's active processes;
- restarting it reconstructs state from durable logs and relationships;
- the Cell remains within one Realm.

## 8. Responsibilities that remain in existing libraries

### 8.1 `commonplace-cell`

It owns:

- Cell descriptors;
- `home_cell_id` semantics;
- logical addresses;
- portable request and response envelopes;
- admission ordering;
- authorizer and resource-adapter behaviours;
- the Realm boundary definition.

It must not gain:

- `MarkdownEditor` types;
- browser sessions;
- CodeMirror concepts;
- mirror UI state;
- product-specific login rules.

### 8.2 `commonplace-doc-sync`

It owns generic Document relationships:

- exact commit-preserving fork;
- lineage;
- merge bases;
- offers and receipts;
- guarded destination admission;
- interruption-safe retry.

It must not gain:

- “open file” workflows;
- browser attachment;
- Markdown interpretation;
- editor Cell provisioning;
- UI status strings.

The application translates generic relationship state into `syncing`, `synced`, or `blocked` UI.

### 8.3 `commonplace-doc-host`

It owns one Document writer path, reads, commands, watches, and restart replay.

It must not know whether its caller is a browser editor, mirror controller, workspace, or agent.

### 8.4 `commonplace-dir-host`

It owns path traversal, tracking overlays, checkpoints, and copy-on-write coordination.

It must not own workspace-tree components or browser navigation state.

### 8.5 `commonplace-merkle-crdt` and `yelixer`

They own generic Yjs semantics, including Y.Text support. They must not acquire Markdown parsing, HTML rendering, CodeMirror bindings, or Cell routing.

### 8.6 `commonplace-value`

It owns inert portable values and efficient checked composition. It must not define Cell request fields, browser payloads, Markdown values, or Yjs binary framing.

## 9. Where new code goes

Use this routing table during implementation:

| New behavior | Repository now |
| --- | --- |
| Validate `commonplace.text/markdown/v1` | `commonplace-markdown` |
| Create or extract the profile's Y.Text content | `commonplace-markdown` |
| Implement a missing generic Y.Text operation | `yelixer` or `commonplace-merkle-crdt` |
| Add immutable Document home-Cell support | `commonplace-doc` |
| Fork one exact Document into a child | `commonplace-doc-sync` |
| Define a portable Cell request | `commonplace-cell` |
| Start and supervise the editor Cell | `commonplace` |
| Decide which mirror corresponds to an opened canonical Document | `commonplace` |
| Run and restart a mirror controller | `commonplace` |
| Attach a browser Y.Doc to a mirror | `commonplace` |
| Speak WebSocket or browser Yjs protocol | `commonplace` |
| Display and edit Markdown | `commonplace` |
| Render a preview | `commonplace` |
| Display save and sync status | `commonplace` |
| Prove the full keystroke-to-canonical scenario | `commonplace` |

When application work exposes a genuinely generic defect, fix it in the owning library and keep only integration code in `commonplace`.

## 10. Testing ownership

### 10.1 `commonplace-markdown`

Tests cover:

- profile declaration and validation;
- empty and non-empty Y.Text content;
- UTF-8 Markdown extraction;
- exact selected-head materialization;
- browser/Elixir Yjs interoperability fixtures;
- rejection of the wrong shared type or root name;
- absence of browser, Cell, and host dependencies.

### 10.2 Existing libraries

Each existing package retains its own semantic and conformance tests. The editor should not reproduce those suites in application code.

### 10.3 `commonplace`

Application tests cover:

- both Cells booting in one Realm;
- editor Cell provisioning and reuse;
- authorized workspace listing;
- mirror provisioning and recovery;
- browser Yjs attachment;
- durable mirror update acknowledgement;
- mirror-to-canonical sync;
- Directory checkpoint advancement;
- UI status progression;
- browser reconnect;
- full Realm restart;
- the goal document's negative authorization and conflict cases.

The end-to-end test belongs here because no lower package can see the complete system.

## 11. Why not create more repositories now

### 11.1 No `commonplace-yjs-web` yet

The first adapter has one content profile, one editor, and one server implementation. Its apparently generic behavior may still hide Markdown-, CodeMirror-, Phoenix-, or deployment-specific assumptions.

Keep it in `commonplace` until a second consumer needs the same protocol.

### 11.2 No `commonplace-editor-cell` yet

The first editor Cell controller is entangled with login provisioning, mirror reuse, status projection, and application lifecycle. Extracting it before another editor exists would freeze guesses into an API.

### 11.3 No `commonplace-mirror-host` yet

`commonplace-doc-sync` already owns generic relationship semantics. The remaining host loop is initially a small application controller around watches and durable relationship state.

Extract only when multiple applications repeat that runtime loop.

### 11.4 No `commonplace-realm` yet

The first Realm is an operational fact of the OTP application. A Registry-backed local Cell router and one supervision tree are sufficient.

A Realm package becomes justified when there are multiple transports, placement strategies, or hosting applications to generalize.

## 12. Extraction criteria

Extraction should follow measured reuse or independent lifecycle, not merely the ability to name a concept.

### 12.1 Extract `commonplace-yjs-web` when

At least one of the following is true:

- a second content profile uses the same browser attachment protocol;
- a second application needs the same durable-before-ack Yjs adapter;
- the adapter needs independent version negotiation or conformance fixtures;
- it can be tested without booting the Commonplace product application;
- its release cadence or security boundary becomes independent.

The extracted package would own browser attachment protocol semantics, not UI components.

### 12.2 Extract `commonplace-editor-cell` when

- Markdown and another editor type share provisioning and mirror lifecycle;
- more than one product hosts editor Cells;
- one-login-per-Cell policy becomes configurable and reusable;
- the controller has a stable API independent of web sessions;
- it can operate through Cell, DocHost, DirHost, and DocSync behaviours without application imports.

### 12.3 Extract a Markdown UI package when

- the editor is embedded in a second frontend;
- browser components have their own stable public API;
- preview, commands, and extensions need independent releases;
- the package can avoid importing server topology and Cell orchestration.

### 12.4 Extract `commonplace-cell-host` when

- both workspace and editor Cell runtimes repeat the same activation, registration, ownership, and adapter machinery;
- another BEAM application needs to host Cells;
- the host contract can be stated without Markdown, login, or browser concepts;
- the extracted runtime remains one-Cell-per-supervision-root and one-Realm-per-runtime-placement.

## 13. Dependency rules

The following imports are allowed conceptually:

```text
commonplace
    ├──→ commonplace-markdown
    ├──→ commonplace-cell
    ├──→ commonplace-dir-host
    ├──→ commonplace-doc-sync
    ├──→ commonplace-doc-host
    └──→ lower semantic libraries

commonplace-markdown
    ├──→ commonplace-doc
    └──→ commonplace-merkle-crdt / yelixer
```

The following directions are forbidden:

```text
commonplace-cell        → commonplace
commonplace-doc-sync    → commonplace
commonplace-doc-host    → commonplace-markdown-editor UI
commonplace-markdown    → commonplace web/session modules
commonplace-merkle-crdt → Markdown parser or renderer
```

Application callbacks may implement behaviours declared by lower packages. Lower packages must not call back into application modules by hard-coded name.

## 14. Migration discipline for the top-level repository

Using `commonplace` as the composition root must not make it the source of duplicate implementations.

Rules:

1. Depend on released or pinned package APIs.
2. Do not copy reducer, JCS, Document, Directory, sync, or Cell logic into the application.
3. If a package lacks a required generic operation, add it to that package with its own tests.
4. Keep product policy, UI, session state, and concrete supervision in the application.
5. Keep cross-package integration tests in the application.
6. Avoid reaching into package-private structs or storage tables.
7. Record temporary adapters clearly and remove them when the owning package gains the required public interface.
8. Treat the old monolith as an integration and design source, not as an alternative source of protocol truth.

## 15. Implementation order

1. Create `commonplace-markdown` with the profile and browser interoperability fixture.
2. Make `commonplace-doc` support immutable `home_cell_id` if it does not already.
3. Land the minimum Cell and Cell-host integration needed to run two supervised Cells.
4. Seed the workspace Cell and list its Directory through Cell routing.
5. Add editor Cell provisioning and mirror reuse in `commonplace`.
6. Integrate exact fork and the one-way DocSync relationship.
7. Build the Yjs browser attachment in `commonplace`.
8. Add the Markdown UI and explicit save/sync status.
9. Complete restart, conflict, and authorization tests.
10. Review the application code for abstractions that now have a second concrete consumer.

The last step is when further extraction decisions should be made.

## 16. Final ownership rule

Use this test when placement is unclear:

> Would this code still make sense if the UI were not Markdown, the client were not a browser, or the runtime were not the Commonplace product application?

- If it defines the durable meaning of a Markdown Document, it belongs in `commonplace-markdown`.
- If it defines generic Document, Directory, sync, Cell, or value semantics, it belongs in the corresponding existing library.
- If it provisions the editor, connects the browser, presents UI state, or composes the two-Cell product, it belongs in `commonplace` for the MVP.

This layout gives the small libraries a real consumer without forcing the first working application to predict every future abstraction in advance.
