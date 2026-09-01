#!/usr/bin/env bash
# ⛔ pipefail: without it a pipeline reports the LAST stage, so a failing script read through
# a filter looks green. NOTE it does NOT save 1-vs-2 when a second stage also fails -- for a
# 0/1/2 script CAPTURE FIRST: out=$(script); rc=$?   (boss-clod, 2026-09-01)
set -o pipefail
# Shadows the Rust build drivers in ~/.cargo/bin INSIDE SOL'S SANDBOX ONLY
# (bind-mounted by sol-egress-run.sh). The host binaries are untouched; nothing
# outside the bwrap namespace sees this file.
#
# WHY THIS EXISTS (2026-08-27, found by commonplace-cell's Sol reporting cell's
# OWN PROMPT AS FALSE):
#   cell's R2b dispatch prompt told Sol "you have NO network and NO cargo".
#   Sol complied -- and then reported that the fence did not actually hold:
#   /home/jes/.cargo/bin/cargo was present and reachable the whole time.
#   The network half was enforced BY CONSTRUCTION. The cargo half was enforced
#   BY A SENTENCE IN A PROMPT, which is to say not at all. Sol refrained
#   because it was told to, not because it could not.
#
# ⭐ THE CLASS: commonplace-biscuit filed the distinction the same morning --
#   `skip_compilation?: true` makes mix INCAPABLE of invoking cargo, whereas a
#   line in a brief is a remembered rule. cell then shipped the remembered kind
#   in the same paragraph where it quoted the structural kind at Sol. Knowing
#   the distinction plainly did not prevent instantiating the wrong side of it.
#   ⇒ A FILED ARTIFACT FIRES; A REMEMBERED RULE DOES NOT. This is the artifact.
#
# WHY A NAMED REFUSAL AND NOT AN EMPTY --tmpfs (cell's point, and it is right):
#   masking ~/.cargo with an empty tmpfs leaves `cargo` resolving via PATH and
#   then failing with a mystery -- no toolchain, confusing error, and a round
#   that burns time deciding whether the fence or the repo is broken. A named
#   refusal says which. Same spirit as the "REFUSED, do not skip" idiom.
#
# ⛔ FAILS CLOSED BY DESIGN, and that is the OPPOSITE default from
#   sol-bd-guard.sh -- read that file's note before "making these consistent".
#   bd guards a CLAIM ABOUT ONE REPO, so a wrong refusal is worse than a missed
#   catch. This guards an INVARIANT ABOUT THE FENCE: a Sol that can compile can
#   use the warm crate registry and rewrite committed build artifacts, and the
#   whole point of a fenced round is that its output is auditable. Refusing IS
#   the feature. There is deliberately NO escape-hatch env var: a hatch that
#   Sol can set is not a fence, and a host operator does not need one because
#   the host binaries are untouched.
#
# WHAT LEGITIMATELY STILL WORKS -- this masks the COMPILER, not the artifact:
#   Rounds that need a prebuilt Rust artifact get it through `mix deps.get` as
#   a COMMITTED .so. R2b proved that path end to end inside the fence: the NIF
#   loaded from deps/commonplace_biscuit/priv/native/libcp_biscuit.so with no
#   cargo involved and decided real tokens. Nothing in the fence should be
#   compiling Rust; if a round needs a fresh .so, it is built on the host and
#   committed, which is the rule that made the fence survivable in the first
#   place.

_me=$(basename "$0")

cat >&2 <<EOF
REFUSED: \`${_me}\` is masked inside Sol's fence.

This is a deliberate refusal by /home/jes/boss-clod/sol-cargo-guard.sh, NOT a
broken toolchain and NOT a missing install. The host toolchain is untouched.

WHY: a fenced round must not compile. A Sol that can invoke cargo can use the
warm crate registry and rewrite committed build artifacts, which is exactly the
auditability a fenced round exists to provide.

WHAT TO DO INSTEAD:
  - Need a Rust artifact? It arrives as a COMMITTED .so through \`mix deps.get\`.
    That path works in here -- it is how the Biscuit NIF loads.
  - Need a NEW .so? It is built ON THE HOST and committed. Say so in your
    report as a NOT-DONE; do not work around this.
  - Cannot measure something without building? Report that you could not
    measure it. An honest "not measured" is worth more than a green.

Do NOT skip this by finding another path to a compiler. If you believe this
refusal is wrong for your round, say so in your report and stop.
EOF

exit 127
