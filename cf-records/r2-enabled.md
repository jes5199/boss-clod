# R2 — ENABLED 2026-09-01, UNUSED BY ANY DEPLOYMENT

⭐ **Written the same hour the product was enabled, which is the whole point.** `cool-recipe-d18f`
exists because nobody could answer WHY a thing was deployed, eight days later. **This is that shape
caught in real time, at a cost of one file.**

| field | value |
|---|---|
| **WHAT** | Cloudflare **R2** object storage, enabled on account `Commonplace Systems` (`d5c4856e…`), plus an R2 scope added to the API token. **0 buckets.** |
| **WHY** | ⛔ **A suggestion that was withdrawn before it was acted on, and acted on anyway because the messages crossed.** boss-clod relayed the beta storage finding to jes with an unpriced default attached — *"R2 is available but not switched on in your dashboard — one click, and probably the shortest path"* (telegram 10680, 17:11Z). Plan's hold on that unpriced decision arrived 3 min later; boss retracted it (10681). **jes enabled R2 at 17:16:33Z, before reading the retraction.** |
| **IS IT USED** | ⛔ **No. Not by anything, and not planned.** The measured answer to the storage question is `LogStore.Cloudflare` over the **Durable-Object SQLite store already deployed and running** (`commonplace-log`, schema live since 2026-08-24). **Object storage has no append or writer-tip semantics**, so R2 was never a candidate once the store was measured. |
| **WHO AUTHORIZED** | jes, 2026-09-01T17:16:33Z — *"R2 added and added to token"* — **acting on boss-clod's withdrawn suggestion.** ⭐ **The error is boss's, not his: it arrived as a config change rather than a decision.** |
| **COST** | Nothing writes to it; 0 buckets. **Unpriced in dollars** — `billing/profile` and `subscriptions` both refuse `10000` to this token, so the account's actual spend is **UNMEASURED at the fleet's end**, not zero-by-assertion. |
| **HOW TO REMOVE IT** | Disable R2 in the dashboard and drop the R2 scope from the token. ⚠️ **Untested — no disable was attempted. A removal path that has never run is a claim, not a capability.** |

## The unintended payoff: it settled an ambiguity three points instead of two

⭐⭐ **Enabling R2 ran the experiment the fleet could not run itself** — biscuit, measuring a
transition rather than inferring one:
```
dns_records   10000 "Authentication error"  →(scope grant)→   success
R2            10042 "Please enable R2 …"    →(enable+scope)→  success
D1            10000, UNMOVED THROUGH BOTH EVENTS
```
⇒ **Product-off produced `10042` and NAMED ITS OWN REMEDY — it never produced `10000`. Two
independent scope grants each moved `10000` → success. D1 held `10000` through both.**
⭐ *"I no longer need to ASSUME what a product-off refusal looks like on this account, because I have
now SEEN one turn on."*

⚠️ **Still short of decisive — the deciding test is a D1 read grant — and still MOOT: D1 is not the
answer under the measured option table either way.** ⛔ **biscuit declined to request that grant:**
*"a scope grant to settle a question whose answer changes nothing is a cost with no consequence
attached."*

## Why this file exists at all

⚠️ **Without it, the next door to inventory this account finds AN ENABLED PRODUCT WITH NO PURPOSE and
has to re-derive why** — which is precisely the eight-day-old question `cool-recipe-d18f.md` was
written to answer after the fact. ⭐ **Provenance is cheap to write at the moment of the act and
expensive to reconstruct at any later moment.**
