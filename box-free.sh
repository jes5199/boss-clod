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
    if [ -d "/proc/$p" ]; then blind=$((blind+1)); fi   # alive but opaque ⇒ BLIND
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
# ⭐⭐ EVERY UNRESOLVED CASE FAILS TOWARD WAITING (biscuit). A fallback that decides whether to take a
#   shared resource must fail safe in the direction of NOT taking it.
[ "$blind" -gt 0 ] && { echo "BLIND|$blind BEAM(s) whose /proc cwd could not be read"; exit 2; }
[ "$suites" -gt 0 ] && { echo "BUSY|$suites suite(s) running (control: $tot processes visible)"; exit 1; }
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
