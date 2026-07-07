# QM5_9283_mql5-keltner-break - Strategy Spec

**EA ID:** QM5_9283
**Slug:** mql5-keltner-break
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA builds a Keltner Channel on H1 using EMA(10) of typical price as the middle line and ATR(10) multiplied by 2.0 for the upper and lower bands. It opens long when the previous closed bar was below the previous upper band and the latest closed bar closes above the latest upper band. It opens short when the previous closed bar was above the previous lower band and the latest closed bar closes below the latest lower band. Positions use the source fixed band offsets for SL/TP and close early when a closed bar moves back inside the channel through the broken band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 10 | >=1 | EMA and ATR period used to construct the Keltner Channel. |
| `strategy_channel_multiplier` | 2.0 | >0 | ATR multiplier added to/subtracted from the EMA middle line. |
| `strategy_stop_offset_points` | 150 | >0 | Stop-loss offset from the broken Keltner band in MT5 points. |
| `strategy_take_offset_points` | 500 | >0 | Take-profit offset from the broken Keltner band in MT5 points. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target forex major with DWX H1 OHLC, EMA, and ATR data.
- `GBPJPY.DWX` - Card target forex cross with DWX H1 OHLC, EMA, and ATR data.
- `GDAXI.DWX` - Available DWX DAX custom symbol used in place of card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; registered `GDAXI.DWX` as the available DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Not specified in card frontmatter; exits via SL/TP or closed-bar recapture inside the channel. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk P2 sizing applies through the framework. |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/14169
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9283_mql5-keltner-break.md`

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
| v1 | 2026-07-07 | Initial build from card | c173eab0-c984-438e-a250-3efe958a18e1 |
