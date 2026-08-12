---
ea_id: QM5_20069
slug: pricebob-eodflat-session-breakout-xtiusd
type: strategy
source_id: 68eff294-e3b2-5010-82d8-e9dd5f4130e6
target_symbols: [XTIUSD.DWX]
sources:
  - "[[sources/forexfactory-pricebob-strategy-thread-1331012]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/eod-flat-commodity-breakout]]"
indicators:
  - "[[indicators/session-anchor-bar]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 100
last_updated: 2026-07-27
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic once-daily reference-bar breakout with explicit SL, measured-move and forced-session-close exits plus plausible filtered cadence; R3 testable on XTIUSD.DWX without an external-series signal dependency; R4 deterministic one-position-per-magic with no ML or martin"
expected_pf: 1.18
expected_dd_pct: 20.0
---

# PriceBob Reference-Bar Breakout — EOD-Flat Commodity Port (NY Open, XTIUSD)

## Quelle
- Source: [[sources/forexfactory-pricebob-strategy-thread-1331012]]
- Forex Factory thread "The PriceBob Strategy",
  https://www.forexfactory.com/thread/1331012-the-pricebob-strategy.
  Anonymous handles, link-only R1 per relaxed criteria.
- Same core MeBob/PriceBob reference-bar mechanic as
  [[strategies/QM5_20065_pricebob-refbar-breakout-eurusd]] (fixed time-of-day
  bar defines the day's range; first close beyond it triggers a breakout
  trade with SL/TP derived from the bar range). This card is a distinct
  **instrument-class port**: WTI crude has a real cash-session structure
  (NYMEX pit-hours heritage, genuine liquidity/volatility concentration
  around the NY open) but — unlike FX majors — is not a 24h continuously
  liquid market in the way EURUSD is, and commodity breakout systems in prior
  QM research have shown a specific DD-tail failure mode from holding
  breakout positions into illiquid off-session hours (memory:
  `project_qm_gold_reaper_breakout_mining_2026-07-23`, live PF 1.08 / DD
  41.7% on an unfiltered gold-breakout clone). This card explicitly bakes in
  a **forced flat-by-session-close** rule as the differentiating exit
  mechanic, testing whether that alone materially bounds the DD-tail risk
  relative to letting a breakout position run overnight.
- Direct thread text not retrievable this session (ForexFactory Cloudflare
  403 to WebFetch and to agy — consistent with 2026-07-21 finding).

## Mechanik

### Entry
- Reference bar = first M15 bar of the **NY session open**: `13:30` broker
  time (`W. Europe Standard Time`; verify against `tester_defaults.json`),
  approximating the WTI pit-hours-heritage liquidity window.
- First bar close beyond refBar.high (LONG) or refBar.low (SHORT) triggers
  entry — identical trigger logic to the base card.
- Only the first qualifying breakout of the trading day; no re-entry.
- One position per magic.

### Exit
- Take-profit: measured move, `1.0 x refRange`, same as the base card.
- **Forced flat by session close**: hard-close any open position at
  `21:00` broker time (or the instrument's own session-close convention if
  earlier) regardless of TP/SL status — this is the card's defining rule,
  not an optional filter. No overnight hold under any circumstance.
- No breakeven move, no trail.

### Stop Loss
- SL = reference-bar opposite edge (long: refBar.low; short: refBar.high),
  same as the base card.

### Position Sizing
- P2 baseline: `RISK_FIXED` = $1,000 per trade.
- Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip if `refRange < 0.3 x ATR(14, D1)` or `> 2.5 x ATR(14, D1)`.
- News filter: standing high-impact calendar window — WTI is highly
  sensitive to EIA/API inventory releases; do not weaken this filter, and
  flag for Codex to confirm the news calendar covers energy-inventory
  events, not just macro/rate releases.
- Spread filter: skip entry if current spread `> 20%` of `refRange`.
- Swap/rollover: XTIUSD is a rolling futures-proxy CFD with contract-roll and
  swap costs (`reference_venue_cost_model_2026-07-19` doctrine) — the
  forced-flat rule minimizes overnight swap exposure by construction, but Q09
  should still confirm the swap figure isn't invented (HR: no invented
  commission/swap values).

## Concepts
- [[concepts/opening-range-breakout]] — primary
- [[concepts/eod-flat-commodity-breakout]] — primary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | TIER_C | Anonymous FF thread, link-only attribution sufficient under relaxed R1. |
| R2 Mechanical | PASS | Explicit reference-bar breakout trigger, explicit SL/TP, explicit hard flat-by-session-close exit rule (no discretion). |
| R3 Data Available | PASS | XTIUSD.DWX available in the DWX matrix; commodity porting of an FX/equity-anchored reference-bar concept is an explicitly valid R3 porting path. |
| R4 ML Forbidden | PASS | Fixed deterministic rules, one position per magic, no martingale, forced flat is a hard-coded time rule (not adaptive). |

## Pipeline-Verlauf
- G0: 2026-07-23, PENDING, drafted from FF thread 1331012 batch 1 (R1-recovery lane).

## Verwandte Strategien
- [[strategies/QM5_20065_pricebob-refbar-breakout-eurusd]] — same core
  trigger/exit skeleton without the forced-flat rule (FX doesn't need it the
  same way; still time-stopped at session end but the distinguishing feature
  here is the explicit commodity-DD-tail motivation).
- [[strategies/QM5_20066_pricebob-atr-gated-lbma-breakout-xauusd]] — sibling
  commodity port (gold), different filter mechanic (ATR gate) rather than
  forced-flat; the two cards test different mitigations for the same
  known commodity-breakout DD-tail failure mode.
- Gold Reaper/Schrynemakers (memory
  `project_qm_gold_reaper_breakout_mining_2026-07-23`) — direct precedent
  for the DD-tail risk this card's forced-flat rule is designed to address.

## Lessons Learned (während Pipeline-Lauf)
- TBD
