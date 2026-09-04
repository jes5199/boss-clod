#!/usr/bin/env bash
# IS THE TEST BOX FREE?   rc 0 = FREE · rc 1 = BUSY · rc 2 = BLIND (do not act)
#
# ⭐ THIS IS A SCRIPT AND NOT A SNIPPET ON PURPOSE. Box protocol v2 ②b first shipped as awk for each
#   door to paste, and chit found the hazard immediately: `$2=="beam.smp"` is correct only for one
#   `ps -eo` format — the FIELD INDEX IS A PROPERTY OF THE FORMAT, NOT OF ps. A door that kept the
#   awk and changed the format would get 0, AND 0 IS THE VALUE THAT SAYS TAKE THE BOX.
#   ⇒ A rule everyone copies is a rule everyone adapts. Call this instead.
#
# ⛔⛔ NEVER KILL A beam.smp TO FREE THE BOX. Not under fallback, not under an expired grant, not
#   ever. One of the BEAMs on this host is hermes's LIVE TRADING SERVICE. A `pkill -f` matching
#   `mix phx.server` killed it on 2026-08-10. IF THE BOX IS NOT FREE, YOU WAIT.
#
# ⭐ THE DISTINCTION THAT KEEPS GETTING LOST (cell): argv is unsafe as a SELECTOR over the process
#   table — it matches your own command line, which caught four of us in one night — and is exactly
#   right as a PREDICATE on a pid you already hold. This uses `comm` to select and `cmdline` to judge.
set -o pipefail
PS=$(mktemp); trap 'rm -f "$PS"' EXIT
ps -eo pid,comm,args > "$PS" 2>/dev/null
# CONTROL (biscuit): the number you are trying to learn cannot control itself. `beams == 0` is both
# the green and the instrument failure, so the control is the CORPUS — all processes, a number whose
# rough answer we already know.
tot=$(command grep -c . "$PS")
[ "$tot" -lt 50 ] && { echo "BLIND|ps returned $tot lines — not a machine's process table"; exit 2; }

# hermes's live-money pid, by TWO paths that fail in different directions (hermes):
#  ① systemd — an identity we own. ⚠️ but `systemctl --user` needs the session bus, so it returns
#    EMPTY from cron, systemd-run, or a detached script — a whole class of caller permanently blind.
#  ② /proc/<pid>/cwd — a KERNEL-MAINTAINED symlink, not a string the process chose, so it cannot be
#    spoofed by argv and needs no bus.
hpid=$(systemctl --user show hermes -p MainPID --value 2>/dev/null)
case "$hpid" in ''|0|*[!0-9]*) hpid="" ;; esac
if [ -z "$hpid" ]; then
  hpid=$(awk '$2=="beam.smp"{print $1}' "$PS" | while read -r p; do
           [ "$(readlink "/proc/$p/cwd" 2>/dev/null)" = "/home/jes/hermes" ] && echo "$p"; done)
fi
n=$(printf '%s\n' "$hpid" | command grep -c .)
[ "$n" -ne 1 ] && { echo "BLIND|hermes MainPID unresolved ($n candidates) — refusing to guess which BEAM is live money"; exit 2; }

