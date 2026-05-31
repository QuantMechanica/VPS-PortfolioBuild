# QM5_10610_mql5-cmo - Strategy Spec

**EA ID:** QM5_10610
**Slug:** mql5-cmo
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the CMO cloud color change from the approved MQL5 CodeBase source. On each completed H4 bar it calculates the source-default CMO: a 14-period SMA of close, then a 14-period Chande momentum sum over SMA changes. A long opens when CMO crosses from below zero to above zero; a short opens when CMO crosses from above zero to below zero. Existing long positions close on the bearish color change, existing short positions close on the bullish color change, and any position is also closed after 16 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for CMO signal calculation. |
| `strategy_cmo_length` | `14` | `2+` | Source-default CMO length and SMA smoothing length. |
| `strategy_signal_bar` | `1` | `1+` | Closed bar index used for the signal. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | `> 0` | ATR multiplier for initial stop loss. |
| `strategy_time_stop_bars` | `16` | `0+` | Number of completed signal-timeframe bars before fallback exit; `0` disables. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` - source test used EURJPY H4, so this is the primary baseline symbol.
- `EURUSD.DWX` - liquid DWX FX major suitable for portable oscillator color-state logic.
- `GBPUSD.DWX` - liquid DWX FX major suitable for portable oscillator color-state logic.
- `XAUUSD.DWX` - DWX metal CFD included by the approved card target basket.

**Explicitly NOT for:**
- Non-DWX symbols - the build and backtest pipeline require canonical `.DWX` instruments from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Up to 16 H4 bars unless the opposite color-change exit appears first. |
| Expected drawdown profile | Momentum-oscillator whipsaw risk during range-bound periods, bounded by ATR catastrophic stop. |
| Regime preference | Momentum color-change regimes with sustained directional follow-through. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase expert and custom indicator
**Pointer:** https://www.mql5.com/en/code/1141 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10610_mql5-cmo.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10610_mql5-cmo.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | f0c8fdce-073e-4672-8e84-15eb9d845ee1 |
