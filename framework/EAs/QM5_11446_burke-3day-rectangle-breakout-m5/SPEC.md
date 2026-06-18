# QM5_11446_burke-3day-rectangle-breakout-m5 — Strategy Spec

**EA ID:** QM5_11446
**Slug:** `burke-3day-rectangle-breakout-m5`
**Source:** `04305b6c-b4ce-522b-87b5-71708b6b8327` (see `strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA detects a three-day price consolidation ("rectangle") on the daily chart,
then trades the M5 breakout out of it. From the three prior CLOSED daily bars, the
oldest bar (D1 shift 3) defines a box: its High is the rectangle top and its Low is
the rectangle bottom. The two following daily bars (shift 2 and shift 1) must each
trade fully inside that box (High not above the top, Low not below the bottom). The
box height must sit between a minimum and maximum pip filter. On the next ("Day 4")
session, a long fires when an M5 bar closes above the rectangle top AND above the M5
EMA(20); a short fires when an M5 bar closes below the rectangle bottom AND below the
EMA(20). Entry is restricted to a broker-time session window (London open through NY
close). The stop is placed a small buffer back inside the rectangle (capped, and
floored at a fraction of box height); the take-profit projects the rectangle height
from entry (measured move). One trade per rectangle per day. On gapless .DWX CFDs the
rectangle is built from closed daily-bar extremes, so no real price gap is required.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rect_bars` | 3 | 2-4 | Number of D1 bars forming the rectangle (oldest defines the box, rest must be contained) |
| `strategy_ema_period` | 20 | 10-50 | M5 EMA confirmation period for the breakout close |
| `strategy_height_min_pips` | 20 | 10-40 | Rectangle height floor in pips (reject too-tight ranges) |
| `strategy_height_max_pips` | 100 | 60-150 | Rectangle height ceiling in pips (reject too-wide ranges) |
| `strategy_sl_buffer_pips` | 5 | 2-15 | Stop placed this far back inside the rectangle from the breakout level |
| `strategy_sl_cap_pips` | 50 | 30-80 | Absolute stop-distance cap in pips |
| `strategy_sl_floor_frac` | 0.5 | 0.3-0.7 | Stop distance must be >= this fraction of rectangle height |
| `strategy_session_start_hr` | 9 | 0-23 | Session window start, broker-time hour (London open) |
| `strategy_session_end_hr` | 22 | 0-23 | Session window end, broker-time hour (NY close) |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip only if spread exceeds this % of the stop distance (fail-open on zero) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean intraday consolidations, low spread.
- `GBPUSD.DWX` — liquid major with strong London-session breakout behaviour.
- `USDJPY.DWX` — liquid major; pip-scaling handled (3-digit) by the pips→price helper.
- `AUDUSD.DWX` — liquid commodity major; mean-reverting then breakout-prone.
- `USDCAD.DWX` — liquid commodity major; NY-session breakout behaviour.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the pip height filter (20-100 pips) and rectangle
  semantics are calibrated for FX majors, not for index/metal point scales.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `D1` rectangle pattern (High/Low of the 3 prior closed daily bars) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (M5 entry) + `QM_IsNewBar(_Symbol, PERIOD_D1)` (rectangle refresh) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~25` |
| Typical hold time | `hours (intraday — TP/SL within the Day-4 session)` |
| Expected drawdown profile | `clustered small losses on failed breakouts; wins = full measured move` |
| Regime preference | `volatility-expansion / breakout (after a consolidation squeeze)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `04305b6c-b4ce-522b-87b5-71708b6b8327`
**Source type:** `book`
**Pointer:** `Stacey Burke, The Stacey Burke Trading Playbook (Part 2, pp. 51-106) — strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11446_burke-3day-rectangle-breakout-m5.md`

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
