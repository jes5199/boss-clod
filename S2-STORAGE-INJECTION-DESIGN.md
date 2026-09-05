# S2 — host-side-once session storage + per-pod injection: design for boss's read

> The (D)-ONCE injection mechanism, host-side, ZERO credentials to design.
> Written to SATISFY boss's four storage-read items (#13230) + plan's
> installation_id item + the initiation-bound relay-provenance
> requirement — so boss's read CONFIRMS, not discovers. This is the
> design; the code (a loader like `MediatorCredentials`) follows boss's
> read of the design, then S1b lands a real session into the location
> this defines, then S3 tests injection-attestation.
>
> ⛔ No credential is touched to DESIGN this. The codex session SHAPE is
> known from ~/.codex/auth.json's structure (key names only, no values):
> `tokens.{access_token, refresh_token, id_token, account_id}` +
> top-level `OPENAI_API_KEY` (null) + `last_refresh`. S0.5 established
> `installation_id` is copyable SOFTWARE state (not hardware-bound).

## Boss's item ① — WHERE the durable host-side session lives

- A DEDICATED runner-owned directory, NOT `~/.codex` (that is the live
  fleet credential — untouched, per every prior stage). Proposed:
  a runner-service-owned dir outside ANY git tree (⛔ 1110753a closes
  staging, not existence — the location must be structurally outside a
  repo, not merely gitignored). Concrete candidate for boss to accept or
  relocate: `$XDG_STATE_HOME/commonplace-runner/d-once-session/` or a
  runner-service dir — boss names the final path; the design's
  requirement is: outside a git tree, mode 0700 dir / 0600 files, owner =
  the runner service principal, never world/group readable.
- The durable session is the FULL device-auth result (refresh + access +
  id + account_id + installation_id) — the "durable stays home" half.
- A NAMED lifecycle, not "expires eventually" (item ② below covers
  teardown): created by S1b, read by S2's injector, removed at
  end-of-discovery by an explicit named teardown.

## Boss's item ② — WHAT injects the per-pod token, proves-never-logs

- A loader (`DOnceSessionInjector`, the MediatorCredentials pattern):
  reads the durable session, extracts ONLY what a pod needs, injects it
  per-pod. It NAMES key paths in every diagnostic, NEVER values — with a
  SENTINEL TEST that can go red: fixtures containing SECRET-ACCESS /
  SECRET-REFRESH, `refute inspect(result_or_error) =~ "SECRET"`, exactly
  MediatorCredentials' proven standard.
- The injection primitive is codex's own: `--with-access-token` reads
  the short-lived access token from STDIN (never a file, never an env
  the pod can dump to disk casually), plus the `installation_id`
  provisioned into the pod's CODEX_HOME (the copyable bundle S0.5
  established). ⇒ the pod holds `access_token + installation_id`, NOT the
  refresh token.

## Boss's item ③ — RED-CAPABLE assert the REFRESH token can't reach a pod

- The injector's contract: it extracts `access_token` and
  `installation_id` and REFUSES to emit `refresh_token` — by
  construction, not by care. A test asserts the refresh_token value
  (a sentinel) NEVER appears in the injected bundle, the pod env, the
  pod CODEX_HOME, or any log — a property that CAN GO RED (feed a
  sentinel refresh token, assert its absence everywhere the pod can see).
  This is the whole point of once-with-injection made a testable
  invariant, not a design intention.

## Boss's item ④ — REAP of what DOES land in a pod

- What lands in a pod: the short-lived access_token (via stdin →
  codex's CODEX_HOME/auth.json inside the pod) + installation_id. Both
  live in the pod's reapable home; A1b/A1c's reap (removes the entire
  pod home before deletion) already reaps them. The design ASSERTS: after
  reap, no pod-home artifact contains the access_token — the same
  reap-removes-the-home property, with a red-capable check.
- ⚠️ The access token is SHORT-LIVED by design; even un-reaped its window
  is bounded. Reap is belt; short-lived is braces.

## Plan's installation_id item + S0.5 consequence

- The injection bundle is `access_token + installation_id`, NOT token
  alone (S0's attestation-binds-to-installation + S0.5's software/copyable
  finding). installation_id is a STABLE identifier — boss's storage read
  covers it as part of the bundle (it is not a secret like the refresh
  token, but it IS the thing that makes N-pods present as one
  installation — the S3 fan-out watch).

## The initiation-bound relay-provenance (S1b creation, referenced here)

- S1b CREATES the durable session via device-auth, and per the ruled
  mechanism the sign-in is JES-INITIATED (he asks, then receives; an
  unprompted code fails by construction — the channel-compromise-resistant
  property). S2 consumes the session S1b created; S2 does not itself
  relay a code. Named here so the two stages' trust boundaries are one
  picture.

## What S2's read CONFIRMS (the deliverable of this design)

Boss reads this design and either accepts it or names the specific change
(the path, the mode, the injector contract) — so the CODE is written to a
read-and-cleared design, and S1b's real session lands into a location
already read. Every credentialed act (S1b creation, S3 test) still stops
for its own boss read; nothing here is a clearance, it is the design his
read confirms.
