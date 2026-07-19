# Dual Thrust v2 — Architecture Design (successor to QM5_12474)

**Author:** Claude (board-advisor lane)
**Date:** 2026-07-19
**Status:** DESIGN — OWNER-commissioned ("Du kannst für 12474 bereits eine v2-Architektur entwerfen! Ich halte den Edge immer noch für real")
**Predecessor:** QM5_12474_gh-dual-thrust (v1, Q08 neighborhood FAIL on both qualified symbols)
**Card lineage:** af7930c8-6c65-52d1-9c01-040490b5ad39 (Q00-approved GitHub Dual Thrust source)

---

## 1. Evidence base (all gross, RISK_FIXED $1,000, M1 real ticks, 2017.01.01–2025.12.31)

### 1.1 Lookback scan (baseline + typed Q08 + night probes 2026-07-19)

| lookback | GBPUSD.DWX trades / PF / DD | XAUUSD.DWX trades / PF / DD |
|---|---|---|
| 4 | 608 / 1.05 / **$9,234 (2.00× base)** | 591 / 1.04 / **$11,970 (2.29× base)** |
| **5 (v1 nominal)** | **442 / 1.25 / $4,621** | **418 / 1.15 / $5,218** |
| 6 | 343 / 1.13 / $3,663 | 327 / 1.13 / $3,741 |
| 7 | 273 / 1.14 / $2,700 | 276 / 1.08 / $2,914 |

