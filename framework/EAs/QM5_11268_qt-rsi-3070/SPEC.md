# QM5_11268_qt-rsi-3070 - Strategy Spec

**EA ID:** QM5_11268
**Slug:** `qt-rsi-3070`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades a symmetric RSI mean-reversion rule on completed bars. It enters long when RSI(14) is below 30 and enters short when RSI(14) is above 70, provided the ADX(14) trend filter is not above 30. Long trades exit when RSI crosses back above the long midpoint, when an opposite short signal appears, when price moves 1.5 ATR against entry, or when the 10-bar time stop fires while RSI is between 40 and 60. Short trades mirror those rules with RSI crossing below the short midpoint, opposite long signal, adverse 1.5 ATR move, or the same neutral-band time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 9-21 test range | RSI lookback used for entries and exits. |
| `strategy_long_entry_rsi` | 30.0 | 25-35 test range | Enter long below this closed-bar RSI value. |
| `strategy_short_entry_rsi` | 70.0 | 65-75 test range | Enter short above this closed-bar RSI value. |
| `strategy_long_exit_rsi` | 50.0 | 45-55 test range | Close long when RSI crosses above this value. |
| `strategy_short_exit_rsi` | 50.0 | 45-55 test range | Close short when RSI crosses below this value. |
| `strategy_neutral_rsi_low` | 40.0 | 0-100 | Lower RSI bound for the neutral-band time stop. |
| `strategy_neutral_rsi_high` | 60.0 | 0-100 | Upper RSI bound for the neutral-band time stop. |
| `strategy_adx_period` | 14 | 14 baseline | ADX lookback for trend-regime filtering. |
| `strategy_enable_adx_filter` | true | true/false | Enables the card's trend-filter skip rule. |
| `strategy_adx_max` | 30.0 | 25-30 test range | Skip new entries when ADX is above this value. |
| `strategy_atr_period` | 14 | 14 baseline | ATR lookback for hard and adverse volatility stops. |
| `strategy_atr_sl_mult` | 2.0 | 2.0 baseline | Initial hard stop distance in ATR multiples. |
| `strategy_atr_adverse_mult` | 1.5 | 1.5 baseline | Exit when price moves this many ATR against entry. |
| `strategy_max_hold_bars` | 10 | 10 baseline | Time stop in current-chart bars while RSI remains neutral. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 forex basket symbol with DWX close-price data.
- `GBPUSD.DWX` - card R3 forex basket symbol with DWX close-price data.
- `USDJPY.DWX` - card R3 forex basket symbol with DWX close-price data.
- `XAUUSD.DWX` - card R3 metals symbol with DWX close-price data.
- `GDAXI.DWX` - canonical DWX DAX symbol used as the available port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester matrix does not provide validated DWX data for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Up to 10 current-chart bars when RSI remains neutral; H4 primary implies up to roughly 40 trading hours before the neutral-band time stop. |
| Expected drawdown profile | Medium risk because RSI mean reversion can suffer in persistent trends. |
| Regime preference | Mean-reversion, oscillator-threshold, symmetric long-short, news-blackout. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository/script
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/RSI%20Pattern%20Recognition%20backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11268_qt-rsi-3070.md`

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
| v1 | 2026-06-08 | Initial build from card | 1d0947c1-9a00-4de8-9425-3c7acca70cfc |
