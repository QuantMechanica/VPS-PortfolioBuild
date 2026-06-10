# QM5_9360_mql5-ichi-kumo-cross — Strategy Spec

**EA ID:** QM5_9360
**Slug:** `mql5-ichi-kumo-cross`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Implements Pattern 2 ("Senkou Span A/B Crossover with ADX Confirmation") from the MQL5 article by Stephen Njuki.

Entry signals are generated on the close of a new M30 bar when the Ichimoku cloud undergoes a "kumo twist" — the two Senkou Spans cross — combined with ADX(14) >= 25 confirming trend strength.

**Buy entry:** SenkouSpanA crosses above SenkouSpanB on the most recently closed bar (SenkouSpanA[2] < SenkouSpanB[2] AND SenkouSpanA[1] > SenkouSpanB[1]) with ADX(14)[1] >= 25. Cloud thickness must be >= 0.5 * ATR(14) to avoid thin-cloud false signals.

**Sell entry:** SenkouSpanA crosses below SenkouSpanB on the most recently closed bar with ADX(14)[1] >= 25. Same cloud thickness filter applies.

**Stop loss:** Placed below the cloud bottom minus 1.0 * ATR(14) for longs; above the cloud top plus 1.0 * ATR(14) for shorts.

**Exit:** (a) Opposite kumo twist detected (SenkouSpanA/B re-cross in reverse direction), or (b) time stop after 96 M30 bars (~48 hours) if no other exit fires, or (c) SL hit by market. No TP; position held until signal reversal or time limit.

**One-position constraint:** At most one open position per symbol/magic. New entry signals are ignored while a position is open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 5-20 | Tenkan-sen (Conversion Line) period |
| `strategy_kijun_period` | 26 | 10-40 | Kijun-sen (Base Line) period; also the Senkou displacement |
| `strategy_senkou_period` | 52 | 26-80 | Senkou Span B lookback period |
| `strategy_adx_period` | 14 | 7-20 | ADX-Wilder smoothing period |
| `strategy_adx_min` | 25.0 | 15.0-40.0 | Minimum ADX to allow entry (trend strength gate) |
| `strategy_atr_period` | 14 | 7-21 | ATR period for cloud thickness filter and SL placement |
| `strategy_cloud_min_atr_mult` | 0.5 | 0.2-1.5 | Cloud thickness must be >= mult * ATR; prevents thin-cloud entries |
| `strategy_sl_atr_mult` | 1.0 | 0.5-3.0 | SL placed mult*ATR beyond cloud edge |
| `strategy_max_hold_bars` | 96 | 24-240 | Maximum M30 bars before time-stop exit |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — liquid major pair, responsive to kumo twist signals on M30
- `EURUSD.DWX` — liquid major pair, tight spreads relative to ATR-based SL
- `USDJPY.DWX` — liquid major pair, trend-prone behaviour suits Ichimoku
- `XAUUSD.DWX` — trending commodity with frequent kumo formations on M30

**Explicitly NOT for:**
- SP500.DWX — backtest-only symbol; not live-routable
- Low-liquidity pairs with wide spreads relative to ATR cloud stops

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 |
| Typical hold time | 4-48 hours (up to 96 M30 bars) |
| Expected drawdown profile | Moderate; ATR-based SL below cloud keeps individual trade risk bounded |
| Regime preference | Trend / cloud-breakout |
| Win rate target (qualitative) | low-medium; compensated by hold through trending moves |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum / article
**Pointer:** https://www.mql5.com/en/articles/18723 — Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 73): Using Patterns of Ichimoku and the ADX-Wilder", 2025-07-04, Pattern 2.
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9360_mql5-ichi-kumo-cross.md`

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
| v1 | 2026-06-10 | Initial build from card | task 21e79a69-9078-478a-9856-362a2785d471 |
