# Commonplace verbs and Biscuit authorization

**Status:** Proposed 0.1 cross-package specification  
**Date:** 2026-08-26  
**Applies to:** `commonplace-cell`, `commonplace-doc`, Cell hosts, resource adapters, and a future mounted-verb executor  
**Credential format:** Eclipse Biscuit 3.3, Ed25519 profile

## 1. Purpose

This specification defines what a **verb** means in Commonplace and how a Cell uses **Biscuit capabilities** to authorize verb invocations.

Its central distinction is:

> A verb names requested behavior. A capability authorizes an operation. A command proposes state change. An event records state change that was admitted.

The complete path is:

```text
Cell request
  target + verb + arguments + proofs
                  |
                  v
        resolve verb contract
                  |
                  v
       authorize required actions
                  |
                  v
       adapter or mounted handler
          |                 |
          |                 +--> portable reply
          |
          +--> proposed self-commands or future outbound requests
                              |
                              v
                    ordinary target admission
                              |
                              v
                     canonical log events
                              |
                              v
                          reducers
```

This document deliberately does not make a verb synonymous with handler code, a BEAM message, a permission string, a Document command, or a log event.

## 2. Normative language

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative.

## 3. Scope

Version 0.1 specifies:

- the Commonplace verb model;
- built-in and mounted verbs;
- verb contracts and immutable invocation plans;
- the distinction between verbs and authorization actions;
- a Commonplace profile for Biscuit 3.3 tokens;
- target-owned authorization against Cell, resource, action, source Cell, time, and current policy;
- exact-action attenuation;
- mounted-verb invocation admission;
- effect authority and outbound-message rules;
- retry, revocation, audit, and Realm-boundary requirements;
- package ownership and conformance requirements.

Version 0.1 does not specify:

- human login or account recovery;
- a global authorization server;
- hostile-code containment inside one Realm;
- Assembly policy language;
- endowed or setuid-like mounted verbs;
- durable subscriptions;
- Directory subtree grant syntax;
- acceptance of third-party Biscuit blocks or external functions;
- multi-writer Document admission;
- a general workflow or transaction language;
- an Elixir implementation of Biscuit cryptography.

This specification does not require a new repository. A small Biscuit adapter may later merit extraction, but the protocol boundaries must settle before repository ownership does.

## 4. Vocabulary

### 4.1 Verb

A stable, target-relative protocol name for an operation that a resource agrees to interpret.

Examples:

```text
cell.describe
directory.list
document.read.content
document.sync.offer
document.invoke.render
```

### 4.2 Local mounted-verb name

The name of a slot in a Document's `verbs` projection, such as `render`.

The corresponding Cell verb is `document.invoke.` followed by that local name.

### 4.3 Request

One portable message asking a target Cell to perform one verb against one resource. A request carries arguments, proofs, request identity, and causal metadata.

### 4.4 Invocation

One admitted attempt to execute the operation named by a verb. A request becomes an invocation only after the target has resolved a verb contract and authorized its required actions.

### 4.5 Verb contract

An immutable, portable description of a verb's input, output, authority requirements, acknowledgement point, and retry semantics.

### 4.6 Handler

The implementation selected for a verb. A built-in handler is supplied by trusted adapter code. A mounted handler is selected by a versioned Document mount and pins exact code content.

### 4.7 Action

A stable authorization predicate checked by a target Cell.

In version 0.1, trusted admission adds a base action whose string exactly equals the wire verb. The two remain different concepts, and one verb may require several additional actions.

### 4.8 Command

A typed intention submitted to a state-owning host, such as `ApplySemanticEdit`, `SelectHead`, or `MountVerb`.

### 4.9 Event

A canonical, durable fact appended after a command has passed admission. Reducers project events into state.

### 4.10 Biscuit

A signed bearer capability token whose authority block grants rights and whose appended blocks can attenuate the token by adding restrictions.

### 4.11 Delivery context

Target-trusted facts established by the router or gateway, including the authenticated source Cell and whether a Realm boundary was crossed. Request fields do not create delivery context.

### 4.12 Authority context

An opaque Realm-local result of successful target authorization. It is not a raw Biscuit and has no portable representation.

## 5. Core invariants

1. A verb is meaningful only relative to a target resource interface.
2. A verb name is not authority.
3. A Cell address is not authority.
4. A Directory reference is not authority.
5. Same-Realm placement is not authority.
6. Transport authentication is not operation authority.
7. A message is not a log event.
8. A handler result is not an already authorized command or event.
9. Authorization occurs before protected resource disclosure, execution, or persistence.
10. Every durable effect passes the admission path owned by the resource receiving that effect.
11. Permission to mount a verb, permission to invoke it, permission to inspect its source, and authority available during execution are separate.
12. A mounted handler is pinned to exact code content before execution begins.
13. Raw Biscuit tokens are not persisted in Documents, Directories, ordinary logs, receipts, or audit records.
14. Current target policy may deny a cryptographically valid Biscuit.
15. Same-Realm and cross-Realm delivery have equal logical authorization semantics.
16. Exact action grants are the version 0.1 default.
17. No wildcard grant silently acquires authority over a verb introduced later.
18. A fork creates no capability by itself and copies no live Biscuit.
19. The executor API intentionally supplies handler code with no ambient Cell root, storage handle, PID, signing key, or raw capability token. Same-Realm Elixir code is nevertheless cooperative, not hostile-code isolated.
20. Reducer replay never performs authorization or executes a verb.

## 6. The verb model

### 6.1 Verb identity

The spelling of a verb is not its whole semantic identity. The effective identity is:

```text
resource interface + verb name + contract identity
```

Two resources may interpret the same verb name differently only when they declare different interfaces or contracts.

### 6.2 Wire names

Cell verb names retain the `commonplace-cell` grammar:

- valid UTF-8;
- 1 through 255 bytes;
- lowercase ASCII letters, digits, `.`, `_`, and `-`;
- beginning with a lowercase ASCII letter;
- no empty dot-separated component.

The first component SHOULD identify the target resource family:

```text
cell.*
directory.*
document.*
subscription.*
```

The dot hierarchy is naming structure. It does not imply authorization inheritance.

In particular, authority over `document.sync` does not authorize `document.sync.offer` unless an explicit policy says so.

### 6.3 Built-in verbs

A built-in verb is declared by a trusted resource adapter or interface implementation.

Examples include:

```text
document.read.content
document.read.attributes
document.read.history
document.read.verbs
document.sync.summary
document.sync.export
document.sync.offer
directory.list
directory.resolve
```

A request MUST NOT select an Elixir module, function, adapter, or handler implementation. Trusted host configuration selects the resource adapter; the adapter resolves the verb.

### 6.4 Mounted verbs

A mounted verb occupies one local name in a Document's `verbs` projection.

Version 0.1 local names MUST:

- match `[a-z][a-z0-9_-]*`;
- be no longer than 64 bytes;
- contain no dot.

For local name `render`, the public Cell verb is:

```text
document.invoke.render
```

The local-name restriction prevents a mount from manufacturing another protocol namespace.

### 6.5 Effective interface

A Document's effective interface is the union of:

- the built-in Document verbs supplied by its adapter; and
- the mounted verbs effective at the selected Document coordinate.

Mounted names live only beneath `document.invoke.*`, so they cannot replace built-in Document verbs.

Enumerating an effective interface is itself an authorized read. `document.read.verbs` authorizes the effective mount descriptions but not the source content of their code Documents.

### 6.6 Not every BEAM message is a verb

Private OTP messages, supervision signals, monitor notifications, watch invalidations, and implementation callbacks are not automatically Commonplace verbs.

A message has Commonplace verb semantics only when it enters the stable Cell request or invocation protocol.

Same-Realm routing MAY avoid physical serialization. It MUST preserve the same target, verb, arguments, proofs, source binding, admission, result, and error semantics as cross-Realm delivery.

## 7. Verb contracts

### 7.1 Required contract value

Every externally invokable verb MUST resolve to an immutable contract equivalent to:

```elixir
%Commonplace.Cell.VerbContract{
  contract_id: String.t(),
  interface: String.t(),
  interface_version: pos_integer(),
  verb: String.t(),
  schema_format: String.t(),
  input_schema: Commonplace.Value.t(),
  output_schema: Commonplace.Value.t(),
  required_caller_authority: [Commonplace.Cell.ActionRequirement.t()],
  effect_class: :read | :command | :outbound | :mixed,
  allowed_effects: [Commonplace.Cell.EffectDeclaration.t()],
  idempotency: :safe | :idempotent | :non_idempotent,
  acknowledgement: :computed | :durably_applied | :accepted,
  extensions: Commonplace.Value.t()
}
```

