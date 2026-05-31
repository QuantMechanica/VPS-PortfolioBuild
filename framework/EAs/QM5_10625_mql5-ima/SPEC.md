# QM5_10625_mql5-ima - Strategy Spec

**EA ID:** QM5_10625
**Slug:** mql5-ima
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase source note)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the MQL5 Index Moving Average daily momentum rule. On the first tick of a new D1 bar it computes IMA as `close / SMA(5) - 1`, then compares the change from the previous IMA value with `k = (IMA_current - IMA_previous) / abs(IMA_previous)`. It opens long when `k >= 0.5`, opens short when `k <= -0.5`, and skips signals when the previous IMA value is zero or unavailable. Exits are handled by the initial ATR stop, ATR trailing stop, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ima_period` | 5 | 2-200 | SMA length used inside the IMA calculation. |
| `strategy_signal_level` | 0.5 | 0.01-5.0 | Absolute threshold for the IMA momentum ratio. |
| `strategy_atr_period` | 14 | 2-200 | ATR period used for the initial stop and trailing stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.25-10.0 | ATR multiple for the initial stop. |
| `strategy_trail_atr_mult` | 2.0 | 0.25-10.0 | ATR multiple for the trailing stop. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with daily OHLC data suitable for IMA.
- `GBPUSD.DWX` - card-listed FX major with daily OHLC data suitable for IMA.
- `USDJPY.DWX` - card-listed FX major with daily OHLC data suitable for IMA.
- `XAUUSD.DWX` - card-listed metal symbol with daily OHLC data suitable for IMA.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester does not provide canonical DWX data for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with the EA blocked outside D1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | Days, bounded by ATR trailing and Friday close |
| Expected drawdown profile | Trend-following losses controlled by fixed ATR stop and V5 fixed-risk sizing |
| Regime preference | Daily MA momentum / trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/149
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10625_mql5-ima.md`

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
| v1 | 2026-05-31 | Initial build from card | 76634b53-baed-41f4-a365-074d7d310f08 |
