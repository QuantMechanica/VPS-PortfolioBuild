# Q03 — Parameter Sweep

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q03 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q03 (Parameter Sweep) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q02 Baseline Screening]] · → [[Q04 Walk-Forward + Commission]] |

**Herkunft:** v4 Q03 = v3 Q03 (Parameter Sweep), ID und Kriterien unverändert (ROT).

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** IS 2017-01-01 → 2022-12-31 (same as Q02 — **OOS still off-limits**)
**Spec version:** 2026-05-23 (post-rewrite)

---

## Purpose

Q03 asks: is this EA's Q02 PASS robust across the parameter neighbourhood, or did it just happen to PASS at the single default parameter point? An EA that passes Q02 only at one razor-thin parameter combination is curve-fit; an EA that passes broadly across a parameter plateau has a real edge.

Q03 runs the parameter sweep **only on symbols that PASSed Q02** for this EA.

---

## Hard Gate Criteria

| Criterion | Threshold |
|---|---|
| **Profitable configs** | **≥ 50% of all swept configurations have PF > 1.0** |
| **Plateau width** | **≥ 3 contiguous configs profitable** in the parameter grid |
| Chosen parameters | **Plateau-median**, not best (cherry-pick penalty) |
| Sample size per config | Same as Q02 (≥ 100 trades per config minimum) |
| Window | 2017-01-01 → 2022-12-31 (IS only) |

**Per-symbol verdict.** Q03 runs the sweep per symbol. A symbol PASSes Q03 if both thresholds hold on its sweep grid.

---

## Cherry-pick Penalty Rule

The best-performing parameter combination in the sweep is **never** picked as the canonical parameter set. Instead:

- Identify the contiguous plateau of profitable configs.
- Pick the **median** config from that plateau.
- That median is what advances to Q04+.

Rationale: best-in-grid is the most likely to be in-sample overfit. Plateau-median has the best generalisation odds.

---

## Plateau Detection

The **prospective plateau gate is one-dimensional by contract**: exactly one
ordered numeric strategy axis, so plateau adjacency is unambiguous. Runtime:
`framework/scripts/q03_plateau_runner.py` (`minimum_fraction = 0.5`,
`minimum_contiguous_width = 3` — matching the Hard Gate Criteria above). The
axis must be a real MQ5 strategy input with `value_type` int/double; cells are
the ordered axis values. Plateau = contiguous run of axis values where every
config has PF > 1.0.

Width ≥ 3 means: at least 3 adjacent axis values all profitable. A lone
profitable point with neighbours below 1.0 = noise, not plateau, **FAIL**.

> [!note] Legacy multi-axis sweep
> The earlier `p3_param_sweep.py` tooling swept a 2D/3D grid (e.g. fast EMA ×
> slow EMA × stop-loss-ATR). It survives as **sweep/exploration tooling
> only** — the closing Q03 verdict is decided by the one-dimensional
> `q03_plateau_runner.py` contract above.

---

## What Q03 explicitly does NOT do

- ❌ Touch OOS data (Q04's job)
- ❌ Apply commission (Q04's job)
- ❌ Try to improve PF beyond what the plateau-median gives
- ❌ Expose individual sweep configs to the dashboard (operator sees aggregate stats + plateau-median result only)

---

## Workflow

1. Pipeline-Op reads Q02 PASS list for the EA.
2. Sweep config (parameter ranges) defined in `framework/EAs/QM5_<NNNN>_<slug>/sweep_grid.json` — typically 100-200 configs per EA.
3. Run: `python framework/scripts/p3_param_sweep.py --ea QM5_<NNNN> --symbols <Q02_pass_list> --grid sweep_grid.json`
4. Per-symbol heatmap aggregation: PF over the parameter grid.
5. Plateau detection algorithm picks the median plateau config per symbol.
6. Update `SPEC.md` with the Q03-chosen parameters (replace defaults).
7. Verdict: PASS if ≥ 50% configs profitable AND plateau width ≥ 3 — per symbol.
8. Output:
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q03/<symbol>/sweep_heatmap.csv`
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q03/<symbol>/plateau_pick.json`
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q03/report.csv` (aggregate)

→ Runtime (prospective plateau gate, closing verdict): `framework/scripts/q03_plateau_runner.py`
(one-dimensional contract; operatorseitiges Gate Q03). The legacy
`framework/scripts/p3_param_sweep.py` remains available as multi-axis
sweep/exploration tooling only, not as the verdict source.

---

## Dashboard Display Rule (OWNER call 2026-05-23)

Q03 individual sweep configurations are **not displayed** in the EA detail page. The operator sees:
- Symbol
- `N tried / M profitable` ratio
- Plateau width found
- Plateau-median parameters chosen
- Best-of-grid PF (for context, NOT as the verdict basis)

Per-config rows are stored on disk but hidden from the UI to avoid the "269 attempts" cognitive load.

---

## After Q03 PASS

- Plateau-median parameters get written into `SPEC.md` and the canonical setfile.
- The EA advances to Q04 with these tuned parameters, NOT the Q02 defaults.
- Commit: `fix(QM5_<NNNN>): Q03 plateau-median params adopted`

---

## After Q03 FAIL

- Symbol is removed from the EA's active universe.
- If ALL Q02-PASS symbols fail Q03, the EA is closed (terminal FAIL).
- Lessons-learned entry under `docs/research/` if the failure pattern is informative.