Concrete module and field names may change. The semantic fields above are normative.

`schema_format` selects a host-supported, deterministic schema dialect. The request or mount may name a format but may not select an Elixir validator module. An unknown format makes the contract invalid. The exact first schema dialect is a Phase 0 dependency of this specification; until it is frozen, a mounted-verb executor is not conformant.

Input validation occurs before handler dispatch. A handler reply MUST be bounded, validated as `Commonplace.Value`, and validated against `output_schema` before disclosure. `effect_class` is enforceable: the executor MUST expose no effect operation outside the class declared by the contract.

An effect declaration is contract-bearing data equivalent to:

```elixir
%Commonplace.Cell.EffectDeclaration{
  name: String.t(),
  kind: :command_self,
  command_profile: String.t(),
  command_type: String.t(),
  min_count: non_neg_integer(),
  max_count: pos_integer()
}
```

Version 0.1 supports only `:command_self` declarations. `effect_class` is a coarse summary; `allowed_effects` is the exact maximum surface. `min_count` MUST be no greater than `max_count`.

The trusted destination adapter owns an immutable mapping from `(command_profile, command_type)` to target semantics, canonical required action, and authoritative command schema. A profile ID changes when that mapping changes. The mount cannot supply or relabel the action. If `min_count > 0`, the adapter-derived action MUST also appear in `required_caller_authority`; an effect with `min_count == 0` may be authorized only when proposed.

A `:computed` contract has no durable `allowed_effects`. A `:durably_applied` contract reaches acknowledgement only after the handler has completed, every declared minimum has been met, and durable receipts exist for every emitted effect.

Effect names are unique within the contract, match `[a-z][a-z0-9_-]*`, and are no longer than 64 bytes.

### 7.2 Contract identity

`contract_id` MUST be a domain-separated SHA-256 hash of the canonical portable contract, excluding the `contract_id` field itself and excluding implementation identity. Its textual form is `sha256:` followed by lowercase hexadecimal digest bytes.

Changing any of these requires a new `contract_id`:

- input schema;
- output schema;
- schema format;
- required caller authority;
- effect class;
- allowed effects;
- acknowledgement semantics;
- idempotency semantics;
- any key in contract `extensions`.

All version 0.1 contract extensions are contract-bearing. Non-semantic display or implementation metadata lives outside `contract_value`; there is no caller-selected “not part of the hash” flag.

A compatible code implementation may change without changing the contract. A semantic change may not retain the old contract ID merely for convenience.

### 7.3 Action requirements

An action requirement is structured data, not an unscoped string:

```elixir
%Commonplace.Cell.ActionRequirement{
  target: :self | Commonplace.Cell.Address.t(),
  action: String.t(),
  constraints: Commonplace.Value.t()
}
```

For version 0.1, `target` MUST be `:self`. A foreign-resource operation is an outbound effect and is authorized by the foreign destination, not a caller precondition that the current Cell pretends to settle.

`constraints` uses a closed vocabulary declared by the verb contract and schema format. Unknown keys are rejected. Constraints are canonical portable data and may narrow a target-version mode or normalized argument facts; they may not name policy code or a validator.

Contract-contained requirements MUST NOT contain their own literal `contract_id` or `mount_id`: either would create a hash cycle. Contract pinning belongs in the capability and invocation precondition; mount pinning belongs in the invocation precondition or an attenuation check.

The existing `VerbMount.required_actions :: [String.t()]` field is interpreted as `target: :self` during migration and SHOULD be replaced by a structured field named `required_caller_authority` or equivalent.

For every public version 0.1 verb, the trusted adapter independently requires a **base action exactly equal to the wire verb**. Mounted `required_caller_authority` entries are additional conjunctive requirements. Mount data cannot remove or replace the base action.

### 7.4 Contract pinning in capabilities

A version 0.1 capability for a mounted invocation MUST authorize both the exact action and the exact `contract_id`. This lets a compatible implementation change retain a contract while preventing an old grant from silently accepting changed input, output, authority, effect, retry, or acknowledgement semantics.

An action-only grant for a moving mounted slot is deferred. If introduced later, it must be visibly broader than a contract grant and must state that target policy may replace the slot's contract.

### 7.5 Argument normalization

Each contract MUST define how portable request arguments are validated and normalized.

Security-relevant values derived from arguments—such as a destination Document, requested path, callback address, exact version, mount contract, or output channel—MUST become trusted authorizer facts.

A caller cannot authorize itself by placing facts in `arguments`.

For a mounted invocation, version 0.1 token checks may refer only to the Stage A fact vocabulary: authenticated source, exact target Cell and resource, outer operation, receiver time, request ID, expected contract, expected mount, and expected target version. Contract-specific normalized predicates that require protected mount or state knowledge are Stage B policy inputs, not legal 0.1 token caveats. A later version may expose additional typed precondition claims, but Stage B must always recompute and compare them.

## 8. Mounted handler descriptions

### 8.1 Durable mount

A mounted handler description MUST contain at least:

```elixir
%Commonplace.Doc.VerbMount{
  name: String.t(),
  contract_value: Commonplace.Value.t(),
  code_document_id: document_id(),
  code_commit_id: commit_id(),
  runtime: String.t(),
  entrypoint: String.t(),
  extensions: Commonplace.Value.t()
}
```

`contract_value` is the portable `commonplace.verb-contract/v1` representation of every field in section 7, including `contract_id`, schema format, schemas, effect class, retry semantics, acknowledgement, and structured caller requirements. Keeping it as a value prevents `commonplace-doc` from depending on `commonplace-cell` runtime structs. The Cell host validates and normalizes it into `Commonplace.Cell.VerbContract` during admission.

The current separate `input_schema`, `output_schema`, and string `required_actions` mount fields migrate into `contract_value`. If denormalized compatibility fields remain temporarily, admission MUST reject any disagreement with the canonical contract value.

`code_commit_id` is the proposed replacement for the current misleading field name `code_head`. It names an exact immutable code commit, not the mutable selected head of the code Document.

In version 0.1, `code_document_id` names a Document in the same Cell as the mounted Document; the owning Cell is implicit. This preserves the `commonplace-doc` layering. Cross-Cell code references require a portable resource-reference layer plus separately authorized retrieval and are deferred.

### 8.2 Mount identity

The composing layer SHOULD derive two identities:

```text
mount_descriptor_id = sha256(descriptor_domain || canonical mount description)
mount_id = sha256(activation_domain || mount_descriptor_id || mount_operation_id)
```

`mount_operation_id` is the durable identity of that mount activation. Repeating the same description after an unmount therefore retains its descriptor ID but gets a new mount ID.

Neither ID is a root of authority. A mounted invocation MUST carry `expected_contract_id` and SHOULD carry `expected_mount_id`; a mismatch is refused before execution without disclosing the replacement mount.

### 8.3 Durable history

Mount and unmount operations remain events in the target Document log. The `verbs` reducer computes the effective map at a log prefix.

Historical materialization MUST recover the exact mount map effective at that Document version.

### 8.4 Runtime representation

The durable verbs projection uses portable maps. `commonplace-doc` MUST normalize one durable mount map into a `VerbMount` value while leaving `contract_value` portable and semantically opaque.

The composing Document host—not `commonplace-doc`—validates the contract and plans invocation from the authoritative composed Document representation. Tests that supply a `%VerbMount{}` directly are not sufficient integration evidence.

### 8.5 Definition, mounting, and execution provenance

Mount authority does not establish that code is safe to execute.

Before loading mounted code, an executor MUST separately verify:

- the exact code Document and content commit;
- the expected content hash;
- the runtime profile;
- whatever authorship, review, signature, or allowlist policy the runtime requires.

Code-provenance policy is target-side current policy. It is not supplied by the caller and is not replaced by a Biscuit granting `document.mount.verb`.

Code materialization is a trusted host operation under executor policy. It may read the pinned same-Cell code commit without granting that read authority to the caller or handler and without disclosing source content in the response. A caller who asks to inspect source still needs ordinary read authority on the code Document.

### 8.6 Mount admission invariants

Before admitting a `MountVerb` command, the composing Document host MUST use the `commonplace-cell` contract codec to prove:

- `contract_value` has the supported format and version;
- recomputing the contract hash yields its stated `contract_id`;
- contract `verb` equals `document.invoke.<mount.name>`;
- the interface and interface version are supported by the Document adapter;
- every version 0.1 caller requirement targets `:self`;
- schema format, effect class, every allowed-effect declaration, retry semantics, and acknowledgement are supported;
- each effect's command profile and type resolve through the trusted adapter to self-target semantics, a canonical action, and a canonical schema;
- every promised effect's adapter-derived action appears in `required_caller_authority`;
- no contract field conflicts with the mount or trusted host policy.

