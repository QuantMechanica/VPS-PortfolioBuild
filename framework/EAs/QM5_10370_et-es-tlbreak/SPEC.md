# QM5_10370_et-es-tlbreak — Strategy Spec

**EA ID:** QM5_10370
**Slug:** `et-es-tlbreak`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades closed-bar breaks of automatic swing trendlines on M1 index-CFD bars. A long is allowed when EMA(9) is above SMA(55), MACD(12,26,9) main is above signal, and the last closed bar breaks above a descending resistance line drawn from confirmed swing highs. A short is allowed when EMA(9) is below SMA(55), MACD main is below signal, and the last closed bar breaks below an ascending support line drawn from confirmed swing lows. Positions trail the stop toward EMA(9), close when the last closed bar finishes on the wrong side of EMA(9), and close at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 9 | 1+ | EMA stop/trail line and fast trend filter. |
| `strategy_sma_period` | 55 | 1+ | Slower trend context line. |
| `strategy_pivot_left` | 4 | 1+ | Older-side bars required to confirm a swing pivot. |
| `strategy_pivot_right` | 4 | 1+ | Newer-side bars required to confirm a swing pivot. |
| `strategy_trendline_max_age` | 10 | 2+ | Maximum recent search age for automatic trendline pivots. |
| `strategy_use_macd_filter` | true | true/false | Enables the MACD direction filter. |
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 1+ | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_atr_period` | 14 | 1+ | ATR period for catastrophic hard stop. |
| `strategy_atr_stop_mult` | 1.0 | >0 | ATR multiplier for initial hard stop. |
| `strategy_spread_median_mult` | 2.5 | >0 | Blocks entries when current spread exceeds this multiple of rolling median spread. |
| `strategy_spread_window` | 31 | 5-101 | Rolling spread sample count. |
| `strategy_session_start_hhmm` | 1530 | 0000-2359 | Broker-time session start for entry eligibility. |
| `strategy_session_end_hhmm` | 2200 | 0000-2359 | Broker-time session end for exit. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — direct S&P 500 custom-symbol port of ES logic; backtest-only per DWX discipline.
- `NDX.DWX` — live-tradable US large-cap index CFD for P2 saturation.
- `WS30.DWX` — live-tradable US large-cap index CFD for P2 saturation.
- `GDAXI.DWX` — DAX index CFD fallback for the card's unavailable `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.
- `ES.DWX` — not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | intraday, minutes to session close |
| Expected drawdown profile | Whipsaw-prone in range days; hard ATR stop caps catastrophic moves. |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/my-es-day-trading-system-rules.122573/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10370_et-es-tlbreak.md`

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
| v1 | 2026-05-25 | Initial build from card | a010c2c9-a065-4504-bf14-159a32d8d384 |
