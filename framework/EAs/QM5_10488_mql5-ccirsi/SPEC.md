# QM5_10488_mql5-ccirsi - Strategy Spec

**EA ID:** QM5_10488
**Slug:** mql5-ccirsi
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates RSI and CCI on the close of each M15 bar. It opens long when RSI is above 55 and CCI is above +100, and opens short when RSI is below 45 and CCI is below -100. It holds at most one position per symbol and magic number. Positions close on the opposite dual-oscillator signal, at a 1.5 ATR(14) protective stop, at a 2.0R target, or after 64 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_tf` | `PERIOD_M15` | MT5 timeframe enum | Timeframe used for RSI, CCI, ATR, and time-stop bar counting. |
| `strategy_rsi_period` | `14` | `> 0` | RSI lookback period. |
| `strategy_rsi_level_up` | `55.0` | numeric | Long threshold for RSI. |
| `strategy_rsi_level_down` | `45.0` | numeric | Short threshold for RSI. |
| `strategy_cci_period` | `14` | `> 0` | CCI lookback period. |
| `strategy_cci_level_up` | `100.0` | numeric | Long threshold for CCI. |
| `strategy_cci_level_down` | `-100.0` | numeric | Short threshold for CCI. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for protective stop distance. |
| `strategy_atr_sl_mult` | `1.5` | `> 0` | ATR multiplier for the initial stop loss. |
| `strategy_target_rr` | `2.0` | `> 0` | Reward-to-risk multiple for take profit. |
| `strategy_time_stop_bars` | `64` | `>= 0` | Maximum holding period in strategy timeframe bars; `0` disables. |
| `strategy_max_spread_points` | `35` | `>= 0` | Maximum allowed spread in points; `0` disables the spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source example is EURUSD M15 and the pair is liquid enough for oscillator thresholds.
- `GBPUSD.DWX` - DWX major FX pair with similar OHLC-derived RSI/CCI portability.
- `USDJPY.DWX` - DWX major FX pair with sufficient M15 history for standard oscillators.
- `XAUUSD.DWX` - DWX metal symbol included by the approved card's portable basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers symbols verified in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Up to 64 M15 bars, roughly 16 hours before time stop. |
| Expected drawdown profile | Fixed ATR stop and 2R target should bound per-trade loss while allowing frequent oscillator entries. |
| Regime preference | Oscillator confirmation on liquid FX/metals; best when RSI and CCI threshold moves persist after bar close. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/21976 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10488_mql5-ccirsi.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10488_mql5-ccirsi.md`

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
| v1 | 2026-05-28 | Initial build from card | 448c48dd-ee2a-408e-af6c-97b87ec5645e |
