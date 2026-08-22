# QM5_1405_as-rpv-bestvalue - Strategy Spec

**EA ID:** QM5_1405
**Slug:** `as-rpv-bestvalue`
**Source:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1405_as-rpv-bestvalue.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA implements the Allocate Smartly Risk Premium Value (Best Value variant) tactical asset allocation strategy on the Daily (D1) timeframe with monthly rebalancing:
- Evaluates three macroeconomic risk premiums on a monthly schedule:
  1. US Equity Risk Premium: S&P 500 earnings yield spread over 10-year Treasury yield (with 4-month reporting lag).
  2. US Corporate Credit Spread Premium: Investment-grade corporate bond yield spread over long-term Treasury yield.
  3. US Treasury Term Premium: Long-term Treasury yield spread over short-term cash yield.
- Normalizes each premium using expanding historical window z-scores without lookahead bias: $Z_t = \frac{X_t - \mu_t}{\sigma_t}$.
- Best Value Selection: Identifies the asset class with the highest normalized z-score. If $\max(Z_t) > 0$, allocates 100% of capital to the winning asset; if $\max(Z_t) \le 0$, allocates 100% to cash.
- On DWX CFD index markets (SP500.DWX, NDX.DWX, WS30.DWX, etc.), the EA enters and maintains a long position when the equity sleeve is the top-ranked positive risk premium; otherwise, it exits to cash.

Exits and Rebalancing:
- Position re-evaluation occurs at each monthly boundary.
- If equity ceases to hold the highest positive normalized value, any open position is closed at market to hold cash.
- Standard framework risk caps and Friday close handling apply.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tf` | `PERIOD_D1` | D1 | Base operational timeframe. |
| `strategy_min_history_months` | 24 | 12-60 | Minimum expanding history months before trading begins. |
| `strategy_rebalance_hour` | 1 | 0-23 | Broker hour on first day of month to evaluate rebalance. |
| `strategy_earnings_lag_months` | 4 | 1-12 | Earnings yield publication reporting lag in months. |
| `strategy_equity_threshold_z` | 0.00 | -1.0-1.0 | Minimum normalized z-score threshold for equity allocation. |
| `strategy_atr_period` | 20 | 5-50 | ATR period for trailing / emergency volatility metrics. |
| `strategy_emergency_sl_atr` | 5.00 | 2.0-10.0 | Catastrophe stop loss distance in ATR units. |
| `strategy_spread_median_days` | 20 | 5-50 | Rolling days for median spread evaluation. |
| `strategy_spread_cap_mult` | 3.00 | 1.0-10.0 | Maximum allowed spread multiplier vs median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Primary US broad equity proxy.
- `NDX.DWX` - US technology equity proxy.
- `WS30.DWX` - US large-cap equity proxy.
- `GDAXI.DWX` - European equity index proxy.
- `UK100.DWX` - UK equity index proxy.
- `XAUUSD.DWX` - Gold commodity proxy.
- `EURUSD.DWX` - FX major universe.
- `GBPUSD.DWX` - FX major universe.
- `USDJPY.DWX` - FX major universe.
- `USDCHF.DWX` - FX major universe.
- `AUDUSD.DWX` - FX major universe.
- `USDCAD.DWX` - FX major universe.
- `NZDUSD.DWX` - FX major universe.

**Explicitly NOT for:**
- High-frequency instruments or symbols outside `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Monthly rebalance cycle calculated from closed D1 bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `1-4` (tactical monthly allocation regime) |
| Typical hold time | `1-6 months` |
| Expected drawdown profile | Low turnover, bounded drawdowns via cash allocation during negative risk premium regimes |
| Regime preference | Cyclical value expansion and positive equity risk premium environments |
| Win rate target (qualitative) | `55-65%` on multi-month holding horizons |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9`
**Source type:** `public quantitative strategy catalogue`
**Pointer:** Allocate Smartly "Testing a Risk Premium Value Strategy", https://allocatesmartly.com/testing-a-risk-premium-value-strategy/; `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1405_as-rpv-bestvalue.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1405_as-rpv-bestvalue.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | Gemini EA implementation |
