#!/usr/bin/env bash
# ⛔⛔ EDIT THIS FILE ATOMICALLY: temp file → `bash -n` → `mv`. NEVER IN PLACE.
# 2026-08-27T18:38Z — `value` measured `box-health.sh` TORN TWICE in four minutes while I
# edited it in place; `dir`'s gate exited on my syntax error; `cell` nearly filed "boss's
# health tool does not parse" from a torn read. ⭐ A TORN READ OF A FILE SOMEONE IS ACTIVELY
# WRITING IS INDISTINGUISHABLE FROM A DEFECT IN THEIR WORK.
# ⛔ THIS FILE IS WORSE THAN THAT ONE. Known consumers, six and counting:
#   markdown/next/cell/doc  — dispatch-round.sh:40 (committed, greppable)
#   yepochs, log            — BY TYPING IT AT A PROMPT (invisible to every grep)
# ⇒ ⭐⭐ A SELECTOR OVER COMMITTED FILES CANNOT SEE A DEPENDENCY THAT IS NEVER WRITTEN DOWN.
#   `log`: "that is a WORSE hiding place, not a better one — markdown's dependency is at
#   least visible at dispatch-round.sh:40; mine is in my habits and nowhere else."
#   ⇒ ASSUME EVERY DOOR THAT DISPATCHES SOL IS EXPOSED, not the four that could prove it.
# ⛔ AND THE ASYMMETRY `dir` NAMED: this file HAS NO VERDICT LINE. A launcher cannot tell
#   "the fence ran and refused" from "the fence was mid-edit", the way a health call can —
#   because the fence's contract is "it runs the round", not "it emits a verdict".
#   ⇒ A torn read here BREAKS A DISPATCH and presents AS A SOL FAILURE, not an editing one.
#   THIS IS THE DOOR WITH NO INTERLOCK. There is no guard on the reader's side; the only
#   protection is that the writer never publishes a partial file.
# ⚠️⚠️ THE FILENAME IS MISLEADING AND THIS BANNER EXISTS BECAUSE IT MISLED SOMEONE.
#
#   "sol-egress-run" MEANS "THE SOL RUNNER **WITH** EGRESS".
#   IT DOES NOT MEAN "THE RUNNER THAT RESTRICTS EGRESS". THERE IS NO EGRESS FENCE HERE.
#   THE SANDBOX SHARES THE HOST NETWORK NAMESPACE, BY DESIGN, BY jes'S RULING.
#
# 2026-08-17: commonplace read the name as a restriction, measured the shared netns
# correctly (with an --unshare-net must-fail control), and escalated it as a security
# finding. The measurement was right; the name is what was wrong. It had dispatched
# eight rounds through this wrapper believing "egress" named a fence.
# ⇒ No harm resulted — the sandbox behaved exactly as documented below — but a careful
#   reader was misled by the filename alone, so the correction lives at the top now.
#
# Sol runner WITH EGRESS — approved by jes 2026-08-07 ("i approve your egress plan").
#
# WHY THIS EXISTS: jes ruled Sol may have internet access. Measurement showed the real
# cost was never the network boolean alone -- it is the boolean COMPOSED WITH BROAD READS.
# Inside a plain `--sandbox workspace-write` run, Sol could read ~/.ssh/id_ed25519 and saw
# LETTA_API_KEY + SQUAD_ALERTS_PUBLISHER_TOKEN in its environment. With egress open, that
# combination is the whole exfiltration surface.
#
# codex's own shell_environment_policy DOES NOT scrub those vars -- measured, three variants
# (inherit="core", exclude globs, exclude exact names) all still showed 2. Cause unknown.
# So the scrub happens HERE, in the parent env, where it is verifiable by effect.
#
# What this does NOT change: the live store and the CLI escript stay unreachable. This
# wrapper only removes secrets and grants network; it never widens write access.

# ⛔⛔ BRIEFING RULE FOR EVERYTHING RUN THROUGH THIS WRAPPER
# (commonplace-plan, 2026-08-09):
#
#   ANYTHING MEASURED INSIDE THE FENCE INHERITS THE FENCE AS A FACT.
#
# Masked paths, denied egress, read-only mounts, absent credentials -- NONE
# of them announce themselves in the result. They surface as ordinary
# negative findings with plausible mechanisms attached. The trust-anchor
# collision below is the instance we happened to CATCH, and only because the
# mask and the anchor source collided somewhere legible. Most collisions
# will not be.
#
#   1. Before briefing sandboxed work, ask: COULD THE FENCE PRODUCE THIS
#      RESULT? If yes, the task is not awkward here -- it is UNASSIGNABLE
#      here.
#   2. NAME WHAT IS MASKED IN THE BRIEF, so a negative result can be READ
#      rather than believed.
#   3. Where it matters, require a CONTROL TAKEN OUTSIDE THE FENCE -- the
#      same discipline as a positive control on an absence check.
#
# ⚠️ Why this is hard to hold: the artefact is most dangerous when the
# sandbox exists for a GOOD reason. Nobody re-examines a mask that is
# correct -- which is exactly how a correct mask goes on quietly generating
# findings.
#
# ⛔⛔ THE ONE INSTANCE THAT KEEPS RECURRING -- IN HERE, RED IS THE EXPECTED
# RESULT AND A GREEN IS THE THING TO DISBELIEVE:
#
#   node_signing_key is masked => NodeIdentity.signing_context/0 fails
#   => the anchor set is EMPTY. NO node-signed write and NO real chain
#   verification can succeed in here.
#
#   * A REFUSAL IS THE FENCE, NOT A DEFECT.
#   * A SUCCESS is evidence about the harness, not about the code -- it
#     means the mask is not applying, and that is the finding.
#   * Test signing paths against a fixture `opts[:signing_context]`. The
#     codebase ALREADY threads opts at Bursar and Frontier.Server -- reuse
#     that seam rather than declaring the success path unverifiable.
#
# ⚠️ Forgetting this does not produce a stuck run. It produces a CONFIDENT
# WRONG DIAGNOSIS -- "signing is broken" -- which is the kind that ships.
# Two briefs in a row carried this as a per-brief note; it belongs here,
# where the fence is defined, so the next brief inherits it without anyone
# having to remember.

