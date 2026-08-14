# The `bd` repo guard is INSTALLED, in OBSERVE mode

Installed 2026-08-14 22:38Z by boss-clod. Artifact: commonplace `bin/bd-repo-guard` @`35afe56a`
(`CX-3zzx`). **It refuses nothing today.** It records what it *would* refuse and delegates.

## What is where

```
~/.local/bin/bd        the guard          7,171 bytes   ← first on PATH
~/.local/libexec/bd    the real binary  178,665,440 bytes
```

The real binary was **hardlinked**, not copied or moved — same inode 569079 — so there was never an
instant when `bd` was absent, and no second 178 MB on disk.

## ROLLBACK (one command, verified reversible before install)

```bash
cp -p /home/jes/.local/libexec/bd /home/jes/.local/bin/bd
```

Nothing else was changed. `PATH` was **not** touched. No shell profile was edited.

## The flip, both directions — what a person types

```bash
export BD_GUARD_MODE=enforce   # fail closed
unset BD_GUARD_MODE            # back to observe
```

⛔ Do **not** flip to enforce yet. On 2026-08-14 a survey found **69 of 84** repos on this box with a
`.beads` directory would be refused, and all 69 have non-empty `.beads` — including `~/.beads`
(an open SQLite db) and three of wimble's four worktrees. Enforce becomes correct when the
would-refuse set shrinks to repos where refusing is *right*, which happens as repos declare
`.bd-archive-policy` when they are touched for other reasons.

## The count is TRAFFIC, not a survey — this surprised me and the tool is right

```bash
bd --count-would-refuse
```

⭐ It counts **repos actually invoked in**, from records under
`~/.local/state/bd-repo-guard/records`. It is **not** a walk of the filesystem.

⚠️ So it will not reproduce the 69. I expected it to and was wrong. The traffic number is the more
useful one: only repos where somebody actually runs `bd` can be broken by the flip. A repo that
nobody touches cannot be hurt by enforce, and inflating the blocker with it would delay the flip
for no safety gain.

Records are pruned for worktrees that no longer exist, and for abandoned temp writes older than 60
minutes. Active-but-idle repos are **not** aged out, so a quiet repo cannot silently leave the count.

## Install acceptance — run 2026-08-14, all against a committed stub, never a real `bd`

| check | result |
|---|---|
| ① stdout byte-identical (`cmp`, real command) | ✅ 30 bytes both sides |
| ② stub exits 7 → guard exits 7 | ✅ 7, not 0 and not 1 |
| ③ **stderr** byte-identical, in a repo it would refuse | ✅ 30 bytes both sides |
| ④ flip both ways | ✅ enforce rc=1 **stub never called**; observe rc=0 stub called |
| ⑤ counting command from the installed copy | ✅ runs; semantics are traffic-based (above) |

⛔ **The first run of ① was VACUOUS and the non-vacuity check is what caught it**: both sides
produced 0 bytes because the stub needs `BD_STUB_CALL_LOG` and it was unset. Byte-identical was
true and meaningless. **Never accept an equality without asserting the compared thing is non-empty.**

✅ The check that actually matters, run after install: `cd /home/jes/hermes && bd list` lists
hermes's real live tickets through the guard. That is the assertion already filed at
`sol-fence-test.sh:80-83`.
