# Q07 — Multi-Seed Validation

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q07 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q07 (Multi-Seed) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q06 Stress HARSH]] · → [[Q08 Davey Statistical Validation]] |

**Herkunft:** v4 Q07 = v3 Q07 (Multi-Seed), ID und Kriterien unverändert (ROT).

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** Full history 2017 → present
**Spec version:** 2026-08-21 (adds OWNER 2026-07-25 second-axis rule; base rewrite 2026-05-23)

---

## Purpose

Q07 tests whether the EA's profitability is a function of one lucky random-number sequence (the MT5 tester seed) or a genuine signal. We run the same backtest 5 times with 5 different seeds and check that the PFs cluster tightly around the baseline.

An EA whose PF varies wildly across seeds — say 2.5 with seed 42 but 0.6 with seed 17 — is exploiting a seed-specific tick ordering, not a real edge.

---

## Hard Gate Criteria

| Criterion | Threshold |
|---|---|
| **Seed set** | **42, 17, 99, 7, 2026** (fixed canonical list) |
| **PF variance across seeds** | **< 20%** (relative to mean PF) — primary axis |
| **Second axis** (OWNER 2026-07-25) | Variance in **[20%, 40%)** also PASSes **if** the worst-seed PF ≥ **1.10**; variance **≥ 40%** → FAIL regardless |
| **Per-seed PF floor** | **No single seed produces PF < 1.0** (a losing seed FAILs on either axis) |
| Window | Full history |
| Parameters | Q03 plateau-median |
| Stress | Q06 HARSH settings applied (highest realistic stress) |

**Per-symbol verdict.** Runs per (EA, symbol) from Q06 PASS list.

**Why the second axis** (OWNER 2026-07-25, `decisions/2026-07-25_q07_second_axis_worst_seed_pf.md`).
The variance metric is *relative*, so it systematically fails the strongest sleeves — a PF≈2
sleeve whose seeds span 1.6–2.2 breaches 20% while every seed is deeply profitable, whereas a
PF≈1.05 sleeve with seeds 1.00–1.10 passes. Variance in [20%, 40%) is therefore tolerated when
the worst seed still clears the ratified cost-noise bottom (1.10, aligned with Q02's hard bottom
per DL-082 §4 and the 2026-07-25 Q02 decision). Variance ≥ 40% fails regardless — extreme
dispersion is overfit-to-fill-sequence territory no worst-seed floor excuses.

---

## Why these 5 seeds

| Seed | Why |
|---|---|
| **42** | Standard ML / scientific benchmark seed |
| **17** | Small prime, common alternative |
| **99** | Two-digit max, structurally distant from 42 |
| **7** | Small prime, structurally distant |
| **2026** | Time-specific (current year), eliminates "pre-2026 cherry-picked seeds" concern |

The set is **fixed** in `framework/registry/multiseed_seeds.json`. Adding/removing seeds requires an OWNER-approved decision record under `decisions/`.

---

## PF Variance Calculation

```
seeds = [42, 17, 99, 7, 2026]
pfs   = [run_backtest(seed=s) for s in seeds]   # 5 values
mean  = sum(pfs) / 5
variance_pct = (max(pfs) - min(pfs)) / mean * 100

# OWNER 2026-07-25 two-axis rule (SECOND_AXIS_MIN_PF=1.10, SECOND_AXIS_VARIANCE_PCT_MAX=40.0):
if min(pfs) < 1.0:
    verdict = "FAIL"                                          # losing seed, either axis
elif variance_pct < 20.0:
    verdict = "PASS"                                          # primary axis
elif variance_pct < 40.0 and min(pfs) >= 1.10:
    verdict = "PASS"                                          # second axis
else:
    verdict = "FAIL"                                          # variance >= 40%, or worst seed < 1.10
```

**No averaging-out.** If one seed gives PF 0.95, the EA fails Q07 even if the other four give 2.0+. The minimum-floor rule prevents seed-cherry-picking from passing.

Provenance: `decisions/2026-07-25_q07_second_axis_worst_seed_pf.md`; runtime constants at
`framework/scripts/q07_multiseed.py:49-59, 761-769`.

---

## What Q07 explicitly does NOT do

- ❌ Use seeds not in the canonical list
- ❌ Drop the weakest seed before averaging
- ❌ Re-optimise parameters per seed
- ❌ Allow the operator to choose which seed "counts"

---

## Workflow

1. Pipeline-Op reads Q06 PASS list per EA.
2. For each (EA, symbol), launch 5 backtests with seeds 42, 17, 99, 7, 2026.
3. Each backtest uses Q06 HARSH stress settings + Q03 plateau-median parameters.
4. Collect PFs, compute mean and variance percentage.
5. Verdict (OWNER 2026-07-25 two-axis): any seed PF < 1.0 → FAIL; else variance < 20% → PASS; else variance in [20%, 40%) AND worst-seed PF ≥ 1.10 → PASS; else (variance ≥ 40%, or worst-seed PF < 1.10) → FAIL.
6. Output:
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q07/<symbol>/seed_<N>/report.htm` (one per seed)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q07/<symbol>/seeds_aggregate.csv` (5-row table)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q07/report.csv` (per-symbol verdict)

→ Runtime: `framework/scripts/q07_multiseed.py`

---

## After Q07 PASS

- Symbol advances to Q08 Davey Statistical Validation.

## After Q07 FAIL

- Symbol removed from EA's active universe.
- If all Q06-PASS symbols fail Q07, EA is closed (terminal FAIL).
- Per-seed PF spread is logged — large spread is a leading indicator that the EA has data-snooping issues that earlier gates missed.
