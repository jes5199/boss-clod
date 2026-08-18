#!/bin/bash
# Samples host memory + the top RSS consumers every 20s into a ring log.
#
# WHY THIS EXISTS (2026-08-18): two OOM kills 11 minutes apart, both of which
# took a Sol round as collateral, and the allocator is UNIDENTIFIED. The one
# artifact that would name it — the kernel's OOM dump with the process table
# at kill time — is unreadable from an agent session: journalctl -k shows
# "No entries" without group adm/systemd-journal, dmesg refuses, and
# /var/log/kern.log is syslog:adm 0640.
#
# ⛔ SO THE NEXT KILL MUST NOT ALSO BE UNOWNED. This does not prevent an OOM;
# it guarantees the 20 seconds before one are on disk in a file I CAN read.
#
# ⚠️ WHAT IT DELIBERATELY DOES NOT DO: name a suspect. A cron at :17 matching
# a kill at 23:17:19 is a temporal coincidence, and the same job ran at 22:17
# and 21:17 with no kill — so it is a candidate, not a cause. This file
# collects evidence; it does not carry a theory.
#
# Runs as a transient unit so it cannot take anything with it if it grows.
LOG=/home/jes/boss-clod/.mem-samples
MAX_LINES=20000

while true; do
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  read -r AVAIL SWU SWT < <(awk '
    /^MemAvailable:/{a=int($2/1024)}
    /^SwapTotal:/{t=int($2/1024)}
    /^SwapFree:/{f=int($2/1024)}
    END{print a, t-f, t}' /proc/meminfo)
  # top 3 by RSS, name+pid+MB, on one line
  TOP=$(ps -eo rss,pid,comm --sort=-rss 2>/dev/null | awk 'NR>1 && NR<=4 {printf "%s/%s:%dMB ", $3, $2, $1/1024}')
  printf '%s avail=%sMB swap=%s/%sMB top=[%s]\n' "$TS" "$AVAIL" "$SWU" "$SWT" "$TOP" >> "$LOG"

  # ring: keep the file bounded without a rotation dependency
  LINES=$(wc -l < "$LOG" 2>/dev/null || echo 0)
  if [ "$LINES" -gt "$MAX_LINES" ]; then
    tail -n $((MAX_LINES / 2)) "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
  sleep 20
done