# SUITES, not BEAMs (cell): after excluding hermes there are still the serve and other long-lived
# BEAMs. The criterion is a running test suite, and the discriminator is the pid's own cmdline.
# ⚠️ Bound, cell's own: this is a PREDICATE OVER A KNOWN INVOCATION SHAPE, not a definition of
#   "suite". A suite started some other way would not match — so an unrecognised BEAM counts as
#   contention below rather than being waved through.
suites=0; unknown=0; blind=0; periodic=0
for p in $(awk '$2=="beam.smp"{print $1}' "$PS"); do
  [ "$p" = "$hpid" ] && continue
  # ⛔⛔ AN UNREADABLE cwd HAS TWO CAUSES AND THEY ARE OPPOSITE VERDICTS (2026-09-04, LESSONS 7x560):
  #   the process EXITED between the `ps` snapshot and this readlink  ⇒ NOT contention. Skip it.
  #   the process EXISTS and its /proc is unreadable (permissions)    ⇒ genuinely BLIND. Refuse.
  # ⚠️ Conflating them made the whole instrument return rc=2 THREE TIMES IN A ROW while the box was
  #   merely busy with SHORT-LIVED fixture BEAMs that spawn and exit constantly. A separate loop over
  #   the SAME pids read all four cwds fine one second later — the race, not a permission wall.
  # ⭐ AND THE COST IS ASYMMETRIC IN THE DIRECTION THAT MATTERS: BLIND means "no information, do not
  #   act", so a racing exit — the most benign event on the box — was DISABLING THE ARBITER. A gate
  #   that goes blind whenever the thing it watches is busiest is worst exactly when it is needed.
  if ! cwd=$(readlink "/proc/$p/cwd" 2>/dev/null) || [ -z "$cwd" ]; then
    # THE DISCRIMINATOR: does the pid still exist at all?
    if [ -d "/proc/$p" ]; then
      # ⭐⭐ SECOND DISCRIMINATOR, ADDED 2026-09-04: AN OPAQUE cwd IS USUALLY A CONTAINER, NOT A
      # MYSTERY. A BEAM inside a docker container has an unreadable /proc/PID/cwd (different mount
      # namespace, and /proc/1/cwd is unreadable to this user too — so the reader is unprivileged,
      # NOT the target being strange). But /proc/PID/cgroup IS readable and NAMES THE CONTAINER.
      # ⛔ WHY IT MATTERS: BLIND means "no information, do not act" and STOPS EVERY DOOR. Reporting
      # biscuit's own DEPLOY-SCOPE-1 build as BLIND would have halted the queue on a tenancy that is
      # announced, expected, and attributable in one read.
      # ⇒ An identified container is CONTENTION (a real tenant, named) — never an absence of data.
      cg=$(cat "/proc/$p/cgroup" 2>/dev/null)
      case "$cg" in
        *docker-*) cid=${cg##*docker-}; cid=${cid%%.scope*}
                   unknown=$((unknown+1))
                   echo "BUSY-CONTAINER|pid $p docker ${cid:0:12} (cwd opaque: container namespace, cgroup read instead)" ;;
        *)         blind=$((blind+1)) ;;                # genuinely opaque ⇒ BLIND
      esac
    fi
    continue                                            # gone ⇒ it is not using the box
  fi
  cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
  case "$cmd" in
    *-extra*mix*test*) suites=$((suites+1)); echo "BUSY-SUITE|pid $p cwd $cwd" ;;
    *) case "$cwd" in
         /home/jes/commonplace-serve-pin) : ;;                       # the serve — known, not contention
         /home/jes/commonplace-monolith)
           # ⭐ BOSS'S OWN HOURLY state-render (cron at :17, `bash bin/state-render`). It is a real
           #   mix run and DOES load the box, so it still counts as contention — but it is NAMED,
           #   because "UNKNOWN" sends a door to ask about a process the arbiter itself started.
           #   ⚠️ Design envelope: inner timeout 2400s and runtime scales with ticket count, so
           #   ~25 min is normal, not stuck. Confirm by STATE.md's mtime, not by elapsed time.
           periodic=$((periodic+1)); echo "BUSY-PERIODIC|pid $p state-render (boss's hourly, cwd $cwd)" ;;
         # ⭐ A CONTAINER RELEASE IS ATTRIBUTABLE, NOT UNKNOWN (2026-09-04). A BEAM inside a docker
         #   container shows on the HOST with cwd `/app` and a `docker-<id>.scope` cgroup. Before
         #   this branch it read `UNKNOWN-BEAM`, which says "an unrecognised cwd is CONTENTION, not
         #   permission" — correct as a VERDICT (it does load the box) and wrong as a NAME.
         # ⛔ An UNKNOWN sends a door to ask the arbiter about a process the arbiter can already
         #   identify — the same defect as BUSY-PERIODIC's, which exists for exactly this reason.
         # ⚠️ VERDICT UNCHANGED: still counted as contention. Only the label improves, and the
         #   container id is printed so the asking door can resolve it itself with `docker ps`.
         /app)
           cid=$(sed -n 's/.*docker-\([0-9a-f]\{12\}\).*/\1/p' "/proc/$p/cgroup" 2>/dev/null | head -1)
           unknown=$((unknown+1)); echo "BUSY-CONTAINER|pid $p docker ${cid:-unresolved} (cwd /app — a release under test, counts as contention)" ;;
         *) unknown=$((unknown+1)); echo "UNKNOWN-BEAM|pid $p cwd $cwd" ;;
       esac ;;
  esac
