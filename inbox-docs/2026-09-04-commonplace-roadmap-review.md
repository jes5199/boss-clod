# Commonplace roadmap review — 2026-09-04

**Author:** Astra, at Jes’s request.

**Recommendation:** Keep the core architecture. Change the order of work so deployed, end-to-end behavior guides the remaining implementation. Give implementers more freedom over code shape while retaining explicit security boundaries and independent review.

This document records recommendations, not adopted project decisions or instructions to override existing gates.

## Review scope and evidence

This review examined the roadmap and selected implementation paths for deployment, identity, sessions, sharing, persistence, and recovery. The principal source snapshots were:

| Repository | Reviewed revision | Role |
| --- | --- | --- |
| `commonplace-plan` | `b528d6c617bdcc51f7d348fa8f33573230eaf74a` | Roadmap and implementation briefs |
| `commonplace-next` | `4534324173e0c8f7e2844c86da60795c32d93da9` | Application and integration code |
| `commonplace-log` | `79edae4a565976e3c9a363902165548b72dc584d` | Storage Worker and backup registration |

Supporting repository trees and dependency pins were also inspected. This was a source review: the application suites were not run, and live Cloudflare deployment state was not independently verified. Findings about runtime outcomes below are identified as code-derived findings or proposed acceptance criteria. Changes after these revisions may supersede them.

