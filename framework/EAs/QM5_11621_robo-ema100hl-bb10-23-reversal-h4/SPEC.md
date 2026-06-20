# QM5_11621_robo-ema100hl-bb10-23-reversal-h4 - Strategy Spec

**EA ID:** QM5_11621
**Slug:** `robo-ema100hl-bb10-23-reversal-h4`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see `strategy-seeds/sources/ed246754-1f4d-5bed-8dd3-3b5cbf1b420d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H4 reversals around an EMA(100) High/Low channel and Bollinger Bands set to period 10 and deviation 2.3. A long entry is allowed when the last closed bar is above EMA(100, Low), touched the lower Bollinger Band, and closed back above that lower band. A short entry is allowed when the last closed bar is below EMA(100, High), touched the upper Bollinger Band, and closed back below that upper band. The stop uses 2 ATR(14), the primary exit closes at the Bollinger middle band, and a 4 ATR(14) target is kept as a protective cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_channel_period` | 100 | 20-200 | EMA period used for the High/Low channel. |
| `strategy_bb_period` | 10 | 5-40 | Bollinger Band period. |
| `strategy_bb_deviation` | 2.3 | 1.0-4.0 | Bollinger Band deviation. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop and protective target sizing. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-6.0 | Stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | 4.0 | 1.0-10.0 | Protective target distance in ATR multiples. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-50.0 | Blocks only genuinely wide spreads above this percent of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - H4 FX major listed in the card and present in the DWX matrix.
- `GBPUSD.DWX` - H4 FX major listed in the card and present in the DWX matrix.
- `USDJPY.DWX` - H4 FX major listed in the card and present in the DWX matrix.
- `USDCHF.DWX` - H4 FX major listed in the card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved card targets only the named FX major basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | `H4 mean-reversion swing; hours to a few days` |
| Expected drawdown profile | `moderate, ATR-bounded per trade` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `book`
**Pointer:** `RoboForex Educational Team, "Forex Strategy Collection", strategy "Pending the reversal", pages 104-105`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11621_robo-ema100hl-bb10-23-reversal-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 5f538eb3-455c-448a-97ac-01cf77702010 |
