# QM5_20260_xauxag-mom-vote — Strategy Spec

**EA ID:** QM5_20260

## 1. Strategy Logic

At the first processed `XAUUSD.DWX` D1 bar of a genuine new broker month, the
EA reconstructs exactly thirteen synchronized consecutive completed broker-
month-end closes for XAU and XAG. For each metal it calculates the arithmetic
average of the completed simple monthly returns over the one-, three-, and
twelve-month formation horizons. It compares XAU with XAG at each horizon and
requires every difference to lie outside `[-1e-10,1e-10]`.

XAU wins a vote when its average return is higher; XAG wins otherwise. When
XAU wins at least two votes the EA buys XAU and sells XAG. When XAG wins at
least two votes it sells XAU and buys XAG. A tied component, invalid history,
or invalid arithmetic consumes the month flat. The two legs split one fixed
package-risk budget equally after independent ATR normalization. Each leg has
a frozen `3.5 * ATR(20,D1)` hard stop and no take-profit.

The prior package closes at the next broker-month boundary before the new vote
is considered. A forty-calendar-day guard closes a stale package. The
evaluated month is persisted before history, signal, news, spread, quote,
sizing, stop, or order gates. Invalid and failed attempts cannot retry during
the same month, and any partial or malformed package is flattened.

## 2. Parameters

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_fast_months` | 1 | newest completed average-return horizon |
| `strategy_medium_months` | 3 | intermediate average-return horizon |
| `strategy_slow_months` | 12 | slow average-return horizon |
| `strategy_required_votes` | 2 | fixed majority threshold |
| `strategy_history_bars_d1` | 800 | bounded synchronized D1 reconstruction |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | stale lifecycle guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | order deviation |

Every strategy parameter and the framework identity, risk, news, Friday, and
stress inputs are fail-closed to the authorized Q02 baseline.

## 3. Symbol Universe

- Logical basket: `QM5_20260_XAU_XAG_MOMVOTE_D1`.
- Host/slot 0: `XAUUSD.DWX`; registered magic `202600000`.
- Companion/slot 1: `XAGUSD.DWX`; registered magic `202600001`.
- Exactly two opposite-direction positions are valid. The logical basket must
  not be decomposed into standalone XAU or XAG gate results.
- Runtime uses native MT5 data only; no external file, API, futures curve,
  portfolio state, or trained output is read.

## 4. Timeframe

- Host timeframe: D1.
- Decision cadence: first D1 bar whose broker-month key differs from the
  immediately preceding completed D1 bar.
- Formation data: thirteen synchronized completed month ends derived from
  bounded D1 history because synchronized MN1 data is not assumed.
- Entry frequency: at most one consumed attempt and one two-leg package per
  broker month.

## 5. Expected Behaviour

After warm-up, the strategy should produce approximately twelve completed
packages per year. Fewer than five completed packages per full post-warm-up
year is a retirement condition. The expected direction is long the metal that
wins at least two of the three locked cross-sectional ranks and short the
other, with equal fixed-risk halves at both 2-1 and 3-0 vote strengths.

The EA remains flat on a tied component, stale or nonconsecutive endpoint,
cross-symbol timestamp mismatch, nonpositive price, invalid return, invalid
ATR or stop geometry, excessive spread, owned exposure, or unlocked baseline
input. It closes the old package before considering a new state and repairs an
orphan, duplicate, same-direction, wrong-symbol, wrong-magic, invalid-type, or
missing-stop package immediately.

The non-duplicate boundary is the completed-calendar-month XAU/XAG
one/three/twelve cross-sectional average-return majority. Existing XAU/XAG
momentum baskets rank one horizon alone. Existing WTI and XNG votes use one
instrument's own cumulative return signs. Ratio, residual, return-spread,
volatility-rank, reversal, and calendar baskets use other state variables.

## 6. Source Citation

Fuertes, Ana-Maria, Joelle Miffre, and Georgios Rallis (2010), "Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term
Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`. The complete-read record is
`strategy-seeds/sources/FMR-MOMTS-2010/source.md`; the bounded vote extraction
is `strategy-seeds/sources/FMR-XAUXAG-MOMVOTE-2026/source.md`.

The paper supplies average-past-return cross-sectional commodity ranks and
explicit one-, three-, and twelve-month formation horizons with one-month
holds. The majority aggregation, two-metal CFD translation, synchronized
month-end reconstruction, fixed cash risk, ATR stops, spread caps, and
lifecycle controls are transparent QM hypotheses. No source performance,
neutrality, or diversification claim transfers.

## 7. Risk Model

The sole setfile is a non-live logical-basket backtest configuration with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The package
splits that one budget equally after independent ATR-stop normalization. Both
news axes and legacy news are off, Friday close is disabled, and stress
rejection probability is zero.

Risk is high: two-name concentration, residual common-metal and USD beta,
industrial-silver exposure, continuous-CFD roll and financing, gaps, legging,
lot granularity, false relative trends, hard-stop slippage, and source-
translation risk may dominate the signal. Q02 owns density and baseline
economics; Q09 alone may establish whether the realized PnL is sufficiently
distinct from the certified book. No live, demo, shadow, stress, or
optimization setfile, AutoTrading action, T_Live change, deployment manifest,
portfolio-gate edit, or correlation waiver is authorized.

## Kill Criteria

Retire on zero trades, fewer than five completed packages per full post-warm-
up year, unsynchronized or nonconsecutive endpoints, wrong simple-return
orientation or average, incorrect rank sign or vote, entry with a tied
component, repeated monthly attempt, non-opposite legs, aggregate-risk breach,
persistent orphan, missing hard stop, risk-mode mismatch, nondeterminism,
nonpositive governed economics, or any later unchanged gate failure. No post-
result horizon, vote, tie threshold, direction, weighting, stop, hold, spread,
retry, or carrier rescue is authorized.
