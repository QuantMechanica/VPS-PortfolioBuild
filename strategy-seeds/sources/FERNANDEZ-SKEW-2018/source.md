---
source_id: FERNANDEZ-SKEW-2018
title: The Skewness of Commodity Futures Returns
publisher: Journal of Banking and Finance
source_type: peer_reviewed_paper_with_open_accepted_manuscript
status: cards_ready
approval_basis: OWNER commodity/energy sleeve missions 2026-07-10 and 2026-08-06
created: 2026-07-10
created_by: Codex
last_updated: 2026-08-06
cards_extracted:
  - energy-skew-rank
  - xauxag-skew-rank
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
- Reopen basis: the OWNER mission dated 2026-08-06 directs Codex to add one
  new, non-duplicate, low-frequency commodity sleeve to the certified-book
  candidate set. This durable reopen authorizes only the source-faithful
  `S02` XAU/XAG carrier below, a branch-only non-live build, and one paced Q02
  enqueue.

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

The first constrained carrier is `energy-skew-rank`. It ranks only
`XTIUSD.DWX` and `XNGUSD.DWX` using the same
12-completed-month daily-return skewness statistic, buys the lower-skew energy
leg, and shorts the higher-skew leg. The source uses a diversified 27-future
cross-section and extreme quintiles. The two-leg DWX carrier is therefore a
falsifiable market-neutral test, not a replication of the source portfolio.

The 2026-08-06 reopen adds `FERNANDEZ-SKEW-2018_XAU_XAG_S02`, a locked carrier
extension of the same rule. Gold and silver are explicit members of the
paper's five-contract metals sector. On each broker-month boundary it ranks
only `XAUUSD.DWX` and `XAGUSD.DWX` by the same prior-12-complete-month Pearson
skewness statistic, buys the lower-skew metal, shorts the higher-skew metal,
and holds the paired package for one month. The 12-month formation, estimator,
low-minus-high direction, monthly renewal, equal package-risk split, ATR stop,
and no-retry lifecycle are unchanged from `S01`; only the traded carrier and
metal spread caps change. This is a carrier falsification under the
survivor-port rule, not a new lookback, threshold, direction, or PnL repair.

The source's co-skewness, filtered-return, and asset-pricing tests remain
robustness analyses rather than separate executable strategies.

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

For `S02`, substitute XAU for XTI and XAG for XNG in the equations and rank:

- if `skew_XAU < skew_XAG`, buy XAU and sell XAG;
- if `skew_XAU > skew_XAG`, sell XAU and buy XAG; and
- on a numerical tie or invalid formation data, consume the month and remain
  flat.

Opposite sides plus equal fixed package-risk halves reduce common precious-
metal direction but do not prove dollar, beta, volatility, or portfolio
neutrality. The logical basket must be evaluated as one package.

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
- Gold and silver are explicit source instruments, but the source never tests
  a two-metal extreme rank. Its five-metal sector and 27-future quintiles are
  narrowed to two CFDs, so breadth and diversification do not transfer.
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

For `S02`, deterministic pre-allocation scanned 4,290 EA-registry rows and 406
cards. It found no exact identity and one expected fuzzy match,
`QM5_13118_energy-skew-rank`, because the source estimator is intentionally
locked. Manual carrier review is clean:

- Existing XAU/XAG EAs use raw/log-ratio or OLS-level convergence, quantile
  envelopes, return shocks, relative momentum, same-calendar effects,
  idiosyncratic volatility, or momentum/IVol agreement. None ranks the metals
  by their third standardized return moment.
- `QM5_13118` trades XTI/XNG. `S02` trades XAU/XAG and preserves every signal
  parameter, so it is an explicit carrier test rather than a renamed energy
  build.
- The incumbent `QM5_12567` is a short-horizon cumulative-RSI pullback and has
  no cross-sectional moment rank or paired monthly lifecycle.

Verdict: `CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Runtime Guardrails

- Native registered D1 OHLC, ATR, spread, broker calendar, symbol metadata,
  and framework position state only. `S01` uses XTI/XNG; `S02` uses XAU/XAG.
- No futures chain, inventory, weather, volume, open interest, COT, external
  file/API, ML, adaptive PnL fit, grid, martingale, or pyramiding.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, split equally across the
  two legs. No live setfile is created.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed *Journal of Banking & Finance* paper with DOI and a
  complete institutional-repository accepted manuscript; crude, natural gas,
  gold, and silver are explicit source instruments.
- R2: PASS. Fixed 12-month daily-return Pearson skewness, deterministic
  cross-sectional rank, monthly rebalance, ATR hard stops, and stale exit.
- R3: PASS. Each bounded carrier uses only its registered native `.DWX` D1
  histories.
- R4: PASS. Deterministic arithmetic; no banned indicator, ML, external runtime
  data, grid, martingale, pyramiding, or adaptive fitting.
