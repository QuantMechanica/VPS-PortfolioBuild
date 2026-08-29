# QM5_41192_xtixng-mdaily-hl-rv - Strategy Spec

**EA ID:** QM5_41192

**Slug:** `xtixng-mdaily-hl-rv`

**Source ID:** `VILLAR-HL-XTIXNG-MDAILY-RV-2026`

**Last revised:** 2026-08-29

## 1. Strategy Logic

At the first synchronized D1 bar of each genuine new broker month, within 180
minutes of the raw host-bar open, the EA copies 45 completed D1 bars for both
legs. It selects all exactly synchronized XTI/XNG observations in the
immediately completed month plus one adjacent older boundary observation and
requires 17 through 23 completed-month sessions.

For chronological log-ratio levels
`s[j]=ln(XTI_close[j])-ln(XNG_close[j])`, the EA forms every adjacent return
ending in the completed month, `r[j]=s[j+1]-s[j]`. Their sum must reproduce the
older-boundary-to-final displacement within `1e-10`.

It enumerates every inclusive pair `(i,j)` with `i<=j` as
`w=(r[i]+r[j])/2`, requiring exactly `n(n+1)/2` finite values and a dynamic
count of 153 through 276. Every self-pair must reproduce its source return.
After sorting, an odd count uses the single center and an even count uses the
arithmetic mean of the two centers.

- A positive pseudomedian opens SELL XTI / BUY XNG.
- A negative pseudomedian opens BUY XTI / SELL XNG.
- Exact zero or any invalid synchronized state consumes the month flat.

The raw endpoint displacement and signal magnitude are diagnostic only. Each
broker month permits one consumed attempt, including a flat or rejected state.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `history_bars` | 45 | completed D1 bars copied for each leg |
| `month_sessions_min` | 17 | minimum synchronized completed-month sessions |
| `month_sessions_max` | 23 | maximum synchronized completed-month sessions |
| `pair_value_cap` | 276 | maximum inclusive pair count |
| `numeric_tolerance` | 1e-10 | endpoint and self-pair identity tolerance |
| `entry_window_minutes` | 180 | maximum delay from the first host D1 bar open |
| `atr_period` | 20 | completed D1 ATR lookback per leg |
| `stop_atr_multiple` | 3.5 | frozen hard-stop distance per leg |
| `notional_mismatch_max` | 0.20 | maximum realized absolute-notional mismatch |
| `stale_exit_days` | 40 | defensive package age limit |
| `xti_max_spread_points` | 1500 | XTI entry spread ceiling |
| `xng_max_spread_points` | 3000 | XNG entry spread ceiling |

No undeclared optimization, adaptive state, or signal threshold is present.

## 3. Symbol Universe

- Host and slot 0: exact `XTIUSD.DWX`, D1, magic `411920000`.
- Companion and slot 1: exact `XNGUSD.DWX`, D1, magic `411920001`.
- Logical tester symbol: `QM5_41192_XTI_XNG_MDAILY_HL_RV_D1`.
- Both symbols are traded as one opposite-sided package; neither component
  preset is an independent strategy.
- Cross-series data is read only from exactly synchronized completed D1 bars.

The logical basket setfile is the only Q02 gate input. The XTI and XNG physical
setfiles are non-gating diagnostics for basket plumbing.

## 4. Timeframe

Signal and execution decisions use broker D1 bars. Package construction runs
once at the first synchronized bar of a new broker month and references only
the immediately completed month plus the adjacent older boundary observation.

Position integrity and stale-state repair run on every tick. A valid package
closes at the next broker-month transition or after 40 elapsed days. Framework
hard stops remain active continuously.

## 5. Expected Behaviour

The card estimates approximately 10 through 12 completed two-leg packages per
full post-warm-up year. Q02 owns measured trade density, profitability, costs,
and drawdown. The intended exposure is a relative oil-versus-gas package rather
than outright commodity beta, but no realized decorrelation claim is made at
build time; Q09 remains authoritative.

Exact-zero pseudomedians, missing synchronization, invalid arithmetic,
unacceptable spreads, invalid sizes, or failed atomic execution consume the
month without retry. A rejected or malformed second leg triggers immediate
flattening of the first leg.

## 6. Source Citation

Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. Energy Information Administration; David J.
Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and Oil
Prices*, *The Energy Journal* 33(2), DOI `10.5547/01956574.33.2.2`.

The deterministic pseudomedian arithmetic and basket lifecycle are governed
QM translation rules documented by source packet
`VILLAR-HL-XTIXNG-MDAILY-RV-2026`. The sources motivate an unstable but
economically related oil/gas carrier; they do not establish profitability for
this exact daily-pseudomedian strategy.

## 7. Risk Model

The package targets equal absolute USD notionals within a 20% realized
rounding tolerance. One aggregate `RISK_FIXED=1000` budget is split across the
two legs using frozen `3.5*ATR(20,D1)` broker stops. Backtest presets lock
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`.

XTI is submitted first and XNG second through the basket-order helper. If the
companion leg fails or the final package is malformed, the EA immediately
flattens owned exposure and does not retry that month. Stops are never widened
or removed. The framework kill switch and account controls remain
authoritative. News axes and Friday close are disabled because the approved
card defines neither as an entry or exit rule.

This is a Q01 build and Q02 research handoff only. It creates no live, demo,
shadow, optimization, stress, deploy, or portfolio authorization. It does not
touch AutoTrading, `T_Live`, a deploy manifest, or the portfolio gate. There
is no ML, banned indicator, averaging, grid, martingale, scale-in, pyramid,
break-even move, partial exit, or discretionary input.

## Revision history

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-29 | Initial OWNER-approved basket implementation |
| v2 | 2026-08-29 | Align Q01 SPEC headings and identity marker with the current validator |
