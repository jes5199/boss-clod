#!/bin/bash
# Heartbeat hook for Claude Code workers.
# Called by PostToolUse and Stop hooks.
# Updates a heartbeat row in the clod-squad SQLite DB via bun:sqlite.
#
# Environment provided by Claude Code hooks:
#   CLAUDE_PROJECT_DIR — project directory for this session
#
# Usage: heartbeat.sh <status>
#   status: "tool_use" (from PostToolUse) or "stop" (from Stop)

DB="/home/jes/.claude/channels/clod-squad/queue.db"
NAME="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"
STATUS="${1:-tool_use}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

exec bun -e "
const { Database } = require('bun:sqlite');
const db = new Database('$DB');
db.exec('CREATE TABLE IF NOT EXISTS heartbeats (name TEXT PRIMARY KEY, status TEXT NOT NULL, timestamp TEXT NOT NULL)');
db.prepare('INSERT INTO heartbeats (name, status, timestamp) VALUES (?, ?, ?) ON CONFLICT(name) DO UPDATE SET status=excluded.status, timestamp=excluded.timestamp')
  .run('$NAME', '$STATUS', '$NOW');
db.close();
"
