# QM5_12561_session-open-pdh-breakout — Strategy Spec

**EA ID:** QM5_12561
**Slug:** `session-open-pdh-breakout`
**Source:** `f1f20c07-5e52-5a7a-be26-10f222d68b62`
**Author of this spec:** Claude
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On each M15 bar the EA builds a 30-minute Opening Range (OR) from the first two M15 bars after the session open. The reference long level is `max(OR_high, prev_day_high)`; the short level is `min(OR_low, prev_day_low)`. Within a 2-hour entry window (bars 3–10 after session open), a long trade fires when a completed M15 bar closes above the long reference level AND the bar's range ≥ 0.5 × ATR(14, M15) AND the cumulative session range ≥ 0.8 × the prior session's range. Stop loss is placed at `OR_low − 0.3 × ATR` (long) or `OR_high + 0.3 × ATR` (short), capped at 1.8 × ATR from entry. Take-profit is 2R; stop moves to break-even at 1R. A time stop closes the trade after 8 M15 bars if price never reached 0.5R. All positions are closed 15 minutes before the session close (EOD flat).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period_m15` | 14 | 5–50 | ATR lookback on M15 for stop sizing and expansion filter |
| `strategy_atr_period_d1` | 14 | 5–50 | ATR lookback on D1 for gap filter |
| `strategy_sl_atr_buffer` | 0.3 | 0.1–1.0 | SL placement beyond OR boundary (multiplier × ATR M15) |
| `strategy_sl_atr_cap` | 1.8 | 1.0–3.0 | Maximum allowed stop distance in units of ATR M15 |
| `strategy_tp_rr` | 2.0 | 1.0–4.0 | Take-profit R-multiple |
| `strategy_be_r` | 1.0 | 0.5–2.0 | Break-even trigger in R units from entry |
| `strategy_time_stop_bars` | 8 | 4–20 | M15 bars elapsed before time stop check |
| `strategy_time_stop_min_r` | 0.5 | 0.1–1.0 | Minimum favorable R needed to avoid time stop |
| `strategy_entry_bar_min_range` | 0.5 | 0.1–1.0 | Breakout bar range filter (multiplier × ATR M15) |
| `strategy_session_range_factor` | 0.8 | 0.3–1.5 | Session range vs prior day range ratio threshold |
| `strategy_gap_atr_d1_mult` | 1.5 | 0.5–3.0 | Skip day if overnight gap exceeds this × ATR(D1) |
| `strategy_session_open_hour` | 16 | 0–23 | Broker hour of session open (US default 16, GDAXI override 10) |
| `strategy_session_open_minute` | 30 | 0–59 | Broker minute of session open (US default 30, GDAXI override 0) |
| `strategy_eod_exit_hour` | 22 | 0–23 | Broker hour of EOD exit (US default 22, GDAXI override 18) |
| `strategy_eod_exit_minute` | 45 | 0–59 | Broker minute of EOD exit (US default 45, GDAXI override 15) |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — US equity Nasdaq-100 index; session open 16:30 broker (US DST and DXZ DST cancel, always 16:30)
- `WS30.DWX` — US equity Dow-30 index; same session time as NDX
- `GDAXI.DWX` — German DAX 40 index (Xetra); session open ~10:00 broker (typically; see open_questions re DST)

**Explicitly NOT for:**
- `GER40.DWX` — not in dwx_symbol_matrix.csv; GDAXI.DWX is the canonical DAX symbol (ported from card)
- Forex pairs — no intraday equity session structure; edge does not apply
- SP500.DWX — not included per card; NDX/WS30 cover US large-cap

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` — previous-day high/low and gap filter ATR |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework-provided) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120 (one per qualifying session day, ~50-65% of trading days) |
| Typical hold time | 1–8 M15 bars (15 min to 2 h); always flat before EOD |
| Expected drawdown profile | Intraday only; uncorrelated to H1–D1 swing survivors |
| Regime preference | Breakout / intraday momentum |
| Win rate target (qualitative) | Medium (2R target + time stop filters losers) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f1f20c07-5e52-5a7a-be26-10f222d68b62`
**Source type:** paper / book
**Pointer:** Crabel (1990) "Day Trading with Short Term Price Patterns and Opening Range Breakout"; Zarattini & Aziz (2023) SSRN 4416622
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12561_session-open-pdh-breakout.md`

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
| v1 | 2026-06-25 | Initial build from card | 22f412cd-b6df-4f05-9efa-8b176676c12d |
