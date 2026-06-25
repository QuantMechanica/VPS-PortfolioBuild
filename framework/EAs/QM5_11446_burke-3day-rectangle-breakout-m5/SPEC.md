# QM5_11446_burke-3day-rectangle-breakout-m5 — Strategy Spec

**EA ID:** QM5_11446
**Slug:** `burke-3day-rectangle-breakout-m5`
**Source:** `04305b6c-b4ce-522b-87b5-71708b6b8327` (see `strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA detects a three-day price consolidation on the daily chart, then trades
the M5 breakout out of it. The oldest of the three prior closed D1 bars defines
the rectangle high and low; the next two prior closed D1 bars must remain inside
that range. A long fires when the last closed M5 candle closes above the
rectangle high and above EMA(20); a short fires when it closes below the
rectangle low and below EMA(20). Entry is restricted to a broker-time London/NY
session window. The stop is placed back inside the rectangle with the card's
5-pip buffer, 50-pip cap, and 0.5 rectangle-height floor; the target projects
the rectangle height from entry.

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
| `strategy_spread_cap_pips` | 15 | 1-30 | Skip only if spread exceeds this pip cap (fail-open on zero) |

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
| Typical hold time | `hours` |
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
| v1 | 2026-06-26 | Initial build from card | b9af56a4-1970-42ea-ab97-ead401ada595 |
