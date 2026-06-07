# QM5_11173_weiss-dmi-adx - Strategy Spec

**EA ID:** QM5_11173
**Slug:** weiss-dmi-adx
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It computes DDIF as plus DI minus minus DI using a 10-period DMI calculation, then enters long when DDIF crosses above +20 and ADX(9) is above 20. It enters short when DDIF crosses below -20 and ADX(9) is above 20. Long positions exit when DDIF crosses below 0 or ADX(9) falls below 20; short positions exit when DDIF crosses above 0 or ADX(9) falls below 20.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dmi_period` | 10 | 1-200 | Period used for plus DI and minus DI. |
| `strategy_adx_period` | 9 | 1-200 | Period used for the ADX trend-strength filter. |
| `strategy_ddif_entry_level` | 20.0 | 0-100 | Absolute DDIF threshold for long and short entries. |
| `strategy_ddif_exit_level` | 0.0 | -100-100 | DDIF zero-line threshold for strategy exits. |
| `strategy_adx_min` | 20.0 | 0-100 | Minimum ADX value required for entry; loss of this level exits positions. |
| `strategy_atr_period` | 20 | 1-200 | ATR period used for the protective catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.1-20 | ATR multiple used for the protective catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with liquid daily OHLC data.
- `USDJPY.DWX` - major FX pair with liquid daily OHLC data.
- `XAUUSD.DWX` - gold trend market included by the approved card basket.
- `XTIUSD.DWX` - crude oil trend market included by the approved card basket.
- `SP500.DWX` - S&P 500 custom symbol available for backtest-only validation.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX data route exists for build registration.

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
| Typical hold time | days to weeks |
| Expected drawdown profile | trend-following whipsaws during sideways periods |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems, Chapter 3, pp. 57-58; https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11173_weiss-dmi-adx.md`

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
| v1 | 2026-06-07 | Initial build from card | 5bc14d20-d821-47ed-88c6-994fec8c6094 |