The reducer remains deterministic when replaying older invalid data, but such a mount is never executable. Cross-projection validity belongs to the composing host because neither isolated projection can prove it.

## 9. Requests, invocations, commands, and events

### 9.1 Request shape

The existing Cell request remains the portable envelope:

```elixir
%Commonplace.Cell.Request{
  format: "commonplace.cell.request/v1",
  request_id: request_id,
  source_cell_id: source_cell_id,
  target: address,
  verb: verb,
  arguments: Commonplace.Value.t(),
  proofs: [Commonplace.Value.t()],
  correlation_id: request_id | nil,
  causation_id: request_id | nil,
  extensions: Commonplace.Value.t()
}
```

For `document.invoke.<local-name>`, `arguments` has an outer shape equivalent to:

```elixir
%{
  "expected_contract_id" => contract_id,
  "expected_mount_id" => mount_id | nil,
  "expected_target_version" => version_ref_hash | nil,
  "input" => Commonplace.Value.t()
}
```

`expected_contract_id` is mandatory. It lets Stage A authorize a contract-pinned capability without first exposing the protected mount. The value is only a caller claim until Stage B resolves the current mount and proves exact equality. `expected_mount_id` and `expected_target_version` are optional optimistic-concurrency preconditions and become mandatory when a token constrains the mount or target version.

### 9.2 Invocation plan

After resolution and authorization, a mounted verb produces an immutable plan equivalent to:

```elixir
%Commonplace.DocHost.InvocationPlan{
  invocation_id: request_id,
  target_document_id: document_id,
  target_version: Commonplace.Doc.VersionRef.t(),
  verb: "document.invoke.render",
  local_name: "render",
  contract_id: contract_id,
  contract: Commonplace.Cell.VerbContract.t(),
  mount_id: mount_id,
  handler: Commonplace.Doc.VerbMount.t(),
  input: Commonplace.Value.t()
}
```

This is a composed host plan. It pins the Document state plus the code Document and `code_commit_id` through `handler`, but it does not claim that code has been materialized or provenance-approved. The executor adds a verified content hash to a later Realm-local execution plan.

The host binds the plan to a Realm-local authority context in a separate dispatch envelope. The invocation plan MUST contain no raw Biscuit, authority context, private key, PID, or mutable selected-head reference.

### 9.3 Command/event separation

The following mappings are all legal:

```text
several verbs  -> one command
one verb       -> several commands
one command    -> several events
one read verb  -> no events
one event      -> replay or sync without a new external invocation
```

No authorization rule may infer the original verb solely from an event shape.

### 9.4 No raw append verb

Version 0.1 MUST NOT expose a general `log.append` or `document.append_event` verb to application callers.

Durable state changes use typed commands owned by the receiving resource profile. Sync import is a separate protocol whose destination validates the offered semantic history.

### 9.5 Invocation audit

An invocation MAY emit a separate audit record. An audit record is not automatically part of target Document content history and does not prove the invocation's effects succeeded.

## 10. Authorization action vocabulary

### 10.1 General rule

Resource adapters and verb contracts map one wire verb to one or more required actions.

For every public version 0.1 verb, trusted admission adds a base action exactly equal to the wire verb. Contract-declared requirements are additional. No compatibility adapter may weaken or rename the base action inside authorization.

### 10.2 Document actions

The initial stable Document action vocabulary is:

```text
document.read.content
document.read.attributes
document.read.history
document.read.verbs
document.write.content
document.select.head
document.write.attributes
document.create-fork
document.mount.verb
document.unmount.verb
document.invoke.<local-name>
document.sync.summary
document.sync.export
document.sync.offer
```

`document.select.head` remains distinct from ordinary attribute writes and from admitting a content commit.

`document.select.head` is the canonical replacement for the legacy `document.select.content-head`. Production authorization does not treat the strings as aliases: migration updates callers and reissues grants. A temporary compatibility adapter may translate the old request before authorization only in an explicitly versioned development migration mode.

`document.create-fork` remains the built-in verb and base action for asking a host to create a new Document lineage from an admitted source coordinate. A contract may additionally require source-history read authority. Authority over the source does not automatically authorize later operations on the new Document.

### 10.3 Mount and invoke separation

`document.mount.verb` does not imply:

- `document.invoke.<name>`;
- permission to read the code Document;
- permission to execute arbitrary code;
- permission to unmount the verb;
- authority for any effect the verb proposes.

`document.invoke.<name>` does not imply:

- mount or unmount authority;
- source inspection;
- Document history access;
- acceptance of handler-proposed writes;
- authority over outbound targets.

Commonplace therefore has no generic Unix-like `execute` bit. To “execute a Document” means to invoke one named mounted verb under its exact contract and current target policy. Authority over `document.invoke.render` says nothing about `document.invoke.publish`.

### 10.4 Exact actions by default

Version 0.1 production Biscuits MUST grant exact actions.

The development-only `document.*` and `document.invoke.*` pattern behavior in `DevScoped` MUST NOT be treated as the production Biscuit policy.

If a later version introduces action sets, each set MUST have an immutable manifest identity. A grant to that set must state whether later manifest versions are included.

## 11. Commonplace Biscuit profile

### 11.1 Version and algorithms

Production version 0.1 MUST use the stable Biscuit 3.3 format.

The Commonplace 0.1 cryptographic profile accepts Ed25519 root and block keys. Other Biscuit 3.3 algorithms are deferred until a conformance suite is added.

Biscuit version 1 tokens MUST NOT be accepted.

The accepted Biscuit Datalog block-version range is `3..6` inclusive, corresponding to Biscuit v3.0 through v3.3. Older or newer block versions are rejected. Acceptance of a block version does not enable third-party blocks or external functions forbidden elsewhere in this profile.

### 11.2 Portable proof wrapper

A Biscuit carried in `Request.proofs` has this portable form:

```json
{
  "format": "commonplace.biscuit/v1",
  "token": "BASE64URL_WITHOUT_PADDING"
}
```

Rules:

1. The decoded token MUST contain a Biscuit `root_key_id`.
2. `root_key_id` is only a lookup hint. The target trust store maps it unambiguously to exactly one allowed root public key.
3. The token value MUST use canonical unpadded Base64url.
4. Unknown wrapper keys are rejected unless namespaced through a future version.
5. A malformed proof rejects the request; it is not ignored in favor of another proof.
6. Raw binary tokens do not appear directly in `Commonplace.Value`.

After signature verification, issuer identity, jurisdiction policy, revocation namespace, and audit identity bind to the verified root public-key fingerprint—not merely to the numeric hint. Trust-store aliases for the same key MUST NOT carry differing policy. Ambiguous or conflicting configuration fails closed.

The issuer fingerprint is `sha256:` plus the lowercase hexadecimal SHA-256 digest of a domain separator, the canonical algorithm identifier, and canonical public-key bytes. Phase 0 fixtures freeze the exact byte framing.

### 11.3 Bearer-token honesty

Biscuit is a bearer token. Commonplace does not claim that the token itself proves possession of a private holder key.

Every production 0.1 Biscuit MUST contain exactly one authority-origin holder fact and SHOULD contain the defense-in-depth authority-block check shown here:

```datalog
holder_cell("EDITOR_CELL_ID");
check if holder_cell($cell), cp_source_cell($cell);
```

The reserved `cp_source_cell` fact comes only from `DeliveryContext.authenticated_source`.

The target authorizer independently requires the authority-origin `holder_cell` to equal that source. It does not rely on recognizing an equivalent token check. A `holder_cell` fact introduced by an attenuation block cannot satisfy the allow policy.

An intercepted token presented by a different authenticated Cell therefore fails. Code cooperating inside the same source Cell remains inside one cooperative trust domain.

Transferable unbound bearer tokens are out of scope and MUST be rejected by the production 0.1 authorizer.

### 11.4 Trust roots

Root public keys and issuer policy are local Realm configuration. They are not established by synced Documents or by data inside the Biscuit.

A target Cell may trust:

- its own issuing root;
- a Realm authority provider;
- an Assembly authority provider explicitly configured by the target;
- another named issuer under an explicit federation policy.

Being an Assembly does not automatically confer root authority. An Assembly may declare required relationships; an authority provider issues the actual tokens.

