# QM5_11318_tc-m5-10-ema40-80-cci — Strategy Spec

**EA ID:** QM5_11318
**Slug:** `tc-m5-10-ema40-80-cci`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

M5 trend-following with a confirming oscillator trigger. The EMA(40) versus
EMA(80) relationship on the last closed bar defines the allowed direction: longs
only while EMA(40) > EMA(80), shorts only while EMA(40) < EMA(80). The trade is
triggered by a single event — CCI(21) crossing the zero line in the trend
direction. LONG fires when the just-closed bar has CCI crossing up through 0
(`cci[2] <= 0 && cci[1] > 0`) inside an up-trend; SHORT mirrors it
(`cci[2] >= 0 && cci[1] < 0`) inside a down-trend. The EMA stack is the
confirming STATE, not a second event, so the two-cross-same-bar zero-trade trap
is avoided. Stop and take are symmetric fixed-pip distances (baseline 12/12,
RR ~1.0). There is no separate indicator exit — the fixed SL/TP closes the
position. One open position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 40 | 20-60 | Trend-direction fast EMA period |
| `strategy_ema_slow_period` | 80 | 60-120 | Trend-direction slow EMA period |
| `strategy_cci_period` | 21 | 10-30 | CCI period for the zero-cross trigger |
| `strategy_cci_zero_level` | 0.0 | -20-20 | CCI cross level (zero line) |
| `strategy_sl_pips` | 12 | 10-15 | Stop-loss distance in pips |
| `strategy_tp_rr` | 1.0 | 0.8-1.5 | Take-profit as R-multiple of the stop (12/12 = 1.0) |
| `strategy_spread_pct_of_stop` | 20.0 | 5-50 | Skip entry if spread exceeds this % of stop distance (fail-open on .DWX) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, deep liquidity, card primary target
- `GBPUSD.DWX` — major FX pair, card target, trends well on M5
- `USDJPY.DWX` — major FX pair, card target; pip-scale handled via `QM_StopFixedPips`

**Explicitly NOT for:**
- Index/commodity `.DWX` symbols — source is an M5 forex system; SL/TP pip baseline is FX-calibrated

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~160` |
| Typical hold time | `minutes to a few hours (M5, 12-pip targets)` |
| Expected drawdown profile | `frequent small wins/losses; symmetric 12/12 → ~50% win rate needed plus cost edge` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #10, page 26 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11318_tc-m5-10-ema40-80-cci.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
