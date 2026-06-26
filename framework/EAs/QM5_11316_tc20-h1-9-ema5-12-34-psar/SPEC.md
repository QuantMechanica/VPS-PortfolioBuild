# QM5_11316_tc20-h1-9-ema5-12-34-psar — Strategy Spec

**EA ID:** QM5_11316
**Slug:** `tc20-h1-9-ema5-12-34-psar`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies, H1 Strategy #9)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

Trend-following on H1 using a triple-EMA cascade plus Parabolic SAR direction
confirmation. Go long when EMA(5) > EMA(12) > EMA(34), SAR is moving lower from
the prior closed bar to the latest closed bar, and the latest SAR value is under
EMA(5). Go short on the mirror: EMA(5) < EMA(12) < EMA(34), SAR is moving
higher, and the latest SAR value is above EMA(5). Exit on a fixed 30-pip stop or
50-pip target (both pip-scaled per symbol), or defensively when the cascade and
SAR placement both invert against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 2-20 | Cascade fast EMA period |
| `strategy_ema_mid_period` | 12 | 5-40 | Cascade middle EMA period |
| `strategy_ema_slow_period` | 34 | 20-100 | Cascade slow EMA period |
| `strategy_sar_step` | 0.1 | 0.01-0.5 | Parabolic SAR step (source value) |
| `strategy_sar_max` | 0.2 | 0.05-0.5 | Parabolic SAR maximum (source value) |
| `strategy_sl_pips` | 30 | 5-200 | Fixed stop in pips (source) |
| `strategy_tp_pips` | 50 | 5-300 | Fixed target in pips (source) |
| `strategy_spread_cap_points` | 20 | 1-200 | Block entry if spread exceeds this many points |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source pair; primary liquid major on H1 trend cadence.
- `GBPUSD.DWX` — liquid major, comparable H1 trend behaviour, portable per card R3.
- `USDJPY.DWX` — liquid major, JPY pip scaling handled by `QM_StopFixedPips`.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card is an FX-majors H1 strategy; pip-based
  fixed 30/50 stops are tuned to FX, not index point scales.

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
| Trades / year / symbol | `~80` |
| Typical hold time | `hours (intraday to ~1 day)` |
| Expected drawdown profile | `moderate; fixed 30-pip stop caps per-trade loss` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #9 (local PDF, see card frontmatter)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11316_tc20-h1-9-ema5-12-34-psar.md`

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
| v2 | 2026-06-26 | Rebuild from card | 7b36cd4a-8f9f-4009-8b74-5a515b65ff08 |
