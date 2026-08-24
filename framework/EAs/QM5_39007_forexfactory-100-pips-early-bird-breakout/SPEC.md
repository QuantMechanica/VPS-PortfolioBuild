# QM5_39007_forexfactory-100-pips-early-bird-breakout — Strategy Spec

**EA ID:** QM5_39007
**Slug:** `forexfactory-100-pips-early-bird-breakout`
**Source:** `forexfactory-100-pips-early-bird-breakout-official-source`
**Author of this spec:** Development
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

The strategy implements Robb's 100 Pips Today Early Bird London Breakout system on the 15-minute (M15) timeframe. At the opening of the 07:00 UTC bar it establishes the high and low of the eight completed M15 bars in `[05:00, 07:00)` UTC and places a pending-stop straddle.

The BUY_STOP is three pips above the box high and the SELL_STOP is three pips below the box low. Both carry a fixed 25-pip stop, a 100-pip broker TP2, and expiration at 12:00 UTC. A fill cancels the opposite pending leg (OCO). At +50 pips the EA closes 50% as TP1; the remainder retains TP2 and moves to entry +1 pip after a +20-pip move. Noon cancels only unfilled pending orders; it does not force-close active positions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpBoxStartHourUTC` | 5 | 4-6 | Asian range box start hour (UTC) |
| `InpBoxEndHourUTC` | 7 | 6-8 | Asian range box end / breakout start hour (UTC) |
| `InpSessionEndHourUTC` | 12 | 11-14 | London morning session end hour (UTC) |
| `InpBufferPips` | 3.0 | 1.0-5.0 | Breakout buffer in pips |
| `InpStopLossPips` | 25.0 | 15.0-40.0 | Default stop loss in pips |
| `InpTakeProfitPips` | 50.0 | fixed card target | TP1 distance in pips |
| `InpTakeProfit2Pips` | 100.0 | fixed card target | Broker TP2 distance in pips |
| `strategy_atr_period` | 14 | 7-28 | ATR period on M15 |
| `strategy_be_trigger_pips` | 20 | 10-30 | Break-even trigger distance in pips |
| `strategy_tp1_close_fraction` | 0.50 | `(0,1)` | Fraction closed at TP1 |
| `strategy_daily_loss_halt_pct` | 2.0 | `>0, <=2.0` | Account realized-loss entry halt |
| `strategy_daily_hard_stop_pct` | 2.5 | `>= daily halt, <=2.5` | Daily equity flatten/halt |
| `strategy_total_dd_halt_pct` | 5.0 | `>= daily hard stop, <=5.0` | Initial-equity drawdown flatten/halt |
| `strategy_per_trade_risk_cap_pct` | 1.0 | `(0,1]` | Framework per-trade risk ceiling |
| `strategy_slippage_ticks` | 3.0 | `(0,3]` | Entry deviation ceiling in ticks |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — Primary currency pair with high London open volatility and strong directional breakout follow-through.
- `EURUSD.DWX` — High-liquidity FX pair with reliable European session opening ranges.

**Explicitly NOT for:**
- Non-DWX symbols absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Card-defined SL/TP lifecycle; no noon force-close |
| Expected drawdown profile | < 3.0% maximum drawdown |
| Regime preference | London session opening range expansion and trend day continuation |
| Win rate target (qualitative) | High (70-75% win rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-100-pips-early-bird-breakout-official-source`
**Source type:** `forum`
**Pointer:** `Robb (2008-2024). 100 Pips Today Early Bird. Forex Factory.`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_39007_forexfactory-100-pips-early-bird-breakout.md`

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
| v1 | 2026-08-18 | Initial build from card | Gemini build pass |
| v2 | 2026-08-24 | Review rework | M15 contract, exact box, pending straddle/OCO, pip units, TP1/TP2, and loss controls repaired |
