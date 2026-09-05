#!/usr/bin/env bun
import { homedir } from 'node:os'
import { basename, join, resolve } from 'node:path'
import { mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs'

const project = resolve(process.argv[2] || process.cwd())
const identity = process.argv[3] || `codex-${basename(project)}`
if (!/^[a-zA-Z0-9_.-]+$/.test(identity)) throw new Error('Invalid identity')
const bun = process.execPath
const codex = Bun.which('codex')
if (!codex) throw new Error('Install and log in to Codex first')
const run = async (args: string[]) => {
  const child = Bun.spawn(args, { stdin: 'inherit', stdout: 'inherit', stderr: 'inherit' })
  if (await child.exited !== 0) throw new Error(`Command failed: ${args[0]}`)
}
const config = join(process.env.CODEX_HOME || join(homedir(), '.codex'), 'config.toml')
copyFileSync(config, config + `.clod-squad-backup-${Date.now()}`)
await run([codex, 'mcp', 'add', 'clod-squad', '--env', 'CLOD_SQUAD_TRANSPORT=codex', '--', bun, join(import.meta.dir, 'server.ts')])
// Preserve the historical alias and its identity/approval settings, but prevent
// its unsupported Claude notification receiver from consuming Codex messages.
let text = readFileSync(config, 'utf8')
if (text.includes('[mcp_servers.clod_squad]')) {
  const header = '[mcp_servers.clod_squad.env]'
  if (!text.includes(header)) text += `\n${header}\nCLOD_SQUAD_TRANSPORT = "codex"\n`
  else text = text.replace(/(\[mcp_servers\.clod_squad\.env\]\n)([\s\S]*?)(?=\n\[|$)/, (_, head, body) => head + body.replace(/^CLOD_SQUAD_TRANSPORT\s*=.*\n?/m, '') + '\nCLOD_SQUAD_TRANSPORT = "codex"\n')
  writeFileSync(config, text, { mode: 0o600 })
}
const unitDir = join(homedir(), '.config', 'systemd', 'user')
mkdirSync(unitDir, { recursive: true })
// systemd quoted arguments escape percent specifiers and special characters.
const quote = (value: string) => '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/%/g, '%%').replace(/\n/g, '\\n') + '"'
const unit = `clod-squad-${identity}.service`
writeFileSync(join(unitDir, unit), `[Unit]\nDescription=Clod Squad Codex participant (${identity})\nAfter=network-online.target\n\n[Service]\nType=simple\nWorkingDirectory=${project.replace(/%/g, "%%")}\nEnvironment=${quote(`CLOD_SQUAD_PROJECT_DIR=${project}`)}\nEnvironment=${quote(`CLOD_SQUAD_IDENTITY=${identity}`)}\nEnvironment=${quote(`CLOD_SQUAD_CODEX=${codex}`)}\nEnvironment=${quote(`PATH=${process.env.PATH}`)}\nExecStart=${quote(bun)} ${quote(join(import.meta.dir, 'codex-bridge.ts'))}\nRestart=on-failure\nRestartSec=10\nKillMode=control-group\nTimeoutStopSec=15\n\n[Install]\nWantedBy=default.target\n`)
await run(['systemd-analyze', '--user', 'verify', join(unitDir, unit)])
await run(['systemctl', '--user', 'daemon-reload'])
await run(['systemctl', '--user', 'enable', '--now', unit])
await run(['systemctl', '--user', 'is-active', unit])
console.log(`Installed ${unit}. Inspect with: journalctl --user -u ${unit}`)
