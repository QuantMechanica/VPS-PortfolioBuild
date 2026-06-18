# QM5_11382_sma10-15-50-trend-cross-m5 — Strategy Spec

**EA ID:** QM5_11382
**Slug:** `sma10-15-50-trend-cross-m5`
**Source:** `828e3848-fdd3-5b45-a780-e746c4691997` (see `strategy-seeds/sources/828e3848-fdd3-5b45-a780-e746c4691997/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Triple simple-moving-average trend-and-breakout scalper on M5. SMA(50) defines the
trend STATE (price above = bullish, below = bearish) and SMA(10)/SMA(15) form a
trigger band. The EA goes long when, on a closed M5 bar, the trend is bullish
(close above SMA50 with both SMA10 and SMA15 above SMA50) AND the bar TRANSITIONS to
being completely above both SMA10 and SMA15 — that is, the prior closed bar's low was
NOT above the band and the current closed bar's low IS above it. The band breakout is
the single trigger EVENT; the SMA50 trend and the SMA10/15>SMA50 alignment are STATES,
which avoids the two-cross-same-bar zero-trade trap. Short is the mirror. Stop = min(ATR(14)×1.0,
20 pips) from entry; take-profit = ATR(14)×1.5. A defensive exit closes the position
when a candle closes back below SMA10 or SMA15 (long) / above SMA10 or SMA15 (short).
Trades only the London+NY broker-time window 13:00–22:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_fast_period` | 10 | 5-20 | Fast SMA of the trigger band |
| `strategy_sma_mid_period` | 15 | 8-30 | Mid SMA of the trigger band |
| `strategy_sma_trend_period` | 50 | 20-200 | Trend-filter SMA |
| `strategy_atr_period` | 14 | 7-28 | ATR period (stop / target) |
| `strategy_sl_atr_mult` | 1.0 | 0.5-2.0 | Stop distance = mult × ATR |
| `strategy_tp_atr_mult` | 1.5 | 0.8-3.0 | Target distance = mult × ATR |
| `strategy_sl_cap_pips` | 20.0 | 5-50 | Hard cap on stop distance (pips) |
| `strategy_spread_cap_pips` | 12.0 | 1-30 | Block only spread wider than this (pips) |
| `strategy_sess_start_broker` | 13 | 0-23 | London+NY window open hour (broker time) |
| `strategy_sess_end_broker` | 22 | 0-23 | Window close hour, exclusive (broker time) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deepest, tightest-spread FX major; ideal for an M5 scalper requiring sub-12-pip spreads.
- `GBPUSD.DWX` — liquid major with London/NY-session trendiness that suits the band-breakout trigger.

**Explicitly NOT for:**
- Index/CFD symbols (NDX.DWX, WS30.DWX, SP500.DWX) — card targets FX majors; pip scaling and 13:00–22:00 FX-session window are calibrated for forex, not cash-index hours.

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
| Trades / year / symbol | `~400` |
| Typical hold time | `minutes to a few hours (M5 intraday)` |
| Expected drawdown profile | `frequent small losses, ATR-capped; trend-aligned scalp` |
| Regime preference | `trend (intraday momentum continuation)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `828e3848-fdd3-5b45-a780-e746c4691997`
**Source type:** `book` (anonymous LQDFX broker promotional ebook, local PDF)
**Pointer:** local PDF — `440084498-5-Minute-Forex-Scalping-Strategy-pdf.pdf` (Dropbox Forex archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11382_sma10-15-50-trend-cross-m5.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor worktree |