done
# ⛔⛔ NON-BEAM TENANCY — STRUCTURAL BLINDNESS, FOUND BY commonplace-next 2026-09-04.
# This script enumerated `beam.smp` ONLY, so a round made of `cp -a` (510 MB), `npx tsc --noEmit`
# and `vitest` — biscuit's BACKUP-1b-i — read `FREE|0 suites` FOR ITS ENTIRE DURATION.
# ⛔ THIS IS NOT THE TIMING GAP EVERY DOOR ALREADY MANAGES. The instrument had NO TERM for that
#   workload, so re-sampling could never help: `suites>=0` proves no BEAM suite is running, it has
#   never proved the box is idle. (next: the same shape as a bogus-ref control proving the endpoint
#   ANSWERS but not that it is the RIGHT one.)
# ⚠️ AND IT MADE THE ANNOUNCEMENT PROTOCOL LOAD-BEARING WITHOUT ANYONE DECIDING THAT: for a BEAM
#   tenancy ⑨ is a SECOND WITNESS; for a node tenancy the announcement was the ONLY witness, so a
#   door whose turn ended mid-round would leave every reader seeing FREE with nothing to contradict it.
# ⭐ OVER-REPORTING CONTENTION IS THE SAFE DIRECTION: a false BUSY costs a wait, a false FREE costs
#   a collision inside someone else's measurement.
# ⛔⛔ AND IT FIRED FALSE ON ITS FIRST RUN, WHICH IS WHY THE cwd TEST EXISTS: a long-lived `esbuild`
#   in /home/jes/hyperstition/voucher-gate — an UNRELATED project's dev server — would have reported
#   BUSY forever. ⭐ A gate that fires on correct state is worse than no gate: the fleet would have
#   learned to ignore this line within a day. ⇒ GATE only on fleet work paths; PRINT the others as
#   NOTE lines so they stay visible and attributable without blocking anyone.
# ⚠️⚠️ WHAT IS AND IS NOT PROVEN ABOUT THIS TERM, 2026-09-04, stated because a gate nobody has seen
#   fire is not known to work:
#     ✅ GREEN ARM, LIVE: an unrelated `esbuild` in /home/jes/hyperstition/voucher-gate prints
#        NOTE-NONBEAM and does NOT gate — verified on the real process.
#     ✅ DISCRIMINATOR, on REAL cwd strings taken from today's rounds: sol-share1b/wt, a /tmp/claude-*
#        scratch clone and next-suite-load/wt all GATE; voucher-gate and UNREADABLE only NOTE.
#     ⛔ RED ARM, LIVE: NOT PROVEN. Three attempts to hold a detached `node` in a fleet path exited
#        immediately (node IS on PATH — /usr/bin/node — so the cause is unexplained), so the gating
#        branch has never been seen firing on a real process.
#   ⇒ The FIRST real non-BEAM round is this term's first live test. If it reads FREE through one,
#     the term is wrong and the announcement protocol is still the only witness.
# ⛔⛔ DO NOT ADD `java` TO THIS LIST (hermes, 2026-09-04, filed BEFORE anyone tried).
#   `java -jar …/hermes/thetadata/ThetaTerminal.jar` is hermes's PERSISTENT market-data feed, cwd
#   `/home/jes/hermes` — a legitimate fleet work path. ⇒ Adding `java` would GATE THE BOX FOREVER,
#   and the path test above would NOT save you: the path is legitimate, the process is legitimately
#   long-lived, and it is legitimately not contention.
#   ⭐ It needs the same treatment as the trading BEAM: EXCLUDED BY IDENTITY, never by path.
#   ⚠️ AND DO NOT PRINT ITS ARGV ANYWHERE — that command line carries a credential in plaintext.
#   This script prints cwd and never `$cmd`, and it must stay that way.
# ⛔⛔⛔ THE SELECTOR WAS WRONG AND THREE DOORS PROVED IT ON LIVE PROCESSES (2026-09-04).
#   `pgrep -x node` SELECTS ON `comm`, AND NODE v24 NAMES ITS MAIN THREAD `MainThread` — so
#   /proc/PID/comm NEVER SAYS "node" and pgrep returns EMPTY FOR A HEALTHY PROCESS.
#   ⇒ The term added FOR `npx`, `tsc` and `vitest` could not see the interpreter those commands run.
#   ⛔ "the process died" and "the process cannot be matched by comm" ARE THE SAME OBSERVABLE through
#     pgrep -x — absence with more than one cause, inside the instrument built to catch exactly that.
#   ⚠️ AND MY GREEN ARM IS WHY IT LOOKED ALIVE: `esbuild` is a compiled Go binary whose comm IS
#     `esbuild`, so ONE entry worked and the ones that mattered could not. cell: "a list where some
#     entries fire and others cannot is worse than one that fires for none — the working entry is the
#     evidence people cite for the whole list."
#   ✅ SELECT BY THE EXECUTABLE: basename(readlink /proc/PID/exe). It is the real binary, immune to a
#     runtime renaming its main thread, and harder to spoof than a 15-byte comm.
#   ✅ BOTH ARMS NOW PROVEN LIVE (2026-09-04, after the fix):
#       RED   a real `node` (comm=MainThread) with cwd /home/jes/sol-boxtest-tmp ⇒ BUSY-NONBEAM, rc 1
#       GREEN the same population outside round-work paths ⇒ NOTE only, rc 0
#     The pre-fix gate had a proven GREEN arm and an unproven RED one, and the RED was the broken half.
#     ⛔ A GREEN ARM CAN PASS ON A SELECTOR THAT MATCHES NOTHING — it proves the PATH TEST and says
#       nothing about the SELECTOR. Prove the arm that requires the selector to WORK.
# ⛔ AND THE GATING PATHS ARE NARROWER THAN THE BEAM TERM'S ON PURPOSE: every Claude session on this
#   box runs its own `node` harness, with cwd in its REPO DIR or its scratchpad. Gating on
#   /home/jes/commonplace* or /tmp/claude-* would mark the box BUSY FOREVER — the voucher-gate
#   failure again, but permanent and fleet-wide. ⇒ Gate ONLY on round-work paths; NOTE everything else.
nonbeam=0
for _pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
  _exe=$(readlink "/proc/$_pid/exe" 2>/dev/null) || continue
  case "$(basename "$_exe" 2>/dev/null)" in
    node|npm|npx|vitest|tsc|esbuild) ;;
    *) continue ;;
  esac
  _b=$(basename "$_exe")
  _cwd=$(readlink "/proc/$_pid/cwd" 2>/dev/null || echo UNREADABLE)
  case "$_cwd" in
    /home/jes/sol-*|/home/jes/*-wt|/home/jes/*-wt/*|/home/jes/*-suite-load*|/tmp/commonplace-*)
      nonbeam=$((nonbeam+1)); echo "BUSY-NONBEAM|pid $_pid $_b cwd $_cwd" ;;
    # ⭐⭐ THE SCRATCHPAD SPLIT (commonplace-chit, 2026-09-04, reported not probed): the LEAK THAT
    #   MOTIVATED THIS WHOLE FIX — biscuit's two orphaned node children — lived at
    #   `/tmp/claude-*/…/scratchpad/cl-d0aff78`, and a blanket exclusion of /tmp/claude-* means it
    #   STILL WOULD NOT GATE. ⛔ But gating the whole prefix marks the box BUSY FOREVER: every
    #   session's own harness node runs there too.
    #   ⇒ THE DISCRIMINATOR IS DEPTH, and it is measured rather than assumed:
    #       harness node   cwd = the scratchpad ROOT            (…/scratchpad)
    #       workload node  cwd = a WORK SUBDIR under it         (…/scratchpad/cl-<sha>, /log-deploy)
    #   ⭐ Separates the two cases in every sample any door has produced today.
    #   ⚠️ Bound: it is a shape, not a proof of ownership. A harness that chdir'd into a subdir would
    #     gate falsely — which fails SAFE (a wait), unlike the reverse.
    #   ✅ BOTH ARMS PROVEN LIVE, and by accident rather than by design — I LEAKED TWO FIXTURES doing
    #     it (`cd X && nohup node &` makes `$!` the SUBSHELL, cell's own finding, committed by me
    #     while testing the fix for a leak). The leak is what proved it:
    #       pid 2804338  cwd …/scratchpad            ALIVE and did NOT gate   ⇐ ROOT arm, GREEN
    #       pid 2805367  cwd …/scratchpad/cl-testfix ALIVE and DID gate       ⇐ SUBDIR arm, RED
    #     Both killed afterwards by VERIFIED cwd, with the four surviving harness nodes as the control.
    */scratchpad)
      echo "NOTE-NONBEAM|pid $_pid $_b cwd $_cwd — scratchpad ROOT (session harness), not gating" ;;
    /tmp/claude-*/scratchpad/*)
      nonbeam=$((nonbeam+1)); echo "BUSY-NONBEAM|pid $_pid $_b cwd $_cwd (work subdir under a scratchpad)" ;;
    UNREADABLE)
      echo "NOTE-NONBEAM|pid $_pid $_b cwd UNREADABLE — not gating, cannot attribute" ;;
    *)
      echo "NOTE-NONBEAM|pid $_pid $_b cwd $_cwd — outside round-work paths (harness/dev), not gating" ;;
  esac
done

# ⭐⭐ EVERY UNRESOLVED CASE FAILS TOWARD WAITING (biscuit). A fallback that decides whether to take a
#   shared resource must fail safe in the direction of NOT taking it.
[ "$blind" -gt 0 ] && { echo "BLIND|$blind BEAM(s) whose /proc cwd could not be read"; exit 2; }
[ "$suites" -gt 0 ] && { echo "BUSY|$suites suite(s) running (control: $tot processes visible)"; exit 1; }
[ "$nonbeam" -gt 0 ] && { echo "BUSY|$nonbeam non-BEAM process(es) — node/npm/vitest/tsc load the box and no BEAM term can see them (control: $tot processes visible)"; exit 1; }
# ⚠️ WORDING: this counter now holds BOTH unrecognised BEAMs AND named container releases, so the old
#   "unrecognised BEAM(s)" summary CONTRADICTED the BUSY-CONTAINER line printed above it. A summary
#   that disagrees with its own detail lines is how a reader learns to stop reading one of them.
[ "$unknown" -gt 0 ] && { echo "BUSY|$unknown non-suite BEAM(s) loading the box — see the lines above for which; an unrecognised cwd is CONTENTION, not permission"; exit 1; }
# ⭐ A NAMED periodic job still blocks the fallback — a door must not decide on its own that boss's
#   housekeeping is ignorable. But BOSS may grant over it deliberately for work that is not a timing
#   measurement, which is a judgement only the arbiter should make.
[ "$periodic" -gt 0 ] && { echo "BUSY|$periodic known periodic job(s) — boss may grant over this; a door may not"; exit 1; }
# 📌 OBSERVED ON THE FIRST LIVE RUN (15:20Z): a running suite shows as TWO BEAMs — the suite itself
#   (matched by cmdline) and a CHILD through `erl_child_setup` whose cmdline does not match, which
#   lands in UNKNOWN-BEAM. ⭐ cell filed that overcount as `suites()` counting BEAMs not doors.
#   ⚠️ I am NOT "fixing" it: the child makes the box read BUSY, which is the safe direction, and any
#   narrowing risks the unsafe one. The UNKNOWN line names the pid so a reader can see what it is.
echo "FREE|0 suites, hermes pid $hpid excluded, control $tot processes visible"
exit 0
