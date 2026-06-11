# QM5_11399_naked-forex-big-belt-d1 - Strategy Spec

**EA ID:** QM5_11399
**Slug:** naked-forex-big-belt-d1
**Source:** 94a3a139-a123-57c2-ae40-b5513532e244
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the Naked Forex Big Belt daily reversal candle. A bearish setup requires the prior closed D1 bar to gap open above the previous close, open in the top third, close in the bottom third, and make a fresh 20-bar high; it places a sell stop 5 pips below that candle's low. A bullish setup mirrors the rule at a 20-bar low and places a buy stop 5 pips above the candle's high. The stop is beyond the opposite Big Belt extreme plus 5 pips, capped at 100 pips for P2, the take profit is ATR(14) x 2.5 from entry, and open trades move to break-even after a 1 x ATR favorable move.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_extreme_lookback_bars | 20 | 1+ | Prior closed D1 bars used for the high/low zone proxy. |
| strategy_atr_period | 14 | 1+ | ATR period used for take profit and break-even trigger. |
| strategy_atr_tp_mult | 2.5 | >0 | ATR multiple added from entry for the take-profit target. |
| strategy_entry_offset_pips | 5 | 1+ | Pip offset beyond the Big Belt high/low for stop entry and initial stop placement. |
| strategy_sl_cap_pips | 100 | 0+ | Maximum initial stop distance in pips; 0 disables the cap. |
| strategy_spread_cap_pips | 30 | 0+ | Maximum allowed spread in pips; 0 disables the spread filter. |
| strategy_be_buffer_pips | 0 | 0+ | Extra pips beyond entry when moving stop to break-even. |
| strategy_order_expiration_bars | 1 | 1+ | Number of D1 bars before an unfilled stop order expires. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX pair with D1 DWX data.
- GBPUSD.DWX - Card-listed major FX pair with D1 DWX data.
- USDJPY.DWX - Card-listed major FX pair with D1 DWX data.
- AUDUSD.DWX - Card-listed major FX pair with D1 DWX data.
- GBPJPY.DWX - Card-listed FX cross with D1 DWX data.

**Explicitly NOT for:**
- Index, metal, energy, and non-card FX symbols - not listed in the approved card's instrument set for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | days; exits are ATR target, capped SL, break-even movement, or framework Friday close |
| Expected drawdown profile | sparse daily reversal trades with capped per-trade stop distance |
| Regime preference | exhaustion / mean-reversion after daily gap excitement |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 94a3a139-a123-57c2-ae40-b5513532e244
**Source type:** book
**Pointer:** Alex Nekritin & Walter Peters, Naked Forex, Wiley 2012, Chapter 9; local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\531226675-Naked-Forex.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11399_naked-forex-big-belt-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 2e0fce62-c5d8-4ca1-9d37-727e0398a592 |
