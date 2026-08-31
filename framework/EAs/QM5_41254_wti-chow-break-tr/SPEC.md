# QM5_41254_wti-chow-break-tr - Strategy Spec

**EA ID:** QM5_41254

**Slug:** `wti-chow-break-tr`

**Strategy ID:** `AI-CODEX-WTI-CHOWBREAK-20260831_S01`

**Source:** `AI-CODEX-WTI-CHOWBREAK-20260831`

**Author:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load the immediately prior 252 completed D1 closes in chronological order and
take their logarithms. Fit one pooled intercept-and-slope OLS line, then scan
two separate OLS lines over every interior split `k=63..189`.

For each split, compare the pooled residual sum of squares with the sum of the
two segment RSS values using
`F_k=((RSS0-RSSk)/2)/(RSSk/248)`. A negative improvement outside the locked
relative round-off tolerance invalidates the monthly signal; a smaller
negative value is clamped to zero. Select the greatest finite score and retain
the latest split on an exact tie. An inclusive score of `3.0` activates the
package. The selected recent segment slope determines long or short. This is
an activity boundary, not a statistical-significance claim, and the score
never scales risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_observation_count` | 252 | completed D1 log-price observations |
| `strategy_split_min` | 63 | first eligible two-regression split |
| `strategy_split_max` | 189 | last eligible split; leaves at least 63 recent points |
| `strategy_score_threshold` | `3.0` | inclusive RSS-improvement activity boundary |
| `strategy_rss_epsilon` | `1e-16` | pooled and split RSS degeneracy guard |
| `strategy_improvement_tolerance` | `1e-12` | relative negative-improvement tolerance |
| `strategy_slope_epsilon` | `1e-12` | selected recent-slope side guard |
| `strategy_history_bars` | 500 | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest completed-close age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412540000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The decision fires only
on the first eligible D1 bar after a genuine broker-month transition. The
current bar is excluded.

```text
T = 252
x[i] = i
y[i] = log(P[i]), i=0..251

pooled OLS: y = a0 + b0*x
RSS0 = sum((y - a0 - b0*x)^2)

for k=63..189:
    left OLS on i=0..k-1
    recent OLS on i=k..251
    RSSk = RSS_left + RSS_recent
    improvement = RSS0 - RSSk
    reject if improvement < -1e-12*max(1, RSS0)
    clamp a smaller negative improvement to zero
    F_k = (improvement/2)/(RSSk/248)

select greatest F_k; latest exact tie wins
require F_k >= 3.0

BUY  iff selected recent slope >  1e-12
SELL iff selected recent slope < -1e-12
FLAT otherwise
```

Every close, logarithm, OLS sum, coefficient, residual, RSS, improvement,
score, and slope must be finite. `RSS0` and every `RSSk` must exceed `1e-16`.
The loader requires exactly 252 positive completed closes in strict
chronological order, and the newest close must belong to the immediately
prior broker month and satisfy the ten-day age ceiling.

## 5. Expected Behaviour

The card expects approximately eight to twelve completed WTI positions per
full post-warm-up year. Q02 must establish at least five in every full scored
year or the candidate retires.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
A qualified month may open at most one market position with one frozen
completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Crossed or
malformed quotes and positive spreads above 1,500 points are rejected; a
valid modeled zero spread is allowed. Both news axes and legacy news are OFF.
Friday close is disabled.

### Exit and deterministic failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
missing-stop, or otherwise invalid owned exposure is repaired before entry-
only gates. A restart that cannot reconstruct the current-month expected side
fails closed. There is no target, trail, break-even, partial close, scale-in,
grid, martingale, pyramid, opposite-signal exit, or same-month retry.

The month attempt is persisted before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order gates. Any failure consumes the month.

## 6. Source Citation

The governed exact-source packet is
`strategy-seeds/sources/AI-CODEX-WTI-CHOWBREAK-20260831/source.md`. It treats
Chow (1960) as bibliographic naming context only because content retrieval was
policy-deferred. Complete-read Moskowitz, Ooi, and Pedersen (2012) evidence
supports only WTI membership, monthly cadence, and own-return continuation.
The scan, threshold, continuous-CFD translation, fixed risk, and lifecycle are
disclosed pre-result QM synthesis with no significance claim.

Preallocation dedup receipt:
`artifacts/qm5_wti_chow_break_tr_preallocation_dedup_20260831.json`.

### Non-duplicate boundary

Unlike `QM5_20261`, this build does not use one whole-window slope/R-squared.
Unlike `QM5_41245`, it does not use monthly return mean CUSUM. Unlike
`QM5_41249`, it does not compare fixed return blocks. Unlike `QM5_41252`, it
does not scan squared-return variance. Certified `QM5_12567` is an XNG
long-only oscillator pullback; this is symmetric monthly direct WTI. Q09 alone
owns the eventual portfolio-correlation verdict.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |

This build authorizes no live preset or deployment action. Retire on zero
positions, fewer than five in any full scored year, nonpositive governed
economics, or deterministic-fixture failure. WTI gaps, continuous-CFD roll
and basis, financing, path outliers, false break selection, dependence,
heteroskedasticity, and broker-month offsets remain material risks.

Fail on current-bar leakage, wrong close/log orientation, wrong OLS or RSS,
wrong split or tie rule, wrong improvement tolerance, wrong inclusive
boundary, wrong recent-slope side, wrong fixed-risk mode, missing hard stop,
same-month retry, lifecycle mismatch, or nondeterminism.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualified recent-slope direction, quote/spread/ATR/
  stop gates, and one fixed-risk WTI order.
- `trade_management`: malformed or wrong-side repair, next-month exit, and
  forty-day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412540000` |
