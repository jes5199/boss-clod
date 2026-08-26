# Roadmap candidates — jes, 2026-08-26T04:15Z (Telegram, verbatim)

> "things on my mind as possibilities for later this week: cell boundary tokens (something like
> macaroons or biscuits), cell-assembly declarative language, live-rendered Yjs XHTML UIs, MCP
> definition language, and generally mining monolith and plan for ideas that I've forgotten about"

⛔ **THESE ARE POSSIBILITIES, NOT A QUEUE.** He said them while standing down for the night, in the
same breath as "I need to actually try the editor soon, and think about the roadmap." **Nothing here
has been ranked, and ranking is commonplace-plan's, not mine.** ⇒ This file exists so the list
survives the night; placement happens when plan next wakes.

## The five, split out

1. **Cell boundary tokens** — "something like macaroons or biscuits". Attenuable bearer credentials
   at the Cell boundary. ⓘ Adjacent to work that already exists: trust + attenuation shipped and
   live-proven; E2c gave every W-facing path an explicit DevAuthority scope, and
   `document.sync.export` is already granted **per document** rather than workspace-wide. So the
   question is not "can a Cell attenuate" but whether the *token itself* should carry the caveats.
2. **Cell-assembly declarative language** — describing how Cells are wired, instead of composing them
   in the composition root's code. ⓘ Touches layout §5.5 (the application owns supervision order and
   endpoints) and next's `Realm.init`, which today boots W plus one editor subtree per `Logins.all()`
   with **no placement configuration** — E2c's plan even carries `MODULE-PLANNED:
   CommonplaceNext.Realm.Placement` / `Realm.Route` markers.
3. **Live-rendered Yjs XHTML UIs** — the document *is* the UI. ⓘ The markdown profile is the first
   content profile; a second profile whose render target is XHTML is the same seam.
4. **MCP definition language** — declaring MCP servers/tools rather than hand-writing them.
5. **Mining monolith and plan for forgotten ideas** — ⭐ **his own words: "ideas that I've
   forgotten about."** This one is a *search*, not a build, and it is the one with no owner today.

## Why this file rather than a message

⚠️ Handing a fresh list to an agent at 04:15Z with no ranking is the **recency-as-priority** failure
jes named on 2026-08-09 — every arrival carrying a priority it had not earned by comparison with
anything. ⇒ It goes to plan for placement against everything else, when plan is awake, and never as
an instruction with implied urgency.
