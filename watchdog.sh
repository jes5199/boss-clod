#!/bin/bash
# Watchdog: checks heartbeats table for stale agents.
# Idle waiting for input: heartbeat > 10 min old
# Possibly stuck: heartbeat > 30 min old
#
# When idle/stuck agents are found, inserts an alert message
# into clod-squad's messages table addressed to boss-clod.
#
# Usage: watchdog.sh [--quiet]
#   --quiet: only output if there are idle/stuck agents

DB="/home/jes/.claude/channels/clod-squad/queue.db"
QUIET="${1:-}"

bun -e "
const { Database } = require('bun:sqlite');
const db = new Database('$DB');

// Check if heartbeats table exists
const tableExists = db.query(\"SELECT name FROM sqlite_master WHERE type='table' AND name='heartbeats'\").get();
if (!tableExists) {
  if ('$QUIET' !== '--quiet') console.log('No heartbeats table found.');
  process.exit(0);
}

const rows = db.query('SELECT name, status, timestamp FROM heartbeats ORDER BY timestamp DESC').all();
if (rows.length === 0) {
  if ('$QUIET' !== '--quiet') console.log('No heartbeat entries found.');
  process.exit(0);
}

const now = Date.now();
const MINUTE = 60_000;

const active = [];
const idle = [];
const stuck = [];

for (const r of rows) {
  const age = now - new Date(r.timestamp).getTime();
  const mins = Math.floor(age / MINUTE);
  const entry = { name: r.name, status: r.status, mins, ts: r.timestamp };

  if (age > 30 * MINUTE) {
    stuck.push(entry);
  } else if (age > 10 * MINUTE) {
    idle.push(entry);
  } else {
    active.push(entry);
  }
}

// Build report
const lines = [];
lines.push('Agent Watchdog Report');
lines.push('====================');
lines.push('');

if (active.length) {
  lines.push('Active (' + active.length + '):');
  for (const a of active) lines.push('  ' + a.name + ' — ' + a.status + ' (' + a.mins + 'm ago)');
  lines.push('');
}

if (idle.length) {
  lines.push('Idle / waiting for input (' + idle.length + '):');
  for (const a of idle) lines.push('  ' + a.name + ' — last seen ' + a.mins + 'm ago (status: ' + a.status + ')');
  lines.push('');
}

if (stuck.length) {
  lines.push('Possibly stuck (' + stuck.length + '):');
  for (const a of stuck) lines.push('  ' + a.name + ' — last seen ' + a.mins + 'm ago (status: ' + a.status + ')');
  lines.push('');
}

lines.push('Total: ' + rows.length + ' agents tracked');

// If there are idle or stuck agents, push alert to boss-clod via clod-squad
if (idle.length > 0 || stuck.length > 0) {
  const alertParts = [];
  if (idle.length > 0) {
    alertParts.push('Idle agents: ' + idle.map(a => a.name + ' (' + a.mins + 'm)').join(', '));
  }
  if (stuck.length > 0) {
    alertParts.push('Possibly stuck: ' + stuck.map(a => a.name + ' (' + a.mins + 'm)').join(', '));
  }
  const alertBody = '[watchdog] ' + alertParts.join('. ');
  const ts = new Date().toISOString();

  // Check if boss-clod identity exists
  const bossExists = db.query(\"SELECT name FROM identities WHERE name='boss-clod'\").get();
  if (bossExists) {
    // Insert as a message from 'watchdog' — create identity if needed
    const watchdogExists = db.query(\"SELECT name FROM identities WHERE name='watchdog'\").get();
    if (!watchdogExists) {
      db.run(\"INSERT INTO identities (name, full_path, last_seen_at, registered_at) VALUES ('watchdog', '/home/jes/boss-clod', ?, ?)\", ts, ts);
    }
    db.run('INSERT INTO messages (from_id, to_id, body, created_at) VALUES (?, ?, ?, ?)',
      'watchdog', 'boss-clod', alertBody, ts);
  }

  if ('$QUIET' !== '--quiet') console.log(lines.join('\n'));
  process.exit(1);  // exit 1 = issues found
} else {
  if ('$QUIET' !== '--quiet') console.log(lines.join('\n'));
  process.exit(0);  // exit 0 = all clear
}

db.close();
"