# ⛔⛔ THIRD FAILURE MODE, OBSERVED 2026-08-09 — THE SANDBOX IS NOT THE ONLY
# FENCE. codex REFUSES SOME BRIEFS OUTRIGHT:
#
#   "ERROR: This content was flagged for possible cybersecurity risk."
#
# CX-s36k burned 31,923 tokens and produced ZERO source changes. The wrapper
# EXITED 0. `git diff --stat` was empty.
#
# ⚠️ ⇒ A REFUSED RUN AND A RUN WITH NOTHING TO DO ARE BYTE-IDENTICAL FROM
# OUTSIDE: empty diff, clean status, rc=0. Reporting "no changes needed" is
# the natural and WRONG reading. The only thing that distinguishes them is
# the run log. ⭐ ALWAYS grep the log for the refusal string before
# interpreting an empty diff — this is the same "blocked and not there share
# an exit code" rule, arriving one layer above where we were watching for it.
#
# ⛔⛔ 2026-08-11: THE RUN LOG IS NOT GUARANTEED TO SURVIVE. On S15, Sol
# DELETED it as tidying -- its own transcript says "Its generated sol-run.log
# was removed." So the artifact the rule above depends on can be absent for a
# reason that has nothing to do with refusal.
# ⭐ DURABLE FALLBACK, use it whenever sol-run.log is missing:
#     ~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-*.jsonl
# That is codex's own session transcript. It carries the COMPLETE final report
# including any refusal sentinel, and Sol cannot tidy it away -- it is outside
# the worktree. ⇒ Missing log is NOT "cannot determine"; it is "look one layer
# down." Treat absence as ambiguous ONLY after the rollout file is also checked.
# ⚠️ AND WATCH WHOSE ARTIFACT YOU ARE READING: the worktree you inspect after a
# run may already be the REVIEWER'S cleaned state, not Sol's raw output. On S15
# the 2-file footprint I read as "exactly right" was post-cleanup; Sol had also
# left formatter churn across 17 web files, discarded before I looked. The
# inference held, but it was a claim about a mutated artifact.
#
# ⚠️ AND IT IS NOT CREDIT EXHAUSTION. Check the two separately; they have
# different remedies (re-brief vs stop the loop). A grep for
# credit|quota|exhaust|rate.?limit returning 0 needs the flag lines as its
# positive control, or the zero means nothing.
#
# ⇒ TRIGGER IS SUBJECT MATTER, NOT INTENT: security vocabulary in quantity --
# crash traces, denial auditing, trust gates, "attack surface", raw
# :calling_self dumps. Same family as the Fable cyber-refusal on deploy work
# (see reference_fable_cyber_refusal_fallback). REMEDY: re-brief in
# MECHANICAL terms -- "pattern-match axis", "process-vs-payload",
# "assert the handler is still registered" -- and drop the trace dumps. The
# work is unchanged; only the vocabulary is.

set -euo pipefail

WORKDIR="${SOL_WORKDIR:?set SOL_WORKDIR to the isolated worktree -- never /home/jes/commonplace}"

