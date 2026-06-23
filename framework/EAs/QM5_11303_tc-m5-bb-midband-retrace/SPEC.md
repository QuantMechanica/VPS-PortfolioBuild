# QM5_11303_tc-m5-bb-midband-retrace - Strategy Spec

**EA ID:** QM5_11303
**Slug:** `tc-m5-bb-midband-retrace`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see local PDF archive citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades a Bollinger Band middle-band retrace on M5. A long signal requires the BB(20,2) middle band to slope upward over three closed bars, then the just-closed bar must touch or cross the middle band with its low while closing at or above the middle band. A short signal mirrors the rule with a downward middle-band slope and a bar high touching the middle band while closing at or below it. Entries are market orders on the next bar; TP is the opposite Bollinger Band at order time and SL is the entry-side band capped to a maximum 15-pip risk.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 14-20 planned P3 sweep | Bollinger Band period; the middle band is the SMA used for slope and touch rules. |
| `strategy_bb_deviation` | 2.0 | fixed by card | Bollinger Band standard-deviation multiplier. |
| `strategy_slope_lookback` | 3 | 1, 3, 5 planned P3 sweep | Closed-bar lookback for the middle-band slope comparison. |
| `strategy_bb_min_width_pips` | 10 | card fixed | Minimum upper-lower band width required before entries are allowed. |
| `strategy_sl_max_pips` | 15 | card fixed | Maximum stop-loss distance in pips; tighter of band stop and this cap is used. |
| `strategy_spread_cap_pips` | 3.0 | card fixed | Maximum live spread in pips; zero modeled .DWX spread does not block trading. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 names EURUSD as a directly testable M5 major-pair target.
- `GBPUSD.DWX` - Card R3 names GBPUSD as a directly testable M5 major-pair target.

**Explicitly NOT for:**
- `GBPJPY.DWX` - The narrative instruments list mentions GBPJPY, but the R3 PASS / P2 basket explicitly limits baseline registration to EURUSD.DWX and GBPUSD.DWX.
- Non-DWX symbols - Research and backtest artifacts must use the canonical `.DWX` symbol matrix names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` from card frontmatter |
| Typical hold time | Not specified in frontmatter; M5 band-to-band exits imply intraday holds |
| Expected drawdown profile | Not specified in frontmatter; fixed 15-pip max SL bounds individual trade risk |
| Regime preference | Trend pullback / dynamic support-resistance from card concepts |
| Win rate target (qualitative) | Not specified in frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `local PDF archive`
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, 2014, "20 Forex Trading Strategies (5 Minute Time Frame)", System #4
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11303_tc-m5-bb-midband-retrace.md`

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
| v1 | 2026-06-23 | Initial build from card | 7bf51ff4-7bdb-4c80-96b9-8061e029da43 |
