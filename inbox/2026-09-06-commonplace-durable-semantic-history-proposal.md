# Commonplace histories that outlive their tools

**Date:** 2026-09-06  
**Status:** Design proposal  
**First application:** Agent coordination and, later, Pods  
**Initial implementation home:** `commonplace-next`

## 1. The idea

Commonplace should preserve the meaning and basic readability of work as the software around that work changes.

A coding agent, importer, workflow, or specialized application can produce durable records. Those records should remain inspectable after the original integration is upgraded, replaced, or removed. Software that understands their semantics should also be able to reconstruct the relevant application state.

This proposal combines two mechanisms:

1. **Domain event normalization:** adapters translate external observations into a versioned semantic vocabulary; shared domain logic enforces the meaning of the resulting history.
2. **Durable fallback presentation:** historical records include a small, inert representation that a basic client can display without executing the producing integration's code.

The first useful application is the Commonplace coding coordinator. It provides a concrete place to establish the contract before generalizing it to other applications.

The design borrows from [bb's provider bridge](https://github.com/get-bb/bb/blob/main/docs/provider-bridge-protocol.md) and [provider plugin API](https://github.com/get-bb/bb/blob/main/docs/provider-plugin-api.md). In bb, bridges translate provider output into semantic deltas; a common assembler owns timeline invariants. Persisted presentation metadata lets history remain readable when its provider plugin is unavailable. The recommendation here adapts those boundaries to Commonplace's existing authority, log, and projection model.

## 2. Fit with the existing architecture

The existing Commonplace stack already separates storage, interpretation, command preparation, and authority.

| Component | Responsibility in this proposal |
| --- | --- |
| Provider adapter | Translate a provider's native messages into domain observations; preserve source identity and relevant evidence. |
| Coordinator domain logic | Match observations to work and attempts; enforce lifecycle and deduplication rules; prepare semantic events. |
| Cell admission and host integration | Authenticate and authorize requests, serialize relevant admission decisions, append accepted events, and supervise execution. |
| `commonplace-log` | Preserve validated entries, provide writer ordering and retry guarantees, and synchronize replicas of the same log. |
| `commonplace-log-reducer` | Provide generic deterministic projection, epoch, and checkpoint mechanics. |
| Work-domain reducer | Derive task, attempt, conversation, and artifact-reference state from accepted domain operations. |
| History viewer | Display fallback records and optionally select an installed richer renderer. |

The domain vocabulary belongs above the generic log and projection engine. The foundation packages do not need to recognize agent providers, tool names, task statuses, or presentation widgets.

The distinction between preparing and committing events also remains intact. `Commonplace.Doc` is pure command preparation; authority and runtime effects belong in the composing host and Cell path. A provider observation cannot grant itself permission to write a Document.

These boundaries follow the current [log contract](https://github.com/commonplace-systems/commonplace-log/blob/main/README.md), [reducer contract](https://github.com/commonplace-systems/commonplace-log-reducer/blob/main/README.md), [Document responsibilities](https://github.com/commonplace-systems/commonplace-doc/blob/main/README.md), and [Cell admission model](https://github.com/commonplace-systems/commonplace-cell/blob/main/docs/proposals/2026-08-24-commonplace-cell-mvp-spec.md).

## 3. Start with a work-history profile

Define one small work-domain profile, initially used by the coordinator. The following event names are illustrative, not existing APIs or a settled wire format.

| Concept | What it records |
| --- | --- |
| `work.requested` | An admitted request for work, including its relevant inputs. |
| `attempt.started` | A particular execution attempt began. |
| `message.recorded` | A message associated with work or an attempt. |
| `invocation.started` | An identified tool or external operation began. |
| `invocation.finished` | Its reported result, failure, or interruption. |
| `work.delegated` | A relationship to separately identified child work. |
| `artifact.recorded` | A result artifact and its exact reference. |
| `attempt.finished` | The execution attempt ended, with an explicit outcome. |

Provider adapters would map Codex, Claude, and later providers into this vocabulary. A shared assembler would own identity mapping, start/completion matching, bounded stream accumulation, and deterministic preparation of domain records. The host would own durable admission and append.

A provider's turn boundary, a process exiting, and a task satisfying its acceptance criteria are distinct facts. In particular, `attempt.finished` does not automatically mean that the requested work has been accepted as complete. A later workflow policy can record that decision separately.

The vocabulary should preserve distinctions that affect coordination. It should also allow versioned, namespaced domain extensions whose contents remain inspectable. The prototype should add only event kinds it actually consumes.

### Compact history and detailed evidence

Continue the coordinator's earlier direction: persist compact semantic records in the canonical journal, and store detailed provider output as referenced artifacts.

Live text can stream to clients without making every token or terminal escape sequence a permanent semantic operation. The implementation must state what can be lost before a stream chunk is durably recorded. If resumable partial output matters, persist bounded chunks or checkpoints of the transcript and identify them explicitly.

Raw provider output remains useful for debugging a translation error. It should retain a link to the normalized records it informed. Correcting the interpretation later should create an explicit correction or a versioned derived view; it should not silently rewrite accepted historical entries.

## 4. A record carries meaning, provenance, and a fallback view

A durable work record has three distinct concerns:

- **Meaning:** versioned structured data used by the domain reducer.
- **Provenance:** the work, attempt, operation, source, and input revision to which the observation belongs.
- **Presentation:** a bounded, inert description of the historical record.

For example, a test invocation might produce the following schematic operation. It belongs inside the work profile's existing projection-operation envelope; it is not a replacement for the log or reducer envelope. IDs and revision values below are readable placeholders.

```json
{
  "type": "work.invocation.finished",
  "schema_version": 1,
  "work_id": "work-42",
  "attempt_id": "attempt-3",
  "invocation_id": "invocation-8",
  "caused_by": "invocation-start-record",
  "source": {
    "adapter": "codex",
    "adapter_version": "example-version",
    "source_event_id": "provider-event-91"
  },
  "result": {
    "kind": "test-run",
    "outcome": "failed",
    "exit_code": 1,
    "passed": 148,
    "failed": 2,
    "input_revision": "tested-tree-revision"
  },
  "artifacts": [
    {
      "id": "report",
      "document_id": "report-document-uuid",
      "revision": "report-commit-id",
      "label": "Test report"
    }
  ],
  "presentation": {
    "format": "commonplace.history-card/v1",
    "title": "Test run finished",
    "summary": "148 passed; 2 failed.",
    "links": [
      {
        "artifact_id": "report",
        "label": "Open test report"
      }
    ]
  }
}
```

The example profile names and fields need implementation review before becoming a protocol. The immediate architectural requirement is the separation of these concerns.

### Presentation rules

Begin with text, labeled scalar fields, lists, and labeled artifact references. A generic history viewer can render that vocabulary as a card or a CLI entry. Add tables or other primitives when an actual record needs them.

The fallback contains values. It contains no handler bindings, scripts, functions, capabilities, or instructions to install code. Rich rendering is selected through an explicitly installed, trusted renderer registry.

The accepted operation's structured data is authoritative for domain state. Its fallback text is a historical display snapshot. For known event kinds, the domain implementation should generate the fallback from the validated payload when preparing the record, keeping both in the same accepted operation.

A title, label, or summary needed to understand the past should be captured at the time. Resolving every label through current plugin templates or current Document titles would make old history change appearance as unrelated software and data change.

The source fields are provenance claims. The Cell host binds relevant identity to authenticated context; writing a provider name into JSON does not authenticate the report or prove its result.

### Artifact references and retention

References to historical evidence should identify exact revisions or immutable blobs, rather than only a live Document's current head.

A reference is useful only while its target remains retrievable. When retention and garbage collection are introduced, the profile must declare which referenced revisions need preservation and how those requirements cross Document boundaries. This proposal does not assume that existing protected-root rules already provide cross-Document retention.

If an artifact is missing or no longer authorized for the reader, the viewer should retain the record's explanation and show that the attachment is unavailable. Possessing a reference does not grant read authority.

## 5. Readability, replay, and execution are separate capabilities

Removing a provider integration should leave ordinary work-domain records replayable by the installed work reducer. Removing a specialized semantic reducer is a stronger loss.

| Available software | What remains possible |
| --- | --- |
| Work reducer and specialized renderer | Reconstruct domain state and show the rich interface. |
| Work reducer and generic viewer | Reconstruct domain state and show fallback records. |
| Generic viewer only | Inspect recorded fallback descriptions and structured payloads; report that specialized state cannot be reconstructed. |

A fallback display cannot teach a client an arbitrary missing algorithm. An unfamiliar state-changing operation must not be silently skipped while the client claims its derived state is complete.

The generic history reader therefore needs a route to the stored record that does not depend on successfully executing that record's specialized reducer. That can be a domain-aware history API exposing its fallback values and opaque payload. It does not require weakening the generic reducer's validation rules.

Historical replay reconstructs state without executing external operations. Viewing an old shell invocation must never rerun it. A future “run again” control creates a new request and passes through current Cell admission, with a new attempt identity and current authority.

Browser actions, CLI calls, MCP tools, and agents should invoke the same domain verbs through the ordinary Cell boundary. Common interfaces do not imply equal permissions; each caller supplies the authority it actually holds.

## 6. Ordering, retries, and recovery

Commonplace's log provides ordering within each writer's sequence. It does not impose a global order across writers, and the current generic reducer supports a single writer. See the [log guarantees](https://github.com/commonplace-systems/commonplace-log/blob/main/README.md) and [reducer constraints](https://github.com/commonplace-systems/commonplace-log-reducer/blob/main/README.md).

For the first coordinator, use one authorized writer for a work journal. Multiple execution workers submit observations to that host; they do not acquire the journal writer's identity. Admission order defines that journal's sequence, while explicit references describe causation and delegation.

This sequence records the order in which the coordinator accepted observations. It does not prove that independent external actions happened in that order. A UI may sort separate histories for convenience, but wall-clock sorting must not become a hidden semantic ordering rule.

Distinguish three identities:

| Identity | Meaning |
| --- | --- |
| Work ID | The requested objective across its execution attempts. |
| Attempt ID | One execution of that objective. |
| Source-operation identity | One observation or operation within a source session or attempt, stable across redelivery. |

Provider-native IDs may be reused after a restart. Deduplication therefore needs a documented scope, such as provider session plus attempt plus source event ID. Where the provider supplies no reliable identity, the adapter needs a durable ingestion cursor or another explicit recovery contract; arbitrary timestamp hashes are insufficient.

Use existing prepared-append and exact-retry facilities for accepted operations. Durable deduplication state and source-to-domain mappings must survive the crash windows covered by the coordinator's recovery contract. A crash after append but before acknowledging a worker must not turn its redelivery into a second completion.

Journal idempotency does not make arbitrary external effects exactly-once. If a process vanishes after possibly performing an action, record the attempt as interrupted or its result as unknown until reconciliation establishes the outcome. Do not infer success from silence.

Replica synchronization retains its existing scope: replicas of the same logical log exchange entries. Importing observations into a different Document or Cell uses destination admission and destination-authored events, preserving source references as provenance. This follows the [Document errata on retry and destination sovereignty](https://github.com/commonplace-systems/commonplace-doc/blob/main/docs/spec-errata.md).

## 7. First implementation and acceptance experiment

Implement the work profile, adapter interface, assembler, reducer, and minimal history viewer together in the coordinator portion of `commonplace-next`. Extract a separate package once another consumer demonstrates a stable semantic boundary.

The first implementation should be small enough to exercise with one Codex task:

1. Admit a work request and start one identified execution attempt.
2. Normalize its messages, one invocation, an output artifact, and its terminal outcome.
3. Persist the semantic records and exact artifact references.
4. Rebuild task state from the journal using the work reducer.
5. Display the same history through a generic view.
6. Disable the provider integration and verify that history, outcome, and artifacts remain understandable.

Use a second adapter or a small replay fixture to demonstrate that the assembler contract is not accidentally defined by Codex-specific message shapes.

The relevant acceptance cases are behavioral:

| Case | Required result |
| --- | --- |
| Duplicate completion delivery | One logical completion remains in domain state. |
| Crash after append, before acknowledgment | Retrying settles the same accepted operation. |
| Provider integration removed | Stored work history still replays through the independent work reducer and displays through the generic viewer. |
| Specialized renderer removed | The fallback remains readable. |
| Unknown semantic version | History remains inspectable; unsupported state reconstruction is explicit. |
| Artifact title changes | The historical label stays stable and its exact revision reference stays the same. |
| Artifact is unavailable | The record still explains what happened and exposes the missing attachment. |
| Replay of an invocation | State is reconstructed without starting a process or calling an external service. |
| Worker disappears during execution | The outcome remains interrupted or unknown until supported by evidence. |

These are the first proof obligations, not a request to build a universal event framework. The proposal can be implemented alongside coordinator work without becoming a prerequisite for the collaborative editor beta.

## 8. What can generalize afterward

Once the work profile is useful, apply the pattern to other domains:

- **File import and export:** record the source, codec decision, exact input/output references, result, and readable import receipt.
- **Chit operations:** retain semantic commit references and a basic history description while specialized graph viewers evolve.
- **Workflow execution:** preserve invocation relationships, outcomes, and evidence independently of the workflow editor.
- **Application extensions:** let specialized events carry a durable base representation while richer interfaces remain replaceable.

Each domain owns its semantic vocabulary and reducer. They can share a small fallback presentation contract and common reference conventions when experience demonstrates that those conventions fit.

The next protocol decisions should be driven by the coordinator prototype: the precise observation grammar, the work profile's projection envelope, the smallest fallback vocabulary, identity persistence across crashes, and the reference/retention contract.

The intended outcome is concrete: users can change agents, interfaces, and integrations while retaining an understandable account of their work.

