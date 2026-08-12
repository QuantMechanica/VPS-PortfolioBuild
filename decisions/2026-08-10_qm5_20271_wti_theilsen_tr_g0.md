# QM5_20271 WTI Theil-Sen Robust Trend G0 Authorization

Date: 2026-08-10

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20271_wti-theilsen-tr`. The candidate observes thirteen consecutive
completed broker-month WTI closes, calculates all 78 forward pairwise slopes
of log price against monthly index, and holds one outright `XTIUSD.DWX`
position in the direction of the median pairwise slope until the next
broker-month boundary.

The candidate may proceed through source/card lint, deterministic registry and
magic allocation, resolver regeneration, strict compile, one `RISK_FIXED`
backtest setfile, Q01 validation, and one paced Q02 enqueue. This authorization
does not pre-approve efficacy, diversification, decorrelation, certification,
execution-contract promotion, or portfolio admission.

## Source Boundary

The approved source of record is the already complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi, and
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable retrieval
receipt records an end-to-end read of the 23-page published paper, the author-
hosted route, page count, byte count, and PDF SHA-256.

The source supports testing monthly own-price direction in WTI over the first
twelve monthly lags. It does not prescribe a Theil-Sen estimator, a standalone
continuous CFD port, fixed-dollar sizing, ATR stop, spread ceiling, restart
ledger, or lifecycle controls. Those are transparent QM hypotheses. No source
return, WTI-specific alpha, trade density, CFD equivalence, correlation result,
or portfolio conclusion transfers.

No newly retrieved public source is used. The bounded child extraction will be
recorded at `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md` only after
this durable approval exists.

## Locked Rule

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month-
end closes `C[0]..C[12]`, oldest to newest. The newest endpoint must belong to
the month immediately before the decision month. Define log prices
`y[i] = ln(C[i])` and all 78 forward pairwise monthly slopes:

```text
s[i,j] = (y[j] - y[i]) / (j - i), for 0 <= i < j <= 12
```

Require positive finite closes, consecutive completed months, strictly
increasing endpoint timestamps, finite log prices, and no endpoint from the
current broker month. Sort the 78 slopes ascending and lock the even-sample
median:

```text
theilsen_slope = (sorted_slopes[38] + sorted_slopes[39]) / 2
```

- `theilsen_slope > 0`: BUY WTI.
- `theilsen_slope < 0`: SELL WTI.
- exact zero or invalid state: consume the month flat.

Slope magnitude never scales risk. Consume and persist the decision month
before history, signal, spread, quote, ATR, sizing, news, or order gates. Close
the prior package at the next month boundary before considering replacement
risk. Use exactly one `RISK_FIXED=1000` stop-risk budget, one frozen
`3.5 * ATR(20,D1)` broker hard stop, a 1,500-point entry spread ceiling, no
take-profit, and a forty-calendar-day stale exit. Friday close and both news
axes are disabled for the full-month native-price package. The framework kill
switch remains binding.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,328 EA-registry rows and 444
cards for slug `wti-theilsen-tr`, strategy ID
`MOP-TSMOM-2012_XTI_THEILSEN12_S20`, and the declared mechanic. It found no
exact or fuzzy identity.

Manual review distinguishes the closest WTI systems:

- pure one-, two-, three-, six-, nine-, and twelve-month TSMOM uses a single
  cumulative endpoint return rather than the distribution of path slopes;
- `QM5_20258` votes across cumulative-return horizons and `QM5_13150` /
  `QM5_20244` count adjacent monthly return signs;
- `QM5_20261` minimizes squared residuals across all thirteen log prices and
  requires `R^2 >= 0.50`; one extreme endpoint can rotate that OLS slope;
- `QM5_20264` uses only the signs of all pairwise price differences and a
  fixed Mann-Kendall integer boundary; it discards slope magnitudes;
- `QM5_20269` and `QM5_20270` sort twelve disjoint adjacent monthly returns,
  not the 78 overlapping multi-horizon log-price slopes; and
- generic daily moving-average, linear-regression, channel, and Donchian EAs
  neither reconstruct this completed-month path nor use its exact robust
  median-of-all-pairwise-slopes estimator.

This rule uses every forward pair of thirteen equally spaced completed-month
log prices, divides each change by its exact month-index distance, sorts all 78
slopes, and averages only central indexes 38 and 39. Endpoint count, pair
enumeration, denominator, log orientation, median indexes, symmetric mapping,
consumed monthly attempt, and renewal clock are jointly load-bearing. Verdict:
`CLEAN_ROBUST_MONTHLY_THEILSEN_TREND`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20271`, subject to deterministic registry allocation;
- slug: `wti-theilsen-tr`;
- strategy ID: `MOP-TSMOM-2012_XTI_THEILSEN12_S20`;
- intended slot: `XTIUSD.DWX` / 0 / magic `202710000`;
- expected cadence: approximately twelve completed monthly packages per full
  post-warm-up year; Q02 owns realized density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on endpoint leakage or nonconsecutiveness, wrong pair count or
  denominator, wrong sort or median indexes, wrong direction, repeated monthly
  attempt, missing hard stop, risk-mode mismatch, hold beyond forty days, or
  nondeterminism;
- no post-result lookback, estimator, side, stop, hold, spread, retry, or
  carrier rescue is authorized.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced farm reaches its
binding backtest CPU ceiling before enqueue, record the stop and do not enqueue
or run a manual test.
