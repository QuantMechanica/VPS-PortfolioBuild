# QM5_10949_zuck-fri-band — Strategy Spec

**EA ID:** QM5_10949
**Slug:** `zuck-fri-band`
**Source:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94` (see `strategy-seeds/sources/21ef3dfd-fac6-5d5d-b9a0-5ba447992f94/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only Friday intraday continuation breakout on M15. On Fridays only, the EA
builds a "morning frame" over a broker-time window (default broker 16:30–19:00,
which is NY 09:30–12:00 for index CFDs; commodity setfiles override to broker
08:00–11:00). It records the morning range high/low and the morning return
(close of the last in-window bar minus open of the first in-window bar). After
the window closes, on a closed M15 bar that is still before the Friday flatten
time, the EA goes LONG when (a) the morning return exceeds
`return_atr_mult * ATR(14,M15)` and (b) the bar's close breaks above the morning
high. It skips dead sessions whose morning range width is below
`min_range_atr_mult * ATR(14,H1)`. Stop is `atr_stop_mult * ATR(14,M15)` below
entry; there is no fixed take-profit — the position is flattened at the Friday
session-close proxy (default broker 20:30), with the framework Friday-close guard
(broker 21:00) as a hard backstop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_window_start_hour` | 16 | 0-23 | Morning window start hour (broker time) |
| `strategy_window_start_min` | 30 | 0-59 | Morning window start minute (broker time) |
| `strategy_window_end_hour` | 19 | 0-23 | Morning window end hour, exclusive (broker time) |
| `strategy_window_end_min` | 0 | 0-59 | Morning window end minute, exclusive (broker time) |
| `strategy_exit_hour_broker` | 20 | 0-23 | Friday flatten hour (broker time) |
| `strategy_exit_min_broker` | 30 | 0-59 | Friday flatten minute (broker time) |
| `strategy_return_atr_mult` | 0.35 | 0.20-0.50 | Morning return must exceed mult × ATR(14,M15) |
| `strategy_min_range_atr_mult` | 0.50 | 0.30-0.80 | Skip if morning range width < mult × ATR(14,H1) |
| `strategy_atr_period` | 14 | 7-28 | ATR period (M15 trigger/stop and H1 range floor) |
| `strategy_atr_stop_mult` | 1.0 | 0.75-1.5 | Stop distance = mult × ATR(14,M15) |
| `strategy_spread_pct_of_atr` | 15.0 | 5-30 | Skip if spread > this % of ATR(14,M15) |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — liquid commodity with a strong intraday session structure; use commodity broker window (08:00–11:00) via setfile.
- `OIL.DWX` — liquid commodity with intraday session structure; commodity broker window via setfile.
- `NDX.DWX` — Nasdaq 100 index CFD with a clear US cash-session morning band; default index broker window (16:30–19:00).
- `WS30.DWX` — Dow 30 index CFD; same US cash-session morning band.
- `SP500.DWX` — S&P 500 index CFD (backtest-only Custom Symbol); same US cash-session morning band. T6 live promotion forbidden for SP500-only (route to NDX/WS30).

**Explicitly NOT for:**
- `SPX500.DWX` / `SPY.DWX` / `ES.DWX` — not canonical Custom Symbol names; no tick data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `ATR(14, H1)` for the morning-range volatility floor |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~42` |
| Typical hold time | `intraday — entry after the morning window, exit by Friday 20:30 broker (hours)` |
| Expected drawdown profile | `bounded — single position, 1×ATR(M15) hard stop, weekly cadence` |
| Regime preference | `breakout / volatility-expansion (Friday morning band continuation)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94`
**Source type:** `book`
**Pointer:** Gregory Zuckerman, "The Man Who Solved the Market", Portfolio/Penguin, 2019, ISBN 9780735217980 — https://www.gregoryzuckerman.com/the-books/the-man-who-solved-the-market/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10949_zuck-fri-band.md`

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
