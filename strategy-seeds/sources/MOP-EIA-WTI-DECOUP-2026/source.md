---
source_id: MOP-EIA-WTI-DECOUP-2026
title: WTI time-series momentum in weak oil-gas co-movement regimes
publisher: Journal of Financial Economics / U.S. Energy Information Administration / The Energy Journal
source_type: peer_reviewed_composite_with_government_research
status: approved_source_complete
approval_basis: decisions/2026-08-14_qm5_21516_wti_decoup_trend_g0.md
created: 2026-08-14
created_by: Research+Development
strategy_ids:
  - MOP-EIA-WTI-DECOUP-2026_S01
---

# WTI Decoupled-Trend Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-14 authorizes one new non-duplicate,
structural, low-frequency commodity/energy card, branch-only build, and paced
Q02 enqueue. Durable authorization is
`decisions/2026-08-14_qm5_21516_wti_decoup_trend_g0.md`.

This extraction is content-bound to two governed parent packets that were read
completely for the relevant rule and limitations:

- `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
  records the complete 23-page published paper and retrieval receipt.
- `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
  `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`,
  records complete reads of the 43-page EIA report, the peer-reviewed Energy
  Journal article, and modern EIA adverse context.

## Canonical Citations

1. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`.
2. Villar, Jose A., and Frederick L. Joutz (2006), "The Relationship Between
   Crude Oil and Natural Gas Prices," U.S. Energy Information Administration,
   Office of Oil and Gas.
3. Ramberg, David J., and John E. Parsons (2012), "The Weak Tie Between
   Natural Gas and Oil Prices," *The Energy Journal* 33(2), 13-35, DOI
   `10.5547/01956574.33.2.2`.
4. U.S. Energy Information Administration (2020), "Natural gas markets remain
   regionalized compared with oil markets."

## Source Findings Used

Moskowitz, Ooi, and Pedersen define time-series momentum by the sign of an
instrument's own past return, trade in that sign, and renew monthly. Their
published tests include WTI crude and the selected twelve-month strategy.
The evidence is a diversified futures result and does not establish a
Darwinex WTI-only premium.

Villar and Joutz document physical and economic oil-gas links, nonstationary
price levels, temporary decoupling, and instability. Ramberg and Parsons find
that no fixed energy-content or price-ratio rule is reliable, that most gas
price-change variance remains unexplained, and that the relationship changes
across regimes. EIA's later context reports little daily WTI/Henry Hub return
correlation in the cited period. These findings justify testing a weak common-
energy state; they do not prescribe a rolling Pearson window, threshold, or
trend strategy.

## Locked QM Mechanization

At a genuine broker-month transition, derive thirteen consecutive completed
broker-month WTI closes and set:

```text
trend_12m = ln(WTI_month_end_latest / WTI_month_end_12_months_ago)
```

From the latest 64 exactly timestamp-matched completed D1 WTI and XNG closes,
form 63 chronological simple returns per asset. With sample means:

```text
cov_xy = sum((x_i-mean_x)*(y_i-mean_y)) / (63-1)
var_x  = sum((x_i-mean_x)^2) / (63-1)
var_y  = sum((y_i-mean_y)^2) / (63-1)
rho    = cov_xy / sqrt(var_x * var_y)
```

Require positive finite variances and `abs(rho) <= 0.30 + 1e-12`.
When qualified, buy WTI for positive `trend_12m` and sell WTI for negative
`trend_12m`. An exact-zero trend, invalid history, or stronger oil-gas
correlation consumes the broker month flat.

The 63-return window and `0.30` ceiling are transparent QM hypotheses selected
before Q02. The sources do not supply them. One terminal-persistent monthly
attempt marker prevents retry. One `RISK_FIXED=1000` WTI position receives a
frozen `3.5*ATR(20,D1)` hard stop, no take-profit, next-month replacement, and
a forty-day stale exit. XNG is read-only.

## Claim And Data Boundary

- The JFE result uses diversified, volatility-scaled futures excess returns;
  the EA uses one continuous CFD and fixed-dollar stop risk.
- Pearson return correlation is not cointegration, causality, beta neutrality,
  or portfolio correlation. A low XTI/XNG value does not guarantee low overlap
  with XAU, SP500, NDX, or the incumbent XNG strategy.
- The oil-gas sources study spot/futures benchmarks and richer econometric
  systems. Synchronized Darwinex CFD closes are a price-native proxy.
- XNG is not a package leg, hedge, risk scaler, or order route. It is one
  read-only state input.
- No source return, alpha, Sharpe ratio, significance, drawdown, trade count,
  cost estimate, CFD statistic, threshold, or book-correlation value transfers.

## Non-Duplicate Boundary

The deterministic pre-allocation command returned `CLEAN` across 4,388
EA-registry rows and 484 cards. Manual review found no existing WTI card that
jointly uses the source-exact twelve-month own-return sign and an absolute
63-return XTI/XNG correlation admission gate.

Unconditional and alternate-horizon WTI momentum EAs never condition on XNG
co-movement. XTI/XNG ratio, return-spread, error-correction, beta, tail, jump,
and volatility baskets trade or rank a cross-energy state rather than using
weak daily correlation solely to admit an outright WTI trend. Calendar and
seasonal trend variants use date state, not synchronized cross-energy return
correlation. The full identity is therefore the carrier, trend horizon,
correlation window and convention, absolute threshold, read-only XNG route,
and monthly consumed-attempt lifecycle.

Verdict: `CLEAN_PRE_ALLOCATION_AND_MANUAL_MECHANIC_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. Named peer-reviewed JFE and Energy Journal papers, a complete U.S.
  government report, durable complete-read receipts, exact source roles, and
  adverse limitations are preserved.
- R2: PASS. Thirteen month ends, exact twelve-month log-return sign, 64 common
  closes, 63 simple returns, sample Pearson arithmetic, fixed absolute ceiling,
  consumed attempt, stop, spread, rollover, and stale exit are locked.
- R3: PASS for the disclosed proxy. Registered XTI/XNG D1 OHLC and native MT5
  calendar/execution metadata provide every runtime field.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Safety Boundary

This packet authorizes no manual backtest, live/demo/shadow/stress/optimization
setfile, AutoTrading action, `T_Live` path, deploy manifest, portfolio-gate
change, portfolio admission, or correlation waiver. Q02 and later gates own
density, economics, robustness, and realized portfolio overlap.
