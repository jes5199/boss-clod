# ⭐ STANDING AUTHORIZATIONS FROM jes — CITE THIS FILE BY PATH AND MESSAGE ID

⛔ **A GRANT IS NOT A GRANT UNTIL A DOOR THAT WAS NOT THERE CAN CITE IT.** Three doors correctly
refused work on 2026-09-04/05 because a peer message is not jes's word (`a plan message is never a
grant`, plan row 736). **That refusal is right and must stay right.** ⇒ This file exists so the
answer is readable instead of re-askable.
⚠️ **RECORDED FROM jes's OWN MESSAGES TO boss-clod, never from a door's report of them.** A door's
account of a grant is a citation of a citation, and the party citing it is the party it benefits.

---

## MERGE — all workers, all `commonplace-*` repos. Granted 2026-09-05T03:32Z.

**Composed by boss-clod in Telegram `11049`, confirmed by jes in Telegram `11051`
("yes that sentence, with 'warranted' delegating to commonplace-plan"):**

> **Standing authorization, all workers, until I revoke it: you may merge a warranted branch to main
> in any commonplace repo without asking me first. No force-push, no history rewrite. This does not
> extend to hermes.**

**AND, from `11051` verbatim: "warranted" DELEGATES TO `commonplace-plan`.**
⇒ ⭐ **plan issues the warrant; jes does not review the branch.** A branch plan has warranted is
merge-authorized. A branch it has not is not, and asking jes does not substitute for the warrant.

**THE FOUR THINGS IT SAYS, spelled out so nobody has to infer them:**
```
WHO       every worker, not a named door
WHAT      merge a WARRANTED branch to main
EXCLUDED  ⛔ force-push · ⛔ history rewrite · ⛔ hermes (any act, any branch)
DURATION  UNTIL HE REVOKES IT — this is not a one-time yes
```
⚠️ **The DURATION clause is the one that was missing from every earlier grant, and its absence is
what made three doors treat a standing permission as scoped to that night.**

⛔ **WHAT THIS DOES NOT COVER, and a door must still stop and ask:**
- **DEPLOY.** A different act with a different blast radius. jes was asked and has not answered;
  silence is not a grant.
- **hermes** — anything at all. Its live-money paths need his own word PER CHANGE, cited.
- **Anything outward-facing under his name**, and destroying data with no earlier commit holding it.

📌 **The box protocol is UNAFFECTED: one CPU-saturating act at a time, announced by name, released by
name. A merge authorization is not a box grant.**

---

## GENERAL — "make it happen". Granted 2026-09-05T04:15Z, Telegram `11058`.

> **"my word is make it happen"**

⭐ **TAKEN AS: stop asking for permission to do the work already ranked. Act, and report what was
done rather than what is proposed.** ⇒ **It removes the ASKING, not the CHECKING.**

**WHAT I AM TAKING IT TO COVER:**
```
✅ dispatching ranked work to any authorized door, without confirming each round
✅ landing anything plan has marked WARRANTED · CLEARED TO LAND
✅ DEPLOY — previously asked and unanswered; silence was not a grant, "make it happen" is
✅ granting box windows, restarting workers, cleaning and reclaiming, pushing branches
```
⛔ **WHAT IT DOES NOT COVER, AND WHY — these are not permission problems:**
```
⛔ hermes: any live-money path still needs his own word PER CHANGE, cited. He has excluded hermes
   explicitly twice tonight (tg 11049/11051), and a later general grant does not silently widen an
   EXPLICIT exclusion. ⭐ A broad yes does not repeal a narrow no.
⛔ preserve/realm-remove-1b: NOT blocked on his permission. Its reviewer arms (D1–D3, R1–R6) were
   NEVER RUN and its own report says typecheck FAILS. plan has it as NOT WARRANTED.
   ⇒ ⭐⭐ HIS WORD CANNOT SUBSTITUTE FOR A TEST. "Make it happen" authorises me to get the arms run;
     it does not make unrun arms green.
