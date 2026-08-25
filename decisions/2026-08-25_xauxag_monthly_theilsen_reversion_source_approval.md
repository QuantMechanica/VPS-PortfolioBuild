# XAU/XAG Monthly Theil-Sen Ratio Reversion — Source Approval

Date: 2026-08-25

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Q02 enqueue is not authority to dispatch a
manual tester or exceed the active factory resource ceiling.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch. The mission names a market-
neutral-style `XAUUSD~XAGUSD` gold/silver ratio-reversion basket as an allowed
candidate, requires a genuinely new structural low-frequency mechanic with
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mtheilsen-rv`
- proposed strategy ID:
  `SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026`
- host/traded slot 0: `XAUUSD.DWX`, D1
- companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a new broker month
- signal: fade the exact Theil-Sen median slope of thirteen synchronized,
  consecutive, completed broker-month-end gold-minus-silver log ratios

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following governed packets were read completely before this decision:

1. `strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
   SHA-256
   `D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
   Its named primary source is Karsten Schweikert (2018), "Are gold and
   silver cointegrated? New evidence from quantile cointegrating
   regressions," *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`. Its official-exchange source is CME
   Group, "Gold & Silver Ratio Spread." The packet supports a related but
   state-dependent gold/silver relation, the intermarket-spread carrier, and
   economically different gold versus silver drivers.
2. `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
   `F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
   It preserves the exact deterministic thirteen-endpoint, 78-forward-pair,
   month-index-denominator, ascending-sort, and even-sample median arithmetic
   used for a Theil-Sen-style robust slope. Its WTI carrier, outright trend
   direction, and any performance boundary do not transfer.

Schweikert and CME support testing gold/silver relative value, not this exact
estimator, horizon, direction, CFD mapping, or trade. The Theil-Sen packet is
governed arithmetic precedent, not evidence that fading a gold/silver slope
is profitable. The synchronized continuous-CFD mapping, thirteen-month
formation, contrarian direction, fixed risk, stops, spread caps, and restart
lifecycle are disclosed QM translations. No source alpha, return, probability,
trade density, cost, neutrality, or decorrelation statistic transfers.

## Locked Mechanic

On the first synchronized executable `XAUUSD.DWX`/`XAGUSD.DWX` D1 tick after
each genuine broker-month transition:

1. Persist the current decision `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, stop, partial fill, or
   restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   For each month retain the latest close pair whose host and companion D1
   timestamps match exactly. Reject a missing month, duplicate month,
   nonchronological pair, nonpositive close, or newest endpoint more than ten
   calendar days stale.
3. In chronological order form `s[i]=ln(XAU_close[i])-ln(XAG_close[i])` for
   `i=0..12`.
4. Enumerate every forward slope
   `(s[j]-s[i])/(j-i)` for `0 <= i < j <= 12`. Require exactly 78 positive-
   denominator finite slopes. Sort ascending and define the even-sample
   Theil-Sen slope as `(sorted[38]+sorted[39])/2`.
5. A strictly positive slope opens SELL XAU / BUY XAG. A strictly negative
   slope opens BUY XAU / SELL XAG. Exact zero or invalid arithmetic consumes
   the month flat. The raw endpoint displacement is diagnostic only and may
   not gate direction.
6. Open at most one opposite-leg package with equal target absolute USD
   notionals, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, frozen `3.5*ATR(20,D1)` broker hard stops, no targets,
   1,500-point XAU and 500-point XAG spread ceilings, and at most 20% realized
   notional mismatch. Signal magnitude never scales risk.
7. Retain the package only when exactly one correctly directed, correctly
   registered, stop-protected position exists in each slot. Flatten all owned
   exposure immediately after any second-leg or package-validation failure.
8. Close both legs on the first tick in a later broker month, after forty
   calendar days, or whenever the package is orphaned, duplicated, same-side,
   wrong-magic, stopless, stale, or notional-invalid. Friday close and both
   news axes are OFF for the monthly hold.

The exact carrier, thirteen consecutive month-end pairs, log-ratio
orientation, 78 forward pairs, `j-i` denominators, even-sample median,
contrarian sides, durable monthly attempt, equal-notional aggregate-risk
package, atomic lifecycle, and next-month exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_ROBUST_SLOPE_TRANSLATION_RISK`: named-author peer-reviewed
  gold/silver research with DOI, official-exchange spread evidence, durable
  complete-read records, and exact governed Theil-Sen arithmetic precedent;
  the trading conjunction is explicitly untested.
- R2 `PASS`: clock, synchronization, month selection, ratio orientation,
  slopes, median, sides, attempt, risk, stops, atomicity, and exits are
  deterministic and locked before Q02.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes plus native MT5 state supply every
  runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, ATR risk stops, and execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical fail-closed checker, rerun against the actual Company Reference
Vault path, scanned 4,656 EA-registry rows, 1,307 card files, and 45 Strategy
Wiki nodes. It returned `CLEAN` with no exact or fuzzy match. Evidence is
`artifacts/qm5_xauxag_mtheilsen_rv_preallocation_dedup_20260825.json`, SHA-256
`A00568A2800CA986B98695826F36F74978786C9B9100687783D402881D602042`.
The preserved first receipt records only the checker's stale default Vault
path and its correct fail-closed `INPUT_ERROR_FAIL_CLOSED` response; it did
not authorize allocation.

Manual family review separates:

- `QM5_20271_wti-theilsen-tr`, which applies the same slope arithmetic to
  thirteen outright WTI month ends, follows the slope, and owns one WTI leg;
- `QM5_20050_xauxag-xmom12` and `QM5_20202_xauxag-rev18`, which use endpoint
  cross-sectional returns at different mechanics/horizons rather than all 78
  month-index-normalized slopes;
- `QM5_20161_xauxag-ols-rv` and `QM5_21526_xau-xag-cadf`, which fit regression
  residual centers/scales and trade threshold crossings rather than a robust
  ratio-path slope renewed once per month;
- `QM5_41138_xauxag-mdaily-hl-rv`, which uses 17-23 daily relative returns
  inside one month and the median of inclusive self/cross-pair averages, not
  thirteen month-end ratio levels and forward temporal slopes; and
- `QM5_12567_cum-rsi2-commodity`, a short-horizon long-only XNG oscillator
  pullback with no paired metal exposure.

Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Every valid nonzero slope may qualify, so the pre-result density prior is ten
to twelve packages per full post-warm-up year. This is not market evidence.
Q02 must retire the candidate below five completed packages in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
any timestamp, month, ratio, slope, denominator, median, side, attempt, risk,
atomicity, lifecycle, or determinism defect.

The opposite equal-notional legs are economically different from the
certified directional XAU/SP500/NDX/XNG book but do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q09 alone owns the
realized portfolio result. No failure may be rescued by changing the sample,
estimator, direction, carrier, risk, hold, or by adding an endpoint,
regression, volatility, event, seasonal, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
