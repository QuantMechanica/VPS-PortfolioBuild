# WTI Low-Downside-Beta Trend — Source Approval

Date: 2026-08-14

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 handoff if the factory CPU ceiling permits.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge, names a WTI trend/seasonality sleeve as an
allowed carrier, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-lowdb-trend`
- proposed strategy ID: `MOP-HOLLSTEIN-WTI-LOWDB-2026_S01`
- traded symbol: `XTIUSD.DWX`, D1, slot 0
- read-only factor: `SP500.DWX`, D1
- decision clock: first processed WTI D1 bar after a genuine broker-month
  transition
- active rule: follow the exact prior-twelve-completed-month WTI return sign
  only when WTI's recent SP500 downside beta is lower than its value in the
  preceding disjoint 252-return block

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Sources

The following complete governed packets were read before this decision:

1. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250. The complete published paper review,
   DOI lineage, retrieval receipt, and WTI membership are recorded at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
2. Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in Commodity Futures
   Markets," *Quarterly Journal of Finance* 11(4), article 2150017. The
   complete accepted-manuscript and online-appendix review, exact DownBeta
   definition, null evidence, and WTI membership are recorded at
   `strategy-seeds/sources/HOLLSTEIN-DOWNBETA-2021/source.md`, SHA-256
   `C6699329DAEC54DE5B89FA25D268229DC5C758E821A7055E8D56F162C009F6F4`.

Moskowitz, Ooi, and Pedersen supply only the twelve-month own-return sign and
monthly cadence. Hollstein, Prokopczuk, and Tharann supply only the
below-average-market-day beta characteristic and its low-beta orientation.
The conjunction, two-block time-series comparison, raw-CFD/risk-free-zero
proxy, fixed-dollar risk, hard stop, spread ceiling, and restart ledger are
transparent QM hypotheses. No source return, alpha, significance, drawdown,
trade count, cost, CFD equivalence, decorrelation, or portfolio result
transfers.

The downside-beta source reports an insignificant characteristic and calls it
mostly unpriced. That adverse evidence is binding and is not converted into a
positive claim. The beta state is admitted only as a falsifiable correlation-
control gate on the separately sourced WTI trend.

## Locked Mechanic

At each genuine broker-month transition, after closing any prior-month owned
position and consuming the new month before fallible gates:

1. Reconstruct thirteen consecutive completed WTI broker-month-end closes and
   calculate `trend_12m = ln(close_latest / close_12_months_older)`.
2. Load exactly 505 synchronized completed `XTIUSD.DWX` and `SP500.DWX` D1
   closes and form 504 chronological simple-return pairs.
3. Split the returns into a preceding block `0..251` and recent block
   `252..503`. They share one boundary close and no return observation.
4. Within each block independently, calculate the arithmetic mean of all 252
   SP500 returns. Retain only rows with `r_SP500 < mean_SP500`, requiring at
   least 100 rows and positive finite SP500 variance.
5. Fit `r_WTI = alpha + beta_down * r_SP500 + error` by intercept OLS on the
   retained rows. Require a finite solution in both blocks.
6. Admit the trend only when
   `beta_down_recent < beta_down_preceding - 1e-12`.
7. In the admitted state, buy on strictly positive `trend_12m`, sell on
   strictly negative `trend_12m`, and consume a numerical tie flat. When beta
   does not fall, consume the month flat.
8. Open at most one WTI position with one `RISK_FIXED=1000` budget, a frozen
   `3.5 * ATR(20,D1)` broker hard stop, no take-profit, and a 1,500-point
   entry-spread ceiling. Close before the next monthly replacement or after
   forty calendar days. Friday close and both news axes are OFF.

`SP500.DWX` is a read-only backtest factor. It receives no magic, order,
position, or package-PnL authority. Log-return substitution in the beta
blocks, population variance, pooled block means, overlapping returns,
non-strict down-day selection, beta-sign reversal, an absolute beta cutoff,
trend-free entry, score-sized risk, or same-month retry is outside approval.

## Reputable-Source Criteria

- R1 `PASS_WITH_ADVERSE_EVIDENCE`: two peer-reviewed primary papers with DOI
  lineage and complete governed reads; explicit WTI coverage; the DownBeta
  null is preserved.
- R2 `PASS`: exact month endpoints, return counts, block offsets, conditional
  OLS, strict low-beta gate, trend direction, attempt ledger, risk, stop,
  rollover, and stale guard are deterministic.
- R3 `PASS_FOR_DISCLOSED_PROXY`: registered WTI and SP500 D1 closes supply the
  runtime inputs; CRSP market excess return and the risk-free series are not
  available and are not claimed.
- R4 `PASS`: native arithmetic and framework state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,394 EA-registry rows and 490
root cards and returned `CLEAN` with no fuzzy match for the proposed slug,
strategy ID, author set, and full mechanic. Manual review fixes the closest
boundaries:

- `QM5_13203_energy-downbeta` estimates concurrent XTI and XNG downside betas
  in one 252-return block, ranks the two coefficients, and trades an opposite-
  leg energy basket. This candidate compares two disjoint WTI beta histories,
  uses the lower-recent-beta state only as an eligibility gate, and trades one
  WTI leg in its independent twelve-month trend direction.
- `QM5_21516_wti-decoup-trend` admits WTI trend under weak absolute 63-D1
  XTI/XNG return correlation. This candidate uses SP500 down-day conditional
  beta, two 252-return blocks, a strict falling-beta state, and no XNG input.
- Pure WTI time-series momentum trades every non-tied monthly signal and has
  no equity-factor state. WTI beta, volatility, jump, tail, calendar, event,
  breakout, reversal, and robust-location families do not implement this
  conjunction.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback above a slow price trend; it shares neither carrier, factor state,
  direction map, nor monthly lifecycle.

Verdict: `CLEAN_WTI_FALLING_DOWNSIDE_BETA_GATED_TWELVE_MONTH_TREND`.

## Kill And Safety Boundary

Expected cadence is approximately five to seven completed positions per full
post-warm-up year. Q02 must retire below five positions/year or on nonpositive
governed economics. Later unchanged gates, especially Q09, alone may establish
portfolio correlation. No failure may change the block support, down-day
definition, regression, beta direction, trend horizon, carrier, cadence,
fixed risk, stop, hold, spread, or retry policy.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. If the
paced factory CPU ceiling is binding before enqueue, stop and record the
capacity state without starting, stopping, reserving, reaping, or
reprioritizing a terminal.
