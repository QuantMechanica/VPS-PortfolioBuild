# QM5_20065_pricebob-refbar-breakout-eurusd - Strategy Spec

**EA ID:** QM5_20065
**Slug:** `pricebob-refbar-breakout-eurusd`
**Source:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6` (ForexFactory PriceBob Strategy Thread 1331012)
**Author of this spec:** Gemini
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

QM5_20065 implements the PriceBob Reference-Bar Breakout strategy ported to EURUSD M15 at the London session open (08:00 broker time). 
The strategy establishes the day's reference range from the first M15 bar of London session (08:00 - 08:15 broker time).
Once the reference bar closes at 08:15:
1. Reference Range Validation:
   - `ref_range = ref_high - ref_low`
   - Filter 1 (too tight / spread dominated): `ref_range >= 0.3 * ATR(14, D1)`
   - Filter 2 (news spike / abnormally wide): `ref_range <= 2.5 * ATR(14, D1)`
   - Spread filter: Current spread must not exceed `20%` of `ref_range`.
2. Breakout Entry:
   - On subsequent closed M15 bars between 08:15 and 21:00 broker time, take the first qualifying bar close beyond the reference bar extremes:
     - Close > `ref_high` -> BUY Entry at market. Stop Loss = `ref_low` (opposite bar edge). Take Profit = `EntryPrice + 1.0 * ref_range` (measured move, 1:1 R:R).
     - Close < `ref_low` -> SELL Entry at market. Stop Loss = `ref_high` (opposite bar edge). Take Profit = `EntryPrice - 1.0 * ref_range` (measured move, 1:1 R:R).
   - Maximum of 1 trade per day (no re-entry on the same trading day).
3. Exits:
   - Hard Stop Loss or Take Profit hit.
   - Time Stop: Flatten open position at 21:00 broker time (session end) to prevent holding overnight.
   - Framework Friday close at 21:00 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ref_bar_hour` | 8 | 0-23 | Broker hour of the reference bar open (London open) |
| `strategy_ref_bar_minute` | 0 | 0-59 | Broker minute of the reference bar open |
| `strategy_d1_atr_period` | 14 | 5-30 | Daily ATR period for reference range sanity checks |
| `strategy_min_range_d1_atr_mult` | 0.3 | 0.1-1.0 | Minimum allowed reference range as fraction of D1 ATR |
| `strategy_max_range_d1_atr_mult` | 2.5 | 1.0-5.0 | Maximum allowed reference range as fraction of D1 ATR |
| `strategy_max_spread_range_ratio` | 0.20 | 0.05-0.50 | Maximum allowed spread as fraction of reference range |
| `strategy_session_end_hour` | 21 | 0-23 | Session end hour (broker time) to flatten and stop entries |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with clean London session opening expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` (for Daily ATR reference filter) |
| Bar gating | `QM_IsNewBar()` on M15 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120 |
| Typical hold time | 2 to 8 hours (same-day intraday) |
| Expected drawdown profile | Intraday false breakout chops bounded by 1:1 SL/TP and 21:00 time-stop |
| Regime preference | Opening range expansion / momentum |
| Target profit factor | 1.18 |

---

## 6. Source Citation

**Source ID:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`
**Source type:** Forum thread
**Pointer:** ForexFactory thread 1331012 "The PriceBob Strategy" (MeBob reference bar lineage)
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20065_pricebob-refbar-breakout-eurusd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | 0.5% of equity |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Initial build from approved card | Gemini draft for task 7e8c9eaa-1af5-40ca-9f49-4c785b5ae07d |
