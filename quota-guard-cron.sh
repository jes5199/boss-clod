#!/bin/bash
# Cron wrapper for quota-guard. Runs every 15 min.
#
# ⚠️ quota-guard.sh was NOT on cron at all until 2026-08-09 — it had been
# computing verdicts nobody received. A guard that isn't scheduled is a guard
# that says whatever you want, since no one hears it disagree.
#
# Appends to a log rather than mailing, and records the verdict WITH ITS
# TIMESTAMP so "it never fired" can be distinguished from "it never ran".
set -o pipefail
LOG=/home/jes/boss-clod/logs/quota-guard.log
mkdir -p "$(dirname "$LOG")"
touch /home/jes/boss-clod/.heartbeat-quota-guard 2>/dev/null || true
OUT=$(/home/jes/boss-clod/quota-guard.sh 2>&1); RC=$?
printf '%s rc=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RC" "$OUT" >> "$LOG"
exit 0