Trusting a root does not give it universal jurisdiction. Target policy MUST constrain each verified issuer fingerprint against the ground operation tuple: target Cell, resource kind and ID, action, and any contract, mount, version, or normalized argument dimension used by that policy. A correctly signed grant outside that jurisdiction is denied before the Biscuit allow query.

Private root keys MUST remain outside ordinary Document storage and application logs.

### 11.5 Canonical Datalog facts

The Commonplace authorizer supplies these reserved ambient facts as applicable:

```datalog
cp_source_cell("CELL_UUID");
cp_target_cell("CELL_UUID");
cp_resource("document", "DOCUMENT_UUID");
cp_operation("document.read.content");
cp_time(2026-08-26T12:00:00Z);
cp_request_id("REQUEST_UUID");
cp_version_ref("sha256:CANONICAL_VERSION_REF");
cp_path("sha256:CANONICAL_NORMALIZED_PATH");
cp_contract("sha256:...");
cp_mount("sha256:...");
cp_arg("REGISTERED_NAME", "sha256:CANONICAL_VALUE");
```

The entire `cp_` predicate namespace is reserved for authorizer-origin facts. Before evaluation, the verifier MUST reject a token containing a fact or rule head whose predicate begins with `cp_`; token checks may reference those predicates. This prevents a signed but scoped issuer from forging the target's operation, source, contract, or current-policy inputs.

Contract-specific normalized facts use `cp_arg(name, value)`, where `name` is registered by the trusted adapter and included in `contract_id`. Where a value is not a native Biscuit term, the second term is a domain-separated hash of its canonical `Commonplace.Value` encoding. Caller text is never parsed as Datalog.

In Stage A, `cp_contract`, `cp_mount`, and `cp_version_ref` facts represent normalized caller preconditions. In Stage B they represent resolved state, and exact equality has already been checked. `cp_path` is available in Stage A only for a built-in public contract, such as `directory.resolve`, whose trusted adapter can normalize the path without protected state.

Every production authority block contains exactly one authority-origin `grant_id`; it names the token's revocation unit. The authority block grants exact rights using:

```datalog
grant_id("GRANT_UUID");
grant("TARGET_CELL_UUID", "document", "DOCUMENT_UUID", "document.read.content");
contract_grant("TARGET_CELL_UUID", "document", "DOCUMENT_UUID", "document.invoke.render", "sha256:CONTRACT");
```

`holder_cell`, `grant_id`, `grant`, and `contract_grant` are authority predicates. They may appear as literal facts in the authority block but MUST NOT appear as a rule head in any token block or as a fact in an attenuation block. This prevents a token rule from deriving its holder or grants from ambient request facts.

Issuer jurisdiction, grant revocation, root trust, source authentication, target current policy, and the actual operation tuple are checked by trusted host code outside Biscuit Datalog. Datalog then proves that the authority block contains the grant and holder for those **ground host values**. For a built-in request from source `E` to exact tuple `(W, document, D, document.read.content)`, the instantiated allow policy is equivalent to:

```datalog
allow if
  holder_cell("E"),
  grant("W", "document", "D", "document.read.content");
```

For mounted contract `C`, trusted host code instead instantiates:

```datalog
allow if
  holder_cell("E"),
  contract_grant("W", "document", "D", "document.invoke.render", "C");
```

A plain `grant(...)` never authorizes `document.invoke.<local-name>` in version 0.1.

The concrete query MUST use Biscuit origin scoping so only authority-origin `holder_cell`, `grant_id`, `grant`, and `contract_grant` facts can satisfy it. Attenuation-block facts may restrict a token but may not manufacture grants. Values used to instantiate the query come from the trusted host; the policy never discovers the effective operation by joining token-supplied generic predicates.

Ground policies MUST be built through the Biscuit library's typed parameter API, never by interpolating caller strings into Datalog source.

The verifier evaluates each complete action requirement in a fresh Datalog world containing exactly one `cp_target_cell`, one effective `cp_resource`, and one `cp_operation`. It MUST NOT put read and write operations into one world and treat one successful check as covering both.

### 11.6 Exact-grant example

A Workspace authority provider granting Editor Cell `E` the minimum live-editing rights over canonical Document `D` may issue:

```datalog
grant_id("019d-grant-1");
holder_cell("E");

grant("W", "document", "D", "document.read.content");
grant("W", "document", "D", "document.sync.summary");
grant("W", "document", "D", "document.sync.export");
grant("W", "document", "D", "document.sync.offer");

check if holder_cell($cell), cp_source_cell($cell);
check if cp_time($time), $time < 2026-09-02T00:00:00Z;
```

This token authorizes no sibling Document and no mounted verb.

For a mounted `render` contract that also reads the target's content, an issuer instead includes both the contract-pinned base grant and the additional read grant in one grant set:

```datalog
grant_id("019d-render-grant-1");
holder_cell("E");

contract_grant("W", "document", "D", "document.invoke.render", "sha256:RENDER_CONTRACT");
grant("W", "document", "D", "document.read.content");

check if holder_cell($cell), cp_source_cell($cell);
check if cp_time($time), $time < 2026-09-02T00:00:00Z;
```

The request supplies the same contract ID as `expected_contract_id`. Stage B proves that the current mount actually has that contract before dispatch.

### 11.7 Offline attenuation

A token holder MAY append a Biscuit block containing additional checks, for example:

```datalog
check if cp_operation("document.read.content");
check if cp_contract("sha256:expected-contract");
check if cp_time($time), $time < 2026-08-27T00:00:00Z;
```

Attenuation may make the token unusable. It may not add a grant trusted by the authorizer.

Delegation does not remove authority from the delegator. Moving authority exclusively requires a separate revocation, lease, or ownership protocol.

Attenuation retains the original holder binding. It cannot rebind authority from one Cell to another. Cross-Cell delegation requires reissuance or a future holder-of-key protocol.

### 11.8 Multiple proofs

A request may carry more than one Biscuit subject to Cell proof-count and envelope limits.

Rules:

1. Each token is decoded, signature-verified, source-bound, revocation-checked, and authorized independently.
2. Facts and rules from two tokens MUST NOT be combined in one Datalog world.
3. One token must satisfy the whole action requirement: holder, issuer jurisdiction, target, resource, action, contract or mount constraints, normalized facts, and time.
4. In version 0.1, at least one independently valid token MUST cover the complete set of requirements for the invocation. Rights from separate tokens are not combined.
5. Per-requirement proof composition is deferred until a policy can name permitted issuer combinations and any required common grant or session binding.
6. A malformed, unknown-root, expired, or revoked token rejects the request rather than disappearing from consideration.

Multiple proofs therefore provide alternatives or support credential rotation; they do not amplify one another.

### 11.9 Third-party blocks

Version 0.1 rejects every externally signed third-party block.

Later support must specify accepted signer keys, predicate schemas, and the exact rules that use `trusting <public-key>`. Configuring a signer alone is not enough.

### 11.10 External functions

Version 0.1 exposes no Biscuit `extern::` functions and rejects tokens that call them. Every key in the Biscuit signature chain and proof must use Ed25519 under the version 0.1 profile. Future external signatures remain unsupported with third-party blocks.

### 11.11 Revocation

The target Realm maintains current revocation state outside Documents being accessed.

At every admission, the authorizer MUST reject a token when:

- any Biscuit block revocation identifier is currently revoked;
- its authority-origin semantic `grant_id` is currently revoked in the verified issuer fingerprint's namespace;
- its root key is no longer trusted;
- a required session or policy epoch is no longer current.

Revocation affects future admissions, subscription delivery, and retries that seek a protected result. It does not erase already appended events.

Block revocation identifiers are extracted only after signature verification and checked before Datalog evaluation. Unavailable or stale trust, policy, or revocation state fails closed.

### 11.12 Expiry and time

Time facts come from the receiving Realm. Caller-supplied timestamps are inert arguments.

Expiry MUST be checked at every admission, lease use, retry disclosure, and subscription resume.

### 11.13 Resource and action patterns

Version 0.1 grants exact resource IDs and exact actions.

Directory subtree grants, semantic resource groups, and patterned action sets require separate canonicalization and conformance specifications. They MUST NOT be improvised through unsafe string-prefix matching.

An exact Directory path caveat is not a subtree grant. It uses `cp_path("sha256:...")`, hashing the domain-separated canonical value of normalized path segments. It matches only that path. Descendant semantics are deferred.

## 12. Admission algorithm

### 12.1 Stage A: envelope and outer-operation admission

For every request, the target Cell MUST:

