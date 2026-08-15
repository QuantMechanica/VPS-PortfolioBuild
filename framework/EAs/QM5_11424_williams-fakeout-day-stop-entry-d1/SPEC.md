# QM5_11424_williams-fakeout-day-stop-entry-d1 — Strategy Spec

**EA ID:** QM5_11424
**Slug:** `williams-fakeout-day-stop-entry-d1`
**Source:** `bb9e26af-ebd1-5a26-b1a8-cc4d78835f03` (see `strategy-seeds/sources/bb9e26af-ebd1-5a26-b1a8-cc4d78835f03/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-15

---

## 1. Strategy Logic

A "Fake Out Day" (Larry Williams' "Failure Day") is a bar that expands the
range in one direction but then closes against that expansion — a trap for
breakout traders. On the bullish side, the signal bar makes a higher high and
higher low than the prior bar, but closes lower than the prior bar's close
(failed upward expansion). The EA places a BUY_STOP at the prior bar's high on
the next trading day: if price recovers back above that level, the failure is
confirmed and the reversal is in motion. The bearish case mirrors this — lower
low and lower high than the prior bar, but a close higher than the prior
close, triggers a SELL_STOP at the prior bar's low. The pending order is
day-only (expires unfilled at end of the trigger bar). Protective stop is the
extreme of the signal bar (low for longs, high for shorts); take-profit is a
fixed multiple of the entry-to-stop risk distance. No active trade management
beyond the initial stop/target — Williams' optional 3-bar trailing exit is
reserved for a P3 sweep variant.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_buffer_pips` | 1 | 0-5 | Pip buffer added beyond the prior bar's H/L to set the stop-order trigger price |
| `strategy_stop_buffer_pips` | 1 | 0-5 | Pip buffer added beyond the signal bar's L/H to set the protective stop |
| `strategy_min_signal_range_pips` | 10 | 5-20 | Minimum signal-bar range (`High[1]-Low[1]`) required to accept the signal; filters trivial/noise bars |
| `strategy_sl_cap_pips` | 70 | 30-100 | P2 cap on stop distance (entry→SL); wide fake-out bars are capped rather than rejected |
| `strategy_tp_rr` | 2.0 | 1.5-3.0 | Take-profit distance as a multiple of the entry→SL risk distance |
| `strategy_spread_cap_pips` | 25.0 | 10-40 | Blocks new entries only when the live spread genuinely exceeds this (fail-open on `.DWX` zero modelled spread) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-named primary FX pair, liquid D1 OHLC geometry
- `GBPUSD.DWX` — card-named portable FX pair
- `USDJPY.DWX` — card-named portable FX pair
- `AUDUSD.DWX` — card-named portable FX pair

**Explicitly NOT for:**
- Index/metals `.DWX` symbols — the card's R3 basket is FX-only (Williams' D1
  fake-out pattern is sourced and validated against FX pairs in the book)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar()` (default symbol/period) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 |
| Typical hold time | 1-3 days (day-only pending trigger, RR-target or cap exit) |
| Expected drawdown profile | Moderate — capped stop distance (70 pips), fixed RR target |
| Regime preference | breakout-failure / reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `bb9e26af-ebd1-5a26-b1a8-cc4d78835f03`
**Source type:** `book`
**Pointer:** Larry Williams, "Inner Circle Workshop Trading Method", local PDF:
`C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\Inner Circle Workshop Trading Method. (Larry Williams) (Z-Library).pdf`
**R1–R4 verdict (Q00):** all PASS — R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_11424_williams-fakeout-day-stop-entry-d1.md`

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
| v1 | 2026-08-15 | Initial build from card | b833fb99-4e4a-4608-8a90-e9eca7738750 |
