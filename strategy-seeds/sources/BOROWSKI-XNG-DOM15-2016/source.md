---
source_id: BOROWSKI-XNG-DOM15-2016
title: Natural-gas day-of-month seasonality - session dated the 15th
publisher: Journal of Management and Financial Sciences, SGH Warsaw School of Economics
source_type: peer_reviewed_open_access_paper
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016
open_full_text_url: https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER
strategy_ids:
  - BOROWSKI-XNG-DOM15-2016_S01
  - BOROWSKI-XNG-DOM15-2016_S02
---

# Borowski Natural-Gas Day-15 Source

## Source identity

Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
Markets of Future Contracts with the Following Underlying Instruments: Crude
Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle,
Lean Hogs and Lumber," *Journal of Management and Financial Sciences*, issue
26, pages 27-44. The official SGH archive identifies the issue; the complete
author-uploaded article is linked above. The full article, including the
literature review, data, methods, every results section, conclusions and
references, was reviewed on 2026-07-20.

The journal documents external double-blind review. This source is classified
quality tier B: it is a named-author, peer-reviewed empirical paper with a
complete public copy, but it is one study in a broad anomaly search and is not
a realizable trading track record.

## Selected natural-gas finding

The study uses NYMEX natural-gas futures observations from 1990-04-03 through
2016-03-31. Its day-of-month test compares the daily return for each numbered
calendar day with returns on all other calendar days. For natural gas:

- 14 of the 31 numbered days have positive sample means;
- the largest mean is `+0.9881%` on the 15th;
- the smallest mean is `-0.7265%` on the 27th; and
- equality of the day-15 mean and the other-day population is rejected with
  reported `p=0.0008`.

The conclusion explicitly lists the natural-gas 15th among the detected
day-of-month anomalies. These are paper statistics, not expected Darwinex CFD
returns or certification evidence.

## Interpretation and limitations

The source result is a numbered-calendar-day effect, not "the middle trading
day" of a month. The executable rule therefore acts only when a broker D1 bar
is dated exactly the 15th. If the 15th is a weekend, holiday, or absent bar,
the month is skipped; the signal is never shifted to the next tradable day.

The paper calculates daily returns. Entering at the first executable price of
the D1 bar dated the 15th and flattening at the first executable price of the
next D1 bar is the closest deterministic MT5 proxy for that one-session
return. Friday-close handling closes a Friday-the-15th position near the end
of the source session instead of carrying it through the weekend.

Important weaknesses are predeclared:

- the article tests many calendar partitions and 31 individual numbered days
  without reporting a family-wise or false-discovery correction;
- the mean-comparison method assumes normal populations and selects an
  equal/unequal-variance test through an F-test;
- evidence ends in March 2016 and does not establish post-publication
  persistence;
- NYMEX futures returns are not the same instrument as the Darwinex
  `XNGUSD.DWX` continuous CFD; and
- financing, spread, gaps, roll/basis construction and broker calendar can
  consume or reverse the reported gross effect.

For those reasons the finding authorizes only a strict Q02 falsification
candidate. No neighboring calendar day, seasonal filter, direction flip or
parameter sweep may be inferred from the paper after results are seen.

## Mechanization boundary

Once per broker month, and only if the current `XNGUSD.DWX` D1 bar is dated
the 15th, open one long package. Flatten it on the first following D1 bar. A
completed-bar `ATR(20)` hard stop at `2.75 * ATR`, one-calendar-day stale
guard, 2500-point entry-spread cap, fixed-risk sizing, framework news gate and
restart-safe one-attempt marker are V5 risk/execution plumbing, not
source-authored alpha.

Expected cadence is about 8-10 completed packages per full year because only
15ths with a tradable D1 bar can enter. Q02 must retire the card below the
portfolio research floor of five completed trades/year/symbol.

## Reputable-source criteria

- R1: TIER_B. One named-author, peer-reviewed article is the sole evidence
  lineage; official archive and complete author-uploaded text are preserved.
- R2: PASS. Exact broker date 15, long direction, next-D1 flatten, no-shift
  rule, one-attempt state and all V5 risk additions are deterministic.
- R3: PASS. `XNGUSD.DWX` D1 is registered and requires no external runtime
  feed.
- R4: PASS. Calendar arithmetic and ATR risk only; no ML, banned indicator,
  adaptive fit, grid, martingale, pyramiding or multiple positions per magic.

## Non-duplicate boundary

Repository-wide slug, card, source and EA searches found no recurring
one-session `XNGUSD.DWX` long rule for calendar day 15.

- `QM5_12567_cum-rsi2-commodity` is a price-conditioned SMA/RSI pullback.
- `QM5_12818_xng-tue-prem`, `QM5_12819_xng-thu-fade` and
  `QM5_20011_xng-thu-tue` are weekday effects.
- `QM5_13009_xng-tom-mom` is a turn-of-month rule.
- `QM5_20013_xng-2m-contr` and `QM5_20014_xng-month-ch3` use multi-month
  return and monthly channel states.
- `QM5_12813_eia-energy-switch` has a broad May-15/August-31 paired energy
  regime; it does not trade every available day-15 natural-gas session.
- `QM5_12725_eia-xng-prestor` is conditional storage-event timing that can
  occasionally overlap the date but has a different trigger and holding rule.

The mechanic is new, but realized correlation with the certified book remains
unproven and must be measured later. No portfolio-gate waiver is claimed.

## Safety boundary

This source authorizes one `RISK_FIXED` research/backtest carrier only. It
does not authorize a live setfile, AutoTrading, T_Live, a deploy or T_Live
manifest, portfolio admission, or any portfolio-gate change.

## Second extraction: day-27 negative extreme

The same fully reviewed source reports calendar day 27 as the minimum
natural-gas numbered-day mean, `-0.7265%`. Unlike day 15, the paper does not
report day 27 as statistically significant, so S02 is explicitly a weak
extreme-mean falsification hypothesis: short only the exact broker D1 session
dated the 27th and flatten at the next D1 boundary. Repository-wide search on
2026-07-22 found no XNG day-27 carrier. No absent date is shifted, no adjacent
date is inferred, and no parameter sweep is authorized.
