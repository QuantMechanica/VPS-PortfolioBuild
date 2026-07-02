---
ea_id: QM5_12918
slug: jegadeesh-1w-reversal-fx
expected_trades_per_year_per_symbol: 40
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/weekly-return]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Jegadeesh 1990 JoF (~3500 citations) is a cornerstone peer-reviewed paper with verified DOI — strongest possible R1.
r2_mechanical: PASS
r2_reasoning: Friday-to-Friday return computation and rank-and-pick of bottom-2 pairs are fully deterministic with zero discretion.
r3_data_available: PASS
r3_reasoning: Seven G10 USD-crosses (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF, NZDUSD) available on DWX with continuous D1 OHLC data.
r4_ml_forbidden: PASS
r4_reasoning: Pure rolling weekly return ranking; no ML, no adaptive params, distinct magic slots per pair satisfy the 1-pos-per-magic rule.
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Jegadeesh 1990 JoF 45(3) 1-week reversal + Lehmann 1990 QJE 105(1) port to 7 G10 FX pairs R1-R4 PASS"
---

# QM5_1142 Jegadeesh 1-Week Short-Term Reversal (FX Port)

## Quelle
- Primary: Jegadeesh, N. (1990) "Evidence of Predictable Behavior of
  Security Returns" Journal of Finance 45(3), pp. 881-898. Canonical
  reference for **short-horizon (1-week / 1-month) reversal**.
  https://onlinelibrary.wiley.com/doi/10.1111/j.1540-6261.1990.tb05117.x
- Companion: Lehmann, B.N. (1990) "Fads, Martingales, and Market
  Efficiency" QJE 105(1) — independent confirmation of 1-week
  contrarian profits on US stocks.
- Reported result: weekly losers outperform weekly winners by ~1.7 %
  the following week on US equities. Mechanism debated
  (liquidity-provision premium per Avramov-Chordia-Goyal 2006 SSRN
  675562 or Nagel 2012 RFS 19478, vs behavioural overreaction).
- Lineage: cornerstone short-term-reversal reference. FX port: De Roon-
  Eiling-Gerard-Hillion (2010) "FX returns and short-horizon reversal"
  and Curcuru-Vega-Hoek (Fed IFDP 1024, 2011) document short-horizon
  reversal in major USD-crosses.

## Mechanik

### Entry
- **Weekly** rebalance — every Monday at session open (broker-time,
  first available bar after Sunday-close gap fills).
- Universe: 7 G10 USD-crosses available on DXZ (EURUSD, GBPUSD, USDJPY,
  AUDUSD, USDCAD, USDCHF, NZDUSD).
- For each pair compute prior-week return
  `r1w = close[Friday-prev] / close[Friday-prev-week] - 1`
  (Friday-to-Friday close-to-close).
- Rank the 7 pairs by `r1w` ascending (most-down pair first).
- **Long** the bottom-2 (worst-prior-week) pairs.
- (Long-short variant in P3 sweep: also **short** top-2 winners.)
- Equal-weight within the long basket.

### Exit
- Hold for exactly 5 trading days (Mon-open → Fri-close).
- Close all positions at next Friday's close.
- Re-rank Monday morning; new bottom-2 enters.

### Stop Loss
ATR(D1,14) × 2 per-position hard stop (1-week-reversal positions are
fragile to continuation; tight stop). Portfolio MAX_DD 20 % trip
(HR3/5).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per pair per cycle for P2 baseline,
`RISK_PERCENT` for live (HR4).

### Zusätzliche Filter
- News-calendar filter — skip entry on weeks where any G10-currency
  central-bank rate decision falls Monday-Friday.
- Skip pair if spread on Monday-open > 2× 20D average spread (avoids
  ill-liquid Mondays).
- P3 sweep: weekly vs 5-day-overlapping rebalance, bottom-1 vs bottom-2
  vs bottom-3 selection, long-only vs long-short.

## Concepts
- [[concepts/short-term-reversal]] -- primary
- [[concepts/mean-reversion]] -- structural family
- [[concepts/cross-sectional-ranking]] -- universe mechanic

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Jegadeesh 1990 JoF (~3500 citations) + Lehmann 1990 QJE — foundational short-term-reversal references. FX port replicated by Fed-IFDP working paper (Curcuru-Vega-Hoek 2011). Tenured author, peer-reviewed, multi-decade evidence base |
| R2 Mechanical | PASS | One number per pair per week (Friday-Friday return). Rank-and-pick rule, deterministic |
| R3 Data Available | PASS | DXZ has 7 G10 USD-crosses with continuous tick data from 2018-07. Cross-section size (7) supports bottom-2 selection. No instrument-specific data requirements beyond OHLCV |
| R4 ML Forbidden | PASS | Pure rolling-return rank. No ML, no adaptive params, no martingale. 1-pos-per-magic per HR4 (multi-symbol EA assigns distinct magic slots) |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 3 (autonomous wake), PENDING

## Verwandte Strategien
- Distinct from: QM5_1141 (debondt-thaler-3y-reversal-idx) — same
  reversal family but long-horizon (36m, country indices) vs
  short-horizon (1w, FX). Different empirical regime entirely.
- Counterpart to: QM5_1111 (qp-fx-momentum-12m) — opposite signal
  on the same FX universe. Both can coexist (negative-correlation
  expected by construction).
- Adjacent: QM5_1095 (qp-dollar-carry-basket), QM5_1127
  (menkhoff-carry-fxvol-filter) — same G10 universe, different
  signal family (carry vs reversal). Portfolio-additive.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX,
  USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX.
- Timeframe: D1 for ranking, H1 or M30 for actual entry execution
  Monday-open.
- "Monday open" — first M30 bar after Sunday-night session reopen
  (broker-time, NY-Close DXZ → typically 23:00 server time Sunday).
- "Friday close" — last M30 bar before Friday 22:00 server time
  (NY-Close convention).
- Magic-slot allocation: per HR4, distinct magic per pair (7 slots).
- P3 sweep: hold-period 1 / 2 / 5 / 10 days; bottom-1 / 2 / 3;
  long-only / long-short; ATR-multiple 2 / 3 / 4.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
