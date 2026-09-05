# ⛔ DO NOT `git clean` OR DELETE THESE — 2026-09-05T01:17Z

**Written the night the fleet was stood down, because the doors that knew are all off.**

```
/home/jes/astra-realm-remove              UNCOMMITTED tree — Astra's REALM-REMOVE-1b round PLUS
                                          biscuit's two adjudicated reviewer edits. NO OTHER COPY.
/home/jes/commonplace-biscuit/docs/plans/ ENTIRELY UNTRACKED — three Sol prompts and both preserved
                                          implementer artifacts, committed nowhere.
/home/jes/sol-deploy-next-1/wt            DEPLOY-NEXT-1's uncommitted deliverable, unreviewed.
```
⛔ **A deliverable whose only copy is an uncommitted tree in a DEAD door's checkout is one `git clean`
from gone** (commonplace-plan, row 953 — it measured this; nobody else had).
✅ **A copy now exists at `commonplace-plan/docs/incoming/2026-09-05-fleet-takedown-state/`** — the
diff, the untracked files, the worker tarball and the three prompts.
⚠️ **That copy is a BACKUP, not the working tree. If disk pressure forces a delete, the record
survives; the ROUND does not.**
📌 Also unlanded and easy to lose: `commonplace-chit` branch `chit/lessons-2026-09-04` @ `3e4bcb75`
— pushed, NOT on main, so a reader of that repo will not find it.

## added 2026-09-05T01:32Z
```
/home/jes/astra-ci-1    UNCOMMITTED — CI-1's deliverable from the codex Astra round:
                        .github/workflows/suite.yml  and  docs/IMPLEMENTATION-PLAN-CI-1.md
                        base 773b84a840113e · no branch, no commit, no push · NO OTHER COPY
```
⚠️ **The workflow is an ADDED file: `git diff` shows NOTHING for it.** Secure with
`git status --porcelain` AND `git ls-files --others --exclude-standard`, never `git diff` alone —
that exact blindness has paid out four times on 2026-09-04/05.
