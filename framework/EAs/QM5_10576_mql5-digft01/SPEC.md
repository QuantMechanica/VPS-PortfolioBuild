# QM5_10576_mql5-digft01 - Strategy Spec

**EA ID:** QM5_10576
**Slug:** `mql5-digft01`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes the DigitalF-T01 oscillator from the published 24-coefficient price filter on the close of each H3 bar. It computes the DigitalF-T01 trigger line from the prior same-day anchor close plus or minus the configured half-channel, matching the source indicator's cloud relation. A long entry is opened when the latest closed signal bar crosses from below the trigger to above it; a short entry is opened when it crosses from above the trigger to below it. Existing positions close on the opposite closed-bar cross, while the framework handles the ATR hard stop, 1.5R target, Friday close, news exits, and kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H3` | H3/H4/H6/H8 sweep candidates | Timeframe used for DigitalF-T01 signal calculation. |
| `strategy_signal_bar` | `1` | >= 1 | Closed bar shift used for signal confirmation. |
| `strategy_halfchannel_points` | `25` | > 0 | Half-channel distance in points used by the trigger/cloud calculation. |
| `strategy_applied_price` | `PRICE_CLOSE` | MT5 applied price enum | Price series fed into the DigitalF-T01 oscillator. |
| `strategy_atr_period` | `14` | > 0 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | > 0 | ATR multiplier for the hard stop. |
| `strategy_take_profit_rr` | `1.5` | > 0 | Fixed reward/risk target relative to the ATR stop. |
| `strategy_max_spread_points` | `0` | >= 0 | Optional spread cap; zero disables the strategy-level spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - Source test symbol and part of the approved R3 FX/metals basket.
- `EURUSD.DWX` - Major FX pair in the approved portable R3 basket.
- `GBPUSD.DWX` - Major FX pair in the approved portable R3 basket.
- `XAUUSD.DWX` - Liquid metal symbol in the approved portable R3 basket.

**Explicitly NOT for:**
- Other `.DWX` symbols - Not listed in the card's Primary P2 basket for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H3` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Not specified in card; exits are opposite closed-bar cross, ATR stop, 1.5R target, Friday close, or news/kill-switch exit. |
| Expected drawdown profile | Moderate oscillator-cross drawdown profile; bounded by ATR(14) 2.0 hard stop. |
| Regime preference | Oscillator/cloud cross regime; suited to moderate directional swings. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/14136`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10576_mql5-digft01.md`

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
| v1 | 2026-05-29 | Initial build from card | e23207a6-4898-4ac5-90e9-d1592fdf7341 |
