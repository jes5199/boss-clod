# clod-squad: Channel Plugin for Inter-Claude Communication

## Overview

clod-squad is a Claude Code channel plugin that enables bidirectional messaging between Claude Code instances running in separate tmux sessions. It uses a shared SQLite database as a message queue, with each instance polling for new messages and surfacing them as native `<channel>` notifications.

## Goals

- Let a "boss" Claude coordinate work across multiple "worker" Claude instances
- Messages appear directly in each Claude's conversation as `<channel>` tags
- Workers stay in their own tmux sessions — no process spawning
- Simple, local, no network services or daemons

## Identity

Each Claude instance is identified by its project directory basename (e.g. `/home/jes/my-cool-app` becomes `my-cool-app`). On registration, the full path is stored to detect collisions — if two directories share a basename, the second registrant gets an error and must be disambiguated (e.g. by renaming the directory or using a symlink).

## Transport

Single SQLite database at `~/.claude/channels/clod-squad/queue.db`, opened in WAL mode for concurrent reader/writer access. Each plugin instance polls the DB every 2 seconds for undelivered messages.

## Database Schema

```sql
CREATE TABLE identities (
    name TEXT PRIMARY KEY,
    full_path TEXT NOT NULL UNIQUE,
    last_seen_at TEXT,
    registered_at TEXT NOT NULL
);

CREATE TABLE messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_id TEXT NOT NULL REFERENCES identities(name),
    to_id TEXT NOT NULL REFERENCES identities(name),
    body TEXT NOT NULL,
    metadata TEXT,
    created_at TEXT NOT NULL,
    delivered_at TEXT
);

CREATE INDEX idx_messages_to_undelivered
    ON messages(to_id, delivered_at)
    WHERE delivered_at IS NULL;
```

Two tables. `identities` tracks who's registered and when they were last seen. `messages` holds the queue. `delivered_at` is NULL until the recipient's plugin picks up the message. `metadata` is an optional JSON blob for structured fields like priority, tags, or status.

## Message Model

Hybrid: free-form text body with optional JSON metadata. Messages can be plain:

> refactor the auth module to use JWT

Or structured:

> refactor the auth module to use JWT
> metadata: `{"priority": "high", "tag": "auth"}`

## Routing

Hub-and-spoke by convention, mesh by capability. Boss typically coordinates, but any peer can message any other peer directly. All messages are visible in the shared DB regardless of routing.

## MCP Server Behavior

### Startup

1. Open/create SQLite DB, enable WAL mode, run migrations
2. Derive identity from `process.cwd()` basename
3. Check for basename collision against `full_path` in `identities` table
4. Register or update identity, set `last_seen_at`
5. Begin polling loop

### Polling Loop (every 2 seconds)

1. `SELECT * FROM messages WHERE to_id = ? AND delivered_at IS NULL ORDER BY id`
2. For each message, emit `notifications/claude/channel` notification
3. Set `delivered_at = now` on delivered messages
4. Update `last_seen_at` on own identity

### Shutdown

On stdin EOF or SIGTERM, stop polling and close DB connection.

## Channel Notification Format

Inbound messages appear as:

```xml
<channel source="clod-squad" from="boss-clod" message_id="42" ts="2026-03-24T18:30:00Z">
refactor the auth module to use JWT instead of session tokens
</channel>
```

With metadata, extra attributes are added:

```xml
<channel source="clod-squad" from="boss-clod" message_id="43" ts="2026-03-24T18:31:00Z" priority="high" tag="auth">
refactor the auth module to use JWT instead of session tokens. this is blocking the mobile release.
</channel>
```

## MCP Tools

### `send`

Send a message to another instance.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `to` | string | yes | Recipient identity name |
| `text` | string | yes | Message body |
| `metadata` | object | no | Optional structured fields (priority, tags, etc.) |

Returns confirmation with recipient's online/offline status.

### `list_peers`

List all registered identities with online/offline status.

No parameters. A peer is "online" if `last_seen_at` is within the last 30 seconds.

### `read_history`

Read past messages between this instance and a peer.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `peer` | string | yes | Peer identity name |
| `limit` | number | no | Max messages to return (default 20) |

Returns messages in both directions, ordered chronologically.

### `broadcast`

Send a message to all registered peers.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | yes | Message body |
| `metadata` | object | no | Optional structured fields |

Writes one message row per peer. Returns delivery summary with online/offline counts.

## Offline Handling

Messages to offline workers are queued in the DB. When the worker's plugin starts and polls, it picks up all undelivered messages. The `send` tool reports whether the recipient is online or offline so the sender knows the message is queued.

## Plugin File Structure

```
clod-squad/
  .claude-plugin/
    plugin.json
  .mcp.json
  package.json
  server.ts
```

### `.claude-plugin/plugin.json`

```json
{
  "name": "clod-squad",
  "description": "Channel plugin for inter-Claude communication via shared SQLite queue",
  "version": "0.0.1",
  "keywords": ["channel", "coordination", "messaging", "mcp"]
}
```

### `.mcp.json`

```json
{
  "mcpServers": {
    "clod-squad": {
      "command": "bun",
      "args": ["run", "--cwd", "${CLAUDE_PLUGIN_ROOT}", "--shell=bun", "--silent", "start"]
    }
  }
}
```

### `package.json`

```json
{
  "name": "clod-squad",
  "version": "0.0.1",
  "type": "module",
  "bin": "./server.ts",
  "scripts": {
    "start": "bun install --no-summary && bun server.ts"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "better-sqlite3": "^11.0.0"
  }
}
```

### Instructions String

```
Messages from other Claude instances arrive as <channel source="clod-squad" from="..." message_id="...">. Reply with the send tool. Use list_peers to see who's online.
```

## Runtime

- **Runtime**: Bun (consistent with existing Claude Code plugins)
- **SQLite driver**: better-sqlite3 (synchronous, WAL-friendly)
- **MCP SDK**: @modelcontextprotocol/sdk (standard Claude Code plugin SDK)
- **Transport**: stdio (spawned by Claude Code as subprocess)

## Installation and Usage

The plugin source lives in `/home/jes/boss-clod/`. Workers reference it with:

```
claude --channels plugin:clod-squad@/home/jes/boss-clod
```

Or after publishing to a marketplace:

```
claude --channels plugin:clod-squad@<marketplace>
```