1. enforce byte, value, proof-count, and verb limits;
2. decode canonical bytes when a Realm boundary was crossed;
3. validate the delivery context;
4. validate the request envelope;
5. verify the request targets the receiving Cell;
6. bind the claimed source Cell to the authenticated source;
7. select a trusted resource-family adapter from the target address;
8. obtain the public outer envelope contract for the requested wire verb without disclosing protected resource state;
9. structurally validate and normalize public argument shape;
10. for a mounted invocation, require `expected_contract_id` and treat it, plus any `expected_mount_id` and `expected_target_version`, as a provisional trusted fact about what the caller is requesting—not what is currently mounted;
11. authorize the exact target resource, base action equal to the outer wire verb, and provisional preconditions against the presented Biscuits;
12. only then resolve the protected target resource.

Failure appends nothing, executes nothing, and discloses no protected metadata.

### 12.2 Stage B: effective-operation admission

After protected resolution, the target MUST:

1. verify ownership and profile;
2. resolve the exact built-in contract or the mount active in the current composed Document;
3. verify that the actual contract, mount, and target version satisfy every caller precondition;
4. validate the full input schema;
5. derive trusted security facts from normalized arguments and resolved state;
6. resolve `:self` in every action requirement to the exact target address;
7. rerun authorization over the base action and every additional requirement using the actual contract, mount, and normalized facts;
8. capture the exact current target version, contract ID, and mount ID;
9. construct an immutable dispatch or invocation plan;
10. begin dispatch only after all checks succeed.

Stage B exists because a reducer or initial envelope parser cannot see cross-projection mount state. It must not become an existence oracle: Stage A authority is required before Stage B resolves protected details.

Stage A and Stage B are complete, separate Biscuit evaluations; no Biscuit check is partially evaluated or deferred. A Stage A claim that does not match Stage B state authorizes no execution and returns the same public refusal class as other protected resolution failures.

The Stage A Datalog world for a mounted invocation contains only the public envelope facts listed in section 7.5. A mounted token whose checks require a Stage B-only fact is invalid for version 0.1 rather than partially evaluated.

Historical mount projections remain inspectable under history and verb-read authority, but version 0.1 invocation resolves only the mount active in the current composed Document. Naming an old coordinate does not bypass an unmount.

### 12.3 Trusted normalization

Authorization covers the effective operation, not merely the outer string.

For example, if `directory.resolve` accepts a path in arguments, the trusted public adapter normalizes the path segments and supplies their exact `cp_path("sha256:...")` fact. A root path address plus attacker-chosen deeper `arguments["path"]` does not inherit root authority accidentally.

### 12.4 No caller-selected policy

Requests MUST NOT supply:

- Datalog allow or deny policies;
- trusted ambient facts;
- root public keys;
- resource-adapter modules;
- schema validators;
- executor modules;
- authority-context values.

### 12.5 Authorization result

Successful authorization returns an inert value equivalent to:

```elixir
%Commonplace.Cell.AuthorizationContext{
  authenticated_source_cell_id: cell_id,
  covered_actions: [Commonplace.Cell.ActionRequirement.t()],
  grant_ids: [String.t()],
  token_fingerprints: [String.t()],
  root_key_ids: [non_neg_integer()],
  issuer_fingerprints: [String.t()],
  policy_epoch: term(),
  decision_id: String.t(),
  extensions: term()
}
```

It MUST NOT contain raw tokens, private keys, or callable authority supplied by the requester.

The context remains inside the receiving Realm and MUST NOT be serialized into the response or persisted automatically.

When a mounted invocation may propose same-Cell effects, the Biscuit authorizer service MAY also create an ephemeral verifier-owned **admission lease** keyed by an opaque, unguessable lease reference. The service retains whatever parsed proof state is necessary to rerun the original proof set under new operation facts, receiver time, current revocation, and current policy. Only the host receives the reference; handler code receives a narrower effect endpoint.

The lease is never serialized, persisted, audited as credential material, or treated as an authorization decision by itself. It closes at invocation completion or deadline. Biscuit expiry is arbitrary Datalog and is not extracted into a guessed lease expiry; every lease use reruns complete authorization with current receiver time. Loss, timeout, or restart of the authorizer service denies the effect.

## 13. Mounted-verb execution authority

### 13.1 Caller preconditions are not handler authority

`required_caller_authority` states what the caller must be permitted to cause before invocation begins. The older name `required_actions` is a migration alias only.

They do not become capabilities handed to handler code.

### 13.2 Default execution authority

The version 0.1 default is:

> A version 0.1 mounted handler has no effect authority except a narrow, reauthorized same-Cell continuation supplied by the executor.

A mounted handler receives only:

- validated portable input;
- non-secret invocation metadata;
- explicitly authorized target data required by its contract;
- a narrow effect interface, if any.

It does not receive the caller's raw Biscuit. Same-Realm BEAM code is cooperative: this rule limits the executor API, not what arbitrary native Elixir could discover by deliberately bypassing that API.

### 13.3 Effect interface

A version 0.1 handler effect interface MAY expose only operations equivalent to:

```elixir
reply(value)
command_self(effect_name, command)
```

Each operation is implemented by trusted executor code. Handler code cannot obtain the underlying router PID, DocHost PID, storage handle, signing key, or authority wallet.

The effect endpoint is invocation-scoped, non-portable, and unusable after completion or lease expiry. It is not a general Cell handle.

For `command_self`, the endpoint first resolves `effect_name` in the immutable contract. It then asks the trusted destination adapter to derive target semantics, canonical action, canonical command schema, and normalized facts from `command_profile` and `command_type`; validates the command; and enforces the count limit. It never trusts an action label or schema supplied by the mount or handler. An undeclared or relabelled command is denied even when the caller's retained proof happens to contain a powerful unrelated grant.

The contract's `effect_class` constrains this interface: `:read` exposes only `reply`; `:command` and `:mixed` may expose `command_self`; `:outbound` mounted contracts are unsupported in version 0.1.

Cross-Cell requests and streaming or subscription emissions are not version 0.1 handler effects. A handler may return an inert proposed request for the original caller to inspect and send under its own identity, but that proposal carries no authority.

### 13.4 Effect admission

Every handler-proposed durable command MUST pass the ordinary admission path of its destination.

For a same-target optimization, the host may avoid constructing network bytes, but it must preserve:

- required action checks;
- command validation;
- idempotency;
- durable append ordering;
- error semantics;
- audit causation.

Handler output is never appended as an event merely because the handler was authorized to run.

Version 0.1 `command_self` is a same-Cell continuation of the original admitted request. The trusted host uses the ephemeral admission lease to rerun the original proofs for the exact command action under current time, revocation, policy, contract, mount, and normalized command facts. An inert authorization summary is not sufficient for this step.

Initial invocation admission covers exactly one final `reply`, after output validation. Every later stream chunk, subscription event, retry disclosure, durable command, or outbound request is a new admission. Streaming and subscription replies are deferred.

### 13.5 Effect identity and crash safety

The trusted endpoint, not the handler, assigns every durable effect a deterministic operation ID. Its hash preimage is the canonical `Commonplace.Value` encoding of:

```json
{
  "format": "commonplace.effect-id/v1",
  "authenticated_source_cell_id": "CELL_UUID",
  "invocation_id": "REQUEST_UUID",
  "effect_name": "declared-name",
  "effect_ordinal": 0,
  "exact_target_address": {}
}
```

`effect_operation_id` is `sha256:` plus the lowercase hexadecimal SHA-256 digest of those canonical bytes. `effect_ordinal` is zero-based **per `effect_name`** within the invocation and cannot reach `max_count`. The destination MUST durably deduplicate the operation ID against the canonical command-body digest and retain or reconstruct its receipt. The same ID and body returns the original receipt; the same ID with a different body returns `request_id_conflict` and performs no new effect.

The derived value is submitted as the destination command's stable `operation_id` (or equivalent idempotency key). Handler code cannot override it.

After a crash, rerunning an idempotent handler therefore cannot append the same effect twice. A nondeterministic rerun that changes an already used ordinal fails closed as `outcome_unknown` or conflict. A `:durably_applied` response is emitted only after the durable effect receipts and invocation receipt are recoverable.

A same-self command carries:

```text
causation_id = invocation.request_id
correlation_id = invocation.correlation_id || invocation.request_id
```

### 13.6 Causal identity for future outbound effects

When cross-Cell effects are introduced, an outbound request caused by invocation `I` receives a fresh request ID and carries:

```text
causation_id = I.request_id
correlation_id = I.correlation_id || I.request_id
```

Retries of that outbound logical operation reuse its own request ID.

### 13.7 Same-Cell caller-authority continuation