The [reviewed roadmap](https://github.com/commonplace-systems/commonplace-plan/blob/b528d6c617bdcc51f7d348fa8f33573230eaf74a/docs/plans/2026-09-04-roadmap-status.md) correctly identifies external login and the first app deployment as the largest unknowns. The recommendations concentrate on the boundaries between those tracks.

## 1. Move two-browser acceptance and cold-start recovery forward

### Finding

`TWO-HUMANS` follows the sharing surface in Track A, while `SLEEP-FIX` appears late in Track C. These are useful discovery tools early in integration, as well as final acceptance conditions.

There is already a real Chromium test for editing, reloading, and restarting a Realm. It uses local SQLite and test Access identities. It is a useful foundation, but it does not establish the same behavior on the deployed storage and identity paths.

Source: [browser durability acceptance](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/test/integration/browser_markdown_durability_test.exs).

### Recommendation

Exercise deployed editing and recovery as soon as the app can be served. Start with internal Access identities, then reuse the journey for external AuthKit identities. Do not wait for the sharing UI to begin two-browser acceptance.

The next concrete milestone should be:

> Two browsers edit the deployed app; replace the container; both reopen the same document and continue editing.

### Acceptance

- Two distinct authenticated users edit one document and both edits converge.
- Reloading either browser retains the edits.
- Replacing the application container while retaining its durable store preserves the document and permits continued editing.
- A sleeping container wakes and serves a usable mirror.
- Results identify the deployed application revision and storage Worker revision.

This should extend the existing acceptance work, avoiding a separate testing framework.

## 2. Make AuthKit own the complete session lifecycle

### Finding

The revised `AUTHKIT-1` prompt addresses provider-specific token claims and extracts `Session.establish/2` from the current authentication function. That is necessary, but later principal derivation and remote membership resolution also call `AccessAuthentication` directly.

A successful callback therefore does not, by itself, establish that an external user can reload, open a document, or cross a Realm boundary. The broader AuthKit brief recognizes the need for an application identity session, but the concrete rounds do not fully specify its lifecycle.

Sources: [session implementation](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/lib/commonplace_next/web/session.ex), [Access authentication](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/lib/commonplace_next/web/access_authentication.ex), [AuthKit implementation prompt](https://github.com/commonplace-systems/commonplace-plan/blob/b528d6c617bdcc51f7d348fa8f33573230eaf74a/docs/plans/sol/AUTHKIT-1/prompt.txt), [AuthKit brief](https://github.com/commonplace-systems/commonplace-plan/blob/b528d6c617bdcc51f7d348fa8f33573230eaf74a/docs/plans/2026-09-03-AUTHKIT-brief.md).

### Recommendation

Assign ownership of the complete external identity session, including how subsequent requests recover a verified principal, how editor admission uses it, and how remote membership resolution validates it.

Share JWT signature verification and JWKS machinery while keeping provider claim policies explicit. Relax the instruction forbidding a separate provider verifier or policy module. A single function with conditionally optional Access claims is one possible implementation; it should not be treated as inherently safer than small provider policies over shared cryptographic machinery.

### Acceptance

- An external user logs in, follows the redirect, reloads, opens a document, and reconnects its WebSocket without a Cloudflare Access assertion.
- Session expiration and logout stop further authorization; reauthentication restores permitted access.
- The same external account resolves correctly across Organizations and separate Realms.
- Unknown external identities receive the intended named refusal.
- Identity lookup uses the intended `(provider, issuer, subject)` key.
- Existing Access behavior remains correct, including rejection of assertions missing its required claims.

The criterion is a usable authenticated editing session, not only a verified token returned by the callback.

## 3. Correct multiple-grant authorization before building the sharing UI

### Code-derived defect

At the reviewed application revision, `ExternalGrant.authorize/3` first calls `admission(grantee_cell_id)`. Admission selects the first unexpired, unrevoked grant. Only then does authorization compare that grant with the requested document and action.

For example:

1. Editor E receives a live grant for document D1.
2. E receives another live grant for document D2.
3. E requests D2.
4. Admission selects D1’s grant, and authorization rejects D2 as `:unentitled` without considering its valid grant.

The gateway uses this authorization function. Existing sharing tests check refusal of an unshared second document, which does not cover acceptance of two independently shared documents. This finding follows from the source; it was not reproduced in a running application during this review.

Sources: [grant lookup and authorization](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/lib/commonplace_next/organization/external_grant.ex), [gateway enforcement](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/lib/commonplace_next/realm/gateway.ex), [sharing tests](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/test/integration/x_realm_external_grant_test.exs).

### Recommendation

Select candidate grants for the requested resource and action, then evaluate their validity. Gateway admission and authorization for a specific document have different selection requirements and should express them explicitly.

### Acceptance

- Share D1 and D2 with the same Editor Cell; both are usable.
- Revoke D1’s grant; D1 is refused and D2 remains usable.
- An unshared document remains inaccessible.
- Grant lookup order cannot change the effective permissions.
- Where multiple grants cover the same document, a valid grant can authorize its permitted action without being masked by an unrelated or insufficient grant.

This correction belongs before, or alongside, the remaining sharing implementation.

## 4. Define backup completion as application recovery

### Finding

The backup brief requires a restore into a fresh realm and comparison of frontiers and entry IDs. That is valuable evidence of log recovery. Application recovery additionally depends on being able to reopen Organizations, resolve memberships, preserve revocations, and establish fresh sessions against restored state.

There is also an explicitly unfinished registration-repair path. Realm creation can mint a read capability and then fail to write it to KV. The code returns `registry_write_failed` and references `BACKUP-1b-iii` for retroactive repair, but that item is absent from the short roadmap. Existing realms also need a route into the backup inventory.

Sources: [backup brief](https://github.com/commonplace-systems/commonplace-plan/blob/b528d6c617bdcc51f7d348fa8f33573230eaf74a/docs/plans/2026-09-04-BACKUP-1-brief.md), [realm creation and registration](https://github.com/commonplace-systems/commonplace-log/blob/79edae4a565976e3c9a363902165548b72dc584d/worker/src/realm/realm_auth.ts), [registry contract](https://github.com/commonplace-systems/commonplace-log/blob/79edae4a565976e3c9a363902165548b72dc584d/worker/src/realm/registry.ts).

### Recommendation

Retain the log-level restore comparison and add an application-level recovery rehearsal. Include existing-realm registration and failed-registration repair explicitly in backup scope. A named failure provides observability; the operator still needs a working recovery mechanism.

### Acceptance

- Restored frontiers and entry IDs match the backed-up state.
- The application opens the restored Organization and reads its documents.
- Membership identities and epochs remain intact.
- Grants revoked in the backed-up state remain revoked after restoration.
- Fresh authorized sessions can edit; stale runtime credentials are renewed or refused according to the intended lifecycle.
- A registry-write failure can be repaired and the affected realm is subsequently backed up.
- Existing realms intended for retention are included, with inventory reconciliation exposing omissions.

This is a proposal to strengthen the existing restore rehearsal, not evidence that per-boot keys must become permanent.

## 5. Preserve behavioral guarantees while loosening implementation constraints

### Finding

The inspected prompts prescribe occurrence counts, byte-identical files, exact extractions, and stopping on any corpus difference. These constraints can protect narrow changes. They become counterproductive when an integration change needs to alter the old boundaries themselves.

AuthKit illustrates this: the roadmap records two stopped attempts caused by defective briefs, while its remaining work spans provider verification, session establishment, later requests, and remote identity handling.

Some source comments also preserve obsolete operational claims. In particular, session and Access comments still describe the production cookie secret as hardcoded, although runtime configuration now requires `SECRET_KEY_BASE`. Keeping an old explanation in the active source can mislead the next implementer.

Sources: [roadmap](https://github.com/commonplace-systems/commonplace-plan/blob/b528d6c617bdcc51f7d348fa8f33573230eaf74a/docs/plans/2026-09-04-roadmap-status.md), [AuthKit prompt](https://github.com/commonplace-systems/commonplace-plan/blob/b528d6c617bdcc51f7d348fa8f33573230eaf74a/docs/plans/sol/AUTHKIT-1/prompt.txt), [session comments](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/lib/commonplace_next/web/session.ex), [runtime configuration](https://github.com/commonplace-systems/commonplace-next/blob/4534324173e0c8f7e2844c86da60795c32d93da9/config/runtime.exs).

### Recommendation

Keep:

- Pinned implementation bases and reviewable diffs.
- Explicit authority and security boundaries.
- Behavioral regression coverage and meaningful negative controls.
- Independent review of implementation and evidence.
- Clear distinction between landed, pinned, and deployed code.

Change the dispatch process so an implementer can propose necessary adjacent edits, explain them, and have the reviewer approve the resulting diff. Reserve exact code-shape constraints for cases where that shape protects an identified invariant. A changed occurrence count should prompt investigation rather than automatically require a new planning round.

Update source comments to describe current behavior. Preserve superseded reasoning in Git history or a decision record.

Any process change should be explicitly adopted by the project; this review does not authorize agents to ignore existing controls.

## Recommended sequence

These are acceptance milestones and can share implementation work across the existing tracks.

| Order | Milestone | Evidence of completion |
| --- | --- | --- |
| 1 | Deploy internal editing and exercise recovery | Two authenticated browsers converge; container replacement and wake-up preserve usable documents |
| 2, alongside 1 | Complete external-session behavior | AuthKit login, reload, editor admission, reconnect, and cross-Realm resolution work without an Access assertion |
| 3 | Finish sharing, including multiple grants | Two shared documents work; revoking one does not disable the other; unrelated documents remain inaccessible |
| 4 | Complete invitations and application restore | Invited users obtain the intended Membership; restored Organizations remain usable and preserve recorded permissions |
| 5 | Admit external beta users | The deployed external-user journey, backup coverage, restore rehearsal, and operational procedures are demonstrated |

Keep chit and further library extraction off the beta path. Preserve the existing architecture while testing how its components compose under actual deployment conditions.

## Schedule confidence

Treat the roadmap’s approximately two-day estimate as an optimistic target until a deployed external user completes the editing and recovery journey. Round count is useful for dispatch, but the remaining integration work has greater uncertainty than a typical bounded library change.

Re-estimate after the first deployed AuthKit editing session and the first successful container-replacement rehearsal. Those observations will provide a stronger basis for a date than extrapolating solely from recent landing throughput.
