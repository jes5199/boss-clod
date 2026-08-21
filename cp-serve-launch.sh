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

CP=/home/jes/commonplace
DATA=$CP/workspace/.commonplace

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
