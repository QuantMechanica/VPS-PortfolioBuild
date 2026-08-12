---
ea_id: QM5_20092
slug: pricebob-refbar-breakout-correlated-metal-xagusd
type: strategy
source_id: 68eff294-e3b2-5010-82d8-e9dd5f4130e6
sources:
  - "[[sources/forexfactory-pricebob-strategy-thread-1331012]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/reference-bar-breakout]]"
indicators:
  - "[[indicators/session-anchor-bar]]"
target_symbols: [XAGUSD.DWX]
g0_status: APPROVED
expected_trades_per_year_per_symbol: 110
last_updated: 2026-07-27
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic session reference-bar breakout with explicit TP/SL/time exit and plausible filtered intraday cadence; R3 testable on XAGUSD.DWX; R4 deterministic, ML-free, one position per magic."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# PriceBob Reference-Bar Breakout — Correlated-Metal Deployment (COMEX-Analog Open, XAGUSD)

## Quelle
- Source: [[sources/forexfactory-pricebob-strategy-thread-1331012]]
- Forex Factory thread "The PriceBob Strategy", https://www.forexfactory.com/thread/1331012-the-pricebob-strategy
  (indexed sub-page this batch: `?page=31`). Anonymous forum handles;
  link-only attribution per relaxed R1 (2026-05-15/06-30), R1-recovery
  lane (2026-07-23). Batch 2 of resume-mining (see source note).
- Indexed snippets document that thread participants apply the fixed
  reference-bar mechanic **simultaneously across correlated futures
  instruments** — "traders will sometimes apply the same interval to ES,
  GC, and NQ simultaneously, and quite often apply a different interval to
  one or more of them" — i.e. the thread itself treats multi-instrument,
  correlated-metal/correlated-index deployment of the identical base engine
  as a documented, legitimate variant, not just a single-symbol system.
- This card is the **base engine** (first-close breakout, measured-move
  target, opposite-edge SL — identical skeleton to Batch 1's
  `QM5_20065`/`QM5_20066`), deployed on **XAGUSD (silver)** as the
  correlated-metal counterpart to Batch 1's `QM5_20066` (XAUUSD, gold,
  ATR-gated variant). Unlike `QM5_20066`, this card does **not** carry the
  ATR-gated actionable-breakout filter — it uses the plain first-close
  trigger — so the two metal cards are a genuine A/B pair (gated vs.
  ungated) on correlated instruments, matching the thread's own
  documented practice of running the same skeleton with varied parameters
  across correlated symbols.
- Direct thread text not pulled verbatim (403 on WebFetch/agy, reconfirmed
  this session).
- **Porting note (R3):** original bar is anchored to the SPX/NYSE cash
  session; the thread's own multi-instrument note references GC (COMEX gold
  futures pit/electronic open). This card anchors to a COMEX-metals-analog
  session window on silver, mirroring the thread's oil-pit-open convention
  ("pricebobbing for oil using the 8-9 AM Eastern bar," also indexed this
  batch) applied to the metals pit-open analog instead.

## Mechanik

### Entry
- Reference bar = the first **M5** bar of the COMEX-metals-analog open
  window, `08:20-08:25` Eastern (broker-time translation via
  `tester_defaults.json` NY-close DST convention — Codex to confirm; this
  mirrors the thread's own oil-pit "8-9 AM Eastern" anchor convention,
  narrowed to the metals pit-open minute rather than a full hour).
- After the reference bar closes, watch subsequent M5 bars for the first
  bar **CLOSE** beyond the reference bar's high or low:
  - Close > refBar.high → enter LONG at next bar open.
  - Close < refBar.low → enter SHORT at next bar open.
- Only the first qualifying breakout of the session is taken (no
  re-entry same day). One position per magic.

### Exit
- Take-profit: measured move = entry price ± (1.0 x reference-bar range),
  projected in the breakout direction (same convention as the rest of this
  source's card family).
- No trailing stop, no breakeven move.
- Time-stop: flatten at session end (`21:00` broker time) if neither TP
  nor SL has been hit.

### Stop Loss
- SL = the opposite edge of the reference bar (long: SL at refBar.low;
  short: SL at refBar.high). Baseline 1:1 R:R by construction.

### Position Sizing
- P2 baseline: `RISK_FIXED` (HR4). Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip the day if the reference-bar range is abnormally small
  (`< 0.3 x ATR(14, D1)`) or abnormally large (`> 2.5 x ATR(14, D1)`).
- News filter: skip entries inside the standing high-impact news window —
  metals are particularly news-sensitive (US CPI/NFP/Fed); apply the same
  standing calendar convention used elsewhere in the framework.
- Spread filter: skip entry if spread `> 20%` of the reference-bar range.

## Concepts
- [[concepts/opening-range-breakout]] — primary
- [[concepts/reference-bar-breakout]] — primary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | TIER_C | Anonymous FF thread; link-only attribution sufficient under relaxed R1; never a rejection reason. |
| R2 Mechanical | PASS | Identical explicit entry/exit/SL/TP skeleton as the already-approved-format Batch 1 base engine; only the anchor time and symbol differ. Exact metals-pit-open broker-time offset is a Codex-fill gap. |
| R3 Data Available | PASS | XAGUSD.DWX, metals commodity CFD, confirmed in `dwx_symbol_matrix.csv`. |
| R4 ML Forbidden | PASS | Fixed deterministic rules, one position per magic, no martingale, no adaptive re-fit — identical control profile to the already-evaluated `QM5_20065`/`QM5_20066` skeleton. |

## Pipeline-Verlauf
- G0: 2026-07-23, PENDING, drafted from FF thread 1331012 batch 2 (R1-recovery lane, resume-mining).

## Verwandte Strategien
- [[strategies/QM5_20066_pricebob-atr-gated-lbma-breakout-xauusd]] —
  correlated-metal sibling (gold, ATR-gated variant); this card is the
  ungated silver counterpart, deliberately kept as a gated/ungated A/B
  pair on correlated instruments per the thread's own documented
  multi-instrument deployment practice.
- [[strategies/QM5_20065_pricebob-refbar-breakout-eurusd]] — identical base
  engine skeleton, different asset class (FX major vs. metal) and session
  anchor (London open vs. COMEX-metals-analog open).

## Lessons Learned (während Pipeline-Lauf)
- TBD
