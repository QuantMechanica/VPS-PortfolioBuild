---
ea_id: QM5_20068
slug: pricebob-bounded-fixedr-intraday-ws30
type: strategy
source_id: 68eff294-e3b2-5010-82d8-e9dd5f4130e6
target_symbols: [WS30.DWX]
sources:
  - "[[sources/forexfactory-pricebob-strategy-thread-1331012]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/bounded-fixed-r-intraday]]"
indicators:
  - "[[indicators/session-anchor-bar]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 250
last_updated: 2026-07-27
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic rolling-range intraday breakout with explicit SL, 2R/close exits and plausible joint cadence; R3 testable on WS30.DWX using price/calendar gates only; R4 deterministic one-position-per-magic with bounded daily entries and no ML/martingale."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# PriceBob Bounded Fixed-R Intraday Breakout (Max N/day, 1:2 RR, Dow Session Open, WS30)

## Quelle
- Source: [[sources/forexfactory-pricebob-strategy-thread-1331012]]
- Forex Factory thread "The PriceBob Strategy",
  https://www.forexfactory.com/thread/1331012-the-pricebob-strategy
  (indexed page `/thread/post/15178318` and surrounding pages). Anonymous
  handles, link-only R1.
- Per indexed thread search snippets, at least one poster in the thread
  reports a mechanized variant of the method run as: **maximum 5 trades per
  day in each direction, 1:2 risk-reward, no breakeven, 1% risk on a $10,000
  account.** This is a materially different exit engine than the base card's
  measured-move target: a fixed R-multiple exit, re-armed for repeated
  signals through the day up to a hard count cap, rather than one shot per
  day off a single fixed reference bar. This card isolates that variant.
- Direct thread text not retrievable this session (ForexFactory Cloudflare
  403 to WebFetch and to agy — consistent with 2026-07-21 finding); the
  reported "5/day" figure is a poster's personal setting, not a documented
  rule from the method's originator — treated here as an upper bound, not a
  target, and set conservatively lower (3/day) pending P3 sweep.
- **Instrument choice:** the original MeBob method was built for the S&P 500
  cash-session open. WS30.DWX (Dow 30) is the live-tradable DWX index CFD
  closest in spirit to that heritage (index cash-session-open reference bar,
  genuine liquidity/volatility concentration at the open) — preferred over
  SP500.DWX here specifically because this variant is meant to be a
  live-promotable candidate, and SP500.DWX is backtest-only per R3 (not
  broker-routable on Darwinex).

## Mechanik

### Entry
- Reference range: **rolling short lookback** high/low, not a single fixed
  daily bar — recompute every `N=6` bars (e.g. every 90 min on M15) using the
  high/low of the preceding `6` bars as the breakout reference. This is the
  mechanic that allows repeated signals through the day (vs. the base card's
  single fixed reference bar), consistent with the "up to 5 trades/day"
  variant needing more than one setup per session.
- Entry trigger: first bar close beyond the current rolling range's high
  (LONG) or low (SHORT).
- **Hard cap: max 3 entries per direction per day** (conservative vs. the
  poster-reported 5; P3 sweeps 2/3/4/5). Counter resets at session open.
- Skip new entries once a position is open (sequential only, 1-position-per-
  magic); the next rolling-range signal can only be evaluated after the
  current position closes.
- Session window: only active during the Dow cash-session hours (`15:30` NY
  cash open through `22:00` NY cash close, converted to broker time) — no
  entries outside the index's own trading session.

### Exit
- Fixed take-profit: `2.0 x SL_distance` (1:2 R:R), matching the reported
  variant.
- **No breakeven move** (explicit thread-reported rule — do not add one).
- No trail.
- Time-stop: flatten any open position at Dow cash-session close if unresolved
  (do not carry an intraday breakout position into the overnight index
  session).

### Stop Loss
- SL = the **opposite edge of the rolling lookback range** at time of entry
  (long: SL at range-low; short: SL at range-high) — same "range defines
  risk" logic as the base card, applied to the rolling range instead of a
  single fixed bar.

### Position Sizing
- P2 baseline: `RISK_FIXED` = $1,000 per trade (HR4). Note the source
  poster's own risk setting (1% of a $10,000 account = $100/trade) is a
  live-sizing detail, not a backtest-baseline instruction — P2 uses the
  standard fixed-dollar convention regardless.
- Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip if rolling-range width `< 0.3 x ATR(14, D1)` or `> 2.5 x ATR(14, D1)`
  (same sanity guard as sibling cards, applied to the rolling range).
- News filter: standing high-impact calendar window.
- Spread filter: skip entry if current spread `> 15%` of the rolling range
  width.
- The 3/day/direction cap is a **hard code-enforced bound**, not a soft
  guideline — required for R4 (no unbounded repeated-entry runaway).

## Concepts
- [[concepts/opening-range-breakout]] — primary
- [[concepts/bounded-fixed-r-intraday]] — primary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | TIER_C | Anonymous FF poster's reported personal variant of the method; link-only attribution sufficient under relaxed R1. |
| R2 Mechanical | PASS | Explicit rolling-range breakout trigger, explicit hard entry-count cap, explicit fixed 1:2 R:R exit, explicit "no breakeven" rule. Lookback length and cap value are placeholder defaults; Codex fills, P3 sweeps. |
| R3 Data Available | PASS | WS30.DWX, live-tradable Dow 30 CFD — direct structural analog to the original S&P-cash-session reference-bar heritage, and avoids the SP500.DWX backtest-only live-promotion caveat entirely. |
| R4 ML Forbidden | PASS | Deterministic rolling-range trigger (price-history-only), hard-coded max-3-entries/direction/day bound prevents runaway repeated entries, fixed R-multiple sizing (no martingale), one position open at a time per magic. |

## Pipeline-Verlauf
- G0: 2026-07-23, PENDING, drafted from FF thread 1331012 batch 1 (R1-recovery lane).

## Verwandte Strategien
- [[strategies/QM5_20065_pricebob-refbar-breakout-eurusd]] — single-shot
  fixed-bar sibling; compare frequency/DD profile against this bounded
  multi-entry variant.
- [[strategies/QM5_20067_pricebob-retracement-reentry-usdjpy]] — a
  different, more conservative approach to "more than one trade per day"
  (exactly one conditional retracement add, vs. this card's rearmed rolling-
  range trigger up to a hard count cap).
- [[strategies/QM5_13036_balke-golong-tat]] — same broad range-breakout
  concept family, unrelated author; Balke died on Q05-DD (21-23%, memory
  `project_qm_balke_rangebreakout_walkforward_2026-07-14`). This card's
  fixed 1:2 R:R exit and session-close time-stop are meant to bound single-
  trade risk more tightly than Balke's swing hold — Q05 reviewer should
  still check empirically, not assume the bound holds under stress.

## Lessons Learned (während Pipeline-Lauf)
- TBD
