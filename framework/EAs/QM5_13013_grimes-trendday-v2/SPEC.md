# QM5_13013_grimes-trendday-v2 — Strategy Spec

**EA ID:** QM5_13013
**Slug:** `grimes-trendday-v2`
**Source:** `exit-surgery-10943` (Adam Grimes trend-day article; surgery evidence from EXIT_SURGERY_SCAN_2026-07-04.md)
**Author of this spec:** Claude
**Last revised:** 2026-07-04

---

## 1. Strategy Logic

Compressed trend-day breakout on M15 with session-lifetime guard (v2). Daily setup: the prior D1 bar must be compressed (range <= 0.65x ATR20(D1)) and either an inside day or the prior two days both compressed (range <= 0.75x ATR). On a qualified setup day, the EA builds a first-hour opening range from the first four M15 bars after the session open (16:30 broker time). Entry triggers when an M15 bar closes above the opening-range high AND above the prior D1 high (long) or below the range low AND prior D1 low (short). The opening range must not exceed 0.9x ATR20(D1). Stop is at range low/high minus/plus 0.15x ATR20(M15). Target 3.0R. Trail after 1.5R using the prior three M15 bar lows/highs. Exit at session close (22:45) or when M15 re-enters the opening range. v2 surgical addition: the pending order is not submitted if fewer than `strategy_min_session_hold_h` hours (default 4h) remain before session close, eliminating the TIME_MGMT kills in the <1h hold bucket identified in EXIT_SURGERY_SCAN_2026-07-04.md §3.2.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period_d1` | 20 | 10-40 | ATR period on D1 for compression and range checks |
| `strategy_atr_period_m15` | 20 | 10-40 | ATR period on M15 for stop sizing |
| `strategy_prior_range_atr_mult` | 0.65 | 0.4-0.9 | Max prior D1 range as fraction of ATR(D1) for compression |
| `strategy_two_day_range_atr_mult` | 0.75 | 0.5-1.0 | Max range for two-compressed-day alternative condition |
| `strategy_opening_range_bars` | 4 | 2-8 | M15 bars defining the opening range (4 bars = 1h) |
| `strategy_session_open_hour_broker` | 16 | 0-23 | Session open hour (broker time, DXZ NY-Close convention) |
| `strategy_session_open_minute_broker` | 30 | 0-59 | Session open minute (16:30 = NDX cash open proxy) |
| `strategy_session_close_hour_broker` | 22 | 0-23 | Session close hour (broker time) |
| `strategy_session_close_minute_broker` | 45 | 0-59 | Session close minute (22:45 = NDX session end) |
| `strategy_max_open_range_d1_atr_mult` | 0.90 | 0.5-1.5 | Reject setup if opening range exceeds this x ATR(D1) |
| `strategy_stop_m15_atr_mult` | 0.15 | 0.05-0.5 | ATR(M15) buffer below/above opening range for stop |
| `strategy_target_r_mult` | 3.00 | 1.0-5.0 | Risk-reward ratio for take-profit |
| `strategy_trail_trigger_r` | 1.50 | 0.5-3.0 | R-multiple gained before trailing stop activates |
| `strategy_trail_lookback_bars` | 3 | 1-10 | Bars back for trailing stop level (prior N M15 lows/highs) |
| `strategy_spread_stop_fraction` | 0.10 | 0.0-0.3 | Max spread as fraction of stop distance |
| `strategy_min_session_hold_h` | 4.0 | 1.0-8.0 | **v2 surgical addition** — min hours to session close required before placing pending. Blocks entries after 18:45 for a 22:45 close. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — surgery evidence target; M15 trend-day breakout on Nasdaq 100. Parent QM5_10943 Q08 data is from this symbol with session parameters matching NDX cash session (16:30-22:45 broker time).

**Explicitly NOT for (v2 scope):**
- `SP500.DWX`, `WS30.DWX`, `GDAXI.DWX` — parent supports these; v2 restricts to NDX to isolate the surgical delta. Future v2-sweep cards may extend if NDX passes Q08.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` (compression filter, ATR, prior day high/low) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8 (conservative; session-lifetime filter removes late-entry noise) |
| Typical hold time | 4-12h (early-session entries only; surgery removes <1h fills) |
| Expected drawdown profile | Low; one trade per session, compressed-day filter is sparse |
| Regime preference | Trend-day / volatility-expansion; requires prior compression + breakout confirmation |
| Win rate target (qualitative) | High (77% WR in 4-12h bucket per scan evidence) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `exit-surgery-10943`
**Source type:** Exit-surgery derivation from parent QM5_10943
**Pointer:** `docs/research/EXIT_SURGERY_SCAN_2026-07-04.md` §3.2; parent source: Adam H. Grimes, "Finding trend days in index futures", https://www.adamhgrimes.com/finding-trend-days-in-index-futures/
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13013_grimes-trendday-v2.md`

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
| v1 | 2026-07-04 | Exit-surgery from parent QM5_10943; added strategy_min_session_hold_h=4.0 guard | 24d706d7-2fd2-4891-b324-e43d869abdca |
