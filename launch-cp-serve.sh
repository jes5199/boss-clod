#!/usr/bin/env bash
# Launch the commonplace :5199 serve with an ALLOWLIST environ.
#
# WHY env -i: on 2026-08-13 the serve was found carrying an inherited
# ANTHROPIC_API_KEY it had no use for. The fix is not "unset that one" --
# it is to name what the serve gets, so a new secret in the launcher's
# shell cannot arrive here by inheritance.
#
# BIRTH REQUIREMENT (measured 2026-08-14): the deploy-gap monitor resolves
# its gauge as Path.expand("bin/cp-deploy-gap"), which is CWD-RELATIVE.
# Launched from anywhere else the serve logs "gap UNKNOWN" every 60s
# instead of working. So the cd below is load-bearing, not tidiness.
#
# ABORT: relaunch with COMMONPLACE_DEPLOY_GAP_MONITOR=0 to drop the monitor.
#
# AFTER LAUNCH, CHECK FOR THE MONITOR'S BOOT LINE (added @e75273ef, so present
# from the first restart after 2026-08-14 19:10Z):
#   grep -i 'deploy gap monitor' logs/commonplace-serve.log   <- expect one [info]
# It names the resolved gauge path and the interval, and says silence means an
# EMPTY gap. ⇒ Its ABSENCE means the monitor never started -- which is the one
# thing the per-check silence cannot tell you apart from "gap is 0".
# And to answer "is the monitor WORKING?", nothing in the log suffices: touch a
# beam, wait one interval, expect an unprompted DEPLOY GAP DETECTED, then
# restore the mtime and md5-verify the content never changed.
set -euo pipefail

CP=/home/jes/commonplace
LOG="${LOG:-/home/jes/boss-clod/logs/commonplace-serve.log}"

cd "$CP"
mkdir -p "$(dirname "$LOG")"

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
  ASDF_CONFIG_FILE=/home/jes/.asdfrc \
  ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=.tool-versions \
  MIX_HOME=/home/jes/.asdf/installs/elixir/1.18.4-otp-27/.mix \
  MIX_ARCHIVES=/home/jes/.asdf/installs/elixir/1.18.4-otp-27/.mix/archives \
  PORT=5199 \
  PHX_SERVER=true \
  COMMONPLACE_DATA_DIR=/home/jes/commonplace/workspace/.commonplace \
  COMMONPLACE_LOCAL_WRITE_GATE=enforce \
  COMMONPLACE_MUD_FULL_CITIZENSHIP=true \
  ${COMMONPLACE_DEPLOY_GAP_MONITOR:+COMMONPLACE_DEPLOY_GAP_MONITOR=$COMMONPLACE_DEPLOY_GAP_MONITOR} \
  ERL_EPMD_ADDRESS=127.0.0.1 \
  ERL_INETRC=/home/jes/boss-clod/erl_inetrc \
  ELIXIR_ERL_OPTIONS='-kernel inet_dist_use_interface {127,0,0,1}' \
  elixir --sname commonplace_dev -S mix phx.server
# ⚠️ --sname commonplace_dev IS LOAD-BEARING, not cosmetic. bin/cp-deploy-gap
# identifies the serve as `comm==beam.smp AND cmdline contains commonplace_dev`.
# Launched without it (2026-08-14, my error) the serve runs fine and the gauge
# reports "REFUSING -- no running commonplace serve found" -> monitor logs
# "deploy gap is unknown (gauge exit 2)" every cycle. The node name is also
# what makes `iex --sname x --remsh commonplace_dev` work.
