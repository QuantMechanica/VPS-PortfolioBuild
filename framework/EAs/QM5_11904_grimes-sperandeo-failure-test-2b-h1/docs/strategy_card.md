---
ea_id: QM5_11904
slug: grimes-sperandeo-failure-test-2b-h1
source_id: d4f8e6a2-9c31-5b47-a672-c8e3f5d2b91a
source_citation: "Adam Grimes, 'The Art and Science of Trading — Course Workbook' (Hunter Hudson Press 2017), Module 6 — Failure Test pattern; formalized via Victor Sperandeo, 'Trader Vic: Methods of a Wall Street Master' (John Wiley, 1991) — the '2B' entry. Concept origin: Richard Wyckoff (springs / upthrusts, 1930s)."
title: "Grimes/Sperandeo Failure Test (2B Reversal at Swing Pivot) H1"
edge_type: false_breakout_reversal_at_swing_pivot
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 10
status: draft
r1_verdict: PASS
r1_note: "R2 — Adam Grimes Wiley-published, formalized via Sperandeo (also Wiley); pattern itself traces to Wyckoff canonical literature"
r2_verdict: UNKNOWN
r3_verdict: UNKNOWN
r4_verdict: UNKNOWN
strategy_params:
  timeframe: H1
  swing_pivot_lookback_bars: 10
  pivot_min_age_bars: 5
  pivot_max_age_bars: 100
  breach_min_pips: 3
  breach_max_pips_atr_mult: 1.5
  atr_period: 14
  close_back_inside_required: true
  target_method: prior_swing_or_rr
  target_rr: 2.0
g0_status: APPROVED
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
last_updated: 2026-07-26
r1_track_record: TIER_C
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Fractal pivot identification, ATR-bounded breach detection, and close-back-inside confirmation are all explicit deterministic rules; SL/TP/time-based exits are fully specified formulas Codex can implement without discretion."
r3_reasoning: "All ten target symbols are standard DWX forex pairs (majors and crosses) testable on H1 with native ATR support."
r4_reasoning: "Uses only price/pivot/ATR comparisons with fixed pip and R-multiple exits; no ML, no PnL-adaptive parameters, one position per signal."
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
card_body_incomplete: false
card_body_missing: ""
legacy_contract_repair: false
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11904_grimes-sperandeo-failure-test-2b-h1.md"
g0_approval_reasoning: "R1 canonical source lineage retained; R2 mechanical pivot, breach, close-back-inside entry and explicit stop/target/time exits with conservative 10 trades/year/symbol; R3 testable on DWX FX; R4 deterministic, ML-free, one-position compatible."
expected_pf: 1.25
expected_dd_pct: 15.0
---

# QM5_11904 — Grimes/Sperandeo Failure Test (2B Reversal at Swing Pivot) (H1)

## Setup

Failure-test pattern (also known as Sperandeo's "2B" entry, Wyckoff
"spring" for bullish or "upthrust" for bearish, and Grimes "Failure
Test"): the market makes an attempt to break beyond a prior swing
high or low, fails to hold beyond that level, and CLOSES back inside
the prior range. The close-back-inside is the failure signal — the
breakout buyers/sellers are trapped, and price tends to reverse with
some momentum as those trapped traders exit.

Distinct from QM5_11892 (Samuels 1-2-3) because the 2B is a SINGLE-BAR
pattern at a prior pivot extreme, requiring only one prior pivot
reference. The 1-2-3 requires three pivots and a bar-count filter
between pivots.

## Entry Rules

Detected on H1 closed bars:

1. **Prior swing pivot identification**: identify the most recent
   significant pivot high/low using a 10-bar fractal:
   - Bullish 2B (long setup): find the most recent `pivot_low` defined
     as `bar[i].low` such that `bar[i].low < bar[j].low for all j in
     {i-5,...,i-1, i+1,...,i+5}`.
   - Bearish 2B (short setup): find most recent `pivot_high` with
     symmetric definition.
2. **Pivot freshness window**: pivot must be at least 5 H1 bars old
   AND at most 100 H1 bars old. Older than 100 → stale; newer than 5 →
   not yet fractal-confirmed.
3. **Breach detection (bullish 2B)**: the just-closed H1 bar t
   satisfies `bar[t].low < pivot_low.price - 3 pips` AND the breach is
   not extreme: `(pivot_low.price - bar[t].low) <= 1.5 × ATR(14)` at
   bar t. Extreme breaches (>1.5 ATR below pivot) suggest a genuine
   breakdown rather than a failure test.
4. **Failure confirmation (bullish 2B)**: same bar t must close BACK
   ABOVE the pivot_low — i.e., `bar[t].close > pivot_low.price`.
   The wick broke the pivot, but the body recovered.
5. **Long entry**: market buy at the open of bar t+1 (or at the close
   of bar t if execution latency allows).
6. **Bearish 2B mirror**: bar t.high > pivot_high.price + 3 pips, the
   breach is ≤ 1.5 × ATR, and bar t closes BELOW pivot_high.price.
7. **Short entry**: market sell at open of bar t+1.

## Exit Rules

- **Stop loss (long)**: at the LOW of the failure-test bar (bar t)
  minus 2 pips. This is the tightest meaningful invalidation — if
  price breaks below the failure-test bar's low, the failure has
  itself failed and the breakout was real.
- **Stop loss (short)**: at the HIGH of bar t plus 2 pips.
- **Take profit (primary)**: 2.0 × initial pip-risk in trade direction.
- **Take profit (alternative)**: the prior counter-direction swing
  high (for longs) or swing low (for shorts) — typically larger than
  2× risk, gives back the full prior range. Take whichever is closer.
- **Time-based exit**: close at H1 bar 48 (2 days) if no other exit
  fires. Failure tests typically resolve quickly (Grimes: "many trades
  will hit profits or stops within a few bars").
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

H1 forex majors — pattern is symbol-agnostic. Both Grimes and
Sperandeo apply it across all liquid markets.

## Source

source_citation: Adam Grimes, "The Art and Science of Trading — Course
Workbook" (Hunter Hudson Press 2017), Module 6. Pattern formalized via
Victor Sperandeo, "Trader Vic: Methods of a Wall Street Master" (John
Wiley & Sons, 1991) — the "2B" entry. Concept origin: Richard Wyckoff
(springs / upthrusts, 1930s — classical Wall Street technical analysis
literature).
