---
source_id: BOROWSKI-COMM-DOW-2016
title: Natural-gas Wednesday day-of-week return anomaly
publisher: Journal of Management and Financial Sciences, SGH Warsaw School of Economics
source_type: peer_reviewed_open_access_paper
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016
open_full_text_url: https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER
strategy_ids:
  - BOROWSKI-COMM-DOW-2016_S01
  - BOROWSKI-COMM-DOW-2016_S02
---

# Borowski Natural-Gas Wednesday Source

## Source identity

Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
Markets of Future Contracts with the Following Underlying Instruments: Crude
Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle,
Lean Hogs and Lumber," *Journal of Management and Financial Sciences*, issue
26, pages 27-44. The official SGH archive identifies the issue; the complete
author-uploaded article is linked above. The full article, including methods,
weekday tables, conclusions, limitations and references, was reviewed on
2026-07-20.

The journal documents external double-blind review. This source is classified
quality tier B: it is a named-author, peer-reviewed empirical paper with a
complete public copy, but it is one broad calendar-anomaly study rather than a
realizable trading track record.

## Selected natural-gas finding

The study uses NYMEX natural-gas futures observations from 1990-04-03 through
2016-03-31. Its day-of-week test compares the daily-return population for each
weekday with returns from all other weekdays. For natural gas:

- Wednesday has a sample mean of `-0.2664%`;
- Friday also has a negative mean, `-0.1274%`, while Monday, Tuesday and
  Thursday have positive sample means; and
- equality of the Wednesday mean and the other-weekday population is rejected
  with reported `p=0.0136`.

The abstract identifies day-of-week effects "on Wednesdays (heating oil,
natural gas, live cattle, lean hogs and lumber)". This is an author claim and
the values above are paper statistics, not expected Darwinex CFD returns or
QM certification evidence.

## Interpretation and limitations

The source result is the return attributed to the Wednesday trading session.
Opening at the first executable price of a broker D1 bar dated Wednesday and
flattening at the first executable price of the following D1 bar is the
closest deterministic MT5 proxy for the source's prior-close-to-Wednesday-
close return. Broker D1 boundaries can differ from the NYMEX settlement
boundary, so this mapping is itself a basis risk.

Important weaknesses are predeclared:

- the article searches multiple commodities and calendar partitions without
  reporting a family-wise or false-discovery correction;
- the weekday mean-comparison method assumes normal populations and selects
  an equal/unequal-variance test through an F-test;
- evidence ends in March 2016 and does not establish post-publication
  persistence;
- NYMEX futures returns are not the Darwinex `XNGUSD.DWX` continuous CFD; and
- spread, financing, gaps, roll/basis construction, news filters and broker
  calendar boundaries can consume or reverse the reported gross effect.

For those reasons the finding authorizes only one locked Q02 falsification
candidate. No neighboring weekday, direction flip, causal story or parameter
sweep may be inferred after results are seen.

## Mechanization boundary

On a genuine new broker D1 bar dated Wednesday, consume one attempt and sell
one `XNGUSD.DWX` package. Flatten it on the first following D1 bar. A
completed-bar `ATR(20)` hard stop at `2.75 * ATR`, one-calendar-day stale
guard, 2500-point entry-spread cap, fixed-risk sizing, framework news gate and
restart-safe daily attempt marker are V5 risk/execution plumbing rather than
source-authored alpha.

Expected cadence is about 45-52 completed packages per full year. Q02 must
retire the card below the portfolio research floor of five completed
trades/year/symbol.

## Reputable-source criteria

- R1: TIER_B. One named-author, peer-reviewed article is the sole evidence
  lineage; official archive and complete author-uploaded text are preserved.
- R2: PASS. Broker Wednesday, short direction, next-D1 flatten, one-attempt
  state and all V5 risk additions are deterministic and frozen.
- R3: PASS. `XNGUSD.DWX` D1 is registered and needs no external runtime feed.
- R4: PASS. Calendar arithmetic and ATR risk only; no ML, banned indicator,
  adaptive fit, grid, martingale, pyramiding or multiple same-magic positions.

## Non-duplicate boundary

The deterministic dedup tool returned CLEAN for the slug, strategy identity,
author and `XNG Wednesday D1 short / next-D1 flat` mechanic. Repository-wide
card/source/EA inspection found no unconditional Wednesday-entry XNG carrier.

- `QM5_12567_cum-rsi2-commodity` is a price-conditioned SMA/cumulative-RSI2
  pullback, not calendar timing.
- `QM5_12818_xng-tue-prem` buys Tuesday; `QM5_12819_xng-thu-fade` sells
  Thursday; `QM5_12806_xng-rev-weekend` trades Monday and Friday.
- `QM5_20011_xng-thu-tue` exits at Wednesday open and therefore does not hold
  the Wednesday return.
- XNG storage EAs may admit Wednesday as an event window but require release
  timing and price state; they are not an unconditional weekday carrier.
- `QM5_20017_xng-dom15-long` uses another result from the same paper but an
  exact numbered calendar day, monthly cadence, and long direction.

Different logic from the certified RSI2 sleeve is established, but realized
portfolio correlation is unproven and remains a governed downstream kill
test. No portfolio-gate waiver is claimed.

## Safety boundary

This source authorizes one `RISK_FIXED` research/backtest carrier only. It does
not authorize a live setfile, AutoTrading, T_Live, a deploy/T_Live manifest,
portfolio admission, or any portfolio-gate change.

## Second extraction: natural-gas Friday short

The same fully reviewed weekday table reports a negative Friday natural-gas
mean of `-0.1274%`. `BOROWSKI-COMM-DOW-2016_S02` isolates that observation as
an unconditional Friday D1 short closed at the next D1 boundary. The Friday
mean is not reported statistically significant, so this is explicitly a weak
falsification candidate rather than a confirmed anomaly. The exact weekday,
short direction, ATR(20) x 2.75 stop, 2500-point spread cap, restart-safe daily
attempt, and one-day stale exit are locked before Q02.

Repository-wide exact-mechanic searches found no unconditional XNG Friday
short/next-D1-flat carrier. Existing XNG weekend, storage, weekday, trend, and
QM5_12567 RSI logic use different information sets. Multiple comparisons,
post-2016 decay, broker-session basis, and costs are binding kill risks.
