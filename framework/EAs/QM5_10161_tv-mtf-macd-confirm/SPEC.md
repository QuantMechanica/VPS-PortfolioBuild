# QM5_10161_tv-mtf-macd-confirm - Strategy Spec

**EA ID:** QM5_10161
**Slug:** `tv-mtf-macd-confirm`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades the TradingView Multi-Timeframe MACD Confirm card mechanically. On H1, it opens long when the H1 MACD line crosses above its signal line and the completed H4 MACD state is bullish; it opens short when the H1 MACD line crosses below its signal line and the completed H4 MACD state is bearish. Long positions close when H1 MACD crosses back below its signal line, and short positions close when H1 MACD crosses back above its signal line. Every entry receives a protective stop 2.0 ATR(14) away from entry; the baseline does not use the source's optional trailing stop mode.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Current timeframe MACD signal in the baseline. |
| `strategy_confirm_tf` | `PERIOD_H4` | MT5 timeframe enum | Higher timeframe MACD confirmation timeframe. |
| `strategy_macd_fast` | `12` | `1+` and less than slow | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | Greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `1+` | MACD signal EMA period. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for the protective stop. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | Stop distance multiplier applied to ATR(14). |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target forex major; MACD OHLC logic ports directly.
- `GBPUSD.DWX` - Card target forex major; MACD OHLC logic ports directly.
- `XAUUSD.DWX` - Card target gold CFD; MACD OHLC logic ports directly.
- `GDAXI.DWX` - DWX matrix DAX custom symbol used for the card's `DAX.DWX` target.

**Explicitly NOT for:**
- Symbols outside the registered list - no implicit runtime universe expansion.
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the verified DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `H4` MACD state from completed bars only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Until H1 MACD reversal or protective stop |
| Expected drawdown profile | Fixed $1,000 per-trade risk in backtest; capped by V5 risk framework |
| Regime preference | Trend-following / momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView public script page
**Pointer:** TradingView script `Multi-Timeframe MACD Strategy ver 1.0`, author handle `fenyesk`, published 2025-03-14, https://www.tradingview.com/script/WqzrfL2Q-Multi-Timeframe-MACD-Strategy-ver-1-0/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10161_tv-mtf-macd-confirm.md`

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
| v1 | 2026-06-09 | Initial build from card | 5baae284-e657-463e-8291-4771f927abca |