# Refuse to run against the live checkout. The fence is not negotiable by argument.
case "$(readlink -f "$WORKDIR")" in
  # ⛔⛔ 2026-08-24T01:08Z — THIS FENCE WAS SILENTLY OPEN FOR ~5 HOURS. The 20:00Z repo rename made
  # /home/jes/commonplace a SYMLINK to /home/jes/commonplace-monolith, and `readlink -f` returns the
  # PHYSICAL path — so the live checkout stopped matching these patterns and SOL_WORKDIR=/home/jes/
  # commonplace was ALLOWED. ⭐ A fence keyed on a path string is keyed on a NAME, and a rename is
  # exactly the event that separates a name from the thing it names.
  # ⇒ Both spellings now, and the physical one FIRST because it is what readlink -f produces.
  /home/jes/commonplace-monolith|/home/jes/commonplace-monolith/*|/home/jes/commonplace|/home/jes/commonplace/*)
    echo "REFUSED: SOL_WORKDIR points at the live checkout ($WORKDIR)" >&2
    exit 64
    ;;
esac

# ══════════════════════════════════════════════════════════════════════════════
# ⛔ CONCURRENCY CAP, MOVED INTO THE RUNNER 2026-08-22.
#
# WHY NOW: until tonight exactly ONE agent (commonplace) dispatched Sol, and the
# cap lived in sol-nudge.sh — so the gate sat on the only path to the runner and
# that was sufficient. jes then moved commonplace-log onto Sol programmers, which
# makes it TWO dispatchers. I grepped both files before widening the dispatch:
# sol-nudge.sh has 9 cap/memory checks, THIS FILE HAD ZERO. Two agents calling the
# runner directly would each have launched unimpeded, and neither would have seen
# the other. sol-nudge.sh's own line 155 already said so in a comment —
# "commonplace's own dispatch bypasses it" — a known bypass that was harmless
# only because there was one caller.
#
# ⭐ THE GATE BELONGS ON THE RESOURCE, NOT ON ONE ROUTE TO IT. A cap that a
# second caller can walk around is not a cap; it is a habit that happened to hold
# while only one agent had the habit. A FILED ARTIFACT FIRES; A NOTE IN A BRIEF
# ASKING AGENTS TO COORDINATE DOES NOT.
#
# ⚠️ A round is ~6G and the box has no cgroup limit anywhere (2026-08-18 OOM).
# OOMPolicy=stop takes the WHOLE tmux scope, and hermes runs a live-money BEAM on
# this host. Declining a round costs a cycle; getting this wrong costs the fleet.
#
# ⛔ COUNT ROUNDS, NOT PROCESSES — one codex round is >=2 pids (the node wrapper
# and the native binary it execs) sharing a PGID. Counting pids made the cap of 2
# silently behave as a cap of 1, which declines quietly and looks exactly like a
# busy pool. This is the same logic as sol-nudge.sh; it is duplicated ON PURPOSE
# so the runner is safe no matter who calls it.
SOL_MAX_PARALLEL="${SOL_MAX_PARALLEL:-2}"
# ⛔ `|| true` HERE FOR THE SAME REASON AS THE grep BELOW, and I needed TWO tries
# to find it: pgrep ALSO exits 1 on no-match. I fixed the grep first, re-ran the
# red arm, still got a silent exit 1, and only a `bash -x` trace showed the script
# was dying HERE — one line earlier — having never reached the fix. ⭐ Two commands
# in this block return 1 on the EMPTY case, which is the NORMAL case; under
# `set -e` the gate aborted the whole runner exactly when nothing was in flight.
# ⇒ Fixing the first cause a trace points at does not mean the symptom had one.
# ⛔⛔ TOCTOU: THE CAP IS CHECK-THEN-ACT AND HAD NO MUTUAL EXCLUSION. (2026-08-24T18:47Z)
#   commonplace-log dispatched two rounds close together while commonplace-dir already had one.
#   BOTH read N_INFLIGHT before EITHER had spawned, both saw a free slot, and three rounds ran
#   under a cap of 2. The counting logic is CORRECT — re-tested against the live 3-round state,
#   it returns N=3 and WOULD refuse. Nothing was wrong with the arithmetic; the window was.
# ⭐ A gate that reads shared state and then acts on it is not a gate until the read and the act
#   are ATOMIC. Every measurement I took of this cap was of the ARITHMETIC, which was never the
#   defect — the same shape as testing an oracle and never testing the corpus.
# ⇒ Serialise admission on a lock file. The lock is held across COUNT + LAUNCH, so a second
#   dispatcher blocks until the first has actually spawned and is therefore countable.
# ⚠️ -w 30: WAIT, do not fail. A refusal here would be indistinguishable from the cap refusing,
#   which is a DIFFERENT decision with a different remedy.
exec 9>/home/jes/boss-clod/.sol-admission.lock
flock -w 30 9 || { echo "REFUSED: could not acquire admission lock in 30s — NOT the cap; investigate." >&2; exit 66; }
# ⛔⛔ 2026-08-25T10:21Z — A PHANTOM HELD A CAP SLOT FOR 48 MINUTES. commonplace-next measured an
#   orphaned wrapper (ppid 1) whose cmdline still carried "codex exec … -C /home/jes/sol-next-p5/wt"
#   AFTER its round had exited — no codex descendant left inside it. `pgrep -f` matches the STRING,
#   so the corpse counted as a live round, and the dispatcher's ps scan even captured it as the next
#   round's outer.pid, which would have made a waiter watch a dead process.
# ⭐ Same family as commonplace-dir's waiter matching a work-id that appears in a sibling's BRIEF:
#   a selector keyed to TEXT matches anything that merely CONTAINS the text, including a corpse.
# ⇒ Count what the round IS, not what its command line SAYS: processes whose comm is exactly
#   `codex`. A wrapper with no live codex inside it is not a round.
# ⚠️ SAFE ONLY BECAUSE OF THE RESERVATION ABOVE: narrowing the count reopens the launch window
#   (wrapper started, real binary not yet exec'd) — and reservations already cover exactly that.
#   Do not narrow this without that block present.
INFLIGHT=$(pgrep -u "$(id -un)" -x codex 2>/dev/null || true)
if [ -n "$INFLIGHT" ]; then
  INFLIGHT_PGIDS=$(ps -o pgid= -p $(printf '%s' "$INFLIGHT" | tr '\n' ',' | sed 's/,$//') 2>/dev/null \
                   | tr -d ' ' | sort -u | grep '[0-9]')
else
  INFLIGHT_PGIDS=""
fi
# ⛔ `|| true` IS LOAD-BEARING, NOT DEFENSIVE PADDING. `grep -c` EXITS 1 WHEN THE
# COUNT IS ZERO, and under `set -euo pipefail` a bare assignment from it ABORTS
# THE SCRIPT on the commonest case of all: nothing in flight. I shipped exactly
# that here on 2026-08-22 and the red-arm test caught it — the gate exited 1 and
# printed nothing, and my GREEN arm passed VACUOUSLY because it only grepped for
# the refusal string, which was absent because the script had already died rather
# than because the gate correctly stayed quiet. ⭐ A green-only pattern cannot
# distinguish "gate stayed silent" from "gate never ran".
N_INFLIGHT=$(printf '%s\n' "$INFLIGHT_PGIDS" | grep -c '[0-9]' || true)

# ⛔⛔ 2026-08-25T06:16Z — THE CAP ADMITTED THREE. Measured: sol-cell-p3 (17:54), sol-value-p6
#   (05:41) and sol-cell-p1c (05:41) all live, three distinct pgids, cap 2. The two 05:41 rounds
#   launched in the same second.
# ⭐ THE LOCK WAS NOT THE BUG — THE WINDOW I DOCUMENTED AS "microseconds" WAS THE BUG. Between
#   `exec 9>&-` and the round becoming visible to pgrep lies env + bwrap (twenty-odd binds) + a
#   NODE wrapper start. That is hundreds of milliseconds, not microseconds. I wrote the estimate
#   without measuring it, and it was the whole safety argument for releasing the lock early.
# ⇒ ⭐⭐ A COUNT OF WHAT IS RUNNING CANNOT SEE WHAT IS ABOUT TO RUN. Fix the referent, not the
#   lock: count LIVE ROUNDS + OUTSTANDING RESERVATIONS. A reservation is written under the lock
#   and retired by a later purge the moment its own round becomes countable.
RESERVE_DIR=/home/jes/boss-clod/.sol-reservations
mkdir -p "$RESERVE_DIR"
# Purge: (a) a reservation whose round is now visible — it is counted as in-flight, not twice;
#        (b) a reservation older than the TTL — its launch died between reserve and exec.
# ⚠️ TTL is a BACKSTOP for a dead launcher, not the mechanism. If it ever does the work, a
#   launcher is failing silently between reservation and exec and that is its own defect.
RESERVE_TTL=120
_now=$(date +%s)
for _r in "$RESERVE_DIR"/*.reserved; do
  [ -e "$_r" ] || continue
  _rwd=$(cat "$_r" 2>/dev/null || echo)
  _rage=$(( _now - $(stat -c %Y "$_r" 2>/dev/null || echo "$_now") ))
  if [ "$_rage" -ge "$RESERVE_TTL" ]; then
    echo "NOTE: retiring reservation for ${_rwd:-?} after ${_rage}s — its launch never became countable." >&2
    rm -f "$_r"; continue
  fi
  for _p in $INFLIGHT; do
    _pc=$(tr '\0' '\n' < "/proc/$_p/cmdline" 2>/dev/null | grep -A1 -x -- '-C' | tail -1)
    if [ -n "$_pc" ] && [ "$_pc" = "$_rwd" ]; then rm -f "$_r"; break; fi
  done
done
N_RESERVED=$(find "$RESERVE_DIR" -maxdepth 1 -name '*.reserved' -type f 2>/dev/null | wc -l)
N_INFLIGHT=$(( N_INFLIGHT + N_RESERVED ))
if [ "$N_INFLIGHT" -ge "$SOL_MAX_PARALLEL" ]; then
  echo "REFUSED: $N_INFLIGHT codex round(s) already in flight, cap is $SOL_MAX_PARALLEL." >&2
  echo "  pgids: $(echo $INFLIGHT_PGIDS | tr '\n' ' ') | pids: $(echo $INFLIGHT | tr '\n' ' ')" >&2
  echo "  of which $N_RESERVED are RESERVATIONS (admitted, not yet visible to pgrep)." >&2
  echo "  This is the CAP, not an error. Wait for a slot; do not raise the cap to get past it." >&2
  exit 65
fi
# ══════════════════════════════════════════════════════════════════════════════

# Sensitive paths masked with an empty tmpfs. ~/.codex/auth.json is deliberately NOT masked:
# codex needs it to authenticate, so it is a known, accepted residual.
MASK=(
  --tmpfs /home/jes/.ssh
  --tmpfs /home/jes/.config/gh
  # ⛔ TWO REASONS, AND THE SECOND WAS NEVER WRITTEN DOWN UNTIL 2026-08-13:
  #   ① it holds channel credentials (the reason it was added), and
  #   ② ⭐ clod-squad's TRANSPORT lives here — queue.db, a SQLite file, not a
  #      socket. So this mask is what fences a sandboxed agent out of the
  #      inter-agent message bus. Removing it as "just credentials, and we
  #      scrub those from the env anyway" would silently restore that reach.
  # ⚠️ An unstated reason that happens to be right is ONE EDIT AWAY from being
  #   removed as redundant — the reverse of the night's other failures, where
  #   stated lists were wrong. Both are cured by writing the reason at the site.
  --tmpfs /home/jes/.claude/channels
  # ⛔ CX-7fxm (2026-08-13): CONTROL-PLANE SOCKETS, not credentials.
  # The tmux server socket lets a sandboxed agent `send-keys` into ANY pane —
  # hermes (live money), boss, every worker. That is command injection into
  # other sessions, strictly worse than the PID-namespace hole closed hours
  # earlier, because typing beats signalling.
  # ⚠️ CLEARING $TMUX IS NOT ENOUGH AND LOOKS LIKE IT IS: tmux falls back to
  # the DEFAULT socket path when the variable is unset, so `tmux list-panes -a`
  # still worked with TMUX=[] — measured. The env handle and the filesystem
  # channel are two properties; closing one certifies nothing about the other.
  --tmpfs /tmp/tmux-1000
  # ⛔ CX-vc0q (2026-08-13): THIS LIST WAS DERIVED BY MEASUREMENT, NOT RECALLED.
  # Three parties produced three incomplete channel lists in one night — Sol
  # found two I had missed (claude-chat relay, the tsx pipe); I had missed
  # cc-socks and the dbus bus; commonplace's brief asked for an inventory
  # without saying how to derive one. ⭐ A HAND-MAINTAINED LIST OF CHANNELS IS
  # THE SAME DEFECT AS A DENYLIST OF SECRETS, ONE LEVEL UP, and "be more
  # thorough" failed three times in a row.
  # ⇒ REGENERATE with, and mask the CONTAINING DIRECTORIES so future sockets
  #   appearing inside them are covered without another edit:
  #     find /run/user/$(id -u) /tmp -maxdepth 3 \( -type s -o -type p \) |
  #       xargs -n1 dirname | sort -u
  #   Last derived 2026-08-13: 23 channels — 6 live Claude Code session sockets,
  #   6 gnupg agent sockets (incl. S.gpg-agent.ssh), the dbus session bus,
  #   systemd's private/notify sockets, a weechat fifo, tmux, claude-chat, tsx.
  # ⚠️ /tmp/cc-daemon-1000 EXISTS AND HOLDS NO SOCKETS — masking it passes an
  #   `ls` check and protects nothing. The live sockets are one tree over. That
  #   is why acceptance is AN ATTEMPTED CONNECTION, never a path's tmpfs-ness.
  --tmpfs /run/user/1000
  --tmpfs /tmp/claude-chat
  --tmpfs /tmp/tsx-1000
  # 2026-08-07: the live store's own credentials. Sol needs commits/ to
  # investigate the 450x gap (jes: "if Claude can do it, then Sol can do it")
  # but it does NOT need the node's signing identity or the secrets store.
  # These were readable from the moment egress was opened -- workspace-write
  # restricts WRITES; READS were always broad. Masking them keeps exactly the
  # access jes asked for and removes the part nobody intended.
  # ⚠️ CX-cj59 (2026-08-09): THIS MASK SILENTLY EMPTIES THE TRUST ANCHOR SET.
  # Trust.config/0 ends in with_local_node_trust/1, which is BEST-EFFORT
  # (`else _ -> cfg`) and supplies the ONLY anchor on this workspace --
  # trust.json's trusted_identities is {}. Masked here, the key reads as
  # 0 bytes but READABLE (not an error), so public_key() fails, the fold is
  # skipped, anchors become the empty set, and check_root rejects EVERY
  # chain with :untrusted_root -- because MapSet.member?(empty, _) is false.
  # ⚠️ node_id is NOT masked and still resolves, so identity() SUCCEEDS while
  # public_key() fails: the two halves disagree and nothing says why.
  # ⇒ A Sol run that exercises trust will see a wave of :untrusted_root and
  # it will look like a CHAIN defect rather than a masked local key. If a
  # brief sends Sol near trust/capability code, SAY THIS IN THE BRIEF.
  # ⛔ STRONGER CONSEQUENCE (commonplace-plan, 2026-08-09): masking the key
  # does not only stop Sol SIGNING -- it disables VERIFICATION. With the
  # node fold as the only anchor source, any commonplace process inside
  # this sandbox silently cannot verify ANY chain. ⇒ CHAIN-VERIFICATION
  # WORK IS STRUCTURALLY IMPOSSIBLE BEHIND THIS FENCE, not merely awkward:
  # do not brief Sol to verify, audit or test capability chains here --
  # it can only ever measure the empty-anchor artefact.
  # ⭐ This is an independent argument for a delegation root DISTINCT from
  # the node signing identity: with one key doing both jobs, masking-it-for-
  # safety and needing-it-to-verify collide. With a separate root, Sol could
  # hold the PUBLIC half to verify while the node's PRIVATE key stays masked.
  #
  # ⛔ THIRD CONSEQUENCE (CX-cj59, 2026-08-09) -- AND IT IS A FORWARD RISK TO
  # THIS FENCE, NOT JUST TO THE SUBJECT. The chain is:
  #   key unreadable -> signing_context() fails -> node_ctx nil
  #   -> sign_opts/1 returns [] -> write unsigned -> REFUSED under enforce
  #   -> the component's ERROR PATH RUNS.
  # A patch that nearly landed made that path `exit(...)` inside init/1 on a
  # `restart: :permanent` child -- i.e. a refused write became a BOOT CRASH
  # LOOP for the custody manager. ⇒ THE SET OF COMPONENTS WHOSE ERROR PATH
  # DIES ON A REFUSED WRITE IS CURRENTLY UNENUMERATED.
  # ⚠️ Sol runs `mix test`, which STARTS THE APPLICATION. So the moment any
  # started component has a refusal-fatal write path, SOL'S TEST RUNS BREAK
  # HERE AND ONLY HERE -- and the failure will look like a test defect, not a
  # fence artifact. That is this file's own rule turned on itself: anything
  # measured inside the fence inherits the fence as a fact.
  # ⭐ And note the fence is harmless TODAY only because no such component
  # happens to start -- an accident of what is wired up, NOT a property
  # anyone arranged. Do not rely on it as a boundary.
  #
  # ⛔⛔ DO NOT REPLACE THIS BIND WITH A --tmpfs OR ANYTHING MAKING THE PATH
  # ABSENT. node_identity.ex:77-82 branches on File.read:
  #     {:ok, contents}   -> decode_keypair(contents)   <- /dev/null lands HERE
  #     {:error, :enoent} -> mint_keypair(data_dir,path) <- ABSENCE lands HERE
  # and mint_keypair (:100-113) does File.write + chmod 0600 + rename.
  # ⇒ An ABSENT key file makes a sandboxed process MINT A BRAND-NEW NODE
  # KEYPAIR AND PERSIST IT -- a fresh identity that does not match the real
  # node, minted silently, and able to overwrite the node's actual key if
  # workspace-write ever reached the real data_dir. STRICTLY WORSE than no
  # anchor. `--ro-bind /dev/null` is load-bearing: it forces the
  # read-succeeds-then-parse-fails branch instead of the mint branch.
  # (Found by commonplace 2026-08-09; this property was accidental, not
  # designed -- which is exactly why it needs writing down.)
  # The mask itself is correct and stays: Sol must not hold the node's
  # signing key. This is a legibility hazard, not a fence bug.
  --ro-bind /dev/null /home/jes/commonplace/workspace/.commonplace/node_signing_key
  --tmpfs /home/jes/commonplace/workspace/.commonplace/secrets
  # 2026-08-08: THE ERLANG COOKIE. Opening egress (network_access=true) also
  # enabled BEAM distribution, which the sandbox had previously blocked with
  # :eperm -- so Sol could see epmd AND net_adm:ping the live serve (verified:
  # ping=pong). Cookie + distribution = erpc into the node that OWNS the store,
  # which routes around every store-path mask above. Masking the store's own
  # credentials while leaving the key to remote code execution on its owner was
  # the hole. Egress changed the fence and nobody re-tested distribution.
  --ro-bind /dev/null /home/jes/.erlang.cookie
  # 2026-08-08: SHADOW `bd` WITH A GUARD, SANDBOX-ONLY. bd is the frozen
  # archive for commonplace (2026-08-05 cutover) and answers "no issue found"
  # for every ticket filed since -- accurately, and about the wrong world.
  # Sol typed `bd ready` on CX-3mj2 and reached the real binary; it only
  # failed because a fresh worktree has no Dolt DB. LUCK STOOD IN FOR A GUARD,
  # and luck reads exactly like coverage. commonplace's PreToolUse hook covers
  # Claude Code agents in that repo; it cannot cover Sol, who runs under codex.
  # The host binary is NOT touched -- hermes/wimble/gastown/turingtest/
  # starloom26/paravel all have LIVE beads stores and must keep working.
  --ro-bind /home/jes/.local/bin/bd /home/jes/.local/bin/bd.real
  --ro-bind /home/jes/boss-clod/sol-bd-guard.sh /home/jes/.local/bin/bd

  # ⛔⛔ 2026-08-27: THE RUST BUILD DRIVERS. Found by commonplace-cell's Sol
  # reporting cell's OWN PROMPT AS FALSE: its R2b brief said "you have NO
  # network and NO cargo", and /home/jes/.cargo/bin/cargo was reachable the
  # entire round. ⭐ THE NETWORK HALF WAS ENFORCED BY CONSTRUCTION; THE CARGO
  # HALF WAS ENFORCED BY A SENTENCE. Sol refrained because it was told to.
  # ⚠️ NOT an empty --tmpfs: that leaves `cargo` resolving via PATH and then
  # failing with a mystery. A named refusal says WHICH thing refused, which is
  # the difference between a round reporting a fence and a round debugging one.
  # ⭐ This masks the COMPILER, not the artifact — a committed .so arriving via
  # `mix deps.get` still loads in here (R2b proved it end to end).
  # ⭐⭐ STRUCTURAL FACT, verified 2026-08-27: ALL 13 toolchain entries in
  # ~/.cargo/bin are SYMLINKS TO `rustup` (cargo, rustc, rustdoc, rustfmt,
  # cargo-clippy, cargo-miri, clippy-driver, rls, rust-analyzer, rust-gdb,
  # rust-gdbgui, rust-lldb). ⇒ THE `rustup` BIND ALONE COVERS EVERY ONE — the
  # other three are belt-and-braces for anyone reading the list and expecting
  # to see the obvious names. Demonstrated: with ONLY the rustup bind,
  # cargo-clippy / rustfmt / cargo-miri all refuse.
  # ⚠️ NEGATIVE CONTROL RUN: weft_inspect and wimble in the SAME directory are
  # real ELF binaries, not shims, and stay intact and runnable — so this is a
  # scoped mask, not a directory-wide one.
  --ro-bind /home/jes/boss-clod/sol-cargo-guard.sh /home/jes/.cargo/bin/cargo
  --ro-bind /home/jes/boss-clod/sol-cargo-guard.sh /home/jes/.cargo/bin/rustc
  --ro-bind /home/jes/boss-clod/sol-cargo-guard.sh /home/jes/.cargo/bin/rustup
  --ro-bind /home/jes/boss-clod/sol-cargo-guard.sh /home/jes/.cargo/bin/rustdoc
)

# ⛔⛔ CX-v14m (2026-08-13): SYSTEM SOCKETS — DERIVED AT LAUNCH, NOT LISTED.
# commonplace found `/var/run/docker.sock` reachable from inside this fence with
# every mask above already applied: `docker version` answered Server 29.3.1.
# ⭐ THE DOCKER SOCKET IS ROOT-EQUIVALENT. The daemon runs as root and honours
#   `-v /:/host` and `--privileged`, so anything reaching it bypasses EVERY
#   fence here at once — the .ssh tmpfs, the PID namespace, the env allowlist,
#   all ten channel masks. THE MASKS FENCE THE PROCESS; THE SOCKET DELEGATES TO
#   SOMETHING THE PROCESS DOES NOT CONTAIN.
# ⚠️ WHY THE EARLIER DERIVATION MISSED IT: it searched `/run/user/<uid>` and
#   `/tmp`. docker.sock lives at `/run`. ⇒ DERIVE-DON'T-RECALL FIXED THE RECALL
#   PROBLEM AND INHERITED A SCOPE PROBLEM — a derived list is only as wide as
#   the roots you hand it.
# ⇒ So this derives, at every launch, over the SYSTEM runtime dir, and masks
#   only what is actually REACHABLE as this uid (mode/group decide, not name).
# ⚠️ THE NUMBERS BELOW ARE A DATED MEASUREMENT, NOT A LIST THIS SCRIPT RELIES ON.
#   The code derives at every launch; these are only what the derivation FOUND
#   on a given day, recorded so a reader can sanity-check the mechanism.
#   ⛔ DO NOT turn them back into a list — that is the recall defect this
#   block exists to prevent, and a note beside a derivation is exactly the
#   thing that ages while the mechanism stays correct.
#   • 2026-08-13 ~09:47Z — 5 reachable: docker.sock (via the `docker` group),
#     snapd.socket + snapd-snap.socket (666), dbus system_bus_socket (666),
#     postgresql (777). lxd/systemd-private/initctl/udev present, NOT reachable.
#   • 2026-08-13 ~15:00Z — 8 reachable: the same five plus
#     systemd/io.systemd.ManagedOOM, systemd/notify, uuidd/request.
#   ⭐ THE DELTA IS THE POINT: three appeared within six hours and the
#     derivation picked them up WITHOUT BEING TOLD. The mechanism was fine;
#     the earlier note was what aged. (commonplace found this by running the
#     red-capability control below, 2026-08-13.)
# ⭐ RED-CAPABILITY CONTROL: `sol-sockmask-control.sh` proves this mask can
#   FAIL — arm B runs the same bwrap with the mask array deliberately EMPTIED
#   and docker answers `Server 29.3.1` from inside the fence. ⇒ Without arm B,
#   "not reachable" is also what a missing CLI, a typo'd path, or an empty
#   derived list reports. A pre-flight arm exits 2 if the hole is absent on the
#   HOST, so a green cannot be theatre.
# ⛔ `--tmpfs /run` IS TOO BROAD AND WAS TESTED: it breaks DNS resolution and
#   codex cannot reach its endpoint. Mask the socket FILES, keep the dirs.
# ⚠️ /run/user/<uid> is excluded here because it is already tmpfs'd above;
#   binding into a masked directory would conflict.
SYS_SOCKET_MASK=()
while IFS= read -r _sock; do
  case "$_sock" in /run/user/*) continue ;; esac
  if [ -r "$_sock" ] && [ -w "$_sock" ]; then
    SYS_SOCKET_MASK+=( --bind /dev/null "$_sock" )
  fi
done < <(find /run -maxdepth 2 -type s 2>/dev/null | sort -u)

# ⚠️ `< /dev/null` IS HARDENING, NOT A CONFIRMED FIX (2026-08-09) — and the
# distinction is recorded because the original justification was WRONG.
#
# ⛔ WHAT I FIRST WROTE HERE: "backgrounded without this, codex blocks forever
# on 'Reading additional input from stdin...'". ⇒ RETRACTED. commonplace
# measured that same line in a run that was PROCEEDING NORMALLY — it is
# INFORMATIONAL, not a block indicator, so it was never evidence of the thing
# it was cited for. And the run that seemed to prove the fix had the redirect
# passed at the call site too, so the two changes are CONFOUNDED.
# ⚠️ The honest evidence is only: one launch made no progress in 55s, later
# ones did — on a box at load ~10, which is thin for "hung" in the first place.
#
# ⭐ THE REDIRECT STAYS, on its own terms rather than on that story: `codex
# exec` takes its prompt as an argument and is non-interactive by design, so
# closing stdin removes a hazard without removing a capability. A backgrounded
# process inheriting a terminal's stdin is a real hazard whether or not it
# caused this particular slow launch.
# ⛔ RECORDED THIS WAY DELIBERATELY: a fix whose justification is a misreading
# teaches the next person that a slow launch is already solved. The change is
# cheap and correct; the CLAIM was not.
# ⇒ The redirect lives HERE rather than at each call site, because a tool
# must not depend on how its caller invoked it — the same lesson that broke
# psgrep and loops-health when they went on PATH. `codex exec` takes its
# prompt as an argument and is non-interactive by design, so closing stdin
# removes a hazard without removing a capability.
# ⛔⛔ DO NOT LOOSEN `--sandbox workspace-write` TO MAKE `.git` WRITABLE. Asked
# and answered 2026-08-11 04:27 (commonplace's ruling, and its reasoning is the
# durable part). codex's workspace-write policy mounts `.git` READ-ONLY, so Sol
# cannot `git add`/commit — three runs in a row produced good work that had
# to be landed by hand (CX-sa5r, the phase-a measurement, CX-7smx).
# ⚠️ THAT FRICTION IS REAL AND THE FENCE STILL STAYS, because:
#   ⭐ A WRITABLE `.git` IS A WRITE→EXECUTE CHANNEL OUT OF THE SANDBOX.
#   `.git/hooks/*` execute on the REVIEWER'S machine the moment they land or
#   merge the branch. An agent that can write .git can arrange code that
#   runs OUTSIDE the sandbox at review time — the same laundering shape the
#   trust belt closes one layer down (see CX-b38c: write must never imply
#   arrange-future-execution).
# ⇒ Cost of the fence: ONE `git commit` per round, by a reviewer who is
#   reading the diff anyway. Cost of removing it: a whole channel.
# ⚠️ REFUTED, so don't retry it: dispatching into a full local CLONE instead
# of a linked worktree does NOT help. Verified 2026-08-11 on CX-7smx — the
# clone's .git was a real writable directory with no alternates, and Sol
# still reported it mounted read-only. The fence is on the PATH INSIDE THE
# SANDBOX, not on where the metadata lives. Back to worktrees.
#
# ⛔⛔ 2026-08-23 — READ THE SCOPE OF THAT REFUTATION. IT IS NOT "DON'T USE CLONES."
# It refutes exactly one claim: that a clone makes .git WRITABLE. It does not.
# ⇒ There is a SECOND, DIFFERENT failure it says nothing about, found by
#   commonplace-doc on 2026-08-23: a LINKED WORKTREE's gitdir lives OUTSIDE the
#   sandbox's writable root entirely — `.git` is a FILE reading
#   "gitdir: /home/jes/<parent>/.git/worktrees/<name>" — so index.lock fails
#   read-only for a reason the clone refutation never addressed.
#   Different operation, different path, different failure.
# ⇒ SO: a clone does not buy you a writable .git, AND a worktree costs you the
#   gitdir. Neither lets Sol commit. Pick on OTHER grounds — a clone is strictly
#   more self-contained — and have the DISPATCHER commit on Sol's behalf either way.
# ⚠️ Flagged by commonplace-dir, which hit this comment while following the
#   opposite instruction and had to reconcile them before dispatching. A reader
#   who greps "clone" finds "REFUTED ... Back to worktrees" and stops.
# ⭐ THE GENERAL SHAPE: a refutation recorded without its SCOPE reads as a
#   refutation of the general case. The evidence was about writability; the
#   sentence sounds like it is about clones.
#
# ⛔ COMMENTS NEVER GO BETWEEN CONTINUATION LINES: a `\`-continued line joins
# the NEXT line, so a comment inserted mid-invocation comments out every flag
# after it — measured 2026-08-11 04:44: codex ran with ONLY `-m gpt-5.6-sol`
# (no sandbox flag, no workdir, no prompt); only the no-prompt fail-fast kept
# those runs harmless. This block therefore lives ABOVE the exec, not inside it.
# ⛔⛔ THIS IS AN ENV ALLOWLIST AND IT STRIPS SILENTLY. 2026-08-23: a worker set
# WRANGLER_LOG_PATH on the dispatch command and reported the env as "applied".
# `env -i` dropped it before codex started — no warning, no error, and the round
# behaved correctly for an unrelated reason, so nothing surfaced the loss.
# ⇒ ANY VARIABLE NOT NAMED ON THE NEXT FOUR LINES DOES NOT REACH THE ROUND.
# ⭐ TO GIVE A ROUND AN ENV VAR: PUT IT IN THE BRIEF so Sol exports it in its own
#   shell. Do NOT set it on the dispatch command and assume it arrived.
# ⚠️ The allowlist is deliberate — it is part of the fence. Do not widen it to
#   solve a one-off; widening it is a fence decision, not a convenience.
# ⛔ RELEASE THE ADMISSION LOCK AT THE LAUNCH POINT. `exec` REPLACES this shell and FILE
#   DESCRIPTORS SURVIVE EXEC — so without this close, fd 9 (and its flock) would be held by the
#   codex process FOR THE ENTIRE ROUND. That does not make the cap stricter; it converts a cap of
#   2 into a hard serialisation of 1 that then FAILS at the 30s timeout with exit 66. ⭐ This
#   script's own header records the last time a cap of 2 silently behaved as a cap of 1; I nearly
#   reintroduced it from the opposite direction while fixing the race.
# ⇒ Closing here leaves a window of a few bash builtins between the release and codex becoming
#   visible to pgrep — microseconds, versus the multi-second window that let three rounds in.
#   Not zero. Small enough to be worth the exchange, and stated rather than pretended away.
# ⭐ Reserve BEFORE releasing. This is the whole fix: the next dispatcher counts this round even
#   though nothing of it is running yet. Retired by the purge above once it is visible.
# ⭐ MODEL IS OVERRIDABLE VIA $SOL_MODEL (default gpt-5.6-sol), added 2026-09-05T01:47Z.
# ⛔ WHY: RED-SAYS-WHAT-3 was dispatched to Astra with a BARE `codex exec` and its integration arms
# died on `:eperm` opening a TCP socket — a BEAM cannot start without egress. The egress lives HERE,
# on the `sandbox_workspace_write.network_access=true` line below, TOGETHER WITH THE MASKS.
# ⚠️ THE MASKS ARE THE REASON NOT TO COPY THE EGRESS FLAG ELSEWHERE: this file's own header records
# that inside a plain `--sandbox workspace-write` run Sol could read ~/.ssh/id_ed25519 and saw
# LETTA_API_KEY and SQUAD_ALERTS_PUBLISHER_TOKEN in its environment. ⇒ THE COST WAS NEVER THE
# NETWORK BOOLEAN ALONE — it is the boolean COMPOSED WITH BROAD READS. Route other species THROUGH
# this wrapper; do not lift one flag out of it.
# ⛔ $SOL_MODEL is read by THIS shell before `env -i`, so it is NOT subject to the env allowlist
# below — set it on the dispatch command, unlike every other variable, which must go in the brief.
printf '%s' "$WORKDIR" > "$RESERVE_DIR/$(printf '%s' "$WORKDIR" | tr -c 'A-Za-z0-9._-' '_').reserved"
exec 9>&-
exec env -i \
  HOME="$HOME" PATH="$PATH" USER="$USER" LOGNAME="$LOGNAME" SHELL="$SHELL" \
  TERM=xterm-256color LANG="${LANG:-C.UTF-8}" LC_ALL="${LC_ALL:-C.UTF-8}" \
  ASDF_DIR="${ASDF_DIR:-}" SOL_WORKDIR="$WORKDIR" \
  bwrap --dev-bind / / --unshare-pid --proc /proc "${MASK[@]}" "${SYS_SOCKET_MASK[@]}" -- \
  codex exec -m "${SOL_MODEL:-gpt-5.6-sol}" \
    --sandbox workspace-write \
    -c 'sandbox_workspace_write.network_access=true' \
    -C "$WORKDIR" \
    "$@" < /dev/null
