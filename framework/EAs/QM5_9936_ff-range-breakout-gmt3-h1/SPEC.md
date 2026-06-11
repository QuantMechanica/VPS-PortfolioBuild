# QM5_9936_ff-range-breakout-gmt3-h1 - Strategy Spec

**EA ID:** QM5_9936
**Slug:** `ff-range-breakout-gmt3-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA builds the completed 01:00-06:00 GMT+3 H1 range for the current trading day. At 06:00 GMT+3 it places a buy stop at the range high and a sell stop at the range low, with the initial stop on the opposite side of the range and no fixed take profit. It skips the day when the range height is below 0.4 x ATR(14,H1) or above 2.5 x ATR(14,H1). Open trades close at 20:00 GMT+3, on an opposite range-side touch, or trail to the prior two completed H1 lows/highs after price has moved at least +1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hour_gmt3` | 1 | 0-23 | First GMT+3 hour included in the range. |
| `strategy_range_end_hour_gmt3` | 6 | 1-24 | First GMT+3 hour after the range and the order placement hour. |
| `strategy_order_cancel_hour_gmt3` | 13 | 0-23 | GMT+3 hour at which untriggered stop orders are removed. |
| `strategy_session_close_hour_gmt3` | 20 | 0-23 | GMT+3 hour at which open positions are closed. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for range-height filters. |
| `strategy_min_range_atr_mult` | 0.4 | >0 | Minimum range height as a multiple of ATR(14,H1). |
| `strategy_max_range_atr_mult` | 2.5 | >0 | Maximum range height and hard SL cap as a multiple of ATR(14,H1). |
| `strategy_trail_trigger_r` | 1.0 | >=0 | Profit in R before the prior-two-bar trailing stop starts. |
| `strategy_range_scan_bars` | 36 | >=6 | Closed H1 bars scanned to reconstruct the current GMT+3 session range. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - card R3 lists USDJPY and the symbol is present in the DWX matrix.
- `GBPUSD.DWX` - card R3 lists GBPUSD and the symbol is present in the DWX matrix.
- `NDX.DWX` - card R3 maps NAS100 exposure to the DWX Nasdaq 100 symbol.

**Explicitly NOT for:**
- Symbols outside the card's R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `140` |
| Typical hold time | Same-day intraday hold, from 06:00 GMT+3 entry window until no later than 20:00 GMT+3. |
| Expected drawdown profile | Fixed-risk breakout losses bounded by the completed 01:00-06:00 GMT+3 range. |
| Regime preference | Breakout / volatility-expansion days after a valid overnight range. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/1299658-range-breakout-system`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9936_ff-range-breakout-gmt3-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 2f252da4-be9f-496c-9857-801bbeae294f |
