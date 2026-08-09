#!/usr/bin/env bash
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
  /home/jes/commonplace|/home/jes/commonplace/*)
    echo "REFUSED: SOL_WORKDIR points at the live checkout ($WORKDIR)" >&2
    exit 64
    ;;
esac

# Sensitive paths masked with an empty tmpfs. ~/.codex/auth.json is deliberately NOT masked:
# codex needs it to authenticate, so it is a known, accepted residual.
MASK=(
  --tmpfs /home/jes/.ssh
  --tmpfs /home/jes/.config/gh
  --tmpfs /home/jes/.claude/channels
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
)

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
exec env -u LETTA_API_KEY -u SQUAD_ALERTS_PUBLISHER_TOKEN \
  bwrap --dev-bind / / "${MASK[@]}" -- \
  codex exec -m gpt-5.6-sol \
    --sandbox workspace-write \
    -c 'sandbox_workspace_write.network_access=true' \
    -C "$WORKDIR" \
    "$@" < /dev/null
