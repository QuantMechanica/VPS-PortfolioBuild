# QM5_11493_carter-t-bb-slope-midline-bounce-m5 - Strategy Spec

**EA ID:** QM5_11493
**Slug:** `carter-t-bb-slope-midline-bounce-m5`
**Source:** `b3b11449-1e72-5140-917b-c35b6253f1e7` (see `sources/carter-thomas-20-forex-m5`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades a Bollinger Band continuation pullback on M5. A long signal requires the BB(20,2) middle band to be sloping up, the last closed candle low to touch or cross the middle band, and that candle to close back above the middle band; short is the mirrored rule with a falling middle band, a high touching the middle band, and a close back below it. The EA enters at market on the next bar, sets take profit at the opposite outer Bollinger Band, and sets stop loss at the same-side outer band capped to 15 pips if the band is farther away. There is no discretionary exit beyond the entry-time SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 15-25 in P3 sweep | Bollinger Band period for the middle SMA and outer bands. |
| `strategy_bb_deviation` | 2.0 | fixed by card | Bollinger Band standard deviation multiplier. |
| `strategy_slope_lookback` | 3 | 2-5 in P3 sweep | Bars back used to compare the middle band slope state. |
| `strategy_sl_pip_cap` | 15.0 | 10-20 in P3 sweep | Maximum stop distance in pips; the tighter of band stop or this cap is used. |
| `strategy_spread_cap_pips` | 15.0 | card fixed | Maximum live modeled spread in pips; zero spread in DWX tester is allowed. |
| `strategy_block_friday` | true | true/false | Suppresses new entries on broker-time Friday per card. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed M5 FX major with DWX history.
- `GBPUSD.DWX` - card-listed M5 FX major with DWX history.
- `GBPJPY.DWX` - card-listed M5 FX cross with DWX history.

**Explicitly NOT for:**
- Non-FX index or commodity `.DWX` symbols - not part of the Carter M5 Forex card basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, usually minutes to a few hours on M5. |
| Expected drawdown profile | Tight capped stops with frequent small losses during choppy, flat midline regimes. |
| Regime preference | Trend-continuation pullback. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b3b11449-1e72-5140-917b-c35b6253f1e7`
**Source type:** book / self-published ebook
**Pointer:** `sources/carter-thomas-20-forex-m5`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11493_carter-t-bb-slope-midline-bounce-m5.md`

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
| v1 | 2026-06-23 | Initial build from card | 0dbbcdba-bbe5-41be-8005-903234a0dd03 |
