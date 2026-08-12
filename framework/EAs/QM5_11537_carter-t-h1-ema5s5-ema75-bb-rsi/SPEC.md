# QM5_11537_carter-t-h1-ema5s5-ema75-bb-rsi — Strategy Spec

**EA ID:** QM5_11537
**Slug:** `carter-t-h1-ema5s5-ema75-bb-rsi`
**Source:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d` (see `strategy-seeds/sources/3001a121-97a0-5db0-b6ff-69b89a0fc07d/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Trend-state entry combining a long EMA trend filter, the Bollinger middle band
(a 20-period SMA), and RSI directional confirmation. On the close of an H1 bar,
go LONG when the prior bar's close is above EMA(75) AND above the Bollinger
middle line (SMA20) AND RSI(14) is above 50. Go SHORT on the full mirror: prior
close below EMA(75) AND below the Bollinger middle AND RSI(14) below 50. Entry
is a market order at the open of the new bar.

The stop-loss is the 5-bar swing extreme (lowest low for longs, highest high
for shorts over the last 5 closed bars) with its distance capped at 40 pips —
the tighter of (swing distance, 40-pip cap) is used. The take-profit is a fixed
2:1 reward-to-risk multiple of that stop distance. There is no discretionary
exit and no trailing/break-even; positions leave via SL, TP, or the framework
Friday close. No new entries are taken on Fridays, and a 15-pip spread cap
blocks fresh entries in wide-spread conditions (never in the zero-spread .DWX
tester).

The source's EMA(5, shift 5) is only a visual SL-placement aid in the original
book and is intentionally NOT implemented as an entry filter — the P2
simplification replaces it with the swing/40-pip stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 75 | 50-100 | EMA trend filter period (P3 sweeps 50/75/100) |
| `strategy_bb_period` | 20 | fixed | Bollinger middle-band SMA period |
| `strategy_bb_deviation` | 2.0 | 2.0-2.5 | Bollinger deviation (P3 sweeps 2/2.5) |
| `strategy_rsi_period` | 14 | fixed | RSI confirmation period |
| `strategy_rsi_threshold` | 50.0 | fixed | RSI directional threshold (>50 long / <50 short) |
| `strategy_swing_lookback` | 5 | fixed | Bars for the 5-bar swing low/high SL structure |
| `strategy_sl_cap_pips` | 40 | fixed | P2 cap on the swing SL distance (pips) |
| `strategy_rr` | 2.0 | fixed | Take-profit = RR x SL distance (2:1) |
| `strategy_max_spread_pips` | 15 | fixed | Spread cap blocking fresh entries only |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — the card's primary R3 basis; deep, liquid H1 tick history and
  the tightest spreads, well suited to a swing-stop / 2:1 trend system.
- `GBPUSD.DWX` — second card R3 pair; same major-FX regime and H1 liquidity, and
  its higher volatility gives the EMA75/BB/RSI trend filter more directional
  moves to catch while staying inside the 40-pip stop cap.

**Explicitly NOT for:**
- JPY crosses, metals, or indices — the 40-pip cap and pip model are calibrated
  for 5-digit major FX; no R3 basis has been asserted beyond the two pairs above.

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
| Trades / year / symbol | ~20 |
| Typical hold time | hours (until SL or 2:1 TP; flat by Friday close) |
| Expected drawdown profile | trend system, ~18% expected DD; whipsaw risk when price chops around EMA75/BB middle |
| Regime preference | trend |
| Win rate target (qualitative) | low (2:1 RR — fewer wins, larger winners) |

---

## 6. Source Citation

**Source ID:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d`
**Source type:** book (self-published)
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", self-published 2014, System #11
**R1–R4 verdict (Q00):** R1 TIER_C (informational, self-published, non-gating), R2/R3/R4 PASS — see `artifacts/cards_approved/QM5_11537_carter-t-h1-ema5s5-ema75-bb-rsi.md`

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
| v1 | 2026-08-10 | Initial build from card | build_ea task 985081a7-3fe8-4012-a6d6-a0dea7d47db2 |
