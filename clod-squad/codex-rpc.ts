import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process'
import { createInterface } from 'node:readline'

export interface Rpc {
  request(method: string, params: any): Promise<any>
}
export class RpcError extends Error {}

/** JSON-lines app-server client. Never retry a request with an unknown outcome. */
export class AppServer implements Rpc {
  private nextId = 0
  private pending = new Map<number, { resolve: (v: any) => void, reject: (e: Error) => void, timer: ReturnType<typeof setTimeout> }>()
  readonly child: ChildProcessWithoutNullStreams
  onNotification: (method: string, params: any) => void = () => {}
  onExit: () => void = () => {}
  constructor(command: string[], cwd: string, env = process.env) {
    this.child = spawn(command[0], command.slice(1), { cwd, env, stdio: ['pipe', 'pipe', 'pipe'] })
    this.child.stderr.on('data', chunk => process.stderr.write(chunk))
    const fail = (error: Error) => {
      for (const p of this.pending.values()) { clearTimeout(p.timer); p.reject(error) }
      this.pending.clear()
    }
    this.child.on('error', fail)
    this.child.stdin.on('error', fail)
    this.child.on('exit', () => { fail(new Error('app-server exited; delivery outcome may be unknown')); this.onExit() })
    createInterface({ input: this.child.stdout }).on('line', line => {
      let msg: any
      try { msg = JSON.parse(line) } catch { return }
      if (msg.method && msg.id !== undefined) {
        // This headless host cannot manufacture user approval or input.
        const result = msg.method === 'item/commandExecution/requestApproval' || msg.method === 'item/fileChange/requestApproval'
          ? { decision: 'decline' } : null
        this.write(result ? { id: msg.id, result } : { id: msg.id, error: { code: -32601, message: 'No interactive user attached to clod-squad bridge' } })
        process.stderr.write(`clod-squad: declined interactive request ${msg.method}\n`)
      } else if (msg.id !== undefined) {
        const p = this.pending.get(msg.id)
        if (!p) return
        this.pending.delete(msg.id); clearTimeout(p.timer)
        if (msg.error) p.reject(new RpcError(msg.error.message))
        else p.resolve(msg.result)
      } else if (msg.method) this.onNotification(msg.method, msg.params)
    })
  }
  private write(message: any) { this.child.stdin.write(JSON.stringify(message) + '\n') }
  notify(method: string, params: any = {}) { this.write({ method, params }) }
  request(method: string, params: any): Promise<any> {
    const id = ++this.nextId
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id)
        reject(new Error(`${method} timed out; delivery outcome may be unknown`))
      }, 60_000)
      this.pending.set(id, { resolve, reject, timer })
      this.write({ id, method, params })
    })
  }
  close() { this.child.kill('SIGTERM') }
}
