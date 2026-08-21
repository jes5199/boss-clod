#!/usr/bin/env bash
# LAUNCH THE COMMONPLACE :5199 SERVE WITH A CLEAN, ALLOWLISTED ENVIRONMENT.
#
# ⛔⛔ WHY THIS FILE EXISTS. On 2026-08-21 00:11 I relaunched the serve by sending the
# documented launch line to a tmux pane. It came up correct in every functional respect
# — :5199 listening, posture `local_write_gate: :enforce (env-set)` — and it had
# **LETTA_API_KEY** in its environment, inherited from the launching shell. The old
# serve did not have it (verified: 0 occurrences in its captured environ). It was found
# ONLY by the whole-environ diff old→new, and it is the THIRD recorded recurrence of
# that same variable leaking into that same process.
#
# ⭐ THE FIX IS AN ALLOWLIST, NOT A STRIP LIST. My notes already record why: a strip
# list is built from the vars you can SEE in the old environ, so it necessarily misses
# the ones the LAUNCHING SHELL adds — which is exactly the category that leaks.
# "Copying forward misses what you didn't grep for; stripping misses what wasn't there
# to see." `env -i` inverts the default: nothing is inherited unless it is named here.
#
# ⚠️ A leaked credential does not make the serve look unhealthy. It returns 200, the
# posture block is correct, and everything works. Nothing about the running system
# reports it. The diff is the only instrument that sees it — which is why the diff is
# mandatory on every restart and not a nicety.
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════════
# ⛔⛔ PINNED BOOT GATE (2026-08-21). THE SERVE BOOTS FROM THE PIN OR IT DOES NOT BOOT.
#
# WHY: three times tonight I restarted this serve and each restart silently deployed
# whatever the SHARED tree at /home/jes/commonplace had compiled in the meantime —
# code that had never been through a span certification. `cp-deploy-gap` read a
# reassuring `0` throughout, because it compares _build to the running process and
# CANNOT SEE A SOURCE TREE THAT IS AHEAD OF _build. The gauge shared fate with the
# thing it measured. (boss LESSONS 7x57/7x58.)
#
# ⭐ THE FIX IS STRUCTURAL: code comes from a dedicated worktree pinned at a sha,
# written ONLY by `bin/cp-deploy-pin` as a ceremony step. The shared tree may churn
# freely; it no longer reaches production by accident.
#
# ⭐⭐ BOOT ONLY ON EXIT 0. REFUSE ON EVERYTHING ELSE — never enumerate the failures.
# A launcher that refused on {2,3} would BOOT on an unanticipated code: a crash
# exiting 1, an ENOENT on the binary, a future exit 4. The GO condition is what gets
# enumerated; everything else is refusal, INCLUDING THE UNKNOWN. cp-pin-status's
# exit table can grow without this file learning about it.
#
# ⛔ AND IT MUST NEVER FALL BACK TO $SHARED. A silent fallback recreates the exact
# accident with extra steps, on the day someone deletes the pin — i.e. when nobody
# is watching. Fail loud, refuse to serve.
PIN=/home/jes/commonplace-serve-pin      # CODE comes from here. Constant, never env:
                                          # if the boot source could arrive by
                                          # environment it would be exactly the class
                                          # of fact `env -i` below exists to eliminate.
SHARED=/home/jes/commonplace              # DATA + tooling only. NOT a boot source.

# ⛔⛔ CAPTURE THE STATUS CORRECTLY. `if ! cmd; then rc=$?` yields the status of the
# NEGATION (0 when cmd failed) — NOT cmd's status. I shipped exactly that bug here on
# 2026-08-21 and the red-arm test caught it: the launcher refused correctly, then
# announced "exited 0" and EXITED 0. ⭐ That is the same defect I had criticised in
# backup.exs three hours earlier — an instrument that reports failure in text and
# success in its exit code. `rc` must come from the command itself, with `set -e`
# suspended so the failure does not abort before we can read it.
set +e
"$SHARED/bin/cp-pin-status" >&2
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "⛔ REFUSING TO BOOT: cp-pin-status exited $rc (boot requires exit 0)." >&2
  echo "   The verdict above is verbatim from the gauge — act on it, do not guess." >&2
  echo "   ⛔ NOT falling back to $SHARED. Run: $SHARED/bin/cp-deploy-pin <sha>" >&2
  exit "$rc"
fi
echo "✅ cp-pin-status exit 0 — booting from the pin at $PIN" >&2
# ══════════════════════════════════════════════════════════════════════════════════

CP=$PIN                                   # code: the pinned worktree
DATA=$SHARED/workspace/.commonplace       # data: the LIVE store, unchanged and absolute

# ⛔⛔ ACTUALLY CHANGE DIRECTORY. `PWD=$CP` in the env below is a STRING; it does not
# move the process. `mix` resolves its project from the REAL working directory, which
# is inherited from the launching shell — i.e. the shared tree.
# ⚠️ 2026-08-21: the first pinned migration came up HTTP 200, gate green, this script
# printing "booting from the pin" — and `readlink /proc/<pid>/cwd` said
# /home/jes/commonplace. Everything reported success and the one property that mattered
# was FALSE. Caught only by checking the cwd BY EFFECT rather than believing the banner.
cd "$PIN" || { echo "⛔ REFUSING TO BOOT: cannot cd to $PIN" >&2; exit 2; }

# ── THE ALLOWLIST ──────────────────────────────────────────────────────────────────
# Derived from the LAST KNOWN-CLEAN serve's own environ, not from what happens to be
# in my shell. Anything not named here does not reach the serve, by construction.
exec env -i \
  HOME=/home/jes \
  USER=jes \
  LOGNAME=jes \
  SHELL=/bin/bash \
  LANG=C.UTF-8 \
  TERM=xterm-256color \
  PATH=/home/jes/.asdf/installs/erlang/27.3.4.8/erts-15.2.7.6/bin:/home/jes/.asdf/installs/erlang/27.3.4.8/bin:/home/jes/.asdf/plugins/elixir/shims:/home/jes/.asdf/installs/elixir/1.18.4-otp-27/bin:/home/jes/.asdf/installs/elixir/1.18.4-otp-27/.mix/escripts:/home/jes/.asdf/shims:/home/jes/.asdf/bin:/home/jes/.local/bin:/home/jes/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  ASDF_DIR=/home/jes/.asdf \
  ASDF_DATA_DIR=/home/jes/.asdf \
  MIX_HOME=/home/jes/.asdf/installs/elixir/1.18.4-otp-27/.mix \
  MIX_ARCHIVES=/home/jes/.asdf/installs/elixir/1.18.4-otp-27/.mix/archives \
  PWD=$CP \
  PORT=5199 \
  PHX_SERVER=true \
  COMMONPLACE_DATA_DIR=$DATA \
  COMMONPLACE_LOCAL_WRITE_GATE=enforce \
  COMMONPLACE_MUD_FULL_CITIZENSHIP=true \
  ERL_EPMD_ADDRESS=127.0.0.1 \
  ERL_INETRC=/home/jes/boss-clod/erl_inetrc \
  ELIXIR_ERL_OPTIONS="-kernel inet_dist_use_interface {127,0,0,1}" \
  /home/jes/.asdf/shims/elixir --sname commonplace_dev -S mix phx.server
