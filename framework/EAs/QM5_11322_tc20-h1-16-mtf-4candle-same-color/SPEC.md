# QM5_11322_tc20-h1-16-mtf-4candle-same-color — Strategy Spec

**EA ID:** QM5_11322
**Slug:** `tc20-h1-16-mtf-4candle-same-color`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Pure same-symbol multi-timeframe candle-direction momentum, no indicators. When a
new H1 bar opens (the prior H1 bar has just closed), the EA reads the direction of
the last CLOSED candle on M5, M15, M30 and H1. Direction is Close-vs-Open
(Close > Open = bullish, Close < Open = bearish), which is gapless-safe on .DWX
CFDs. If all four timeframes are bullish it places a BuyStop a few pips above the
H1 close; if all four are bearish it places a SellStop a few pips below the H1
close. The pending stop order carries a fixed take-profit and stop-loss and
auto-expires after 15 minutes if price never reaches the trigger. Only one
position (or live pending order) per magic at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_offset_pips` | 3 | 1-5 | Stop-entry offset beyond the H1 close (pip-scaled) |
| `strategy_sl_pips` | 20 | 10-40 | Fixed stop-loss distance in pips |
| `strategy_tp_pips` | 35 | 20-50 | Fixed take-profit distance in pips (mid of card's 30-40) |
| `strategy_expiry_minutes` | 15 | 5-60 | Pending-order expiry if the stop is not triggered |
| `strategy_spread_cap_pips` | 10.0 | 2-20 | Block entry only when spread exceeds this (fail-open on zero) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary; deepest liquidity, tightest spread, suits a 3-pip stop-entry edge.
- `GBPUSD.DWX` — card R3 portable basket; liquid major with comparable H1 momentum behaviour.
- `USDJPY.DWX` — card R3 portable basket; liquid major, pip-scaling handled for 3-digit JPY.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the fixed 20/35-pip geometry and forex
  "candle colour" cadence are calibrated to FX majors, not index points.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `M5, M15, M30 last-closed candle direction (same symbol)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `minutes to a few hours (intraday stop/target)` |
| Expected drawdown profile | `shallow per-trade; capped 20-pip fixed risk, stop-entry filters non-momentum bars` |
| Regime preference | `momentum-continuation / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", 2014, Strategy #16 — `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11322_tc20-h1-16-mtf-4candle-same-color.md`

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
