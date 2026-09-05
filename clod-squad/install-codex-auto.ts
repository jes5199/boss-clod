#!/usr/bin/env bun
import { homedir } from 'node:os'
import { join } from 'node:path'
import { mkdirSync, copyFileSync, readFileSync, writeFileSync, existsSync } from 'node:fs'

const codexHome = process.env.CODEX_HOME || join(homedir(), '.codex')
const codex = Bun.which('codex')
if (!codex) throw new Error('Install and log in to Codex first')
const run = async (args: string[]) => {
  const child = Bun.spawn(args, { stdin: 'inherit', stdout: 'inherit', stderr: 'inherit' })
  if (await child.exited) throw new Error(`Command failed: ${args[0]}`)
}
mkdirSync(codexHome, { recursive: true })
const config = join(codexHome, 'config.toml')
const previous = existsSync(config) ? readFileSync(config, 'utf8') : ''
// `codex mcp add` replaces the server table, including its per-tool settings.
const savedToolTables = previous.match(/^\[mcp_servers\.(?:clod-squad|"clod-squad")\.tools(?:\.[^\]]+)?\]\r?\n[\s\S]*?(?=^\[|$(?![\s\S]))/gm) || []
if (existsSync(config)) copyFileSync(config, config + `.clod-squad-auto-backup-${Date.now()}`)
await run([codex, 'mcp', 'add', 'clod-squad', '--env', 'CLOD_SQUAD_TRANSPORT=codex', '--', process.execPath, join(import.meta.dir, 'server.ts')])
// Retain legacy settings for rollback, but load exactly one copy of the tools.
let text = readFileSync(config, 'utf8')
if (savedToolTables.length) text += '\n' + savedToolTables.join('\n')
else for (const tool of ['send', 'list_peers', 'read_history']) {
  text += `\n[mcp_servers.clod-squad.tools.${tool}]\napproval_mode = "approve"\n`
}
text = text.replace(/(\[mcp_servers\.clod_squad\]\r?\n)([\s\S]*?)(?=\n\[|$)/, (_, head, body) =>
  head + 'enabled = false\n' + body.replace(/^enabled\s*=.*\r?\n?/m, ''))
writeFileSync(config, text, { mode: 0o600 })
const unitDir = join(homedir(), '.config/systemd/user')
mkdirSync(unitDir, { recursive: true })
const quote = (value: string) => '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/%/g, '%%').replace(/\n/g, '\\n') + '"'
const unit = 'clod-squad-codex-router.service'
const unitPath = join(unitDir, unit)
if (existsSync(unitPath)) copyFileSync(unitPath, unitPath + `.backup-${Date.now()}`)
writeFileSync(unitPath, `[Unit]\nDescription=Clod Squad automatic Codex session delivery\nAfter=network-online.target\n\n[Service]\nType=simple\nEnvironment=${quote(`CODEX_HOME=${codexHome}`)}\nEnvironment=${quote(`CLOD_SQUAD_CODEX=${codex}`)}\nEnvironment=${quote(`PATH=${process.env.PATH}`)}\nExecStart=${quote(process.execPath)} ${quote(join(import.meta.dir, 'codex-router.ts'))}\nRestart=on-failure\nRestartSec=5\nKillMode=control-group\nTimeoutStopSec=15\n\n[Install]\nWantedBy=default.target\n`)
await run(['systemd-analyze', '--user', 'verify', unitPath])
await run(['systemctl', '--user', 'daemon-reload'])
await run(['systemctl', '--user', 'enable', '--now', unit])
await run(['systemctl', '--user', 'restart', unit])
await run(['systemctl', '--user', 'is-active', unit])
console.log('Installed automatic delivery for live local Codex sessions. Restart existing sessions to reload MCP identity binding. Messages to busy sessions run after the current turn.')
