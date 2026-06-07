# QM5_11081_schaff-cycle - Strategy Spec

**EA ID:** QM5_11081
**Slug:** `schaff-cycle`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades the Schaff Trend Cycle on completed H1 bars. It computes a fixed 23/50 EMA MACD line, applies a 10-bar stochastic, smooths it with the source factor, then applies a second 10-bar stochastic and smoothing pass. A long entry is opened when the completed STC value rises above 25 after being at or below 25; a short entry is opened when the completed STC value falls below 75 after being at or above 75. Long positions close on a short STC signal, short positions close on a long STC signal, and all trades carry the V5 P2 ATR catastrophic stop and optional ATR target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_short` | 23 | 1 to `strategy_ma_long - 1` | Fast EMA period used in the STC MACD line. |
| `strategy_ma_long` | 50 | greater than `strategy_ma_short` | Slow EMA period used in the STC MACD line. |
| `strategy_cycle` | 10 | 2 or higher | Cycle length for both stochastic passes in the STC calculation. |
| `strategy_buy_level` | 25.0 | greater than 0 and below `strategy_sell_level` | Long trigger level; STC must cross upward through this value. |
| `strategy_sell_level` | 75.0 | above `strategy_buy_level` and below 100 | Short trigger level; STC must cross downward through this value. |
| `strategy_stc_factor` | 0.5 | greater than 0 and up to 1 | Fixed smoothing factor used by the source STC formula. |
| `strategy_atr_period` | 14 | 1 or higher | ATR period for the catastrophic stop and optional target. |
| `strategy_atr_sl_mult` | 2.5 | greater than 0 | ATR multiplier for the catastrophic stop. |
| `strategy_atr_tp_mult` | 3.5 | greater than 0 | ATR multiplier for the optional target. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair from the card's R3 portable DWX basket.
- `GBPUSD.DWX` - major FX pair from the card's R3 portable DWX basket.
- `USDJPY.DWX` - major FX pair from the card's R3 portable DWX basket.
- `XAUUSD.DWX` - liquid precious-metal CFD from the card's R3 portable DWX basket.

**Explicitly NOT for:**
- Any symbol not listed above - no implicit runtime universe expansion is allowed for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Not specified in card frontmatter; exits on opposite STC signal or ATR stop/target |
| Expected drawdown profile | Bounded by 2.5 x ATR(14) catastrophic stop plus V5 portfolio controls |
| Regime preference | Cycle momentum oscillator; best suited to directional trend acceleration and deceleration |
| Win rate target (qualitative) | Not specified in card frontmatter |

Expected trade frequency from card frontmatter: STC threshold re-entry signals on H1 are moderate cadence; conservative estimate 40 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** GitHub repository and MQL5 indicator source
**Pointer:** `https://github.com/EarnForex/Schaff-Trend-Cycle`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11081_schaff-cycle.md`

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
| v1 | 2026-06-07 | Initial build from card | 205f4cf6-303f-4f52-90d4-2687574d7578 |
