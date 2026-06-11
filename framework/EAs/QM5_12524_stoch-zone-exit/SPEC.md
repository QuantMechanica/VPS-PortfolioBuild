# QM5_12524_stoch-zone-exit - Strategy Spec

**EA ID:** QM5_12524
**Slug:** stoch-zone-exit
**Source:** 3826b7f5-8cc3-536f-8093-ff36dd567ef4 (see `sources/backtest-rookies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades completed-bar stochastic reversals. It enters long when both %K and %D are at or below the oversold level and %K crosses above %D, and enters short when both lines are at or above the overbought level and %K crosses below %D. Long positions close when both stochastic lines reach the overbought zone; short positions close when both lines reach the oversold zone. A 3.0 x ATR(14) stop is used only as a catastrophic protective stop because the source did not define an independent stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 14 | >= 1 | Stochastic %K lookback period. |
| `strategy_stoch_d_period` | 3 | >= 1 | Stochastic %D smoothing period. |
| `strategy_stoch_slowing` | 3 | >= 1 | Stochastic slowing value. |
| `strategy_oversold_level` | 20.0 | 0.0-100.0 | Zone threshold for long entries and short exits. |
| `strategy_overbought_level` | 80.0 | 0.0-100.0 | Zone threshold for short entries and long exits. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the protective catastrophic stop. |
| `strategy_atr_stop_mult` | 3.0 | > 0.0 | ATR multiplier for the protective catastrophic stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - Named FX candidate in the approved card and present in the DWX matrix.
- `GBPUSD.DWX` - Named FX candidate in the approved card and present in the DWX matrix.
- `EURUSD.DWX` - Named FX candidate in the approved card and present in the DWX matrix.
- `NZDUSD.DWX` - Named FX candidate in the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- Index `.DWX` symbols - The source/card describes a forex stochastic review, not an index basket.
- Commodity `.DWX` symbols - The card names forex candidates only.
- FX crosses not listed above - The card mentions broader FX majors but does not enumerate an R3 basket for this build.

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
| Trades / year / symbol | 36 |
| Typical hold time | Multiple completed bars, often several days on D1, until the opposite stochastic zone is reached. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent directional trends; catastrophic loss bounded by ATR stop. |
| Regime preference | mean-revert / oscillator-reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3826b7f5-8cc3-536f-8093-ff36dd567ef4
**Source type:** article
**Pointer:** Backtest Rookies, "Backtrader Stochastic Indicator Review", 2017-08-02; source location: "Test Strategy" / "Exit Method 2" section.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12524_stoch-zone-exit.md`

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
| v1 | 2026-06-11 | Initial build from card | 64e5da50-8ed0-4eeb-9edf-10ec07b8d143 |