The first implementation MAY let trusted executor code cause a same-Cell, self-target command only when the caller's independently verified authority covers that exact command effect.

The host retains the admission lease and performs current effect checks on behalf of the handler. It MUST NOT expose reusable raw credentials or verifier handles to handler code.

The host MUST close the lease when execution completes, times out, crashes, or is cancelled. A failed close is handled as credential-state cleanup and never changes a denial into an allow.

This continuation cannot authorize a cross-Cell request: a token bound to source Cell `E` does not authorize a new request authenticated as executor Cell `W`. Cross-Cell execution requires either a separately issued, invocation-bound capability for `W` or a request returned to `E` for sending. Delegated executor credentials are deferred.

### 13.8 Endowed or setuid-like lane

A future Assembly or activation may grant a handler its own service authority. That is a separate execution lane and is deferred.

It must define:

- the handler principal;
- the issuer and grant lifecycle;
- the maximum effect surface;
- whether caller authority is also required;
- confused-deputy protections;
- revocation and audit behavior.

No mount acquires endowed authority merely by naming `required_caller_authority` or by being stored in a privileged Document.

### 13.9 Realm containment

Elixir code in the same Realm is cooperatively trusted and can technically inspect or reach VM and OS facilities beyond a narrow function argument.

Code requiring hostile containment MUST run in another Realm or in a separately reviewed sandbox. A separate Unix process on the same machine qualifies as another Realm when all communication crosses the authenticated, serialized Cell gateway.

## 14. Mount lifecycle

### 14.1 Mount

Mounting a verb requires `document.mount.verb` on the target Document and target-side code-provenance acceptance.

The command validates and appends a mount event. It does not execute the handler or issue invocation authority.

### 14.2 Unmount

Unmounting requires `document.unmount.verb`.

An unmount affects invocations planned after the unmount's coordinate. It does not retroactively erase audit history or durable effects.

An invocation whose immutable plan was admitted before an unmount MAY finish unless target policy explicitly cancels it.

### 14.3 Remount

Remount after unmount is legal. The new mount has a new `mount_id`. It retains a `contract_id` only when the semantic contract is genuinely unchanged.

### 14.4 Fork

A Document fork copies historical mount facts as ordinary Document history when the fork protocol says so. It does not copy:

- runtime authority contexts;
- raw Biscuits;
- issuer private keys;
- executor activation grants.

Capabilities naming the old Document UUID do not cover the fork's new UUID. An Assembly or authority provider may reissue equivalent grants after solving the forked relationship graph.

Because version 0.1 code references are same-Cell-relative, a Document lineage fork activated in another Cell MUST either remap and remount every code reference to a code Document owned by the new Cell or reset those verb mounts to inactive. It MUST NOT reinterpret the old UUID silently in the new Cell.

## 15. Retry, acknowledgement, and revocation

### 15.1 Request identity

`request_id` identifies one logical operation. Retrying the same operation reuses it and the same semantic request body.

Reusing an ID with a different body returns `request_id_conflict`.

The target keys an idempotency record by authenticated source Cell, exact target, and `request_id`. Its canonical semantic digest covers the request format, source, target, wire verb, normalized arguments, contract and mount preconditions, causation/correlation identity, and every extension declared semantic. It excludes proofs, transport metadata, and non-semantic extensions, so an expired credential may be replaced without changing the logical operation.

The record also retains the original authorization descriptor: exact required actions, normalized security facts, contract ID, mount ID, and target version. A retry must match the original source and semantic digest and must be reauthorized against that original descriptor before a prior result is disclosed. It does not silently re-resolve a remounted verb as a new operation.

For `:durably_applied`, the invocation record, every effect operation ID and body digest, and the final receipt MUST be durable before acknowledgement. An in-memory deduplication cache is insufficient.

### 15.2 Authorization before replay

Every delivery attempt, including a duplicate, MUST pass current source binding, expiry, revocation, and target policy before a cached or durable result is disclosed.

After successful reauthorization, the target command protocol may return the original durable receipt without repeating the effect.

This rule must be identical for same-Realm structured delivery and cross-Realm encoded delivery.

### 15.3 Acknowledgement

Every verb contract declares one acknowledgement point:

- `computed`: a read or pure result was computed;
- `durably_applied`: all promised durable effects were confirmed and applied by their target hosts;
- `accepted`: work was durably or explicitly accepted for later processing.

A success response means only that the declared acknowledgement point was reached.

Version 0.1 mounted execution accepts only `:safe` or `:idempotent` contracts and only `:computed` or `:durably_applied` acknowledgement. `:non_idempotent` and `:accepted` require a durable invocation journal or queue and are deferred.

### 15.4 Lost outcome

If a non-idempotent invocation may have crossed its acknowledgement boundary but the host cannot prove the outcome, it returns `outcome_unknown`. It MUST NOT invent a replacement operation ID.

### 15.5 Revocation during execution

Revocation before invocation starts prevents execution.

Immediately before entering handler code, the host compares the authorization context's root-trust, policy, and revocation epochs with current state. A mismatch causes full reauthorization or denial. The successful comparison is the invocation-start linearization point.

A revocation observed after that point does not retract the already admitted computation or its one validated final reply, but every later durable effect, stream or subscription delivery, and retry disclosure passes current admission. Revocation never rolls back an already durable event.

## 16. Same-Realm and cross-Realm behavior

### 16.1 Same Realm

The router may carry already constructed `Commonplace.Value` values and avoid encoding. It still:

- authenticates the source Cell cooperatively;
- supplies trusted delivery context;
- invokes the target authorizer;
- checks Biscuit source binding;
- performs both admission stages;
- returns only portable response semantics.

### 16.2 Across Realms

The gateway must additionally:

- authenticate the transport peer as a Cell or Realm principal;
- derive `DeliveryContext.authenticated_source` either from direct Cell authentication or from an assertion by a specifically trusted source-Realm identity provider;
- decode bounded canonical request bytes;
- reject native runtime authority;
- protect confidentiality and integrity through the configured transport;
- bound response frames;
- create delivery context independently of request claims.

A Biscuit does not replace authenticated transport. Authenticated transport does not replace a Biscuit.

A Realm peer's unverified claim about an inner Cell never establishes the source identity used for holder binding.

### 16.3 Moving a Cell

Moving a Cell between Realms changes no Cell ID, resource address, verb, contract, grant, or request body. Only routing and transport change.

## 17. Biscuit verification safety

### 17.1 Resource bounds

The authorizer MUST bound at least:

- decoded bytes per Biscuit;
- Biscuit blocks;
- proofs per request;
- Datalog facts;
- generated facts;
- rule iterations;
- query execution time;
- total authorization time.

Recommended initial limits are:

```text
decoded Biscuit bytes:       65,536
blocks per Biscuit:          16
Biscuits per request:        16
facts after evaluation:      10,000
rule iterations:             100
authorization wall budget:   25 ms
```

An implementation may choose tighter limits. Limit failures are authorization failures and append nothing.

### 17.2 BEAM scheduling

Biscuit parsing, signature verification, and Datalog evaluation operate on attacker-controlled bytes and MUST NOT monopolize an ordinary BEAM scheduler.

An Elixir integration SHOULD use a supervised port or a dirty CPU NIF with explicit input and execution bounds. A crash or timeout in the verifier returns a bounded internal authorization error and never grants access.

### 17.3 Policy source

Production policies are trusted application artifacts selected by the target. They MUST NOT be assembled from request-provided Datalog strings.

### 17.4 Caching

Cryptographic parsing or signature verification MAY be cached by token hash and root-key identity.

An allow decision MUST NOT be reused unless its cache key includes all security-relevant current state, including:

- target policy version;
- revocation state or epoch;
- root trust version;
- authenticated source;
- exact required action and normalized facts;
- time validity.

Failing to prove cache freshness means reevaluate or deny.

## 18. Audit and privacy

### 18.1 Decision record

The target MAY persist a redacted authorization decision containing:

```text
decision ID
request ID
authenticated source Cell
target Cell and resource
wire verb
required actions
contract ID and mount ID, when present
grant IDs
root key ID hints and verified issuer fingerprints
token fingerprints
policy epoch
allow or deny
bounded reason code
time
```

### 18.2 Forbidden audit material

Ordinary logs and telemetry MUST NOT contain:

- raw Biscuit bytes or Base64url strings;
- private keys;
- complete sensitive arguments;
- full Datalog worlds by default;
- handler secrets;
- stack traces returned to remote callers.

### 18.3 Token fingerprint

A token fingerprint is a domain-separated cryptographic hash of the canonical token bytes. It is useful for correlation but is not itself authority.

