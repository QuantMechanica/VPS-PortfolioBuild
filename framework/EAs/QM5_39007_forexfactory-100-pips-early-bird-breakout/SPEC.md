# QM5_39007_forexfactory-100-pips-early-bird-breakout — Strategy Spec

**EA ID:** QM5_39007
**Slug:** `forexfactory-100-pips-early-bird-breakout`
**Source:** `forexfactory-100-pips-early-bird-breakout-official-source`
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy implements Robb's 100 Pips Today Early Bird London Breakout system on the 15-minute (M15) timeframe. It establishes the high and low range of the Asian tail session between 05:00 and 07:00 GMT (UTC) and evaluates directional breakouts during the London morning window between 07:00 and 12:00 GMT.

Long entry executes when price breaks above the 05:00-07:00 box high plus a 3.0-pip buffer. Short entry executes when price breaks below the box low minus a 3.0-pip buffer. Stop loss is set to 25.0 pips (clamped between 0.5 and 3.5 ATR), and take profit is targeted at 50.0 pips (1:2.0 R:R). Open trades move to break-even after advancing 20 pips into profit, and any remaining open positions or sessions are closed at 12:00 GMT daily.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpBoxStartHourUTC` | 5 | 4-6 | Asian range box start hour (UTC) |
| `InpBoxEndHourUTC` | 7 | 6-8 | Asian range box end / breakout start hour (UTC) |
| `InpSessionEndHourUTC` | 12 | 11-14 | London morning session end hour (UTC) |
| `InpBufferPips` | 3.0 | 1.0-5.0 | Breakout buffer in pips |
| `InpStopLossPips` | 25.0 | 15.0-40.0 | Default stop loss in pips |
| `InpTakeProfitPips` | 50.0 | 30.0-100.0 | Default take profit in pips |
| `strategy_atr_period` | 14 | 7-28 | ATR period on M15 |
| `strategy_be_trigger_pips` | 20.0 | 10.0-30.0 | Break-even trigger distance in pips |

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
| Typical hold time | 1-5 hours |
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
