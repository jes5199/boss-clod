---
title: "Review of the Commonplace-Defined Topology Proposal"
date: 2026-08-16
status: review
source:
  document: https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-16-topology-proposal.md
  blob: d36def8e33e8a42f39ce29be580d86c42fa47fa0
related:
  - commonplace-storage-ephemerality-proposal.md
  - commonplace-attenuated-identity-pods-analysis.md
---

# Review of the Commonplace-Defined Topology Proposal

## Executive verdict

The [topology proposal](https://github.com/commonplace-systems/commonplace-plan/blob/main/docs/plans/2026-08-16-topology-proposal.md) identifies the correct missing object: a declared account of the world as it should be, independent of the accidental processes and tmux labels that happen to exist now.

Its strongest choices are:

- moving topology out of tmux window names and into a Commonplace document;
- giving participants stable declared identifiers;
- separating topology roles from security authority;
- distinguishing `READS` from `RECEIVES-A-COPY` and recognizing freshness as a property of a relationship;
- making expected state explicit;
- beginning maintenance with divergence reporting rather than automatic killing or restarting; and
- preserving the current host-agent path instead of pretending the pod launcher already implements it.

The proposal should move forward, but its object model needs one correction before implementation. It currently compresses logical participants, durable identities, desired deployments, observed processes, host placement, and authority into one participant record.

There are actually four related planes:

1. **Logical topology** — participants, resources, roles, and relationships.
2. **Deployment intent** — which incarnations should exist, where, and under which runtime profile.
3. **Observed topology** — processes, sessions, peer connections, heartbeats, and exit facts.
4. **Authority** — capabilities and certificates governing who may instantiate, rank, review, restart, or retire things.

The topology document can declare the first two. Sensors produce the third. Commonplace's certificate machinery controls the fourth.

The governing distinction is:

> Capabilities say who **may** act.  
> Topology says who **should** act.  
> Audit events say who **did** act.

That preserves the proposal's correct ruling that topology must not become a second trust root while still making organizational divergence mechanically visible.

## What the proposal gets right

### It finds the actual defect

The defect is not merely that agents run in tmux. It is that the declared topology exists nowhere.

The current system can observe a window named `commonplace`, but it cannot answer:

- whether that participant ought to exist;
- whether one or several instances ought to exist;
- which identity or deployment the process represents;
- which other participant is expected to dispatch or brief it;
- whether its configuration is current;
- whether an empty window is a spare, a stopped deployment, or debris; or
- whether an observed process satisfies the intended declaration.

A stable desired-state document is the correct foundation.

### Roles should be declarative, not an alternate permission system

The proposal is right to reject topology-enforced authority. A graph edge saying `plan ranks` must not become permission to rank. That permission belongs to capability and certificate verification.

The topology still has an important normative job: it says who is currently assigned or expected to perform the work. If boss ranks work despite the assignment saying plan ranks, that should become observable divergence even if boss possesses a broad capability that makes the action cryptographically valid.

This requires three separately queryable facts:

```text
permission:  boss may rank
assignment:  plan should rank
observation: boss ranked CX-123
```

The act may be authorized and still violate the operating arrangement. Commonplace should be able to say both.

### Maintenance should begin as reporting

The first reconciler should be a pure comparison between declared deployment intent and observations. It should explain differences without acting on them.

That is the correct first rung because:

- matching and adoption semantics are not established yet;
- process absence does not prove a crash;
- an outdated or partially edited declaration must not kill live work;
- authority to restart is different from authority to observe; and
- the current system lacks durable deployment receipts from which to recover.

Later automation can consume a proposed reconciliation action under a separately granted capability.

## The central modeling correction

### `participant` currently represents five different things

The proposed record is approximately:

```jsonc
{
  "id": "commonplace",
  "role": "builder",
  "home": {"kind": "worktree", "path": "..."},
  "instantiate": {"recipe": "...", "args": {}},
  "edges": [
    {"verb": "briefs", "to": "sol"},
    {"verb": "reports", "to": "commonplace-plan"}
  ],
  "expect": "running"
}
```

That one object conflates:

- the logical participant called `commonplace`;
- a durable agent or cell identity;
- the desired deployment slot;
- the worktree or pod in which it runs;
- and the current process incarnation.

These things have different lifetimes and cardinalities. They must have separate identifiers.

| Object | Meaning | Lifetime |
|---|---|---|
| `participant_id` | Stable name in this organizational topology | Long-lived |
| `cell_ref` or `principal_ref` | Durable cryptographic identity, where applicable | Long-lived |
| `deployment_slot_id` | Desired place for an incarnation | Until topology changes |
| `deployment_id` | One launched incarnation with an attenuated principal | One deployment |
| `runtime_instance_id` | Observed OS process, container, or session | One runtime attempt |

This distinction is essential for attenuated-identity pods. The durable `commonplace` participant can persist while deployment A dies and deployment B appears under a fresh short-lived principal. Neither the worktree path nor the container is the identity.

### Expectation belongs to deployment intent

The proposal asks whether `expect` belongs to each participant or to the fleet as a whole. It belongs to neither in quite that form.

The topology document is a revisioned declaration of desired state as a whole. The expectation itself belongs to a deployment slot or deployment class.

For example:

```json
{
  "deployments": {
    "commonplace.primary": {
      "participant": "commonplace",
      "desired": {
        "mode": "singleton",
        "count": 1
      }
    },
    "commonplace.subagents": {
      "participant": "commonplace",
      "desired": {
        "mode": "on-demand",
        "max": 8
      }
    }
  }
}
```

Useful initial modes are likely:

- `singleton` — exactly one active deployment;
- `replicated` — a bounded desired cardinality;
- `on-demand` — zero or more, created in response to work;
- `external` — observed and related, but not instantiated here; and
- `absent` — explicitly retired or forbidden from running in the selected scope.

This prevents every transient Opus hand or Sol task from becoming a permanent topology node. The topology can declare a spawn relationship and a deployment class; observations can enumerate the current instances.

## Declared absence is not proof of a crash

The proposal currently maps:

```text
declared running + not running = crash
```

The comparison can establish only:

```text
desired running + no matching observed instance = desired-but-absent
```

Calling the state a crash requires additional evidence such as:

- an abnormal process exit record;
- an expired heartbeat or deployment lease;
- a supervisor observation;
- an abandoned launch receipt; or
- a previously adopted instance disappearing without a clean shutdown.

Without that evidence, absence might instead mean:

- a clean exit;
- a launch that never succeeded;
- a missing dependency;
- a host reboot;
- a declaration that has not yet been applied; or
- an observation system that cannot currently see the process.

The first divergence vocabulary should therefore include:

```text
desired-but-absent
observed-but-undeclared
declared-absent-but-observed
matched
observation-unavailable
```

Deployment history can refine `desired-but-absent` into `crashed`, `exited`, `launch-failed`, or `unknown`.

## A Commonplace document needs an activation boundary

Making topology a native Commonplace JSON document is exactly right. It provides collaborative editing, history, synchronization, and signed provenance.

Its live CRDT head must not directly control process creation.

Otherwise:

- an intermediate edit can momentarily describe executable nonsense;
- a temporarily invalid JSON or schema state can disrupt maintenance;
- concurrent edits can merge into a valid document nobody intended to activate;
- an unreviewed edit can gain operational effect merely by synchronizing; and
- the runtime cannot name the exact declaration it attempted to realize.

Topology therefore has three clocks:

| Clock | Trigger | Meaning |
|---|---|---|
| **Edit clock** | CRDT updates | People and agents revise a draft topology |
| **Ratification clock** | Explicit activation | One valid topology moment becomes desired state |
| **Reconciliation clock** | Observation or control loop | Runtime is compared with that active moment |

Instantiation must target a pinned, schema-valid, ratified topology revision. An invalid or unresolved draft leaves the last-known-good active revision untouched.

Commonplace gives the document history and synchronization. It does not make every intermediate edit an authorized deployment decision.

## `instantiate.recipe` is an execution authority boundary

The proposal says that role declarations do not confer authority. That is correct. But an instantiator that executes an arbitrary recipe read from the topology would turn permission to edit topology into permission to execute arbitrary host code.

The topology should select a governed execution profile rather than embed an unconstrained shell recipe:

```json
{
  "executor": {
    "kind": "host-agent",
    "profile": "workerclaude-v1",
    "arguments": {
      "workspace": "commonplace"
    }
  }
}
```

The governed profile owns mandatory safety behavior:

- `oom_score_adj`;
- cgroup, systemd scope, or other failure-domain isolation;
- environment filtering;
- executable allowlisting;
- secret-reference resolution;
- network policy;
- filesystem scope;
- shutdown behavior; and
- required deployment receipts.

The controller validates the selected profile and the requester's capability before acting. This prevents safety requirements from being copied into many declarations and then drifting apart.

The topology may make host-agent and pod execution alternatives behind one declarative interface. Moving an agent into a pod will not literally be only a `home.kind` change: it also introduces deployment identity, capability transfer, filesystem synchronization, model credentials, network controls, and teardown barriers. The valuable promise is that those differences live behind an executor profile rather than leaking throughout the logical relationship graph.

## Edges need stable, typed semantics

The distinction between `READS` and `RECEIVES-A-COPY` is one of the proposal's most important findings. It demonstrates why free-form edge verbs are insufficient for maintenance.

An edge should have a stable identity, a small typed kind, typed endpoints, and properties appropriate to that kind:

```json
{
  "id": "known-reds-brief-copy",
  "kind": "materializes",
  "from": {"resource": "known-reds"},
  "to": {"participant": "commonplace"},
  "delivery": "brief-copy",
  "freshness": {"max_age": "1h"}
}
```

At minimum, the schema should distinguish:

- informational relationships;
- dispatch relationships;
- communication and relay routes;
- operational dependencies;
- materialization or delivery relationships;
- supervision and shared-fate relationships; and
- normative role assignments.

These kinds have different validation and observation rules. For example:

- `cp-serve is consumed by commonplace` is an operational dependency with readiness semantics;
- `boss relays jes to agents` is a communication path with availability and redundancy implications;
- `known-reds is copied into briefs` is a materialization edge with freshness semantics; and
- `plan ranks work` is a normative assignment whose actual exercise must be observed through events.

The static graph alone cannot detect that boss ranked something. It can state the expected assignment. Visibility arises when typed action events identify who actually performed the rank operation and a reporter compares the two.

## Separate portable topology from physical bindings

A synchronized topology document should not canonically identify a participant by an absolute host path. That repeats the same category error found in the storage design: confusing logical meaning with physical placement.

Use separate layers:

1. The topology names a portable workspace or home resource.
2. Deployment intent selects a host, placement constraint, or executor.
3. A node-local binding resolves the resource to a path, volume, checkout, or pod mount.
4. Observations report the actual physical location.

For example:

```json
{
  "resources": {
    "commonplace.workspace": {
      "kind": "workspace",
      "repository": "commonplace-systems/commonplace"
    }
  },
  "deployments": {
    "commonplace.primary": {
      "participant": "commonplace",
      "workspace": "commonplace.workspace",
      "placement": {"node": "workstation"},
      "executor": {"profile": "workerclaude-v1"}
    }
  }
}
```

The workstation's local binding may resolve that workspace to a worktree. A pod executor may resolve it to a synchronized checkout. The portable topology need not change identity when the physical realization changes.

## The bootstrap problem

`cp-serve` appears inside the proposed topology, but Commonplace must already be available to read a Commonplace-hosted topology. This creates a small, unavoidable bootstrap kernel.

The node needs enough local configuration to recover:

```text
node identity
data directory
active topology document ID
controller execution profile
last-known-good ratified topology revision
```

Bootstrap starts the substrate and topology reader. The topology can then describe and instantiate everything above that kernel.

Loss of contact with the topology document must not be interpreted as a new empty topology. The runtime should continue from its last-known-good ratified revision, report degraded observation, and refuse destructive reconciliation.

## Proposed top-level shape

The exact schema should remain small, but the document needs distinct collections for distinct lifetimes:

```json
{
  "schema_version": 1,
  "topology_id": "jes-workstation",
  "participants": {
    "boss-clod": {
      "kind": "agent",
      "roles": ["dispatcher", "relay", "host-health"]
    },
    "commonplace": {
      "kind": "agent",
      "roles": ["builder", "reviewer"]
    },
    "commonplace-plan": {
      "kind": "agent",
      "roles": ["designer", "ranker"]
    },
    "cp-serve": {
      "kind": "service"
    }
  },
  "resources": {
    "commonplace.workspace": {
      "kind": "workspace",
      "repository": "commonplace-systems/commonplace"
    }
  },
  "deployments": {
    "commonplace.primary": {
      "participant": "commonplace",
      "workspace": "commonplace.workspace",
      "desired": {"mode": "singleton", "count": 1},
      "executor": {"profile": "workerclaude-v1"},
      "placement": {"node": "workstation"}
    }
  },
  "edges": {
    "commonplace-briefs-sol": {
      "kind": "dispatches",
      "from": {"participant": "commonplace"},
      "to": {"deployment_class": "sol"}
    },
    "commonplace-reports-plan": {
      "kind": "reports",
      "from": {"participant": "commonplace"},
      "to": {"participant": "commonplace-plan"}
    }
  }
}
```

The actual process list, deployment IDs, PIDs, tmux windows, MCP connections, heartbeat times, and health verdicts do not belong in this desired-state document. They are observations keyed back to the stable IDs above.

## Reconciler shape

The first reconciler can remain deliberately unpowerful:

```text
ratified topology revision
        +
node-local bindings
        +
current observations
        |
        v
pure divergence report
        |
        v
optional proposed actions
```

It should produce explanations such as:

```text
commonplace.primary
  desired: one instance using workerclaude-v1
  observed: zero matching deployments
  last receipt: deployment dep-123 exited abnormally at 03:14
  verdict: crashed
  proposed action: instantiate replacement
  authority required: instantiate(commonplace.primary)
```

The proposal or a human may approve the action. A future controller can apply a standing restart policy if explicitly authorized. The reporter itself never acquires that authority merely by detecting divergence.

Instantiation also needs idempotent adoption semantics. Every launch should receive:

- a deployment slot ID;
- an immutable topology revision;
- a fresh deployment ID;
- a launch-attempt ID;
- a runtime profile ID;
- and a place to write its startup and exit receipts.

PID, tmux window, and worktree path are observed handles, not identities.

## Relationship to storage ephemerality

The topology design is a concrete client of the tiered storage proposal. Its data naturally spans different retention obligations:

| Topology information | Storage treatment |
|---|---|
| Ratified topology revisions | Durable CoreStore control facts plus durable object closure |
| Editable topology CRDT history | Durable or compactable HistoryStore according to policy |
| Deployment intents and lifecycle receipts | Durable CoreStore |
| Active deployment leases | CoreStore authority plus LeaseStore payloads |
| Heartbeats and process observations | Ephemeral memory or LeaseStore |
| Health projections and divergence reports | CacheStore |
| Generated MCP configuration | Disposable filesystem projection |
| Agent session work later pinned by a chit | LeaseStore followed by durable promotion |

This division reflects the same rule:

> Logical meaning, retention obligation, and physical residency are separate dimensions.

The ratified statement that `commonplace.primary` should exist is durable. A heartbeat saying process 4182 was alive two seconds ago is not. They should not share a single undifferentiated lifecycle merely because both concern topology.

## Answers to the proposal's open questions

### 1. Is `expect` per participant or fleet-wide?

The document is a whole desired-state revision. The expectation belongs to each deployment slot or deployment class. Participants persist independently of whether they presently have an active incarnation.

### 2. Should topology generate `mcp-config-*.json`?

Yes, as a disposable projection.

The topology should contain stable endpoint and routing declarations plus references to required credentials. Secret values must remain outside the topology and be resolved by the authorized launcher. Generated MCP configuration is rebuildable output, never another authority source.

### 3. What should happen when maintenance finds a crash?

Use three rungs:

1. Report the divergence and supporting evidence.
2. Produce a proposed, reproducible reconciliation action.
3. Apply it only through a controller holding the required capability or an explicitly authorized restart policy.

The first implementation should stop after rung one except when a human explicitly invokes `instantiate` for a named deployment slot and topology revision.

### 4. Which currently opaque windows belong in topology?

Include something when it participates in a relationship Commonplace needs to explain, instantiate, or monitor. Do not turn topology into an inventory of every terminal.

A temporary debugging shell may remain outside topology. A service consumed by declared participants belongs. An externally managed process may appear as an `external` participant or resource if its health affects the declared system.

## Recommended implementation sequence

1. **Enumerate the real graph.** Finish the measured inventory without prematurely forcing every observed window into a permanent role.
2. **Define distinct IDs.** Introduce participant, deployment slot, deployment, and runtime-instance identifiers.
3. **Define topology schema v1.** Use top-level maps for participants, resources, deployment intents, and typed edges.
4. **Add ratification.** Make one pinned, schema-valid topology moment the active desired state.
5. **Build sensors.** Observe tmux, processes, worktrees, MCP peers, configuration projections, and launcher receipts with timestamps and provenance.
6. **Build the pure reporter.** Compare active intent with observations and emit precise divergence without side effects.
7. **Generate MCP config.** Treat it as a local, secret-free projection from topology plus local bindings.
8. **Wrap `workerclaude()` as a governed profile.** Preserve OOM and environment safety behavior and create durable launch receipts.
9. **Add explicit instantiate.** Launch one named deployment slot from one named topology revision under a checked capability.
10. **Introduce deployment leases and attenuated principals.** Make pod and host deployments instances of the same lifecycle model.
11. **Consider automatic repair last.** Add restart or retirement policies only after matching, receipts, leases, and authority checks are dependable.

## Final assessment

The proposal should be adopted in direction and amended in structure.

Its major achievement is discovering that Commonplace needs both a declared world and an observed world. Its remaining mistake is attempting to represent those worlds—and identity, deployment, authority, and placement—inside one participant record.

Separate those planes, activate topology through a pinned revision, and make instantiation select governed runtime profiles. Then Commonplace-defined topology becomes more than a replacement for tmux naming: it becomes the organizational and operational substrate that attenuated identities, leased agent deployments, reconciliation, and eventually self-maintaining agent fleets can safely share.
