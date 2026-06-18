# QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern — Strategy Spec

**EA ID:** QM5_11339
**Slug:** `tc20-h1-15-ema5-21-rsi21-candle-pattern`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies — 1H, Strategy #15)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A trend-following H1 EA on FX majors. A trade fires on a single trigger EVENT —
either a fresh EMA(5)/EMA(21) cross OR a directional candlestick pattern on the
last closed bar — provided two STATE filters agree on direction: RSI(21) on the
correct side of 50, and the EMA(5)/EMA(21) stack already pointing that way.
Bullish candle patterns are Engulfing (current bullish body engulfs the prior
bearish body, evaluated gapless-safe via prior open/close rather than a gap) or
Hammer (long lower wick, tiny upper wick, bullish close); the bearish mirror is
Bearish Engulfing or Inverted Hammer. The stop is the recent swing low (long) or
swing high (short) over a 10-bar lookback plus a small pip buffer; the take
profit is an RR multiple (default 2R) of that structural stop distance. The
position also exits defensively if EMA(5)/EMA(21) crosses in the opposite
direction or RSI(21) crosses back through 50 against the trade. One position per
magic; RISK_FIXED in the tester.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 3-15 | Fast EMA for cross trigger + direction state |
| `strategy_ema_slow_period` | 21 | 15-50 | Slow EMA for cross trigger + direction state |
| `strategy_rsi_period` | 21 | 7-30 | RSI period (direction state + exit) |
| `strategy_rsi_mid_level` | 50.0 | 40-60 | RSI midline for state filter and exit cross |
| `strategy_use_candle` | true | bool | Enable candle-pattern trigger (B) |
| `strategy_use_ema_cross` | true | bool | Enable EMA-cross trigger (A) |
| `strategy_engulf_min_ratio` | 1.0 | 0.5-2.0 | Current body must be >= ratio × prior body to engulf |
| `strategy_hammer_wick_mult` | 2.0 | 1.5-3.0 | Long wick >= mult × body for hammer / inverted hammer |
| `strategy_hammer_oppwick_pct` | 10.0 | 5-25 | Opposite wick <= this % of bar range for hammer |
| `strategy_swing_lookback` | 10 | 5-20 | Bars for structural swing-low/high stop |
| `strategy_swing_buffer_pips` | 2.0 | 0-10 | Extra buffer beyond the swing extreme (pips) |
| `strategy_tp_rr` | 2.0 | 1.0-4.0 | Take-profit = RR × structural stop distance |
| `strategy_spread_cap_pips` | 20.0 | 5-40 | Block only a genuinely wide spread (card: 20 pips) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tight spread suits a 20-pip cap and H1 trend cadence.
- `GBPUSD.DWX` — liquid major with enough H1 trend/volatility for EMA-cross + candle entries.
- `USDJPY.DWX` — major with distinct trend behaviour; pip-scaling handled via `QM_StopRules*` helpers.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the card mechanises an FX-majors 1H strategy; trend/candle geometry and the 20-pip spread cap are calibrated for FX.

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
| Trades / year / symbol | ~70 |
| Typical hold time | hours to a few days (H1 trend leg) |
| Expected drawdown profile | moderate; structural stop caps per-trade risk, RR target 2R |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", 2014, Strategy #15 (local PDF archive per card frontmatter)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern.md`

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
| v1 | 2026-06-18 | Initial build from card | EMA5/21 cross OR candle pattern EVENT; RSI21 state |
