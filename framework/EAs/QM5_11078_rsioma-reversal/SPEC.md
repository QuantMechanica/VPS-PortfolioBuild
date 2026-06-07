# QM5_11078_rsioma-reversal - Strategy Spec

**EA ID:** QM5_11078
**Slug:** `rsioma-reversal`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA computes RSIOMA on closed H4 bars as an RSI-style oscillator over an EMA of close prices. It opens long when RSIOMA crosses above 20 from below, and opens short when RSIOMA crosses below 80 from above. A long position exits when RSIOMA crosses below 50 or when the short signal appears; a short position exits when RSIOMA crosses above 50 or when the long signal appears. Each entry uses an ATR(14) x 2.5 hard stop and no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsioma_period` | 14 | 2+ | RSI period applied to the moving-average series. |
| `strategy_rsioma_ma_period` | 14 | 2+ | EMA period used to build the RSIOMA input series. |
| `strategy_rsioma_signal_ma` | 21 | 1+ | Source default for MA of RSIOMA; retained for parameter visibility, not used by the P2 main-cross baseline. |
| `strategy_buy_trigger` | 20.0 | 0-50 | Long trigger crossed upward from below. |
| `strategy_sell_trigger` | 80.0 | 50-100 | Short trigger crossed downward from above. |
| `strategy_trend_level` | 50.0 | 0-100 | Midline used for strategy exits. |
| `strategy_atr_period` | 14 | 1+ | ATR period for hard stop placement. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiplier for the hard stop. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread block; zero disables it for the card baseline. |
| `strategy_use_trading_hours` | false | true/false | Optional time window block; disabled for the card baseline. |
| `strategy_start_hour` | 0 | 0-23 | Start hour if the optional time window is enabled. |
| `strategy_end_hour` | 24 | 0-24 | End hour if the optional time window is enabled. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary P2 basket forex major with DWX data.
- `GBPUSD.DWX` - Card R3 primary P2 basket forex major with DWX data.
- `USDJPY.DWX` - Card R3 primary P2 basket forex major with DWX data.
- `USDCAD.DWX` - Card R3 primary P2 basket forex major with DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - Build and pipeline artifacts must use registered `.DWX` research/backtest symbols.

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
| Trades / year / symbol | 40 |
| Typical hold time | hours to days |
| Expected drawdown profile | Mean-reversion entries with ATR-capped per-trade loss. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** public indicator source
**Pointer:** EarnForex RSIOMA GitHub repository and MQL5 source, https://github.com/EarnForex/RSIOMA
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11078_rsioma-reversal.md`

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
| v1 | 2026-06-07 | Initial build from card | 737642a0-ff83-4c63-a857-3b992bc74632 |