Evidence:
- Baseline + lb4/lb6: `D:\QM\reports\pipeline\QM5_12474\Q08\neighborhood\{GBPUSD_DWX,XAUUSD_DWX}\perturbations.json` (engine `q08_neighborhood_param_type_aware_v2`, evidence_status VALID)
- lb6/lb7 confirmation probes: `D:\QM\reports\smoke\dt12474\lb{6,7}_{GBPUSD,XAUUSD}\QM5_12474\...\summary.json`
- Baseline determinism: 5 identical GBPUSD reruns (`D:\QM\reports\pipeline\QM5_12474\Q08\_baseline\`)

### 1.2 Q08 typed verdict on v1 (why v1 is dead as-is)

The ONLY breach on both symbols is `strategy_lookback_sessions = 4`: PF stays > 1.0
(OWNER's "in Summe positiv" observation is correct) but **DD blows through the 1.5×
ceiling** (2.00× / 2.29×). All other perturbations (strategy_param ±10%, lb6) are clean.
Q08 FAIL disqualifies — no soft pass (OWNER rule 2026-07-17). Gates stay as they are;
v2 must remove the mechanism, not argue with the gate.

### 1.3 Root-cause diagnosis

Shorter lookback → tighter `dual_range` → tighter bands AND tighter stop
(`stop = range × mult`) → +38–41% more trades, dominated by marginal breakouts in
low-range regimes → consecutive whipsaw losses cluster → DD doubles even though
per-trade risk shrinks. The failure is **regime-degeneracy of a single-window range
estimate**, not a broken edge: the upward direction (6, 7) decays smoothly and stays
profitable on both symbols. The edge (session breakout after range formation) is real
but sits on a fragile estimator.

v1 mechanics (verified in source `framework/EAs/QM5_12474_gh-dual-thrust/QM5_12474_gh-dual-thrust.mq5`):
`range1 = maxHigh − minClose`, `range2 = maxClose − minLow` over N complete sessions;
`dual_range = max(range1, range2)`; long above `open + K·range`, short below
`open − (1−K)·range` (K = 0.50); stop = 1.0 × range; opposite-band reversal;
hard session close 19:00; session window 10:00–19:00 broker.

---

## 2. v2 architecture

Two pillars. Everything else stays v1 (K = 0.50 classic constant, stop 1.0× range,
session 10:00–19:00, opposite-band reversal, session-close exit, news gate, framework
risk model, no ML — HR compliant).

### Pillar A — Robust range estimator: median-of-3 ensemble

```
DR(n)        = dual-thrust range computed over n complete sessions
range_v2     = median( DR(center−1), DR(center), DR(center+1) ),  center = 5
```

- **Kills the cliff mechanism:** a single anomalously tight window can no longer drag
  the bands down; the median outvotes the degenerate member. The lb4 failure mode
  (tight-range whipsaw factory) is structurally damped.
- **Smooths the Q08 lattice by construction:** perturbing `center` 5→4 yields ensemble
  {3,4,5}, sharing 2 of 3 members with nominal {4,5,6}. Discrete steps become gradual.
- **Median-of-±1 is a structural constant, not a tuning knob.** It is the minimal
  symmetric robust estimator; the span is NOT exposed as an input (exposing it would
  manufacture a pseudo-parameter whose only purpose is gate arithmetic). `center`
  remains the honest lattice parameter Q08 perturbs.

### Pillar B — Range floor (whipsaw/cost gate) — conditional, must earn its place

```
trade session only if  range_v2 ≥ strategy_min_range_atr_mult × ATR(D1, 20)
default strategy_min_range_atr_mult = 0.50   (continuous param, Q08 ±10%)
```

- Rationale: whipsaw clusters AND cost-thin trades both live in low-range regimes
  (evidence: lb4 rows). A relative (ATR-normalized) floor is symbol-agnostic and
  tester-clean; the 0.50 default is first-principles (a breakout range below half a
  typical day's range carries neither signal nor $-edge), not fitted per symbol.
- **Anti-pattern guard (ICT lesson 2026-07-16: a filter that only concentrates has no
  predictive power):** Pillar B survives only if, vs Pillar-A-only, per-trade
  expectancy RISES and DD FALLS. If it merely removes trades proportionally
  (PF unchanged), it is dropped — simplicity wins. This is an explicit A/B stage
  (v2a = ensemble only, v2b = ensemble + floor), decided on evidence before Q08.

### Economics note (why B exists at all)

v1 gross profit-per-trade: GBPUSD ~$24, XAUUSD ~$17 at RISK_FIXED $1,000 —
cost-sensitive territory on FX (documented commission model:
`reference_commission_by_asset_class`, tester Groups file
`Darwinex-Live_real.txt`). XAUUSD carries the better cost profile; GBPUSD the better
gross PF cushion. Both stay in scope; the net gate (Stage 2 below) decides.

---

## 3. Parameter table (Q08-typed compliance view)

| Param | Default | Class | Q08 perturbation | Expected behavior / kill risk |
|---|---|---|---|---|
| `strategy_lookback_center` | 5 | discrete lattice | ±1 → ensembles {3,4,5} / {5,6,7} | THE design validation. Ensemble must hold DD ≤ 1.5× where raw lb4 hit 2.0–2.3×. If it still breaches, the edge does not support a robust estimator → v2 dies honestly. |
| `strategy_param` (K) | 0.50 | continuous | ±10% | Clean in v1 on both symbols (PF 1.10–1.24); expected clean. |
| `strategy_stop_range_mult` | 1.00 | continuous | ±10% | Clean in v1; ensemble range makes stops steadier. |
| `strategy_min_range_atr_mult` | 0.50 | continuous | ±10% | Only if v2b wins the A/B. Smooth by construction (marginal sessions enter/leave gradually). |
| `strategy_session_open/close_hhmm` | 1000 / 1900 | discrete lattice | ±1h | Untested in v1's pick; card-anchored (03:00/12:00 EST source rule). Expected tolerant; if session edges are load-bearing, that is a real fragility we want surfaced. |

No fitted coefficients anywhere → nothing to exclude from the lattice.

---

## 4. Validation plan & kill criteria (gates unchanged — no softening)

| Stage | What | Kill rule |
|---|---|---|
| 0. Build | v2a + v2b variants, GBPUSD + XAUUSD | build errors / smoke fail |
| 1. Q02 gross full-history | both variants × both symbols (4 runs) | PF < 1.20 on both symbols → RETIRE family; single-symbol survivor OK |
| 2. Net probe (ad-hoc, documented commission injection via report chain) | winner variant × both symbols | net PF < 1.10 → drop that symbol |
| 3. A/B decision | v2b beats v2a on expectancy AND DD? | else ship v2a (fewer params) |
| 4. Q05 / Q07 | DD ceiling, PBO/DSR with honest trial ledger (§5) | standard |
| 5. Q08 typed | full lattice incl. center ±1 | any breach = FAIL, final |
| 6. Q09/Q10 | portfolio fit vs Final-24, full-history confirm | standard |

Expected frequency: ~35–50 trades/yr/symbol (v2a ≈ v1 nominal; v2b trims the thin
tail) — an order of magnitude above the 5/yr economics floor.

## 5. Selection-bias ledger (feeds Q07 DSR/PBO honestly)

Distinct configs already evaluated on this family/data: v1 Q02 × 4 symbols; GBPUSD
lookback scans 2026-07-14/15 (T1/T9 series, ~12 runs); XAUUSD scan 2026-07-19 morning
(T2/T3 series, ~14 runs); Q08 perturbations 4+4; lb6/lb7 probes ×2. **≈ 35–40 trials
before v2.** v2 adds 4 (two variants × two symbols) with parameters FIXED at
first-principles defaults — no optimizer pass, no per-symbol tuning. Full-history +
fixed params = legit OOS-by-parameter-fix (`reference_gate_windows_and_oos`), but the
trial count must be declared to the DSR gate.

## 6. Build & process plan

1. New EA id + dir (next free id at registry append — **order of operations:** dirs →
   CSV append with tail-recheck → resolver regen → verify → compile serial; magic
   collision rule `grep '^<id>,'`). Suggested slug: `dual-thrust-v2-ensemble`.
2. Card: v2 revision referencing this design doc + original source citation
   (R1–R4 remain valid — same underlying source).
3. Builder: build lane (Codex or Claude-headless Sonnet), AFTER the current live-week
   priorities (Live-Blend extraction v1 due Friday outranks it). Agent-EA build rule:
   `symbol_slot` set/ZeroMemory (news-filter UB class).
4. Backtests through the normal T1–T10 queue — no manual terminal sessions while
   factory automation runs (Operating Rules 2026-07-03).

## 7. Risks / honesty section

- **Data-informed architecture:** the median-of-3 choice exists BECAUSE lb4 failed.
  That is one more trial on the same data; mitigated by the declared ledger (§5),
  fixed defaults, and the fact that v2 must survive the full untouched gate chain.
- **Ensemble may cost gross PF:** median-of-3 will sit between lb4/5/6 behavior;
  GBPUSD gross PF may land below v1's 1.25. Acceptable only if ≥ 1.20 (Q02 floor)
  and net-viable; otherwise the family retires and the verdict is final.
- **OWNER's "ich vernachlässige die 4er-Klippe":** noted as risk appetite, but the
  pipeline cannot — Q08 binds all admissions. v2's design answer is to remove the
  cliff mechanism rather than to relitigate the gate.
- Complexity budget: +1 param (v2b only). Anything beyond the two pillars
  (breakeven stops, trailing, HTF bias) is explicitly OUT of v2 — Balke lesson:
  surgical, one mechanism per revision.
