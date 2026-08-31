# QM5_41252_wti-css-volshift-tr - Strategy Spec

**EA ID:** QM5_41252

**Slug:** `wti-css-volshift-tr`

**Strategy ID:** `AI-CODEX-WTI-CSSVOLSHIFT-20260831_S01`

**Source:** `AI-CODEX-WTI-CSSVOLSHIFT-20260831`

**Author:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

At the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
reconstruct the immediately prior 253 completed D1 closes and derive 252
chronological adjacent log returns. Mean-center the returns, square them, and
scan the source-defined centered cumulative sum of squares over interior
splits `k=21..231`.

Select the greatest `sqrt(252/2)*abs(C_k/C_T-k/252)` score, retaining the
latest split on an exact tie. A score at or above `0.63` activates the package.
The raw return sum after the selected split determines long or short; a zero
sum consumes the month flat. The boundary is an activity rule, not a
significance claim, and the score never scales risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_return_count` | 252 | completed adjacent D1 log returns |
| `strategy_split_min` | 21 | first eligible CSS split |
| `strategy_split_max` | 231 | last eligible CSS split |
| `strategy_score_threshold` | `0.63` | inclusive CSS activity boundary |
| `strategy_total_square_epsilon` | `1e-16` | degenerate-path guard |
| `strategy_direction_epsilon` | `1e-12` | post-shift side guard |
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
- Symbol slot: 0; magic: `412520000`.
- Native MT5 price, calendar, ATR, quote, position, deal, and persistent state
  are the only runtime inputs.
- There is no companion, conversion, ratio, hedge, external, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The decision clock fires
only on the first eligible D1 bar of a new normalized broker month. Current-
bar price is excluded.

```text
T = 252
r[i] = log(P[i+1] / P[i]), i=0..251
mean_r = sum(r) / T
q[i] = (r[i] - mean_r)^2
C_T = sum(q)

for k=21..231:
    C_k = sum(q[0:k])
    D_k = C_k / C_T - k / T
    M_k = sqrt(T/2) * abs(D_k)

select largest M_k; latest exact tie wins
require M_k >= 0.63
post_return = sum(r[selected_k:252])

BUY  iff post_return >  1e-12
SELL iff post_return < -1e-12
FLAT otherwise
```

Every close, ratio, logarithm, return, mean, centered return, square,
cumulative sum, normalized value, score, and post-shift return must be finite.
`C_T <= 1e-16` is a valid flat decision. The history loader requires exactly
253 positive closes in strict chronological order and a newest close in the
immediately prior broker month no more than ten calendar days old.

## 5. Expected Behaviour

The card expects approximately seven to ten completed WTI positions per full
post-warm-up year. This is a falsifiable design expectation, not a performance
claim. Q02 must prove at least five in every full scored year or the candidate
retires.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
A qualified month can open at most one market position with one frozen
completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Crossed or
malformed quotes and spreads above 1,500 points are rejected; a valid modeled
zero spread is allowed. Both news axes and legacy news are OFF. Friday close
is disabled so the approved monthly hold is not truncated.

### Exit and deterministic failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
missing-stop, or otherwise invalid owned exposure is repaired before entry-
only gates. A restart that cannot reconstruct a fresh valid current-month
expected side fails closed. There is no target, trail, break-even, partial
close, same-month retry, scale-in, grid, martingale, pyramid, or opposite-
signal exit.

The month attempt is persisted before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order gates. A failed gate never causes a late
retry.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/source.md`. It records
complete-read peer-reviewed centered-CSS variance-change evidence from Inclan
and Tiao (1994) and complete-read peer-reviewed WTI time-series-momentum
evidence from Moskowitz, Ooi, and Pedersen (2012). The exact conjunction,
threshold, continuous CFD, fixed risk, and lifecycle are explicitly disclosed
as untested QM synthesis.

Preallocation receipt:
`artifacts/qm5_wti_css_volshift_tr_preallocation_dedup_20260831.json`.

### Non-duplicate boundary

Unlike monthly mean-CUSUM `QM5_41245`, this build locates variance change by
accumulating squared centered daily returns. Unlike permutation-MAD
`QM5_41250`, it retains return order and searches an interior split. Unlike
VoV-rank `QM5_20298`, it uses no volatility rank. Certified `QM5_12567` is an
XNG long-only oscillator pullback. No realized decorrelation claim is made;
Q09 alone owns that test.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |

The Q02 preset seals the fixed-risk row above. This build authorizes no live
preset or deployment action.

Retire on zero positions, fewer than five in any full scored year, nonpositive
governed economics, or deterministic-fixture failure. WTI gaps, continuous-
CFD roll/basis, financing, outlier sensitivity, change-point masking, and
broker-month offsets remain material risks.

Fail on current-month leakage, wrong return order or mean center, wrong square
path, normalization, split, tie, inclusive boundary, post-shift direction,
fixed-risk mode, hard stop, lifecycle, or determinism.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, risk, news, Friday, stress,
  strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualified direction, quote/spread/ATR/stop gates, and
  one fixed-risk WTI order.
- `trade_management`: malformed/wrong-side repair, next-month exit, and stale
  exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412520000` |
