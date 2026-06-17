# QM5_11038_atc-imex-time — Strategy Spec

**EA ID:** QM5_11038
**Slug:** `atc-imex-time`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

At a few fixed time-points inside each daily bar (25%/50%/75% of the broker D1
lifetime = 06:00/12:00/18:00, derived from the bar timestamp converted to UTC),
the EA forecasts whether the current daily bar will close bullish or bearish
using an IMEX index. IMEX approximates the source's proprietary index from the
disclosed Bulls/Bears Power logic: BullsPower = High − EMA(close), BearsPower =
Low − EMA(close) over an MA period; IMEX = zscore(BullsPower) − zscore(|BearsPower|)
over a lookback window, evaluated on the last closed bar. The EA runs on H1 so
the framework new-bar gate provides intrabar cadence within the daily bar. It
goes long when IMEX > threshold (bar forecast bullish) and short when IMEX <
−threshold (bar forecast bearish), only inside a permitted time-point window and
before the latest-entry cutoff (0.75 of the D1 bar), with one position per
symbol/magic. Exit is a fixed ATR stop (0.70×ATR) / target (0.45×ATR); with
reversal enabled, an opposite forecast at a later time-point closes the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tp1_utc_minutes` | 360 | -1..1439 | Time-point 1 window start, UTC min-of-day (25% of D1; <0 disables) |
| `strategy_tp2_utc_minutes` | 720 | -1..1439 | Time-point 2 window start, UTC min-of-day (50% of D1) |
| `strategy_tp3_utc_minutes` | 1080 | -1..1439 | Time-point 3 window start, UTC min-of-day (75% of D1) |
| `strategy_tp_window_min` | 60 | 1-240 | Time-point window width in minutes (1 H1 bar) |
| `strategy_latest_entry_utc_minutes` | 1080 | 0-1439 | No new entry / reversal past this UTC min-of-day (0.75 of D1) |
| `strategy_imex_ma_period` | 13 | 5-55 | EMA period for Bulls/Bears Power |
| `strategy_imex_lookback` | 34 | 20-55 | Z-score lookback window in bars |
| `strategy_imex_threshold` | 0.50 | 0.25-0.75 | |IMEX| must exceed this to forecast a color |
| `strategy_atr_tf` | PERIOD_D1 | H1/H4/D1 | ATR timeframe (source = daily ATR) |
| `strategy_atr_period` | 14 | 7-21 | ATR period for stop/target |
| `strategy_sl_atr_mult` | 0.70 | 0.50-1.00 | Stop distance = mult × ATR |
| `strategy_tp_atr_mult` | 0.45 | 0.35-0.70 | Target distance = mult × ATR |
| `strategy_reversal_enabled` | false | true/false | Close on opposite forecast at a later time-point |
| `strategy_spread_pct_of_stop` | 25.0 | 5-50 | Skip if spread > this % of stop distance (fail-open on .DWX) |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` — liquid FX major with clear daily-bar directionality; card primary basket.
- `EURUSD.DWX` — most liquid FX major; clean intraday time-point structure.
- `GBPUSD.DWX` — liquid FX major with strong London/NY daily moves.
- `XAUUSD.DWX` — gold; pronounced intraday momentum suits a daily-color forecast.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, etc.) — card targets FX/metals; daily-bar
  IMEX calibration is for the FX/gold basket, not cash-index sessions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `ATR on PERIOD_D1` (configurable via `strategy_atr_tf`) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50 (card range 40-90)` |
| Typical hold time | `intraday to ~1 day (ATR stop/target inside the daily bar)` |
| Expected drawdown profile | `bounded by fixed 0.70×ATR stop and one position per magic` |
| Regime preference | `momentum / intraday directional continuation` |
| Win rate target (qualitative) | `medium (SL > TP => higher hit rate, smaller wins)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum` (MQL5 Articles / ATC 2010 interview)
**Pointer:** `https://www.mql5.com/en/articles/533`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11038_atc-imex-time.md`

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