## 19. Errors

Internal errors SHOULD distinguish at least:

```text
invalid_verb
verb_not_supported
verb_not_found
invalid_arguments
invalid_contract
contract_mismatch
mount_changed
invalid_biscuit
unsupported_biscuit_version
unknown_root_key
source_not_authenticated
source_mismatch
unauthorized
expired
revoked
policy_changed
effect_unauthorized
executor_unavailable
execution_refused
execution_timeout
request_id_conflict
outcome_unknown
limit_exceeded
internal_error
```

Before outer authorization succeeds, the public error surface MUST NOT reveal whether a protected resource, mount, contract, or code Document exists. Internal audit may retain the more specific bounded reason.

## 20. Package ownership

### 20.1 `commonplace-value`

Owns canonical inert values and JSON encoding. It knows nothing about verbs or Biscuits.

### 20.2 `commonplace-cell`

Owns:

- request and response envelopes;
- verb-name grammar;
- addresses;
- delivery context;
- action requirements and verb-contract protocol values;
- the canonical verb-contract codec and hash verification;
- ordered admission;
- authorizer, resolver, adapter, and router behaviours;
- opaque authorization and dispatch plans;
- stable portable errors.

It does not implement Biscuit cryptography or mounted execution.

### 20.3 Biscuit adapter

A future module or package such as `commonplace-biscuit` may own:

- Biscuit 3.3 decoding and verification;
- the Commonplace Datalog profile;
- candidate root-key lookup by `root_key_id` and verified-key fingerprint binding;
- revocation checks;
- bounded evaluation;
- conversion to an inert authorization decision;
- ephemeral admission-lease creation, effect reauthorization, and closure.

It MUST NOT resolve Documents, execute handlers, append logs, or define application verbs.

### 20.4 `commonplace-doc`

Owns:

- durable mounted-verb descriptions;
- the `verbs` projection;
- mount and unmount command planning;
- normalization of projected mount maps.

It retains verb contracts as semantically opaque portable values so it does not need a dependency on `commonplace-cell`. It does not verify Biscuits, interpret contracts, choose target policy, or execute code.

### 20.5 Cell host / composition root

Owns:

- active Cell supervision;
- target trust-root configuration;
- authorizer installation;
- resource and contract resolution;
- local and remote routing;
- current policy and revocation state;
- cross-projection mount and contract validation;
- immutable mounted-invocation planning against an exact Document version;
- invocation admission and dispatch;
- ephemeral admission-lease custody for same-Cell effects;
- audit integration.

For the Document profile, these composition duties naturally belong in `commonplace-doc-host` or an equivalent package that depends on both `commonplace-doc` and `commonplace-cell`.

### 20.6 Executor

Owns:

- exact code materialization;
- construction of the Realm-local execution plan, including verified code content hash;
- code provenance checks;
- runtime selection and isolation;
- resource bounds;
- portable input and output delivery;
- narrow effect interfaces;
- effect routing and causal metadata;
- execution lifecycle and errors.

### 20.7 Assembly / authority provider

An Assembly may declare which relationships and actions are required. An authority provider resolves those declarations against current identities and policy and issues Biscuits.

Assembly Documents contain requirements and public references, not root private keys or reusable live tokens.

## 21. Proposed API seams

Exact names may change. The semantic seams should resemble:

```elixir
Commonplace.Cell.VerbContract.validate(contract)
Commonplace.Cell.ActionRequirement.validate(requirement)

Commonplace.Cell.Authorizer.authorize(
  request,
  delivery_context,
  action_requests,
  trusted_facts,
  options
)

Commonplace.Biscuit.Authorizer.authorize(
  proof_values,
  delivery_context,
  action_requests,
  trust_store,
  current_policy
)

Commonplace.Biscuit.Authorizer.authorize_with_lease(
  proof_values,
  delivery_context,
  action_requests,
  trust_store,
  current_policy,
  invocation_deadline
)

Commonplace.Biscuit.Authorizer.reauthorize_effect(
  lease_ref,
  exact_effect_requirement,
  trusted_effect_facts,
  current_policy
)

Commonplace.Biscuit.Authorizer.close_lease(lease_ref)

Commonplace.Doc.normalize_verb_mount(projected_map)
Commonplace.Doc.mount_verb(document_view, mount, operation_id)
Commonplace.Doc.unmount_verb(document_view, local_name, operation_id)
Commonplace.DocHost.plan_invoke(
  document_view,
  local_name,
  expected_contract_id,
  expected_mount_id,
  expected_target_version,
  input,
  invocation_id
)

Commonplace.Cell.Dispatch.bind(invocation_plan, authorization_context, admission_lease)
Commonplace.Executor.prepare(invocation_plan, options)
Commonplace.Executor.execute(execution_plan, effect_endpoint, options)
Commonplace.Executor.command_self(effect_endpoint, effect_name, command)
```

`authorize/5` returns only an inert decision. `authorize_with_lease/6` returns that decision plus an opaque Realm-local lease reference; all parsed token state remains behind the authorizer service. Raw library handles, Rust resources, and proof bytes do not escape into ordinary Cell or handler code.

## 22. Conformance requirements

### 22.1 Verb semantics

1. A built-in verb resolves through trusted adapter configuration.
2. A request cannot select a module or function.
3. A local mount name cannot escape `document.invoke.*`.
4. An unknown mounted verb executes nothing and appends nothing.
5. Historical materialization returns the historical verb map.
6. An invocation plan pins the exact target version, contract, mount, and code content.
7. The real reducer's portable mount map flows through Document normalization and composing-host validation into `plan_invoke`.
8. Changing input schema changes `contract_id`.
9. Changing code alone may retain a compatible contract but changes `mount_id`.
10. A stale `expected_mount_id` is refused before execution.
11. An identical remount retains `mount_descriptor_id` but changes `mount_id`.
12. An unmounted historical handler cannot be invoked through an old coordinate.
13. Mount admission rejects a contract hash mismatch, wrong verb/name binding, foreign target requirement, or unsupported effect declaration.

### 22.2 Biscuit verification

1. A valid exact-action Biscuit authorizes its exact source, target, resource, and action.
2. The same token fails from another authenticated source Cell.
3. A sibling Document is denied.
4. A different action is denied.
5. An attenuation block can narrow to one action.
6. An attenuation block cannot add a trusted grant.
7. An expired token is denied using receiver time.
8. A revoked block identifier is denied.
9. A revoked semantic grant ID is denied.
10. An unknown or retired root key is denied.
11. A Biscuit without source binding is denied in production mode.
12. A holder fact from an attenuation block cannot satisfy source binding.
13. A valid signature outside the verified issuer's configured jurisdiction is denied.
14. A malformed proof rejects the entire request.
15. Two tokens cannot combine facts or separate actions to manufacture one invocation right.
16. One token covering the complete requirement set succeeds even when unrelated alternative proofs are present and valid.
17. A third-party block is rejected.
18. An external-function opcode is rejected.
19. Every resource and Datalog limit has a red arm and a positive control.
20. Every action requirement is evaluated with exactly one operation and resource fact.
21. Biscuit v1 and Datalog blocks outside versions `3..6` are rejected.
22. A hostile authority block that injects or derives any reserved `cp_` predicate is rejected.
23. A missing or duplicate authority-origin `grant_id` is denied.
24. Revoking `(issuer A, grant G)` does not collide with the same grant string under issuer B.
25. A root-key alias with conflicting issuer policy fails closed.
26. A token rule that derives `holder_cell`, `grant_id`, `grant`, or `contract_grant` is rejected.

### 22.3 Admission

1. Authorization occurs before protected resource resolution.
2. Stage B resolves no protected mount before Stage A authority succeeds.
3. A mounted invocation without `expected_contract_id` is denied before protected resolution.
4. Stage B rejects a caller contract or mount claim that differs from current state.
5. Security-relevant arguments are normalized into target-trusted facts.
6. Changing a destination in arguments without widening the grant is denied.
7. Authorization rejection reaches no adapter execution path.
8. Same-Realm and cross-Realm delivery return equivalent decisions for the same logical request.
9. A duplicate request is reauthorized against its original descriptor before its old response is disclosed.
10. Refreshed proofs do not create a request-ID conflict; changed semantic arguments do.
11. Revocation causes identical refusal locally and remotely.
12. A mounted-token check requiring a Stage B-only fact is rejected rather than partially evaluated.

### 22.4 Mounted execution

