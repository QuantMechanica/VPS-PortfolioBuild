---
source_id: GURRIB-WTI-ROC14-2024
title: Trading Momentum in the U.S. Crude Oil Futures Market
publisher: International Journal of Energy Economics and Policy
source_type: peer_reviewed_open_access_paper
status: cards_ready
approval_basis: OWNER mission directive 2026-07-10
created: 2026-07-10
created_by: Codex
cards_extracted:
  - wti-roc14-xtrm
---

# Gurrib, Starkova, and Hamdan WTI ROC-14 Source Packet

## Source Identity And Approval

- Gurrib, Ikhlaas; Starkova, Olga; and Hamdan, Dalia (2024), "Trading
  Momentum in the U.S. Crude Oil Futures Market", *International Journal of
  Energy Economics and Policy* 14(5), 593-604.
- DOI: https://doi.org/10.32479/ijeep.16520.
- Open published paper:
  https://www.econjournals.com/index.php/ijeep/article/download/16520/8218.
- Official WTI supplement: CME Group, "WTI Crude Oil Futures",
  https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html.
- Approval basis: the OWNER mission dated 2026-07-10 directs Research and
  Development to select, card, build, and enqueue one new structural
  commodity/energy sleeve.

The complete 12-page published paper was reviewed, including the literature,
data, ROC definition, trading rules, MA-filter variants, results, limitations,
and references. The CME page is a market-lineage supplement only.

## Bounded Extraction

The paper evaluates WTI end-of-month prices from May 2004 through April 2024.
It compares 9- through 14-month rate-of-change horizons, selects 14 months, and
uses fixed +40% and -40% extremes. A move through +40% creates an overbought
sell state; a move through -40% creates an oversold buy state. A position is
paired with the next opposite signal.

This packet extracts only that ROC-14 extreme-crossing system. The paper's
moving-average confirmation produces no trades, and the disjunctive ROC-or-MA
variant is rejected because the authors prefer the simpler ROC-only model.

## QM Translation

The EA reconstructs completed month-end closes from registered
`XTIUSD.DWX` D1 bars and computes:

`ROC14 = latest_month_end / month_end_14_months_earlier - 1`.

- Cross from below to at/above +40%: target short.
- Cross from above to at/below -40%: target long.
- Between crossings: retain the last non-zero target.
- Before the first crossing in available history: remain flat.

The paper accounts for a continuous position between opposite signals. The V5
port expresses the same target as one non-overlapping monthly risk package:
close the prior package at a new month, then reopen the retained target. This
preserves monthly direction while making fixed-risk attribution, stops, and
Q02 trade counting explicit. A frozen D1 ATR hard stop and a 35-day stale
guard are V5 risk-contract additions.

The port is a falsifiable Darwinex CFD translation. It does not claim to
replicate a rolled NYMEX futures series, and it imports no source performance
number as a QM expectation.

## Evidence And Limitations

- Source sample: 241 WTI end-of-month observations, May 2004-April 2024.
- Selected signal: 14-month ROC with fixed +40%/-40% extreme levels.
- Source trade count: eight completed continuous positions in about 20 years.
- Reported results are highly dependent on a 2009 outlier; the paper also
  reports that its four positions from 2017 onward lost money.
- The paper's own risk-adjusted discussion is cautious and recommends further
  filters, but its tested MA confirmation eliminated all signals.
- Q02 must reject the CFD port if the monthly packages cannot clear frequency,
  cost, PF, or drawdown gates.

## Non-Duplicate Boundary

- Not `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`, or
  `QM5_13100_wti-dmac16`: those are continuation states based on return sign,
  horizon agreement, or a monthly moving-average neutral band.
- Not `QM5_12621_comm-reversal-4wk-xtiusd`,
  `QM5_12594_yang-wti-reversal`, or `QM5_12979_wti-6m-reversal`: those fade
  20-, 63-, or 120-D1 moves with weekly/monthly threshold, SMA/stretch, zero
  cross, confirmation, and/or short time-hold logic. This rule requires an
  explicit source-defined 14-month +/-40% crossing and retains its state until
  the opposite extreme crossing.
- Not an event, weekday, month-of-year, inventory, roll, futures-curve,
  ratio, basket, channel-breakout, RSI, or volatility-state system.

Repository dedup was run before ID allocation with slug `wti-roc14-xtrm`,
strategy ID `GURRIB-WTI-ROC14-2024_S01`, and the full mechanic fingerprint;
the verdict was `CLEAN`.

## Runtime Guardrails

- Native `XTIUSD.DWX` D1 OHLC, ATR, spread, broker calendar, and framework
  position state only.
- No futures chain, inventory, volume, open interest, COT, EIA, OPEC, CSV,
  API, external feed, adaptive PnL rule, ML, grid, martingale, or pyramiding.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and no live setfile.
- Friday close is disabled to preserve the paper's monthly holding cadence;
  the monthly rollover and 35-day stale guard bound each package.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed 2024 paper with DOI and full open published text;
  CME supplies official WTI benchmark lineage. Quality tier B for the primary
  signal evidence because the sample is short, the trade count is eight, and
  the paper discloses substantial outlier and recent-period fragility.
- R2: PASS. Fixed month-end sampling, 14-month ROC, +/-40% crossings,
  persistent direction, monthly package rollover, ATR stop, and stale exit.
- R3: PASS. Only registered `XTIUSD.DWX` D1 market data is required.
- R4: PASS. Deterministic arithmetic only; no banned indicator, ML, external
  runtime data, grid, martingale, pyramiding, or adaptive fitting.

