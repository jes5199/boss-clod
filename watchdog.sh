#!/bin/bash
# Watchdog: checks heartbeats table for stale agents.
# Idle waiting for input: heartbeat > 10 min old
# Possibly stuck: heartbeat > 30 min old
#
# Outputs a summary suitable for relay via telegram.

DB="/home/jes/.claude/channels/clod-squad/queue.db"

bun -e "
const { Database } = require('bun:sqlite');
const db = new Database('$DB', { readonly: true });

// Check if heartbeats table exists
const tableExists = db.query(\"SELECT name FROM sqlite_master WHERE type='table' AND name='heartbeats'\").get();
if (!tableExists) {
  console.log('No heartbeats table found. No agents have reported in yet.');
  process.exit(0);
}

const rows = db.query('SELECT name, status, timestamp FROM heartbeats ORDER BY timestamp DESC').all();
if (rows.length === 0) {
  console.log('No heartbeat entries found.');
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
console.log(lines.join('\n'));
db.close();
"
