---
source_id: FERNANDEZ-SKEW-2018
title: The Skewness of Commodity Futures Returns
publisher: Journal of Banking and Finance
source_type: peer_reviewed_paper_with_open_accepted_manuscript
status: cards_ready
approval_basis: OWNER mission directive 2026-07-10
created: 2026-07-10
created_by: Codex
cards_extracted:
  - energy-skew-rank
---

# Fernandez-Perez et al. Commodity-Skewness Source Packet

## Source Identity And Approval

- Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre,
  Joelle (2018), "The Skewness of Commodity Futures Returns", *Journal of
  Banking & Finance* 86, 143-158.
- Published DOI: https://doi.org/10.1016/j.jbankfin.2017.06.015.
- Full accepted manuscript: Auckland University of Technology repository,
  https://openrepository.aut.ac.nz/server/api/core/bitstreams/05e08e2e-f763-4f46-ac67-4c13ac10a451/content.
- Approval basis: the OWNER mission dated 2026-07-10 directs Codex to select,
  card, build, and enqueue one new structural commodity/energy sleeve.

The complete 44-page accepted manuscript was reviewed end to end, including
the theoretical motivation, data, portfolio construction, robustness tests,
cross-sectional tests, appendices, tables, figures, conclusions, and
references.

## Bounded Extraction

The paper estimates Pearson's moment coefficient of skewness for each of 27
commodity futures from daily log returns over the preceding 12 months. At each
month-end it ranks the cross-section into quintiles, buys the 20% with the
lowest skewness, shorts the 20% with the highest skewness, and holds the
fully-collateralized long-short portfolio for one month. Crude oil and natural
gas are both explicit members of the five-contract energy sector.

This packet extracts one constrained carrier for the mission:
`energy-skew-rank`. It ranks only `XTIUSD.DWX` and `XNGUSD.DWX` using the same
12-completed-month daily-return skewness statistic, buys the lower-skew energy
leg, and shorts the higher-skew leg. The source uses a diversified 27-future
cross-section and extreme quintiles. The two-leg DWX carrier is therefore a
falsifiable market-neutral test, not a replication of the source portfolio.

The paper's co-skewness, filtered-return, and asset-pricing tests are robustness
analyses rather than separate executable strategies, so no other card is
extracted from this bounded source for this one-edge mission.

## QM Translation

On the first tradable D1 bar of each broker month, use only completed D1 bars
from the preceding 12 complete broker-calendar months. For each energy leg,
compute daily log returns and Pearson's population moment coefficient:

`skew = mean((r - mean(r))^3) / mean((r - mean(r))^2)^(3/2)`.

- If `skew_XTI < skew_XNG`, buy XTI and sell XNG.
- If `skew_XTI > skew_XNG`, sell XTI and buy XNG.
- If the difference is an exact numerical tie, or either leg has insufficient
  observations or variance, remain flat.
- Close and rerank at the next broker-month transition.

Per-leg fixed-risk ATR hard stops, equal risk allocation, orphan cleanup, and a
35-day stale guard implement the V5 risk contract without changing the
source-defined rank direction.

## Evidence And Limitations

- The source reports a monotonic inverse relation between skewness rank and
  subsequent returns in its broad universe. Its long-short result and
  robustness tests are source evidence, not an expectation for this carrier.
- The effect is more strongly driven by underperformance of the high-skew short
  side than by the low-skew long side. A two-asset energy rank can therefore
  lose the diversification that made the source portfolio investable.
- The paper uses exchange-traded front/second futures with an explicit roll
  rule. The EA observes continuous Darwinex CFDs, so futures roll, collateral,
  and basis economics are not reproduced.
- Equal risk and opposite directions reduce common energy beta but do not
  guarantee dollar, beta, or factor neutrality. Q09 alone may measure realized
  correlation to the certified book.
- Friday close is disabled to preserve the one-month holding cadence. Monthly
  rollover, ATR stops, orphan repair, and the stale guard remain active.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, pullback, long-only state, or
  short holding period.
- Not `QM5_12733_xti-xng-xmom`: no return-momentum rank.
- Not `QM5_12840_xti-xng-rspread`: no short-horizon return-spread z-score fade.
- Not `QM5_12850_xti-xng-vcb`: no volatility-contraction breakout.
- Not `QM5_13089_xti-xng-carry`: no swap/carry rank.
- Not `QM5_13113_energy-mom-ivol`: no momentum agreement or residual-volatility
  regression.
- Not `QM5_13115_energy-samecal`: no same-calendar-month return history.
- Repository content search found no existing commodity realized-skewness or
  third-moment strategy. Pre-allocation dedup was `CLEAN` for the exact slug,
  strategy ID, universe, cadence, and mechanic.

## Runtime Guardrails

- Native `XTIUSD.DWX` and `XNGUSD.DWX` D1 OHLC, ATR, spread, broker calendar,
  symbol metadata, and framework position state only.
- No futures chain, inventory, weather, volume, open interest, COT, external
  file/API, ML, adaptive PnL fit, grid, martingale, or pyramiding.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, split equally across the
  two legs. No live setfile is created.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed *Journal of Banking & Finance* paper with DOI and a
  complete institutional-repository accepted manuscript; XTI and XNG are
  explicit source instruments.
- R2: PASS. Fixed 12-month daily-return Pearson skewness, deterministic
  cross-sectional rank, monthly rebalance, ATR hard stops, and stale exit.
- R3: PASS. Registered XTIUSD.DWX and XNGUSD.DWX D1 data only.
- R4: PASS. Deterministic arithmetic; no banned indicator, ML, external runtime
  data, grid, martingale, pyramiding, or adaptive fitting.

