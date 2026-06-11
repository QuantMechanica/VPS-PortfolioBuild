# QM5_11478_williams-l-smash-day-d1 - Strategy Spec

**EA ID:** QM5_11478
**Slug:** williams-l-smash-day-d1
**Source:** b943674a-985e-5634-8420-47a9412c3ab5
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades Larry Williams' D1 Smash Day reversal pattern. A bearish setup requires the last closed bar to make a higher high, higher low, and higher close than the prior bar while closing in the lower half of its own range; the EA places a sell stop one pip below that bar's low. A bullish setup mirrors the rule with a lower high, lower low, lower close, and a close in the upper half of the bar; the EA places a buy stop one pip above that bar's high. Each pending order is valid for one D1 bar, uses the opposite Smash Day extreme plus one pip as stop loss with an 80-pip cap, takes profit at 1.5 times the Smash Day range, and closes any still-open position after three D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_close_half_threshold` | 0.50 | 0.01-0.99 | Fraction of bar range used to test lower-half or upper-half Smash Day closes. |
| `strategy_entry_offset_pips` | 1.0 | >0 | Pip offset beyond the Smash Day high or low for stop entry and structural SL. |
| `strategy_tp_range_mult` | 1.50 | >0 | Take-profit distance as a multiple of the Smash Day bar range from entry. |
| `strategy_time_stop_bars` | 3 | >=1 | Maximum D1 bars to hold an open position before strategy close. |
| `strategy_max_sl_pips` | 80.0 | >0 | P2 maximum stop-loss distance in pips. |
| `strategy_spread_cap_pips` | 25.0 | >0 | Maximum allowed current spread in pips. |
| `strategy_use_atr_filter` | false | true/false | Optional above-average range filter from the card. |
| `strategy_atr_period` | 14 | >=1 | ATR period used when the optional range filter is enabled. |
| `strategy_atr_range_mult` | 1.20 | >0 | Required Smash Day range multiple of ATR when the optional range filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid DWX FX major with D1 history.
- `GBPUSD.DWX` - Card-listed liquid DWX FX major with D1 history.
- `USDJPY.DWX` - Card-listed liquid DWX FX major with D1 history.
- `AUDUSD.DWX` - Card-listed liquid DWX FX major with D1 history.
- `USDCAD.DWX` - Card-listed liquid DWX FX major with D1 history.

**Explicitly NOT for:**
- Non-DWX symbols - Build and pipeline artifacts must use matrix-verified `.DWX` symbols.
- Non-FX symbols - The card's R3 universe is D1 DWX FX, not indices or commodities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Expected trade frequency | Roughly monthly to twice monthly per symbol, depending on stop-entry fills. |
| Typical hold time | Up to 3 D1 bars. |
| Expected drawdown profile | Bar-reversal strategy with capped per-trade fixed risk and failed-breakout losses when follow-through does not appear. |
| Regime preference | D1 failed-continuation reversal after apparent range expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b943674a-985e-5634-8420-47a9412c3ab5
**Source type:** book/workshop
**Pointer:** Larry Williams, Inner Circle Workshop Trading Method local PDF; approved card at `artifacts/cards_approved/QM5_11478_williams-l-smash-day-d1.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11478_williams-l-smash-day-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 221d5058-9a7c-47bb-9bf8-cf353fc57d5e |
