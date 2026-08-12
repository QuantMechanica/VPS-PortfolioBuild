# QM5_11494_carter-t-mtf-triple-ema-bb-align-m5h1 — Strategy Spec

**EA ID:** QM5_11494
**Slug:** `carter-t-mtf-triple-ema-bb-align-m5h1`
**Source:** `b3b11449-1e72-5140-917b-c35b6253f1e7`
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each closed M5 bar, the EA buys when EMA(14) is above EMA(21), EMA(21) is above EMA(50), and the same bullish ordering is present on H1. It also requires EMA(50) to remain inside the 20-period Bollinger envelope on both timeframes, then enters after the M5 bar touches EMA(14) or EMA(21) and closes bullish; sells use the mirrored rules. Positions exit through a 1.5× ATR(14) stop or 2.0× ATR(14) target, each capped at 20 pips, plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 14 | fixed baseline | Fast EMA on M5 and H1. |
| `strategy_ema_mid_period` | 21 | fixed baseline | Middle EMA on M5 and H1. |
| `strategy_ema_slow_period` | 50 | fixed baseline | Slow EMA on M5 and H1. |
| `strategy_bb_period` | 20 | fixed baseline | Bollinger Band lookback on M5 and H1. |
| `strategy_bb_deviation` | 20.0 | 2.0–20.0 | Bollinger deviation; the card baseline is 20.0. |
| `strategy_use_h1_filter` | true | true/false | Require H1 triple-EMA alignment. |
| `strategy_use_bb_filter` | true | true/false | Require EMA(50) inside the Bollinger envelope. |
| `strategy_touch_ema21_too` | true | true/false | Accept a pullback to EMA(14) or EMA(21); false limits the test to EMA(14). |
| `strategy_atr_period` | 14 | fixed baseline | ATR period used for stop and target. |
| `strategy_sl_atr_mult` | 1.5 | 1.0–2.0 | ATR multiplier for the stop distance. |
| `strategy_tp_atr_mult` | 2.0 | fixed baseline | ATR multiplier for the target distance. |
| `strategy_sl_cap_pips` | 20 | fixed baseline | Maximum stop distance in scale-correct pips. |
| `strategy_tp_cap_pips` | 20 | fixed baseline | Maximum target distance in scale-correct pips. |
| `strategy_spread_cap_pips` | 15 | fixed baseline | Block entry only when the quoted spread exceeds 15 pips. |
| `strategy_no_friday_entry` | true | true/false | Prevent new Friday entries while leaving management active. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — the exact Darwinex backtest symbol for the EUR/USD instrument named by the source card.

**Explicitly NOT for:**
- Other `.DWX` symbols — the approved card names EUR/USD only and does not authorize basket expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H1` EMA(14/21/50) ordering and BB(20,20) containment |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the canonical skeleton on an M5 setfile |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 50 |
| Typical hold time | intraday to several hours, inferred from the M5 signal and ATR exits |
| Expected drawdown profile | losses can cluster when M5 pullbacks reverse an apparently aligned trend |
| Regime preference | directional trends aligned across M5 and H1 |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b3b11449-1e72-5140-917b-c35b6253f1e7`
**Source type:** self-published book
**Pointer:** `[[sources/carter-thomas-20-forex-m5]]`; Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)*, System #6 (2014)
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11494_carter-t-mtf-triple-ema-bb-align-m5h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-02 | Initial build from card | cd08bccc-f823-4bee-a4da-cc1ecfb0abe6 |
