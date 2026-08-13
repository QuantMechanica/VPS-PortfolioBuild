# QM5_20302_wti-aliq-regime - Strategy Spec

**EA ID:** QM5_20302
**Slug:** `wti-aliq-regime`
**Source:** `YIYI-WTI-ALIQ-REGIME-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, consume one
attempt and load exactly 505 completed `XTIUSD.DWX` D1 rates. Calculate the
source Amihud-style illiquidity proxy - absolute log return divided by same-
bar tick volume and multiplied by one million - over two consecutive,
disjoint 252-return blocks. Buy when recent ALIQ is higher than preceding
ALIQ and sell when it is lower. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly replacement, and a
forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_returns_per_block` | `252` | `[252]` | Log-return/activity terms per block |
| `strategy_prior_block_offset` | `252` | `[252]` | Preceding block return offset |
| `strategy_history_bars_d1` | `505` | `[505]` | Exact completed D1 rate count |
| `strategy_aliq_scale` | `1000000.0` | `[1000000.0]` | Source scale factor |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest endpoint freshness |
| `strategy_aliq_tolerance` | `1e-12` | `[1e-12]` | Symmetric comparison tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

Designed only for registered `XTIUSD.DWX`, D1, magic slot 0. This is one
outright WTI carrier, not an XTI/XNG ALIQ rank basket and not a port to XNG,
XAU, XAG, or XBR.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Exactly 505 completed rates |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and all incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk WTI activity-regime losses with gap, roll, and persistent-state exposure |
| State | Long when recent ALIQ is higher; short when recent ALIQ is lower |

The WTI carrier and activity-price-impact state are diversification
hypotheses relative to the incumbent XAU/SP500/NDX/XNG book. Q09 alone owns
realized overlap.

## 6. Source Citation

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," *Journal of Futures Markets*
45(3), 176-207, DOI `10.1002/fut.22559`.

The source defines ALIQ as prior-year average absolute daily return divided
by dollar volume and uses monthly high-minus-low sorts. The EA's two-block
own-history comparison and tick-volume proxy are locked QM hypotheses, not a
source-tested WTI rule. The paired energy sibling's Q08 runs-test failure is
retained as material family evidence.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k=0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block b=0:       close pairs 0/1..251/252; volumes 0..251
preceding block b=252:  close pairs 252/253..503/504; volumes 252..503
```

Require positive finite closes, positive tick volumes, strictly older
timestamps by increasing series index, a fresh completed endpoint, finite log
returns and terms, and exactly 252 terms per block. Buy above the preceding
value by more than `1e-12`, sell below it by more than `1e-12`, and consume a
tie or invalid state flat.

## 9. Non-Duplicate Boundary

`QM5_13140` is a two-leg cross-sectional XTI/XNG ALIQ rank. This EA compares
two disjoint WTI history blocks, owns one magic, and has no shared risk or
orphan leg. `QM5_20301` averages thirteen lower-tail simple returns rather
than all 252 tick-volume-adjusted absolute log returns. WTI trend, calendar,
event, variance-ratio, robust-location, reversal, skewness, kurtosis, MAX,
ES, and VoV builds use other state objects. `QM5_12567` is a short-horizon
long-only XNG oscillator pullback.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong history count/orientation, wrong return type or volume
alignment, nonpositive volume acceptance, wrong scale, overlapping block
support, inverted direction, repeated attempt, missing stop, hold beyond
forty days, risk mismatch, or nondeterminism. No rescue parameter is
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

## 12. Q01 Status

PENDING. The EA source, canonical setfile, compiled artifact, and deterministic
reference evidence have not yet been created.

## 13. Q02 Handoff

NOT ENQUEUED. Q02 requires Q01 PASS plus a fresh seven-terminal capacity
check.

