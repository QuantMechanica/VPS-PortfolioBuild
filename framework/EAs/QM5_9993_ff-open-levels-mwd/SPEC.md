# QM5_9993_ff-open-levels-mwd - Strategy Spec

**EA ID:** QM5_9993
**Slug:** `ff-open-levels-mwd`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `artifacts/cards_approved/QM5_9993_ff-open-levels-mwd.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades M30 closed-bar reactions to the UTC daily, weekly, and monthly opening prices. A long breakout requires the last closed bar to cross above the daily open while also closing above the weekly and monthly opens, with RSI(14) above 50; the short breakout mirrors this below the same levels. Bounce entries use a bar touch within 0.15 ATR(14) of any of the three open levels, a close back through the level, price on the correct side of at least two open levels, and the same RSI confirmation. Exits use the broker SL/TP, opposite daily-open breakout with opposite RSI confirmation, UTC session rollover, 24 M30 bars, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI period for breakout and bounce confirmation. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for bounce tolerance, spread guard, and stop distance bounds. |
| `strategy_touch_atr_mult` | 0.15 | 0.01-2.00 | Maximum distance from an open level for bounce qualification, expressed in ATR. |
| `strategy_rsi_midline` | 50.0 | 1.0-99.0 | RSI threshold for long/short confirmation. |
| `strategy_min_stop_atr` | 1.0 | 0.1-10.0 | Minimum stop distance as an ATR multiple. |
| `strategy_max_stop_atr` | 2.5 | 0.1-10.0 | Maximum permitted stop distance as an ATR multiple. |
| `strategy_fallback_rr` | 1.5 | 0.1-10.0 | Fallback reward/risk target when no qualifying key level exists beyond entry. |
| `strategy_time_stop_bars` | 24 | 1-200 | Maximum hold in M30 bars. |
| `strategy_max_spread_atr` | 0.25 | 0.0-5.0 | Blocks only genuinely wide modeled spread relative to ATR; zero spread remains tradable. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card emphasizes gold-style open-level examples and R3 includes it.
- `XTIUSD.DWX` - card emphasizes oil-style open-level examples and R3 includes it.
- `EURUSD.DWX` - portable FX major in the approved R3 basket.
- `GBPUSD.DWX` - portable FX major in the approved R3 basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of this card's R3 basket.
- `NDX.DWX` - not part of this card's R3 basket.
- `WS30.DWX` - not part of this card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | Same UTC session or up to 24 M30 bars, about 12 hours. |
| Expected drawdown profile | ATR-bounded open-level breakout and bounce losses; trades are skipped when required stop distance exceeds 2.5 ATR. |
| Regime preference | Breakout and rejection around daily, weekly, and monthly UTC open levels. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/1328051-trading-system-based-on-monthly-weekly-and-daily`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9993_ff-open-levels-mwd.md`

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
| v1 | 2026-06-25 | Initial build from card | 64e56a52-037a-4a37-801d-2aa1496dbf2d |
