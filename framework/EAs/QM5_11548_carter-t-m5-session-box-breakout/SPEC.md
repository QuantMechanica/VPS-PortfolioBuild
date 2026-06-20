# QM5_11548_carter-t-m5-session-box-breakout — Strategy Spec

**EA ID:** QM5_11548
**Slug:** carter-t-m5-session-box-breakout
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

On each M5 bar, the EA checks for the broker-time 15:00 bar. At that time it reads the just-closed H1 candle as the session box, then places a BuyStop at the box high plus 20% of the box height and a SellStop at the box low minus 20% of the box height. The long stop loss is the box low and the short stop loss is the box high; profit targets are four box heights from the corresponding box extreme. Pending orders expire after one hour and no new orders are placed on Fridays.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_hour_broker` | 15 | 0-23 | Broker-time hour used for the daily signal. |
| `strategy_signal_minute_broker` | 0 | 0-59 | Broker-time minute used for the daily signal. |
| `strategy_breakout_box_pct` | 0.20 | >0 | Fraction of box height added beyond the high or low for stop entry placement. |
| `strategy_tp_box_mult` | 4.0 | >0 | Box-height multiple used for target placement from the box extreme. |
| `strategy_pending_expiry_minutes` | 60 | >=1 | Pending order lifetime after the 15:00 signal. |
| `strategy_max_box_pips` | 50 | 0 disables, otherwise >0 | Maximum allowed H1 box height in pips for the P2 stop cap. |
| `strategy_max_spread_pips` | 5 | 0 disables, otherwise >0 | Maximum allowed spread in pips; zero modeled DWX spread passes. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — The card lists GBP/USD as one of the source strategy's best instruments and it is available in the DWX matrix.
- `GBPJPY.DWX` — The card lists GBP/JPY as one of the source strategy's best instruments and it is available in the DWX matrix.

**Explicitly NOT for:**
- Non-GBP DWX symbols — The source card names GBPUSD and GBPJPY only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 just-closed session-box candle |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Pending order valid for 1 hour; filled trades exit by SL/TP or framework Friday close. |
| Expected drawdown profile | Intraday breakout risk bounded by the opposite side of the H1 session box, with a 50-pip P2 box-height cap. |
| Regime preference | Volatility expansion / breakout after the 15:00 DWX session box. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", self-published 2014, System #7.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11548_carter-t-m5-session-box-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | d3243ce1-6208-4b97-ad42-8d44e475ca1f |
