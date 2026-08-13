# QM5_20296_xng-skew-prem — Strategy Spec

**EA ID:** QM5_20296
**Slug:** `xng-skew-prem`
**Source:** `FERNANDEZ-XNG-SKEW-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct the
twelve complete preceding broker months from completed natural-gas D1 closes.
Compute Pearson's population skewness from boundary-contained daily log
returns. Buy when skewness is below zero, sell when it is above zero, and
consume a numerical tie or invalid state flat. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly replacement, and a
forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | `12` | `[12]` | Exact complete-month formation span |
| `strategy_history_bars_d1` | `500` | `[500]` | Bounded completed-D1 history request |
| `strategy_min_return_observations` | `180` | `[180]` | Inclusive minimum contained returns |
| `strategy_max_return_observations` | `280` | `[280]` | Inclusive maximum contained returns |
| `strategy_variance_floor` | `1e-12` | `[1e-12]` | Positive population-variance floor |
| `strategy_skew_tolerance` | `1e-12` | `[1e-12]` | Symmetric zero-pivot tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `2500` | `[2500]` | XNG entry spread ceiling |

All values are locked for baseline. No optimization or alternate estimator is
authorized.

## 3. Symbol Universe

Designed only for registered `XNGUSD.DWX`, D1, magic slot 0. It is not a port
to XTI, XAU, XAG, XBR, or an unregistered natural-gas proxy. The carrier is
outright natural gas, not a two-leg energy rank.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal window | Twelve complete broker months |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and boundary-crossing returns do not enter the signal.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk XNG third-moment losses with jump and regime-persistence exposure |
| Regime preference | Long negative skew; short positive skew |
| Win rate target (qualitative) | Unknown; Q02 falsification only |

The natural-gas carrier and third-moment state are diversification hypotheses
only. Q09 owns any realized portfolio-overlap conclusion.

## 6. Source Citation

Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre,
Joelle (2018), "The Skewness of Commodity Futures Returns," *Journal of
Banking & Finance* 86, 143-158, DOI
`10.1016/j.jbankfin.2017.06.015`.

**Source ID:** `FERNANDEZ-XNG-SKEW-2026`
**Source type:** peer-reviewed trading paper with governed complete-read record
**Pointer:** `strategy-seeds/sources/FERNANDEZ-XNG-SKEW-2026/source.md`
**R1–R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/approved/QM5_20296_xng-skew-prem_card.md`.

The source defines prior-twelve-month Pearson return skewness, documents a
negative cross-sectional relation, rebalances monthly, and includes natural
gas. The absolute zero-pivot XNG rule is a locked QM hypothesis, not a
source-tested natural-gas timing rule.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

```text
r[d] = ln(close[d] / close[d-1])
mu   = sum(r[d]) / n
m2   = sum((r[d] - mu)^2) / n
m3   = sum((r[d] - mu)^3) / n
skew = m3 / (m2^(3/2))
```

Require exactly twelve covered month keys, 180 through 280 returns, positive
finite closes, strictly increasing timestamps, finite arithmetic, and
`m2 > 1e-12`. Buy below `-1e-12`, sell above `+1e-12`, and consume a tie or
invalid state flat. Never use simple returns, bias correction, rank, a fitted
pivot, or magnitude-scaled risk.

## 9. Non-Duplicate Boundary

`QM5_13118` is a two-leg XTI/XNG skewness rank and `QM5_20233` is a two-leg
XAU/XAG rank. `QM5_20290` is the separately evaluated WTI carrier. This EA has
one XNG state, one magic, one position, no rank, and no orphan state.
`QM5_12567` is a short-horizon long-only cumulative-RSI pullback. Other XNG
trend, reversal, calendar, storage-event, breakout, carry, and variance-ratio
systems use different information objects.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong formation bounds, return inclusion, estimator denominator,
moment convention, pivot, direction, repeated attempt, missing stop, hold
beyond forty days, risk mismatch, or nondeterminism. No rescue parameter is
authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-13 | Initial scaffold from approved card | Build pending |
| v2 | 2026-08-13 | Implemented locked statistic and monthly lifecycle | Strict compile and reference checks pass |
| v3 | 2026-08-13 | Completed target Q01 validation | Build check and P1 PASS |

## 12. Q01 Status

PASS. The registered one-slot EA implements the exact twelve-complete-month
Pearson-skewness contract, restart-safe monthly attempt state, one-position
lifecycle, frozen hard stop, and fixed-risk contract. Strict compile passed
with zero errors and zero warnings; the target build check passed with zero
failures and zero warnings; the independent statistic, direction, chronology,
coverage, count, and freshness reference vectors passed; and P1 artifact
validation found the compiled `.ex5`.

## 13. Q02 Handoff

READY FOR CAPACITY CHECK. No queue mutation is permitted unless a path-
anchored T1-T10 factory sample is below the binding CPU ceiling.
