# QM5_11739_rfs-alligator-sma144-m15 - Strategy Spec

**EA ID:** QM5_11739
**Slug:** `rfs-alligator-sma144-m15`
**Source:** `b5a932a2-40b6-5628-840b-d5069ac35c4a` (see approved card source pointer)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades an M15 trend-following Alligator setup with an SMA144 trend filter. It opens long when the last closed bar is above SMA144 and the Alligator lines are ordered Lips > Teeth > Jaw; it opens short when the last closed bar is below SMA144 and the lines are ordered Lips < Teeth < Jaw. The Alligator lines are implemented as shifted SMMA lines on median price, using the card periods and shifts. Long positions close when Lips drops below Teeth; short positions close when Lips rises above Teeth.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M15` | MT5 timeframe enum | Signal timeframe from the card. |
| `strategy_jaw_period` | `13` | `1+` | Alligator Jaw SMMA period. |
| `strategy_jaw_shift` | `8` | `0+` | Alligator Jaw forward-shift offset applied as a closed-bar read offset. |
| `strategy_teeth_period` | `8` | `1+` | Alligator Teeth SMMA period. |
| `strategy_teeth_shift` | `5` | `0+` | Alligator Teeth forward-shift offset applied as a closed-bar read offset. |
| `strategy_lips_period` | `5` | `1+` | Alligator Lips SMMA period. |
| `strategy_lips_shift` | `3` | `0+` | Alligator Lips forward-shift offset applied as a closed-bar read offset. |
| `strategy_sma_period` | `144` | `2+` | Macro trend filter and source level for the initial stop. |
| `strategy_atr_period` | `14` | `1+` | ATR period for stop cap and factory hard take-profit. |
| `strategy_sma_stop_buffer_pips` | `1` | `1+` | Stop buffer beyond SMA144. |
| `strategy_atr_stop_cap_mult` | `2.0` | `0.1+` | Maximum initial stop distance in ATR units. |
| `strategy_atr_take_mult` | `3.0` | `0.1+` | Factory hard take-profit distance in ATR units. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target FX major with DWX M15 data.
- `GBPUSD.DWX` - card target FX major with DWX M15 data.
- `USDJPY.DWX` - card target FX major with DWX M15 data.
- `USDCHF.DWX` - card target FX major with DWX M15 data.
- `AUDUSD.DWX` - card target FX major with DWX M15 data.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX` - card is FX-major specific.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX` - card does not authorize metals or energy symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Expected trade frequency | Approximately 80 trades per year per symbol, from the card approval reasoning. |
| Typical hold time | Until Alligator Lips/Teeth reversal; not explicitly specified in frontmatter. |
| Expected drawdown profile | Trend-following whipsaw risk in ranging regimes, bounded by SMA144 stop capped at 2 ATR. |
| Regime preference | `trend-following` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b5a932a2-40b6-5628-840b-d5069ac35c4a`
**Source type:** `web compilation`
**Pointer:** Anonymous, "Alligator", Robo-forex Strategy Compilation, robofx.com, circa 2015, PDF pages 34-35.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11739_rfs-alligator-sma144-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 3aff5ab6-26c2-44d8-98b6-180d0898574f |
