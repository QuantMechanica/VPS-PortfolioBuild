# QM5_10614_mql5-3genxma - Strategy Spec

**EA ID:** QM5_10614
**Slug:** `mql5-3genxma`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades completed H4 bar direction changes in the MQL5 3rdGenerationXMA moving average. It enters long when the 3rdGenXMA changes from falling to rising at bar close, and enters short when it changes from rising to falling. Open positions close on an opposite 3rdGenXMA direction change, framework Friday close, the ATR catastrophic stop, or after 18 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_xma_length` | 50 | >=2 | Source default 3rdGenXMA smoothing depth. |
| `strategy_atr_period` | 14 | >=1 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiplier for the catastrophic stop. |
| `strategy_time_stop_h4_bars` | 18 | >=0 | Fallback time stop measured in completed H4 bars; 0 disables it. |
| `strategy_close_on_opposite` | true | true/false | Close an open position when the opposite XMA direction-change signal appears. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `NZDUSD.DWX` - source test symbol and card target; liquid major FX pair with verified DWX history.
- `EURUSD.DWX` - card target; liquid major FX pair with verified DWX history.
- `GBPUSD.DWX` - card target; liquid major FX pair with verified DWX history.
- `USDJPY.DWX` - card target; liquid major FX pair with verified DWX history.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX history for build registration.

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
| Trades / year / symbol | `75` |
| Typical hold time | Not specified in card frontmatter; capped by 18 completed H4 bars. |
| Expected drawdown profile | Not specified in card frontmatter; trend-following direction-change strategy with ATR catastrophic stops. |
| Regime preference | Trend-following moving-average direction changes. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/1069`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10614_mql5-3genxma.md`

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
| v1 | 2026-06-13 | Initial build from card | ce3fad1a-7f4a-4b1a-99c8-2d56f566ca1b |

