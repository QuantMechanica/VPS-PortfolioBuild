# QM5_20289_wti-rsj-rev — Strategy Spec

**EA ID:** QM5_20289  
**Slug:** `wti-rsj-rev`  
**Source:** `KISS-WTI-RSJ-REV-2026`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-12

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct the
immediately preceding complete WTI broker month. Compute close-to-close log
returns only when both adjacent timestamps lie inside that month. Sum squared
positive returns into upside semivariance and squared negative returns into
downside semivariance, then normalize their difference by total realized
variance. Buy when normalized RSJ is negative, sell when it is positive, and
consume exact zero or invalid state flat. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a forty-day
stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | `1` | `[1]` | Immediately prior complete broker month |
| `strategy_min_return_observations` | `15` | `[15]` | Minimum contained D1 log returns |
| `strategy_max_return_observations` | `25` | `[25]` | Maximum contained D1 log returns |
| `strategy_rsj_tolerance` | `1e-12` | `[1e-12]` | RSJ bound tolerance |
| `strategy_history_bars_d1` | `80` | `[80]` | Bounded D1 month reconstruction |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked for baseline. No optimization or alternate estimator is
authorized.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI route and only authorized carrier.

**Explicitly not for:**

- `XNGUSD.DWX` — already represented in the book and in a separate RSJ rank
  basket.
- `XAUUSD.DWX` and `XAGUSD.DWX` — governed by a separate two-leg RSJ rank EA.
- `XBRUSD.DWX` — distinct crude benchmark and not authorized by this card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal window | Immediately prior complete broker month of contained D1 returns |
| Stop estimator | Completed `ATR(20,D1)` |
| Bar gating | One new-bar consume, then genuine broker-month transition check |

The current broker month contributes no signal return.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI reversal losses with gap and volatility-clustering exposure |
| Regime preference | Mean reversion after asymmetric realized-volatility dominance |

The WTI carrier and RSJ state are diversification hypotheses only. Q09 owns
any realized portfolio-overlap conclusion.

## 6. Source Citation

Kiss, Tamas, and Igor Ferreira Batista Martins (2025), "Good Volatility, Bad
Volatility and the Cross Section of Commodity Returns," *Finance Research
Letters* 86 Part D, article 108656, DOI
`10.1016/j.frl.2025.108656`.

The source defines normalized RSJ, documents a negative cross-sectional
commodity premium, and includes WTI. The absolute time-series zero pivot is a
locked QM hypothesis; the paper does not test it. See
`strategy-seeds/sources/KISS-WTI-RSJ-REV-2026/source.md` and the canonical card.

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
r[d]     = ln(close[d] / close[d-1])
RV_plus  = sum(r[d]^2 where r[d] > 0)
RV_minus = sum(r[d]^2 where r[d] < 0)
total    = RV_plus + RV_minus
RSJ      = (RV_plus - RV_minus) / total
```

Both timestamps for each return must belong to the immediately prior broker
month. Require 15-25 returns, positive total variance, finite arithmetic, and
RSJ in `[-1,1]` within `1e-12`. Buy below zero, sell above zero, and consume
exact zero or invalid state flat. Never scale risk from RSJ magnitude.

## 9. Non-Duplicate Boundary

`QM5_13129` and `QM5_20234` are two-leg cross-sectional RSJ rank baskets. This
EA uses one outright WTI state, no second leg or rank, and an absolute zero-
pivot time-series reversal map. `QM5_12567` is a short-horizon long-only RSI
pullback. Ordinary WTI trend, robust-location, return-reversal, calendar,
event, breakout, and variance-ratio systems use different information objects
and clocks. The contained prior-month returns, normalized semivariance
difference, zero pivot, reversed direction, outright carrier, and monthly
lifecycle are load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on nonpositive
governed economics, or on later portfolio-correlation rejection. Fail on the
wrong month, boundary-crossing/current-month returns, wrong orientation,
count outside 15-25, nonpositive total variance, missing normalization,
alternate pivot, trend-following direction, repeat attempt, missing stop,
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
| v1 | 2026-08-12 | Initial scaffold from approved card | Build pending |
| v2 | 2026-08-12 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent RSJ vectors PASS |

## 12. Q01 Status

PASS. Strict compile completed with zero errors and zero warnings; the target
build check completed with zero failures and zero warnings; P1 artifact
validation found the EA directory and current `.ex5`; and independent vectors
proved reversal direction, exact-zero handling, positive scale invariance,
boundary-return exclusion, 15-25 observation bounds, zero-variance rejection,
and the genuine broker-month transition gate. Evidence:

- `D:/QM/reports/compile/20260812_074558/summary.csv`
- `D:/QM/reports/framework/21/build_check_20260812_074442.json`
- `D:/QM/reports/pipeline/QM5_20289/P1/P1_QM5_20289_result.json`
- `framework/EAs/QM5_20289_wti-rsj-rev/docs/test_rsj_reference.py`

## 13. Q02 Handoff

NOT ENQUEUED. Capacity must be checked against the path-anchored factory CPU
ceiling after Q01 passes. No manual dispatch or backtest is authorized.
