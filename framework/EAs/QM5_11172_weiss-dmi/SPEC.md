# QM5_11172_weiss-dmi - Strategy Spec

**EA ID:** QM5_11172
**Slug:** weiss-dmi
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades Weissman's DMI directional-difference rule on completed D1 bars. It computes `DDIF(10)` as `+DI(10) - -DI(10)`: a cross above +20 opens long, and a cross below -20 opens short. Long positions close when `DDIF(10)` crosses below zero; short positions close when it crosses above zero. The source does not define a normal stop, so the build uses the card's V5 fallback catastrophic stop at the greater of `3 * ATR(20,D1)` and broker minimum distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dmi_period` | 10 | `1+` | Period for the DMI plus/minus DI values used to compute DDIF. |
| `strategy_entry_threshold` | 20.0 | `> 0` | Positive and negative DDIF entry threshold. |
| `strategy_atr_period` | 20 | `1+` | ATR period for the catastrophic protective stop. |
| `strategy_atr_stop_mult` | 3.0 | `> 0` | ATR multiplier for the catastrophic protective stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX forex instrument with D1 OHLC data for DMI.
- `USDJPY.DWX` - card-listed DWX forex instrument with D1 OHLC data for DMI.
- `XAUUSD.DWX` - card-listed DWX metals instrument with D1 OHLC data for DMI.
- `XTIUSD.DWX` - card-listed DWX energy instrument with D1 OHLC data for DMI.
- `SP500.DWX` - card-listed S&P 500 custom symbol; valid for backtest registration with T6 live-routing caveat.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest routing.

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
| Typical hold time | Days to weeks, until DDIF crosses the zero line. |
| Expected drawdown profile | Trend-following losses cluster during sideways DDIF whipsaws. |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, pp. 56-57, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11172_weiss-dmi.md`

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
| v1 | 2026-06-07 | Initial build from card | 4cc057f1-f913-4b5c-95c3-8f4d5a772de7 |
