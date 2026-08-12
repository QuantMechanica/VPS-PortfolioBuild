# QM5_20294 XAU/XAG Low-MAX Rank G0 Authorization

Date: 2026-08-12

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20294_xauxag-max-rk`. At each genuine broker-month transition, the
candidate computes the peer-reviewed MAX characteristic for XAU and XAG as
the arithmetic mean of each metal's five largest simple D1 returns among the
latest 252 completed observations. It buys the lower-MAX metal and shorts the
higher-MAX metal for one broker month as one logical two-leg package.

The candidate may proceed through bounded source/card extraction, schema and
G0 lint, deterministic registry and two-slot magic allocation, resolver
regeneration, strict compile, one logical-basket `RISK_FIXED` backtest
setfile, Q01 validation, and one paced Q02 enqueue. This authorization does
not pre-approve efficacy, market neutrality, decorrelation, certification,
execution-contract promotion, or portfolio admission.

## Source Boundary

The approved source of record is the complete governed packet
`strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md`, covering Hollstein,
Prokopczuk, and Tharann (2021), "Anomalies in Commodity Futures Markets,"
*Quarterly Journal of Finance* 11(4), article 2150017, DOI
`10.1142/S2010139221500178`. The packet records an end-to-end read of the
57-page accepted article and online appendix and is content-bound by SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.

The source defines MAX as the average of the five largest daily commodity-
futures excess returns over the prior twelve months, ranks the commodity
cross-section monthly, and reports a negative high-minus-low relation only
in its December 2000-December 2015 post-financialization subsample. Its full-
sample hedge return and directly relevant two-portfolio result are null. The
paper uses a broad collateralized futures universe, not a two-metal CFD pair.

The XAU/XAG carrier, 252 completed simple CFD returns, equal stop-risk halves,
ATR hard stops, spread ceilings, restart ledger, and lifecycle controls are
transparent QM translations. No source return, alpha, significance, cost,
trade density, CFD equivalence, neutrality, correlation, or portfolio result
transfers. The 2017+ Q02 window is an out-of-sample falsification of weak and
subsample-dependent evidence.

## Locked Rule

On the first processed `XAUUSD.DWX` D1 bar after a genuine broker-month
transition, load exactly 253 completed positive D1 closes for each of
`XAUUSD.DWX` and `XAGUSD.DWX`, ordered oldest to newest, and form exactly 252
chronological simple returns:

```text
r[d] = close[d] / close[d-1] - 1
MAX_i = arithmetic_mean(five_largest(r_i[1..252]))

BUY XAU / SELL XAG when MAX_XAU < MAX_XAG
SELL XAU / BUY XAG when MAX_XAU > MAX_XAG
FLAT when abs(MAX_XAU - MAX_XAG) <= 1e-12 or state is invalid
```

Require strictly increasing timestamps, positive finite closes, finite
returns and MAX values, a newest endpoint before the decision bar and no more
than ten calendar days stale, and exactly five order statistics per metal.
There is no ratio, z-score, OLS, quantile regression, kurtosis, skewness,
semivariance, expected shortfall, volatility-of-volatility, momentum,
calendar direction, threshold rescue, score sizing, or prior-result input.

Consume and persist the decision month before history, signal, spread, quote,
ATR, sizing, news, or order gates. Close the prior package at the next genuine
month transition before considering replacement. Split one
`RISK_FIXED=1000` package into equal stop-risk halves and attach a frozen
`3.5 * ATR(20,D1)` hard stop to each leg. XAU and XAG entry spreads may not
exceed 1,500 and 3,000 points respectively. No take-profit is authorized.
Close stale after forty calendar days. Friday close and both news axes are
disabled for the source-aligned full-month native-price package.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,359 EA-registry rows and 470
cards for slug `xauxag-max-rk`, strategy ID
`HOLLSTEIN-MAX-2021_XAU_XAG_S04`, and the declared mechanic. It found no exact
registry or card identity and returned ten expected fuzzy source/carrier
neighbors for manual review.

Manual mechanic review resolves those neighbors:

- `QM5_13130_xti-xng-lowmax` uses the same source statistic and direction on
  an XTI/XNG energy carrier; this authorized XAU/XAG carrier imports no
  sibling pipeline result;
- `QM5_20291_xauxag-kurt-rk` uses all 252 returns in a centered fourth moment
  divided by squared sample variance and buys high kurtosis; this rule uses
  only the five largest returns and buys low MAX;
- XAU/XAG skewness, signed-semivariance, expected-shortfall, volatility-of-
  volatility, variance-ratio, return-shock, ratio, OLS, quantile, momentum,
  calendar, and RSI systems observe different information objects; and
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback rather than a paired monthly order-statistic rank.

The exact 252 simple returns, five-largest arithmetic mean, low-minus-high
direction, XAU/XAG carrier, monthly consumed attempt, equal aggregate risk,
and monthly renewal are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20294`, subject to deterministic registry allocation;
- slug: `xauxag-max-rk`;
- strategy ID: `HOLLSTEIN-MAX-2021_XAU_XAG_S04`;
- intended XAU slot/magic: `XAUUSD.DWX` / 0 / `202940000`;
- intended XAG slot/magic: `XAGUSD.DWX` / 1 / `202940001`;
- expected cadence: approximately eleven to twelve completed packages per
  full post-warm-up year; Q02 owns observed density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on a wrong observation count or orientation, any statistic other than
  the top-five arithmetic mean, inverted rank direction, repeated monthly
  attempt, orphan persistence, aggregate risk breach, missing hard stop,
  hold beyond forty days, risk-mode mismatch, or nondeterminism; and
- no post-result formula, direction, carrier, stop, hold, spread, retry, or
  threshold rescue is authorized.

Opposite metal legs target lower outright metal direction than a standalone
XAU sleeve but do not prove dollar, beta, volatility, factor, market, or
portfolio neutrality. The unchanged downstream correlation gate alone may
measure realized overlap.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress,
and optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one logical-basket D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced farm reaches its
binding seven-terminal backtest CPU ceiling before enqueue, record the stop
and do not enqueue or run a manual test.
