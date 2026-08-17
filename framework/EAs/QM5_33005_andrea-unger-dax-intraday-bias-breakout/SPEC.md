# QM5_33005_andrea-unger-dax-intraday-bias-breakout — Strategy Spec

**EA ID:** QM5_33005
**Slug:** andrea-unger-dax-intraday-bias-breakout
**Source:** andrea-unger-dax-intraday-bias-breakout-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

The strategy implements 4-time World Cup Trading Champion Andrea Unger's DAX opening range breakout system on M15 bars (`GDAXI.DWX`). The Frankfurt cash equity open creates persistent institutional trend expansion during the European morning session.

The 30-minute opening range is formed from 09:00 to 09:30 CET (10:00 to 10:30 broker time). At 10:30 broker open, buy stop and sell stop orders are placed 3.0 points beyond the range extremes. Positions are protected by a $0.60 \times Range_{30}$ stop loss, targeted at $1.80 \times Range_{30}$ take profit (1:3.0 R:R), and strictly force closed at the Frankfurt cash close at 17:30 CET (18:30 broker time).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_start_hhmm` | 1000 | 0900-1100 | Opening range calculation start time in broker HHMM (09:00 CET) |
| `strategy_range_end_hhmm` | 1030 | 0930-1130 | Opening range calculation end / order placement time (09:30 CET) |
| `strategy_exit_time_hhmm` | 1830 | 1700-1930 | Intraday forced position close time in broker HHMM (17:30 CET) |
| `strategy_breakout_offset` | 3.0 | 1.0-10.0 | Points buffer beyond 30m high/low range extreme |
| `strategy_sl_fraction` | 0.60 | 0.40-1.00 | Multiplier of 30m range for initial hard stop loss |
| `strategy_tp_fraction` | 1.80 | 1.00-3.00 | Multiplier of 30m range for initial take profit |
| `strategy_atr_period` | 14 | 10-20 | ATR period for spread filter evaluation |
| `strategy_spread_atr_mult` | 1.8 | 1.2-2.5 | Maximum allowable spread relative to ATR |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` (Primary, slot 0) — DAX 40 index CFD with high liquidity and distinct European cash open volatility.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | 2 to 8 hours |
| Expected drawdown profile | <= 15% peak-to-trough equity drawdown |
| Regime preference | Intraday European trend momentum / directional cash open expansion |
| Win rate target (qualitative) | Medium-High (55% to 70% with 1:3.0 R:R) |

---

## 6. Source Citation

**Source ID:** `andrea-unger-dax-intraday-bias-breakout-official-source`
**Source type:** Championship Trader Book
**Pointer:** Unger, A. (2018). The Unger Method: 4-Time World Cup Trading Champion.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_33005_andrea-unger-dax-intraday-bias-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | Router task fdac61ae-c7a2-407e-bfef-fdda420857f2 |
