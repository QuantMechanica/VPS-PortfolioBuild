# FTMO density lever — validation on T8–T10 (2026-07-10)

Test: does adding high-frequency, diverse sleeves make the FTMO book reach +10% FASTER
without raising breach? Recompiled 3 candidates with the current MAE-emitting framework
(they were 2026-06-21 builds, pre-MAE) and backtested fresh on T8–T10, 2017–2025, Model 4:

| ea | symbol | tf | terminal | trades | span | sum net (q08 base) |
|---|---|---|---|---|---|---|
| 10118 | NDX.DWX | H1 | T8 | 714 | 2018-07…2025-12 | +$40,217 |
| 10916 | GDAXI.DWX | H1 | T9 | 611 | 2018-07…2025-12 | +$77,939 |
| 10546 | XAUUSD.DWX | M30 | T10 | 1708 | 2017-10…2025-12 | +$96,692 |

All three fresh-MAE (entry_time+mae_acct), profitable. Chosen deliberately non-JPY (the book
is already USDJPY-heavy via 11476) to avoid concentrating the daily-breach engine.

## Result — 12 vs 15 sleeves (tools: ftmo_density_compare.py, ftmo_density_speed_at_budget.py)

At MATCHED annualized return ($30k/yr):
| book | sleeves | P(+10%) | median cal days | daily-breach | max-breach |
|---|---|---|---|---|---|
| current 12 | 12 | 47.1% | 37 | 22% | 31% |
| 12 minus 10163 | 11 | 48.3% | 38 | 19% | 32% |
| 15 (+3 dense) | 14 | 61.0% | 54 | **5%** | 34% |

At MATCHED daily-breach budget (~20%, scaled up to spend the same risk):
| book | ann$ @budget | P(+10%) | median cal days | daily-breach | max-breach |
|---|---|---|---|---|---|
| current 12 | $29.6k | 47.5% | 38 | 21% | 31% |
| 12 minus 10163 | $30.4k | 48.2% | 38 | 19% | 33% |
| 15 (+3 dense) | $34.0k | **52.3%** | 40 | 19% | **29%** |

## Read
- The 4× daily-breach drop (22%→5%) at matched RETURN is a **scale artifact** — the denser
  book was running smaller. Scaled to the same breach budget, the true gain is **real but
  modest**: P1 pass 47.5%→52.3% (+5pp), max-breach 31%→29%, ~15% more return-per-budget.
- **10163 (NDX.DWX H1) removal is a free win** (net-negative → +1pp pass, −3pp daily-breach).
- Modest, not dramatic, because the book is already NDX/GDAXI/XAUUSD-heavy — adding MORE of
  the same barely decorrelates the tails (max-breach stays ~30%, now the co-binding constraint).

## Recommendation
1. **Remove 10163** from the FTMO book (free).
2. **Add 10118 / 10916 / 10546** at ~median risk_fixed weight (real +5pp pass, lower max-breach).
   Hand Codex the IDs + weights for the book manifest.
3. **Next build target ≠ more high-freq — it's DECORRELATION.** Max-breach (~30%) is now the
   co-dominant failure and it is driven by the index+gold tail moving together. The book needs
   high-freq sleeves on symbols/mechanisms uncorrelated with the index+gold core to cut that
   tail. That is the lever that would genuinely compress time-to-+10%. (Codex build-lane.)
