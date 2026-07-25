---
source_id: KELOHARJU-MOP-WTI-CALTREND-2026
title: WTI same-calendar seasonality and medium-horizon trend agreement
publisher: The Journal of Finance / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-07-25
created_by: Codex
last_updated: 2026-07-25
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-07-25
strategy_ids:
  - KELOHARJU-MOP-WTI-CALTREND-2026_S01
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
---

# WTI Same-Calendar Seasonality And Trend Source

## Source Identity

This packet joins two already governed peer-reviewed source lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI https://doi.org/10.1111/jofi.12398. The complete open NBER working
   paper is https://www.nber.org/papers/w20815.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI https://doi.org/10.1016/j.jfineco.2011.11.003. The governed
   institutional research page is
   https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

The bounded repository packets
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` were read completely before
this extraction. The first packet records the complete 57-page NBER review and
the paper's explicit crude-oil membership. The second is the governed
JFE/AQR lineage for own-past-return time-series momentum, including the
predeclared three-month WTI translation.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg find that an asset's returns in the same
  calendar month of prior years contain recurring seasonal information. Their
  commodity test ranks a broad futures cross-section that includes crude oil.
- Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
  futures, including commodities, and define direction from an instrument's
  own trailing-return sign.
- Neither paper tests an agreement gate between those states, a single
  Darwinex continuous WTI CFD, fixed-risk monthly renewal, or an ATR hard
  stop. Those are explicit QM falsification hypotheses.

No paper statistic is imported as a forecast for the candidate. The existing
parent packets remain the evidence boundary; this packet introduces no new web
claim.

## Bounded Mechanization

`KELOHARJU-MOP-WTI-CALTREND-2026_S01` is one predeclared interaction:

- host and only traded symbol: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker month;
- seasonal state: arithmetic mean of WTI's completed log return for the
  decision calendar month over up to ten prior years, with at least five valid
  samples;
- trend state: sign of the completed 63-D1 WTI log return;
- buy only when both states are strictly positive;
- sell only when both states are strictly negative;
- disagreement, exact zero, invalid arithmetic, or insufficient history:
  remain flat for that month;
- close and, when agreement exists, renew at the next month boundary;
- frozen `3.5 * ATR(20)` hard stop, 35-day stale guard, 1,500-point spread
  ceiling, and one consumed attempt per broker month; and
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, backtest-only execution.

The agreement gate should select roughly half of monthly decisions under an
uninformative sign prior, but realized density is unknown. Q02 must retire the
carrier if completed packages average below five per year. No threshold may
be fitted after results.

## Non-Duplicate Boundary

The pre-allocation deterministic check scanned 4,193 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-caltrend`, strategy ID
`KELOHARJU-MOP-WTI-CALTREND-2026_S01`, and the complete mechanic fingerprint.

Manual semantic review resolves the closest systems:

- `QM5_20099_wti-samecal` trades the historical same-calendar sign alone and
  does not inspect recent trend.
- `QM5_20055_wti-tsmom3m` trades the completed 63-D1 sign alone and has no
  historical same-calendar estimator.
- `QM5_20135_wti-winter-trend` uses a fixed November-May regime and a 252-D1
  trend sign. It does not recompute seasonality across prior matching months.
- `QM5_13115_energy-samecal` ranks WTI against natural gas and always requires
  a two-leg energy basket.
- `QM5_12576_eia-wti-season` uses fixed refined-product demand months,
  SMA(84), and 21-D1 ROC confirmation.
- `QM5_12983_wti-tom-mom` is restricted to a turn-of-month trading window.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The new information state is the conjunction of an adaptive, prior-year
same-calendar WTI sign and a completed 63-D1 WTI trend sign. Removing either
state recreates an already-built parent. The conjunction is fixed before
testing and is not a rescue parameter sweep.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed papers with DOI and durable,
  completely reviewed repository packets.
- R2: PASS. The seasonal estimator, trend lookback, agreement rule, monthly
  cadence, stop, stale exit, spread cap, and retry state are deterministic and
  locked.
- R3: PASS. Registered `XTIUSD.DWX` D1 data supplies every runtime input.
- R4: PASS. Runtime uses native MT5 OHLC, ATR, broker calendar, quotes,
  positions, deal history, and framework state only; there is no ML, banned
  indicator, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Safety Boundary

The sources do not establish profitability, CFD/futures equivalence, trade
density, decorrelation, or portfolio admission for this interaction. WTI gaps,
roll/basis behavior, financing, limited same-month samples, and conjunction
sparsity are binding kill risks.

This OWNER-approved packet authorizes one Strategy Card, deterministic
registry allocation, V5 build, strict compile, one `RISK_FIXED` backtest
setfile, and one paced Q02 enqueue. It does not authorize a live setfile,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.
