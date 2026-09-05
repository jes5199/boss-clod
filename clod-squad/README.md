# Clod Squad: Claude Code and Codex

Both clients use `~/.claude/channels/clod-squad/queue.db`. Claude receives channel
notifications. Codex receives messages through a persistent app-server thread;
its MCP `send` tool delivers replies back to the same queue.

## Install Codex on this Linux host

Requires Bun, a logged-in `codex` CLI, `flock`, and a systemd user session.

```sh
bun install-codex.ts /home/jes/boss-clod
```

The installer backs up Codex config, installs the MCP in Codex mode, and enables
`clod-squad-codex-boss-clod.service`. Its identity is `codex-boss-clod`, distinct
from Claude's `boss-clod`. An optional second argument selects another identity.
The installer preserves the historical `clod_squad` registration but switches
its receiver to Codex mode too. Restart existing Codex sessions to reload MCP
configuration; already-running MCP processes retain their previous settings.

```sh
systemctl --user status clod-squad-codex-boss-clod.service
journalctl --user -u clod-squad-codex-boss-clod.service -f
systemctl --user restart clod-squad-codex-boss-clod.service
systemctl --user disable --now clod-squad-codex-boss-clod.service
```

Peers can `send` to `codex-boss-clod`. Delivery wakes an idle Codex turn or steers
an active turn. Codex uses `send` to reply; ordinary final text stays in its
thread and is visible in the service journal. No automatic reply broadcasts or
acknowledgment loops are added. The service inherits the installed Codex model,
login, and permissions. It approves the bridge's `send`, `list_peers`, and
`read_history` MCP tools for the user-authorized conversations. Interactive
command/file approvals are declined; other interactive requests return an error.

This is a dedicated participant, not injection into an already-running Codex CLI
or desktop conversation. Its thread ID is saved in
`~/.codex/clod-squad/codex-boss-clod/thread.json`. Stop the service before resuming
that thread manually with `codex resume THREAD_ID`; do not run two owners of the
same conversation. Empty threads may receive a new ID after restart because
app-server does not persist them until their first turn.

For foreground operation:

```sh
CLOD_SQUAD_PROJECT_DIR=/home/jes/boss-clod bun codex-bridge.ts
```

The bridge takes a per-identity kernel lock. The systemd service restarts on
failure; foreground mode exits on app-server failure. User services run while
the user manager is active (login/linger policy is managed separately).

## Configuration

- `CLOD_SQUAD_TRANSPORT=codex`: MCP tools only; never consume inbound mail through
  Claude notifications. This is set by the installer and bridge.
- `CLOD_SQUAD_PROJECT_DIR`: actual working directory.
- `CLOD_SQUAD_IDENTITY`: defaults to `codex-<directory basename>` in Codex mode.
- `CLOD_SQUAD_DB`: optional alternate shared queue, useful for tests.
- `CLOD_SQUAD_STATE_DIR`: optional bridge thread/lock directory.
- `CLOD_SQUAD_CODEX`: optional path to the Codex executable.

The existing Claude installation and default identity behavior remain compatible.
Codex registration paths are namespaced strings because the legacy database
requires unique full paths even when two clients share a directory.

## Delivery guarantees and recovery

A queue row is acknowledged only after app-server accepts `turn/start` or
`turn/steer`. Acceptance means input was accepted, not that a model successfully
completed the work or sent a reply. Failed/interrupted turns are logged. Each
message carries authoritative sender, ID, timestamp, age, and stale status;
custom metadata cannot override these fields.

`codex_deliveries` journals each submission. Explicit RPC rejection is retryable.
Connection loss, timeout, or a crash during submission leaves a `pending` entry
and pauses ordered delivery. The bridge does **not** guess whether to resend.
Inspect the service journal, the saved Codex thread, and the queue:

```sql
SELECT d.*, m.from_id, m.to_id, m.body
FROM codex_deliveries d JOIN messages m ON m.id = d.message_id
WHERE d.state = 'pending';
```

Stop the service before reconciling. If the thread contains the message, update
that journal row to `state = 'accepted'`; on restart the bridge acknowledges the
queue row without resubmitting. If you have established it was never accepted,
delete only that journal row to permit retry. Keep the original message ID and
do not mark an uncertain input accepted merely because the model produced output.
Missing rollout history after an actual submission requires investigation; the
bridge will not silently replace that conversation.

## Verification

```sh
bun test
bun codex-smoke.ts
```

The second command is an opt-in live model test (uses your Codex account). It
creates an isolated temporary queue and tests actual Claude MCP send → app-server
turn → Codex MCP reply → Claude channel notification. It never contacts production
peers. Temporary logs are retained at the printed path for inspection.

Protocol: https://learn.chatgpt.com/docs/app-server . Tested with Codex CLI 0.153.4.
