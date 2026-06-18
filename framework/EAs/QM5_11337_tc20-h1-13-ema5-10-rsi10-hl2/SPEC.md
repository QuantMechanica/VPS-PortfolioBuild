# QM5_11337_tc20-h1-13-ema5-10-rsi10-hl2 — Strategy Spec

**EA ID:** QM5_11337
**Slug:** `tc20-h1-13-ema5-10-rsi10-hl2`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On the close of each H1 bar the EA looks for a fresh EMA(5)/EMA(10) crossover —
this is the single trigger event. A bullish cross (EMA5 crossing above EMA10)
opens a long; a bearish cross (EMA5 crossing below EMA10) opens a short. Momentum
is confirmed by RSI(10) computed on the bar median price (H+L)/2: a long also
requires RSI to sit at or above the 50 midline, a short requires RSI at or below
50. Each trade carries a fixed 30-pip stop loss and a fixed 50-pip take profit
attached at entry; there is no discretionary or trailing exit. The card prose
asks for a simultaneous RSI-cross-of-50, but two fresh cross events rarely
coincide on .DWX (zero-trade trap), so RSI-vs-50 is implemented as a directional
state filter rather than a second cross event.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | PERIOD_H1 | H1 | Signal timeframe (card base TF) |
| `strategy_fast_ema_period` | 5 | 2-20 | Fast EMA (yellow) period |
| `strategy_slow_ema_period` | 10 | 5-50 | Slow EMA (red) period |
| `strategy_rsi_period` | 10 | 2-30 | RSI period (on median price) |
| `strategy_rsi_midline` | 50.0 | 30-70 | RSI directional state threshold |
| `strategy_sl_pips` | 30.0 | 5-200 | Fixed stop loss in pips |
| `strategy_tp_pips` | 50.0 | 5-300 | Fixed take profit in pips |
| `strategy_max_spread_pips` | 20.0 | 0-100 | Spread cap (pips); fail-OPEN on 0 spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary major; deep liquidity, clean H1 EMA-cross behaviour.
- `GBPUSD.DWX` — primary major; trends well on H1, card R3 PASS symbol.
- `USDJPY.DWX` — P2 expansion major; card R3 PASS; JPY pip-scaling handled by `QM_StopFixedPips`.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card is a forex-major H1 system; pip and session
  characteristics differ.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~110` |
| Typical hold time | `hours (intraday H1, fixed 30/50-pip exits)` |
| Expected drawdown profile | `moderate; clustered losses in chop where EMA whipsaws` |
| Regime preference | `trend / momentum-continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #13 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11337_tc20-h1-13-ema5-10-rsi10-hl2.md`

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
| v1 | 2026-06-18 | Initial build from card | EMA5/10 cross EVENT + RSI10(median) 50-state |
