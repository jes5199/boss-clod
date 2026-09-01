#!/usr/bin/env bash
# Capture a process's WHOLE environ for deploy diffing. Values are NEVER
# written in plaintext — every value is stored as its sha256.
#
# ⛔ WHY THIS EXISTS (LESSONS 7aw/7ax, 2026-08-12). The standing rule is
#    "capture the whole environ, NEVER grep-filter it" — filtering misses what
#    you didn't think to grep for. That rule collides with secret hygiene, and
#    I got the collision wrong TWICE before landing here:
#
#    v1  resolved it in the DISPLAY path (diff only shows changes, so secrets
#        stay hidden). FAILED: I diffed against an already-exited pid, the
#        "after" side came back EMPTY, every line rendered as a removal, and a
#        live ANTHROPIC_API_KEY got dumped. A diff with one empty side is not a
#        diff, it is a DUMP — and the safety evaporated exactly when something
#        went wrong, which is when I was most likely to be looking.
#
#    v2  redacted by KEY NAME at capture time. Better — but commonplace-plan
#        caught that it carries the SAME blind spot as the value-sniffing it
#        replaced, merely rotated 90°: a name list misses secrets in names you
#        did not anticipate (MY_WEIRD_TOKEN sails straight through), exactly as
#        value-sniffing missed shapes you did not anticipate. A curation list
#        is a list of things you already thought of.
#
# ⭐ v3, THE SHAPE THAT DISSOLVES THE TENSION INSTEAD OF MANAGING IT:
#    store name=sha256(value) for EVERY var. No plaintext values at all, so
#    there is no list to maintain and nothing to get wrong.
#      • drift detection loses NOTHING — a changed value changes its hash
#      • added/removed vars stay visible, because NAMES remain plaintext
#      • what a value changed TO is recoverable AT NEED-TIME, as a named
#        exception, by reading that one var live
#    Secret hygiene and whole-environ capture stop being in tension BY
#    CONSTRUCTION rather than by curation.
#
# ⚠️ HONEST LIMIT: sha256 of a LOW-ENTROPY value is brute-forceable (PORT=5199
#    falls in one guess). That is fine and by design — low-entropy values are
#    not the secrets. Real credentials are high-entropy and safe under this.
#    The guarantee is "no plaintext secret is written", not "the file is opaque".
#
# Usage: capture-environ.sh <pid> <outfile>

set -euo pipefail

PID="${1:?usage: capture-environ.sh <pid> <outfile>}"
OUT="${2:?usage: capture-environ.sh <pid> <outfile>}"

if [ ! -r "/proc/$PID/environ" ]; then
  echo "REFUSING: /proc/$PID/environ is not readable — process gone or not yours." >&2
  echo "  (Capturing an empty file here is what turns a later diff into a dump.)" >&2
  exit 1
fi

# NAME stays plaintext (so appearances/disappearances diff); VALUE becomes a
# hash. Split on the FIRST '=' only — values legitimately contain '='.
tr '\0' '\n' < "/proc/$PID/environ" \
  | awk -F= '
      NF >= 1 {
        name = $1
        value = substr($0, length(name) + 2)
        print name "\t" value
      }' \
  | while IFS=$'\t' read -r name value; do
      h=$(printf '%s' "$value" | sha256sum | cut -c1-16)
      printf '%s=sha256:%s\n' "$name" "$h"
    done \
  | sort > "$OUT"

N=$(wc -l < "$OUT")
if [ "$N" -eq 0 ]; then
  echo "REFUSING: captured 0 vars from pid $PID — refusing to write an empty baseline." >&2
  rm -f "$OUT"
  exit 2
fi

# Non-vacuity: prove no plaintext survived the transform.
if grep -qvE '=sha256:[0-9a-f]{16}$' "$OUT"; then
  echo "REFUSING: a line escaped hashing — not writing a file that may hold plaintext." >&2
  grep -vE '=sha256:[0-9a-f]{16}$' "$OUT" | head -3 | sed 's/^/  /' >&2
  rm -f "$OUT"
  exit 3
fi

echo "captured $N vars from pid $PID -> $OUT (all values sha256, no plaintext)" >&2
