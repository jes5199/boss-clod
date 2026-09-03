#!/usr/bin/env bash
# Watch for the BOX to go quiet of test runs, so a deferred gate can be told to go.
#
# ⛔⛔ REWRITTEN 2026-09-03T04:38Z AFTER MY FIRST VERSION DECLARED A FALSE CLEAR.
#     v1 selected on the path `/home/jes/next-suite-load`. It logged six consecutive clear
#     samples and fired the sentinel — WHILE next was running
#     `mix test test/integration/remote_editor_test.exs` (pid 366619) in a DIFFERENT worktree,
#     `/home/jes/next-base/wt`. There are ~30 `/home/jes/next-*` worktrees on this box.
#     ⭐ MY SIX CLEAR SAMPLES WERE TRUE OF MY CORPUS AND FALSE OF THE BOX — which is exactly
#     the lesson I had filed as 7x442 one hour earlier, arriving at my own door: A GATE'S
#     LITERAL IS A CLAIM ABOUT ITS CORPUS.
#     ⚠️ The `busy_seen` control did NOT catch it: the selector was non-vacuous (it really did
#     see next-suite-load busy), it was merely INCOMPLETE. A non-vacuity control proves the
#     corpus is not empty; it CANNOT prove the corpus is the whole subject.
#     ✅ Caught only because I re-measured with a WIDER instrument (a `ps` with no path filter)
#     instead of trusting my own sentinel. Nothing was relayed; biscuit was never told.
#
# ⇒ THE CORPUS IS NOW THE BOX, because "the box is clear" is a claim about the box. Any
#   `mix test` anywhere loads it, regardless of which repo or worktree it runs from.
#
# ⛔ NEVER pgrep -f / pkill -f: the pattern would match this script's own command line.
#    Enumerate /proc directly and skip our own pid.
# ⭐ WHY THIS SURVIVES cell's suites() FINDING (commonplace-cell via plan row 614): counters
#    that compare a BEAM count against an expected k are wrong by a factor, because a child
#    BEAM through `erl_child_setup` also matches `-extra … mix … test`, so one suite reads
#    as 2. THIS WATCHER IS A BOOLEAN: it tests `n > 0` and never compares n to anything.
#    ⚠️ KEEP IT THAT WAY — make it count suites and cell's finding applies to it too.
# ⭐ THE SENTINEL IS A TRIGGER, NOT A VERDICT. Boss still confirms with next that its column
#    set is FINISHED before telling any door the box is clear. A quiet box and a finished
#    column set are different claims.
SELF=$$
NEED=6            # consecutive clear samples required
INTERVAL=60
OUT=/home/jes/boss-clod/.next-box-clear
LOG=/home/jes/boss-clod/.next-box-watch.log
clear_n=0
busy_seen=0
while :; do
  n=0; who=""
  for d in /proc/[0-9]*; do
    pid=${d#/proc/}
    [ "$pid" = "$SELF" ] && continue
    cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null) || continue
    # ⛔⛔ AND A SECOND SELF-MATCH, CAUGHT IN THE FIRST SAMPLE OF v2: a shell whose command
    #     line CONTAINS the words `mix test` — such as the boss shell writing this very
    #     script from a heredoc — matched and logged as busy (369186:boss-clod).
    #     ⚠️ That is the pgrep-self hazard wearing different clothes: not my own command line,
    #     but ANY command line that quotes the pattern. ⭐ It fails SAFE (busy when idle, so a
    #     delay and never a false clear) — which is exactly why it would have lived for weeks.
    #     ⇒ Require the process to actually BE an Erlang VM, not merely to mention one.
    case "$cmd" in *beam.smp*) : ;; *) continue ;; esac
    case "$cmd" in
      *" mix test"*|*"/mix test"*|*"mix test "*)
        n=$((n+1))
        who="$who $pid:$(basename "$(readlink "$d/cwd" 2>/dev/null)" 2>/dev/null)"
        ;;
    esac
  done
  ts=$(date -u +%FT%TZ)
  if [ "$n" -gt 0 ]; then
    busy_seen=1; clear_n=0
    echo "$ts busy=$n$who" >> "$LOG"
  else
    clear_n=$((clear_n+1))
    echo "$ts clear ($clear_n/$NEED) busy_seen=$busy_seen" >> "$LOG"
    if [ "$clear_n" -ge "$NEED" ] && [ "$busy_seen" -eq 1 ]; then
      echo "$ts CLEAR: no 'mix test' anywhere on the box for $((NEED*INTERVAL))s; busy observed earlier (non-vacuous). STILL ONLY A TRIGGER — confirm next's column set is finished before relaying." > "$OUT"
      exit 0
    fi
  fi
  sleep "$INTERVAL"
done
