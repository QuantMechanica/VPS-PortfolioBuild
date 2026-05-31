# QM5_10546_mql5-ma4060 - Strategy Spec

**EA ID:** QM5_10546
**Slug:** `mql5-ma4060`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades the closed-bar crossover of the 40-period and 60-period simple moving averages. It opens long when SMA(40) crosses above SMA(60), and opens short when SMA(40) crosses below SMA(60). An open long is closed on the opposite bearish cross, and an open short is closed on the opposite bullish cross. Entries use an ATR-normalized hard stop and no fixed take-profit, matching the card's P2 baseline preference for signal-reversal exits across symbols.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 40 | 1-59 | Fast simple moving average period used for crossover detection. |
| `strategy_slow_sma_period` | 60 | 2-300 | Slow simple moving average period used for crossover detection. |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback used to normalize the hard stop distance. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for the initial stop loss. |
| `strategy_max_spread_points` | 35 | 0-1000 | Maximum allowed spread in points; 0 disables the spread filter. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source example was EURUSD M30 and the symbol is native in the DWX matrix.
- `GBPUSD.DWX` - Major FX pair with DWX data and comparable trend-crossover mechanics.
- `USDJPY.DWX` - Major FX pair with DWX data and comparable trend-crossover mechanics.
- `XAUUSD.DWX` - Liquid metal symbol with DWX data included in the approved R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `Trend-following crossover drawdowns during choppy range regimes.` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/17400`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10546_mql5-ma4060.md`

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
| v1 | 2026-05-29 | Initial build from card | af59b269-3821-44cd-a8a7-9389d60f8aee |
