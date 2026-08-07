# QM5_20261_wti-lr-trend — Strategy Spec

**EA ID:** QM5_20261

## 1. Strategy Logic

At the first processed `XTIUSD.DWX` D1 bar of a genuine new broker month, the
EA reconstructs exactly thirteen consecutive completed broker-month-end closes
in chronological order. It fits the natural logarithm of those closes to the
fixed index `x=0..12`:

```text
x_bar = 6
y_i   = ln(C[i])
Sxx   = sum((x_i - x_bar)^2)
Sxy   = sum((x_i - x_bar) * (y_i - y_bar))
Syy   = sum((y_i - y_bar)^2)
beta  = Sxy / Sxx
R2    = Sxy^2 / (Sxx * Syy)
```

Finite, nondegenerate arithmetic, `abs(beta) > 1e-10`, and `R2 >= 0.50` are
required. A positive beta buys WTI and a negative beta sells it. A weak, flat,
malformed, stale, or unavailable state consumes the month flat. An actionable
state opens one position with a frozen `3.5 * ATR(20,D1)` hard stop, no
take-profit, no scale-in, and no intramonth reversal. The prior package closes
at the next broker-month boundary; a forty-calendar-day guard closes a stale
package.

The current month is persisted before history, signal, news, spread, quote,
sizing, and order gates. Owned positions and entry-deal history provide restart
recovery, while tester initialization clears stale terminal-global state. A
flat, rejected, failed, or stopped attempt cannot retry during the same month.

## 2. Parameters

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_regression_points` | 13 | completed month-end log-price observations |
| `strategy_min_r_squared` | 0.50 | fixed path-quality threshold |
| `strategy_slope_epsilon` | 1e-10 | deterministic flat-slope boundary |
| `strategy_history_bars_d1` | 800 | bounded D1 endpoint-recovery buffer |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale lifecycle guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

Every strategy parameter and the framework identity, risk, news, Friday, and
stress inputs are fail-closed to the authorized Q02 baseline.

## 3. Symbol Universe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Slot: 0.
- Registered magic: `202610000`.
- This is a direct WTI energy carrier; no basket leg, futures chain, inventory
  feed, or external data is read at runtime.

## 4. Timeframe

- Host timeframe: D1.
- Decision cadence: the first D1 bar whose broker-month key differs from the
  immediately preceding completed D1 bar.
- Formation data: thirteen completed month endpoints derived from bounded D1
  history because custom-symbol MN1 data is not assumed.
- Entry frequency: at most one consumed attempt and one position per month.

## 5. Expected Behaviour

After warm-up, the strategy should produce roughly six to ten completed
monthly positions per year. Fewer than five completed positions per full
post-warm-up year is a retirement condition. Positive qualified slopes map to
long and negative qualified slopes map to short; R-squared changes eligibility,
not cash risk.

The EA remains flat on stale or nonconsecutive endpoints, nonpositive prices,
invalid logarithms, degenerate sums, a flat slope, `R2 < 0.50`, invalid ATR or
stop geometry, excess spread, owned exposure, or any unlocked baseline input.
It closes the old package before considering the next month and repairs
duplicate, wrong-symbol, invalid-type, missing-stop, or unexpected-TP exposure
bearing its magic.

The non-duplicate boundary is the oldest-to-newest log-price OLS slope plus a
fixed regression-fit gate. Existing WTI EAs use endpoint returns, return-sign
votes, monthly-sign counts, moving averages, channels, variance ratios,
calendar states, events, or relative baskets. None requires this exact path
consistency statistic. Direct WTI expands carrier exposure beyond the certified
XAU, SP500, NDX, and XNG book; only Q09 may establish realized decorrelation.

## 6. Source Citation

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete-read record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded mechanization is
`strategy-seeds/sources/MOP-WTI-LRTREND-2026/source.md`.

The paper supplies WTI membership and the monthly own-price continuation
family. The OLS path, R-squared threshold, CFD endpoint reconstruction, fixed
cash risk, ATR stop, spread cap, and lifecycle controls are transparent QM
hypotheses and are not attributed to the authors. No source performance or
diversification claim transfers.

## 7. Risk Model

The sole setfile is a non-live `XTIUSD.DWX` D1 backtest configuration with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The V5 risk
layer sizes from the frozen ATR hard stop. Both news axes and legacy news are
off, Friday close is disabled, and stress rejection probability is zero.

Risk is high: continuous-CFD roll and financing, crude-oil gaps, false smooth
trends, regression sensitivity to extreme endpoints, hard-stop slippage, and
single-energy concentration may dominate the signal. Q02 owns density and
baseline economics; Q09 alone may establish portfolio correlation. No live,
demo, shadow, stress, or optimization setfile, AutoTrading action, `T_Live`
change, deployment manifest, portfolio-gate edit, or correlation waiver is
authorized.

## Kill Criteria

Retire on zero trades, fewer than five completed positions per full post-warm-up
year, wrong or nonconsecutive endpoints, current-month leakage, wrong regression
orientation, incorrect R-squared, entry below the fit threshold, wrong-side
entry, repeated monthly attempt, missing hard stop, risk-mode mismatch,
nondeterminism, nonpositive governed economics, or any later unchanged gate
failure. No post-result lookback, transform, threshold, direction, stop, hold,
spread, retry, or carrier rescue is authorized.
