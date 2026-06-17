# QM5_11030_atc-zigzag-pend — Strategy Spec

**EA ID:** QM5_11030
**Slug:** `atc-zigzag-pend`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

On each closed H1 bar the EA reconstructs a deterministic, non-repainting ZigZag
from confirmed fractal swings: a bar is a swing high only when its high is the
strict maximum over the window `[bar-depth, bar+depth]` (symmetric for swing
lows), with alternation, a `deviation`-point minimum move versus the prior
pivot, and a `backstep` minimum bar spacing. Because the right wing of `depth`
bars is fully closed before a pivot is accepted, confirmed pivots never repaint.

It then places a BUY STOP at `last confirmed swing high + entry_buffer_atr*ATR`
and a SELL STOP at `last confirmed swing low - entry_buffer_atr*ATR`, but only
if the confirmed swing range `(high-low)` is at least `min_range_atr*ATR`. When
a new confirmed pivot appears, both pending orders are cancelled and replaced.
When one side fills, the opposite pending order is cancelled (one active
position per symbol/magic). Each filled position carries a fixed stop of
`sl_atr_mult*ATR` and a take-profit of `tp_atr_mult*ATR` (TP several times
larger than SL), and arms an ATR trailing stop after price moves
`trail_start_atr*ATR` in favour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_zz_depth` | 12 | 6-48 | ZigZag depth: half-window of bars for a confirmed swing |
| `strategy_zz_deviation` | 5 | 0-40 | Minimum move (points) vs the prior pivot to accept a new one |
| `strategy_zz_backstep` | 3 | 0-12 | Minimum bar spacing between consecutive pivots |
| `strategy_entry_buffer_atr` | 0.10 | 0.0-0.5 | Stop-entry buffer beyond the swing, in ATR multiples |
| `strategy_min_range_atr` | 1.5 | 0.0-4.0 | Require swing range ≥ this × ATR (0 disables the filter) |
| `strategy_atr_period` | 14 | 5-50 | ATR period for filter / stop / target / trail |
| `strategy_sl_atr_mult` | 1.0 | 0.5-2.0 | Stop distance = mult × ATR |
| `strategy_tp_atr_mult` | 3.0 | 1.5-6.0 | Target distance = mult × ATR (TP >> SL) |
| `strategy_trail_start_atr` | 1.0 | 0.0-3.0 | Arm ATR trailing after +this × ATR in favour |
| `strategy_trail_atr_mult` | 2.0 | 1.0-4.0 | ATR trailing-stop distance once armed |
| `strategy_pending_expiry_h` | 72 | 0-336 | Pending-order expiry in hours (0 = GTC) |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Skip new placement if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean ZigZag structure, tight modeled cost.
- `GBPUSD.DWX` — liquid major with strong breakout/trend bursts off swing levels.
- `USDJPY.DWX` — liquid major; pip_factor handled via ATR-relative SL/TP (no raw points).
- `EURJPY.DWX` — liquid cross with sustained directional swings suited to breakouts.

**Explicitly NOT for:**
- Index/metal CFDs (`NDX.DWX`, `XAUUSD.DWX`, …) — card scopes this to the FX
  major/cross basket; volatility scaling and swing cadence are calibrated for FX.

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
| Trades / year / symbol | `~50 (card range 25-80)` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `bounded — fixed ATR stop, one position per magic, no grid/martingale` |
| Regime preference | `breakout / volatility-expansion off confirmed swing levels` |
| Win rate target (qualitative) | `low-to-medium (small SL, large TP; positive expectancy via TP>>SL)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum` (MQL5 Articles interview)
**Pointer:** `https://www.mql5.com/en/articles/607` (Evgeny Gnidko, ATC 2012, ice_rain_ATC2012)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11030_atc-zigzag-pend.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
