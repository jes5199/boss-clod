# Recovery record — commonplace stash drop, 2026-08-19

**Authorized by jes on Telegram, 2026-08-19 00:53Z ("drop those"), in reply to my report that these
two commits were the only thing keeping a 7.77 GB blob reachable in a public repo.**

## What was dropped

    stash@{0}  b922558e8ad5b8880fc2e63e51cebcbac4230c08  "On main: boss-rollback-stash-708e00c"
    parent     17f7c736...                               "untracked files on main: 708e00c ..."

These are **mine** — a boss rollback stash. `17f7c736` is the untracked-files parent that `git stash`
creates, which is why dropping the single entry removes both from ref reachability.

## The blob

    25b422c7cf63e6b35865d17911204c761d2079e3
    dogfood-mud/.commonplace.crashed-20260706/commits/17.cub
    7,771,316,795 bytes (a crashed CubDB store)

**Why it mattered:** `git log -S` inflates blob contents to scan them, so any pickaxe search over full
history had to materialize 7.7 GB on a box with ~9 GB free. It OOM-killed three Sol rounds on
2026-08-18 (23:06:30, 23:17:19, 23:21:07), taking commonplace's whole tmux scope down with the first.
The malloc error read 7,771,316,796 — size+1, a fingerprint.

## ⭐ HOW TO RECOVER, and why no bundle was made

**A dropped stash deletes the REF, not the OBJECTS.** Both commits remain in the object store until a
gc prunes them, so recovery is:

    git -C /home/jes/commonplace stash store b922558e8ad5b8880fc2e63e51cebcbac4230c08
    # or, to just look:
    git -C /home/jes/commonplace show b922558e8ad5b8880fc2e63e51cebcbac4230c08

⚠️ **No `git bundle` backup was taken deliberately.** A bundle containing that blob would be multi-GB
on a filesystem at **87% (16 GB free)**, on a box that OOM-killed three times the same night. **The
backup that costs 16 GB of headroom is more dangerous than the thing it insures against.** The sha
above IS the backup, and it is good until someone prunes.

## ⚠️ WHAT THIS DID AND DID NOT DO

- ✅ **Defused the pickaxe hazard immediately** — `--all` walks refs, and the ref is gone.
- ⛔ **Did NOT reclaim disk.** The objects are still in the pack; space returns only after a gc with
  pruning. **That is a separate, irreversible act, not done here** — a gc across a repo with 41
  worktrees while CI is mid-flight is its own decision, and it destroys this recovery path.
- ⇒ If anyone later wants the space, they are choosing to make this irreversible. Say so out loud
  when proposing it.
