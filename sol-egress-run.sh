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

exec env -u LETTA_API_KEY -u SQUAD_ALERTS_PUBLISHER_TOKEN \
  bwrap --dev-bind / / "${MASK[@]}" -- \
  codex exec -m gpt-5.6-sol \
    --sandbox workspace-write \
    -c 'sandbox_workspace_write.network_access=true' \
    -C "$WORKDIR" \
    "$@"
