# CX-rvbr probe-cost measurement — results and how to reproduce

Taken 2026-08-13 ~10:05Z from a frozen copy of the live commit store.
The 4 GB copy has been deleted (commonplace: *"4 GB back is worth more than a copy I'd
re-request in a week"*). **`measure.exs` beside this file regenerates every number** —
copy the store again and run it, rather than trusting these figures against a moved store.

| measurement | value |
|---|---|
| store on disk | **4.0 GB** (3 `.cub` files) |
| entries | **150,779** |
| decoded value bytes | **1,368,835,248** (1.37 GB) |
| full `CubDB.select \|> Enum.each` | **13,862 ms** |
| probe budget | **5,000 ms** ⇒ **2.8× over, on an idle host with no serve contention** |
| value size min / median | 7 / **38** bytes |
| P99 / max | **436,699** / 987,248 bytes |
| ten largest as share of all bytes | **0.71%** |

⇒ **The probe is BYTE-BOUND, not entry-bound.** 150,779 entries is modest; 1.37 GB of decoded
CRDT payload is not.
⛔ **Both obvious fixes are ruled out by the distribution**: no head to special-case (top-10 =
0.71%), and **sampling is actively misleading** — a random sample is dominated by 38-byte
entries and reports a tiny store.
⚠️ **A denominator is unaffordable**: `CubDB.size/1` is `Enum.count(btree)`, a full traversal —
`deps/cubdb/lib/cubdb/reader.ex:47`.

**Status:** the coverage RIDER landed (commonplace main @697a7a8c). **CX-rvbr stays OPEN** — the
method is still byte-bound and the budget still cannot cover it; the probe now *says so* rather
than implying otherwise.
