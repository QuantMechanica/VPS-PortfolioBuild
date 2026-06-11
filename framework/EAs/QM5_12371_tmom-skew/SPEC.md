# QM5_12371_tmom-skew - Strategy Spec

**EA ID:** QM5_12371
**Slug:** tmom-skew
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA calculates the skewness of daily close-to-close returns over a 252-bar D1 lookback. It opens long when skewness is greater than +0.50 and opens short when skewness is less than -0.50. It exits when skewness returns inside the neutral band below 0.25 in absolute value, when the opposite threshold is reached, or when the position has been held for 20 D1 bars. A 2.0 x ATR(14) hard stop is placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_days` | 252 | 126-504 | Number of D1 returns used for skewness. |
| `strategy_entry_threshold` | 0.50 | 0.25-0.75 | Positive or negative skewness threshold required for entry. |
| `strategy_exit_threshold` | 0.25 | 0.00-0.25 | Neutral skewness band used for signal exit. |
| `strategy_max_hold_bars` | 20 | 10-40 | Maximum D1-bar holding window before strategy exit. |
| `strategy_atr_period` | 14 | 14 | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiplier for the hard stop distance. |
| `strategy_min_warmup_bars` | 280 | 280+ | Minimum D1 history required before signal evaluation. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card R3 includes metals and DWX matrix confirms gold.
- `XTIUSD.DWX` - card R3 includes energy and DWX matrix confirms WTI crude.
- `EURUSD.DWX` - card R3 includes FX and DWX matrix confirms EURUSD.
- `GBPUSD.DWX` - card R3 includes FX and DWX matrix confirms GBPUSD.
- `GDAXI.DWX` - DAX equivalent for card-stated GER40 because `GER40.DWX` is absent from the DWX matrix.
- `NDX.DWX` - card R3 includes US large-cap index exposure.
- `WS30.DWX` - card R3 includes US large-cap index exposure.
- `SP500.DWX` - optional card R3 backtest-only S&P 500 custom symbol.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Up to 20 D1 bars |
| Expected drawdown profile | Slow statistical factor with sparse turnover and ATR-defined per-trade loss. |
| Regime preference | Skewness-premium / statistical-factor regimes with stable higher-moment estimates. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository
**Pointer:** `ThewindMom/151-trading-strategies`, `src/strategies/commodities/skewness_premium.py`, https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/commodities/skewness_premium.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12371_tmom-skew.md`

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
| v1 | 2026-06-11 | Initial build from card | 6bcc182c-5f15-42de-ad47-6d35e0019767 |