⛔ anything outward-facing under his name · destroying data no earlier commit holds
```
⚠️ **THE SCOPE IS MINE TO HAVE STATED, NOT HIS.** He wrote five words; the enumeration above is my
reading, recorded so it is checkable and correctable rather than carried in my head. **If he meant
more, he will say so; if he meant less, the record shows exactly what I assumed.**

---

## ⛔⛔ A DEFAULT IS NOT A PERMISSION IN HIS ABSENCE (commonplace-plan, 2026-09-05T04:45Z)

**Several grants in this file, and several of plan's rows, carry a DEFAULT — "if he says nothing, X".**
⇒ ⛔ **A default is something jes CHOSE TO ALLOW while reachable. It is NOT something to assume when
he is not there.**

⚠️ **WHY THIS MATTERS TONIGHT AND NOT ABSTRACTLY: boss-clod is the ONLY door with the Telegram
channel.** ⇒ **If boss-clod is gone, anything needing his word STOPS AND WAITS. It does NOT proceed on
a default.** ⭐ **A successor reading a row that says "default: proceed" would otherwise talk itself
into acting, and the row would look like authorisation rather than like a standing arrangement whose
precondition — that he can be asked and can interrupt — has silently lapsed.**

📌 **THE DEFAULTS CURRENTLY LIVE IN THIS FILE AND IN plan's LEDGER, and every one of them is
conditional on the channel existing:**
```
DEPLOY               covered by "make it happen" — but that grant was given TO A REACHABLE jes
hermes kill_all      DEFAULTED-BY-SILENCE, no code change. ⛔ Silence with no channel is not silence.
browser edit durability  deferred, not declined
```
⭐ **`commonplace-plan/docs/plans/BOX-ARBITER-SUCCESSION.md` (44 lines, verified at the endpoint
2026-09-05T04:46Z) carries the rest: what the box protocol is, that `box-free.sh` is an INSTRUMENT
any door can run and NOT the arbiter, and that TWO DOORS READING ONE INSTRUMENT AND ANNOUNCING IS
THE PROTOCOL — the arbiter is an optimisation that removes coordination cost, not a dependency.**

## RANKING SEAT HANDOVER — 2026-09-05T16:49Z

**Grant:** jes, Telegram 11091, 2026-09-05T16:36:21Z, verbatim:
> *"okay. when claude code commonplace-plan reaches a stopping place, let's take to offline, and have the codex plan take over"*
Preceded by tg 11087 (*"I asked the codex to review the roadmap, yes… take the suggestions seriously"*)
and sharpened by tg 11089 (*"to be more clear: adopt suggestions from codex"*).

**Executed:** the Claude `commonplace-plan` session declared **STOPPED** in its own words (msg 30011)
after issuing its final warrant (`BACKUP-1b-iii` @ `8bb134d`, which then LANDED). I exited it at
16:49Z; **verified by effect — claude pid 193846 is GONE**, pane returned to the shell. Resume string
if ever needed: `claude --resume 1a505826-33d1-4a45-b2be-0694cbd28b36`.
**Pre-exit durability check, run BEFORE the exit because afterwards its context could not answer:**
`commonplace-plan` main `590e637` at the endpoint · `b2129de`, `e3c198f`, `bdd5a45`, `c6dadac` all
ancestors · `docs/plans/2026-09-05-HANDOVER-to-codex-plan.md` present · local tree **0 uncommitted**.

**Seat now held by:** `codex-commonplace-plan-01a07262-…`, pid 450375, cwd `/home/jes/commonplace-plan`
— **and it is now the SOLE writer there**, so the read-only fence I imposed at 16:25Z is lifted.

⛔⛔ **THE ONE DEFECT IN THE OUTGOING SESSION'S HANDOVER, FOUND BY MEASURING RATHER THAN ASSUMING:**
its *"read-first"* pointer lives in **`~/.claude/projects/-home-jes-commonplace-plan/memory/MEMORY.md`**
— **a CLAUDE per-door memory file.** ⇒ **The successor is a CODEX session and does not read that file
at all.** ⚠️ **The entry point was FILED WHERE ONLY THE OUTGOING DOOR COULD STAND** — my own HOST-FACTS
rule, arriving in a handover. **I carried the path to the successor by message instead.**
⭐ And I nearly reported a different, false version of this: the repo's own `MEMORY.md` has 0 hits for
the handover doc, which looked like the pointer was simply missing. **Reading the control first showed
the pointer exists and is in the wrong PLACE, not absent.** Ninth costume of the day's one defect.
