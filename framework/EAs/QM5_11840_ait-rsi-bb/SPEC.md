# QM5_11840_ait-rsi-bb - Strategy Spec

**EA ID:** QM5_11840
**Slug:** ait-rsi-bb
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `whchien/ai-trader`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades a long-only daily mean-reversion signal. On each completed D1 bar after warmup, it enters long when RSI(14) is below 30 and the D1 close is at or below the lower Bollinger Band using period 20 and deviation 2.0. The protective stop is placed 2.0 times ATR(14) below the estimated market entry price. The EA exits the long when RSI rises above 70 or the completed D1 close reaches or exceeds the upper Bollinger Band; framework Friday close can also flatten positions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | >= 1 | RSI lookback period for entry and exit thresholds. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long entry threshold; RSI must be below this value. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Strategy exit threshold; RSI must be above this value. |
| `strategy_bb_period` | 20 | >= 1 | Bollinger Band lookback period. |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger Band standard-deviation multiplier. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple used to place the hard stop from entry. |
| `strategy_warmup_bars` | 100 | >= 1 | Minimum completed D1 bars required before signals are valid. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with daily close-derived RSI and Bollinger portability.
- `GBPUSD.DWX` - liquid FX major matching the card's R3 basket.
- `USDJPY.DWX` - liquid FX major matching the card's R3 basket.
- `XAUUSD.DWX` - liquid metal CFD included by the card's R3 basket.
- `GDAXI.DWX` - matrix-valid DAX custom symbol used as the available DWX equivalent for card-stated `GER40.DWX`.
- `NDX.DWX` - liquid Nasdaq 100 index CFD included by the card's R3 basket.
- `WS30.DWX` - liquid Dow 30 index CFD included by the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to the DWX backtest terminals.

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
| Trades / year / symbol | 14 |
| Typical hold time | Several days, until RSI overbought or upper-band recovery. |
| Expected drawdown profile | Vulnerable to prolonged downside trends after oversold entries. |
| Regime preference | Daily mean-reversion after lower-band extension. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository source file
**Pointer:** `whchien/ai-trader`, `ai_trader/backtesting/strategies/classic/rsi.py`, `RsiBollingerBandsStrategy`, https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/rsi.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11840_ait-rsi-bb.md`

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
| v1 | 2026-06-11 | Initial build from card | f98ab4a8-8833-4208-b4b3-598b04413451 |
