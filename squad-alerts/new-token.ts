#!/usr/bin/env bun
/**
 * CLI: bun run new-token <publisher_name>
 *
 * Generates a fresh 256-bit token, stores its hash against the named
 * publisher in the squad-alerts DB (insert-or-replace), and prints the
 * raw token to stdout exactly once. Anything else (logs, prompts) goes
 * to stderr so the caller can do:
 *
 *   TOKEN=$(bun run new-token hermes)
 *
 * Re-running for the same publisher rotates the token: the old hash is
 * overwritten and previous tokens stop working.
 */

import { Database } from 'bun:sqlite'
import { homedir } from 'os'
import { join } from 'path'
import { mkdirSync } from 'fs'
import { initDb, upsertPublisher, generateToken } from './db'

const name = process.argv[2]
if (!name || !/^[a-z0-9][a-z0-9-]{0,63}$/.test(name)) {
  process.stderr.write(
    'usage: bun run new-token <publisher_name>\n' +
      '  publisher_name must match /^[a-z0-9][a-z0-9-]{0,63}$/\n',
  )
  process.exit(64)
}

const dbDir = join(homedir(), '.claude', 'channels', 'squad-alerts')
mkdirSync(dbDir, { recursive: true })

const db = new Database(join(dbDir, 'queue.db'))
initDb(db)

const token = generateToken()
upsertPublisher(db, name, token)
db.close()

process.stderr.write(`squad-alerts: provisioned publisher "${name}"\n`)
process.stderr.write(`squad-alerts: token is printed to stdout once — save it now.\n`)
process.stdout.write(token + '\n')