1. Invoke authority alone cannot mount or unmount.
2. Mount authority alone cannot invoke.
3. An authorized invocation does not grant an arbitrary append.
4. Handler output is rejected when it violates the output schema or is not a valid typed self-command.
5. Every durable effect is independently admitted.
6. The executor API gives a handler no raw token, key, PID, store, or DocHost handle.
7. A handler cannot widen an attenuated effect request.
8. Causation and correlation IDs survive same-self commands.
9. Revocation during a long invocation prevents later unauthorized effects.
10. A timeout kills or isolates the invocation without corrupting the target host.
11. Version 0.1 refuses a mounted cross-Cell effect.
12. A same-Cell command is reauthorized through the host's admission lease under current policy.
13. An undeclared command is denied even when the caller proof contains its action.
14. Repeating the same effect ID and body returns one durable receipt; changing the body under that ID conflicts without another append.
15. Loss or expiry of an admission lease denies the effect.
16. A changed revocation or policy epoch immediately before dispatch causes reauthorization or denial.
17. Mount admission rejects an effect whose claimed semantics would relabel the adapter's canonical command action.
18. A command is validated against the destination adapter's canonical schema even when handler or mount data claims another schema.
19. A version 0.1 effect resolving to a foreign target is rejected.

### 22.5 Forking

1. A forked resource receives a new identity; a Document fork does not by itself change the owning Cell identity.
2. A Biscuit naming the source Document does not authorize its fork.
3. No raw token appears in forked history or Directory entries.
4. Reissued grants name the new identities and are independently revocable.
5. A cross-Cell fork resets or explicitly remaps same-Cell code mounts before activation.

## 23. Implementation sequence

### Phase 0: contract and fixture package

- freeze `VerbContract`, `ActionRequirement`, `EffectDeclaration`, the first schema dialect, proof wrapper, reserved predicates, and Datalog vocabulary;
- publish canonical value fixtures;
- publish positive and negative Biscuit fixtures generated by an independent implementation;
- add exact-action authorization tests without changing the demo path.

### Phase 1: one real Biscuit vertical slice

- install a Biscuit 3.3 verifier behind `Commonplace.Cell.Authorizer`;
- issue one source-bound, expiring token from the Workspace authority provider to one Editor Cell;
- grant exact read and sync actions for one canonical Document;
- bind issuer jurisdiction and grant revocation to the verified root-key fingerprint;
- reject token definitions in the reserved `cp_` namespace;
- use the same token on local and cross-Realm routes;
- prove sibling-Document, wrong-action, wrong-source, expiry, and revocation denials;
- retain `DevScoped` only for explicit development tests.

### Phase 2: verb-contract admission

- add adapter-declared built-in contracts;
- add trusted argument normalization;
- separate wire verbs from structured required actions;
- require contract preconditions and exact contract grants for mounted invocation;
- add `document.read.verbs` and `document.select.head` to the stable vocabulary;
- make duplicate reauthorization identical on local and remote paths.

### Phase 3: mounted invocation planning

- replace scattered mount contract fields with canonical `contract_value` and add activation-derived `mount_id`;
- normalize real reducer maps into `VerbMount` values;
- move semantic contract validation and invocation planning into the composing Document host;
- plan invocations from authoritative composed Document versions;
- materialize and verify exact code content;
- execute nothing yet.

### Phase 4: constrained executor

- run one pinned BEAM handler in a deliberately chosen Realm posture;
- supply validated input and no ambient authority;
- support one validated portable reply plus a narrow same-Cell caller-authority command interface;
- derive deterministic effect operation IDs and require destination exact-body deduplication;
- route every effect through ordinary admission;
- enforce time and memory bounds;
- prove no raw capability reaches handler code.

### Phase 5: lifecycle extensions

- durable or resumable subscriptions;
- policy epochs and root rotation operations;
- Assembly-driven issuance;
- cross-Cell effects with invocation-bound delegated authority;
- service/endowed handler authority, only after a separate confused-deputy review;
- additional runtimes or hostile-code Realms.

## 24. Settled decisions

1. Commonplace uses literal Eclipse Biscuit tokens rather than a bespoke token merely called a Biscuit.
2. Version 0.1 uses Biscuit 3.3 with Ed25519.
3. A verb is a target-relative protocol operation.
4. A verb is not a handler, command, event, or generic BEAM message.
5. Actions are authorization predicates derived from a verb contract.
6. Exact action grants are the production 0.1 default.
7. Mounted local names contain no dots and are exposed beneath `document.invoke.*`.
8. Every public verb has a base action equal to its wire verb.
9. Mounted invocation grants pin the exact contract ID.
10. Mount, invoke, code provenance, source reading, and effect authority are separate decisions.
11. Caller preconditions are not capabilities handed to handler code.
12. Version 0.1 handler effects are limited to one reply and reauthorized same-Cell commands.
13. Cross-Cell handler effects require new delegated authority and are deferred.
14. Production tokens are bound to the authenticated source Cell by both token data and authorizer policy.
15. One Biscuit covers the complete requirement set in version 0.1; separate tokens do not combine rights.
16. Host ambient facts occupy a reserved predicate namespace, and allow queries use ground host values.
17. A contract declares the exact self-command effects a handler may propose.
18. Target-side revocation and current policy remain part of every admission.
19. Raw tokens and private roots do not live in Documents or Assemblies.
20. Forking reruns issuance; it does not copy capability authority.
21. Same-Realm routing is an optimization over the same logical protocol.

## 25. Deferred decisions

- the final repository and Elixir module name for the Biscuit adapter;
- whether the verifier uses a supervised port, Rustler dirty NIF, or another bounded integration;
- human/session holder binding beyond a source Cell;
- the concrete first schema dialect, which must be settled before mounted execution;
- Directory subtree grant encoding;
- immutable action-set manifests;
- acceptance of third-party Biscuit blocks;
- Biscuit external functions and additional signature algorithms;
- action-only grants for moving mounted slots;
- composition of rights from multiple Biscuits;
- durable subscription tokens;
- cross-Cell code Documents and handler effects;
- service/endowed mounted-verb authority;
- code-signing and review policy for each runtime;
- OS sandbox and remote executor protocol;
- invocation cancellation after admission;
- durable support for `:accepted` or `:non_idempotent` mounted contracts;
- cross-Cell transactions and compensations.

## 26. References

- [`commonplace-cell` MVP specification](https://github.com/commonplace-systems/commonplace-cell/blob/main/docs/proposals/2026-08-24-commonplace-cell-mvp-spec.md)
- [`commonplace-doc` specification](https://github.com/commonplace-systems/commonplace-doc/blob/main/docs/proposals/2026-08-23-commonplace-doc-spec.md)
- [`Commonplace.Cell.Request`](https://github.com/commonplace-systems/commonplace-cell/blob/main/lib/commonplace/cell/request.ex)
- [`Commonplace.Cell.Admission`](https://github.com/commonplace-systems/commonplace-cell/blob/main/lib/commonplace/cell/admission.ex)
- [`Commonplace.Doc.VerbMount`](https://github.com/commonplace-systems/commonplace-doc/blob/main/lib/commonplace/doc/verb_mount.ex)
- [Current `Commonplace.Doc.InvocationPlan` implementation to migrate toward the composing-host seam](https://github.com/commonplace-systems/commonplace-doc/blob/main/lib/commonplace/doc/invocation_plan.ex)
- [Eclipse Biscuit specification](https://github.com/eclipse-biscuit/biscuit/blob/main/SPECIFICATIONS.md)
- [Eclipse Biscuit authorization policies](https://doc.biscuitsec.org/getting-started/authorization-policies)
- [Eclipse Biscuit implementation support](https://github.com/eclipse-biscuit/biscuit)
- [UCAN specification](https://github.com/ucan-wg/spec)
- [UCAN Invocation](https://github.com/ucan-wg/invocation)
- [Erlang process and message semantics](https://erlang.org/documentation/doc-15.0/doc/system/ref_man_processes.html)
- [JSON-RPC 2.0](https://www.jsonrpc.org/specification)

## 27. One-paragraph model

A Cell request names a target and a verb and carries inert arguments plus source-bound Biscuit proofs. The target authorizes the outer operation, resolves the verb's immutable contract, derives the exact actions and security facts the effective operation requires, and authorizes the resolved operation against current target policy before dispatch. A built-in adapter or pinned mounted handler may compute a validated result or propose a typed same-Cell command, but it never appends arbitrary events merely because invocation was allowed. Every durable effect is admitted again, and reducers only project canonical history that survived those gates. Biscuits carry attenuable authority; they do not define verb semantics, replace authenticated transport, grant ambient handler power, or travel into Document history.
