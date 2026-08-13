# QM5_20299_xng-vov-regime — Strategy Spec

**EA ID:** QM5_20299  
**Slug:** `xng-vov-regime`  
**Source:** `HOLLSTEIN-XNG-VOV-REGIME-2026`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, consume one
attempt and load exactly 543 completed `XNGUSD.DWX` D1 closes. Calculate two
price-native realized volatility-of-volatility estimates. Each estimate has
252 overlapping realized-volatility observations built from 20 log returns;
the recent and preceding blocks use disjoint return support. Buy when recent
VoV is lower than preceding VoV and sell when it is higher. Every entry has a
frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly replacement, and
a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rv_window_d1` | `20` | `[20]` | Log returns per RV observation |
| `strategy_vov_samples` | `252` | `[252]` | RV observations per VoV block |
| `strategy_prior_block_offset` | `271` | `[271]` | Preceding block return offset |
| `strategy_history_bars_d1` | `543` | `[543]` | Exact completed D1 close count |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest endpoint freshness |
| `strategy_vov_tolerance` | `1e-12` | `[1e-12]` | Symmetric comparison tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `2500` | `[2500]` | XNG entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

Designed only for registered `XNGUSD.DWX`, D1, magic slot 0. This is one
outright XNG carrier, not an XTI/XNG or XAU/XAG rank basket and not a port to
WTI, XAU, XAG, or XBR.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Exactly 543 completed closes |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and all incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk XNG uncertainty-regime losses with gap, roll, and persistent-state exposure |
| State | Long when recent VoV is lower; short when recent VoV is higher |

The uncertainty-of-risk state is a diversification hypothesis relative to the
incumbent XNG RSI sleeve. Q09 alone owns realized portfolio overlap.

## 6. Source Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`.

The source defines option-implied VoV, reports a negative high-minus-low
commodity relation, renews monthly, and includes natural gas. The EA substitutes a
nested realized-volatility proxy and an own-history comparison. Those are
locked QM hypotheses, not source-tested natural-gas rules. See the bounded packet and
approved card.

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
r[b,s,k] = ln(close[b+s+k] / close[b+s+k+1]), k=0..19
rv[b,s]  = sample_std(r[b,s,0..19], denominator 19) * sqrt(252), s=0..251
mean_rv[b] = average(rv[b,0..251])
vov[b] = sqrt(sum((rv[b,s] - mean_rv[b])^2) / 252) / mean_rv[b]

recent block b=0:      return indices 0..270
preceding block b=271: return indices 271..541
```

Require positive finite closes, strictly older timestamps by series index, a
fresh completed endpoint, positive inner variances, positive RV means and VoV
variances, and finite arithmetic. Buy below the preceding value by more than
`1e-12`, sell above it by more than `1e-12`, and consume a tie or invalid state
flat.

## 9. Non-Duplicate Boundary

`QM5_13146` and `QM5_20236` are two-leg cross-sectional realized-VoV ranks.
This EA compares two disjoint XNG history blocks, owns one magic, and has no
shared risk or orphan leg. `QM5_20298` preserves the estimator and lifecycle
on WTI but has different registered history, contract economics, spread,
magic, and Q02 verdict. `QM5_13046` uses raw realized-volatility level;
`QM5_20297` uses Pearson kurtosis; `QM5_20296` uses skewness; and `QM5_12567`
is a short-horizon long-only RSI pullback. Trend, calendar, event, variance-
ratio, breakout, and ordinary reversal builds use other state objects.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong history count/orientation, wrong block support or denominator,
overlapping return blocks, inverted direction, repeated attempt, missing stop,
hold beyond forty days, risk mismatch, or nondeterminism. No rescue parameter
is authorized.

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

## 12. Q01 Status

PENDING BUILD.

## 13. Q02 Handoff

NOT ENQUEUED.
