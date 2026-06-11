# QM5_12524_stoch-zone-exit - Strategy Spec

**EA ID:** QM5_12524
**Slug:** stoch-zone-exit
**Source:** 3826b7f5-8cc3-536f-8093-ff36dd567ef4
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades stochastic oscillator reversals on completed bars. It enters long when `%K` and `%D` are both at or below the oversold level and `%K` crosses above `%D`; it enters short when both lines are at or above the overbought level and `%K` crosses below `%D`. Long positions close when both stochastic lines reach the overbought zone, and short positions close when both lines reach the oversold zone. The only protective stop is a catastrophic ATR stop; the primary exit remains the stochastic zone condition.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_stoch_k_period` | 14 | 1+ | Stochastic `%K` lookback period. |
| `strategy_stoch_d_period` | 3 | 1+ | Stochastic `%D` averaging period. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing value. |
| `strategy_oversold_level` | 20.0 | 0.0-99.0 | Zone threshold for long entries and short exits. |
| `strategy_overbought_level` | 80.0 | 1.0-100.0 | Zone threshold for short entries and long exits. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for the catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | >0.0 | ATR multiple for the catastrophic stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - FX candidate named in the approved card.
- `GBPUSD.DWX` - FX candidate named in the approved card.
- `EURUSD.DWX` - FX candidate named in the approved card.
- `NZDUSD.DWX` - FX candidate named in the approved card.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved source and card target forex markets.
- FX symbols outside the registered basket - not listed as initial candidates in the approved card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 36 |
| Typical hold time | Not specified in card frontmatter; held until the opposite stochastic zone or catastrophic ATR stop. |
| Expected drawdown profile | Mean-reversion oscillator strategy with losses bounded by ATR stop. |
| Regime preference | Mean-reversion / oscillator reversal. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3826b7f5-8cc3-536f-8093-ff36dd567ef4
**Source type:** article
**Pointer:** Backtest Rookies/Rookie1, "Backtrader Stochastic Indicator Review", 2017-08-02; original URL and archive URL in `artifacts/cards_approved/QM5_12524_stoch-zone-exit.md`
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
