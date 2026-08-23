# Q04 — Walk-Forward + Commission

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q04 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q04 (Walk-Forward + Commission) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q03 Parameter Sweep]] · → [[Q05 Gross Full-History Robustness]] |

**Herkunft:** v4 Q04 = v3 Q04 (Walk-Forward + Commission), ID und Kriterien unverändert (ROT).

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** Anchored expanding, **3 folds × 12-month OOS: 2023, 2024, 2025**
**Spec version:** 2026-05-23 (post-rewrite)

**OOS BEGINS HERE.** Before Q04, OOS data (post-2022) is strictly off-limits — looking at it during Q02/Q03 is a hard embargo violation.

---

## Purpose

Q04 is the EA's first encounter with data it has never seen during development. Two things happen at once:

1. **Walk-forward validation** — does the EA generalise to unseen years?
2. **Commission applied** — does it still make money once realistic ECN fees ($7/lot round-trip) are subtracted?

Many EAs that look great on Q02/Q03 (in-sample, commission-free) die at Q04. That's the point.

---

## Hard Gate Criteria

| Criterion | Threshold |
|---|---|
| **Fold count** | 3 clean anchored folds (more auto-add as years close) |
| **Per-fold PF (commission-adjusted, "PF-net")** | **PF > 1.0 on every single fold** — no exceptions |
| **Commission** | **$7/lot round-trip ECN** applied to all trades |
| Embargo | DEV→HO clean — no OOS data was analysed during Q02/Q03 |
| Verdict basis | All folds must PASS — no average-out |
| Reported metrics | **Both PF-gross (no commission) AND PF-net (with commission) per fold** for diagnostic clarity |

**Per-symbol verdict.** Q04 runs per (EA, symbol) pair from the Q03-PASS set, using the plateau-median parameters chosen at Q03.

**Single backtest per fold, two PF numbers extracted** (OWNER call 2026-05-23). The MT5 run applies commission and produces PF-net directly. PF-gross is derived by adding back the per-trade commission cost from the trade log. The verdict is on PF-net; both numbers appear in the EA detail page so the operator can see whether the EA failed because of OOS regime change (PF-gross also low) or because of execution cost (PF-gross > 1.2 but PF-net < 1.0 → "edge eaten by commission, marginal candidate").

---

## Fold Geometry

**Anchored expanding window, 12-month OOS per fold:**

| Fold | DEV window | OOS window |
|---|---|---|
| **F1** | 2017-01-01 → 2022-12-31 | **2023-01-01 → 2023-12-31** |
| **F2** | 2017-01-01 → 2023-12-31 | **2024-01-01 → 2024-12-31** |
| **F3** | 2017-01-01 → 2024-12-31 | **2025-01-01 → 2025-12-31** |

**F4 auto-adds in Jan 2027** (OOS 2026), F5 in Jan 2028, etc. The pipeline always uses the **last closed calendar year** as the most recent OOS fold — partial years are NOT used (OWNER call 2026-05-23: "Das Jahr 2025 ist das letzte").

For each fold:
- DEV is the anchored expanding window (always starts 2017-01-01).
- OOS is the 12-month slice immediately after DEV.
- The EA uses the Q03-chosen plateau-median parameters fixed across all folds — Q04 does NOT re-optimise.
- Commission is applied during the OOS run.

---

## Commission Model

| Parameter | Value | Source |
|---|---|---|
| Commission per lot, round-trip | **$7** | quantmechanica.com/pipeline original spec |
| Application | Subtracted from gross P&L on every trade close | MT5 commission setting in `tester_defaults.json` |
| Per-instrument override | Future: per-instrument table in `framework/registry/tester_defaults.json` | If actual DXZ schedule differs materially |

The Q04 commission is the canonical realistic commission of the funnel. NOTE (re-ratified 2026-07-05, decisions/2026-07-05_q05_spec_reratification.md): Q05 runs GROSS (no cost multipliers were ever implemented); cost STRESS lives at Q08 via the DL-072 cost-cushion gate (gross must cover ≥2× worst-case commission). Q06's implemented stress is trade-rejection RNG, not cost multipliers.

---

## What Q04 explicitly does NOT do

- ❌ Re-optimise parameters per fold (Q03's job, already done)
- ❌ Pick the best fold and call it PASS (all folds must PASS)
- ❌ Apply stress (Q05/Q06's job)
- ❌ Run on 2026-YTD partial year (only closed calendar years count)

---

## Embargo Verification

Quality-Tech (or automated audit) confirms before Q04 runs:
- No work_item in Q02/Q03 history has `updated_at > 2023-01-01` AND `data_window` reaching past 2022-12-31.
- No report file under `D:/QM/reports/pipeline/QM5_<NNNN>/Q02/` or `/Q03/` references OOS data.

Embargo violation = Q04 Hard FAIL, regardless of fold performance.

---

## Workflow

1. Pipeline-Op reads the Q03 PASS list for the EA (per-symbol plateau-median params).
2. Verify embargo (Q02/Q03 reports clean).
3. Run: `python framework/scripts/q04_walkforward.py --ea QM5_<NNNN> --symbol <S> --params <plateau_pick.json>`
4. For each fold (F1, F2, F3): the runner produces an OOS backtest report with commission applied.
5. Per-fold verdict: PF > 1.0 commission-adjusted (PASS) or below (FAIL).
6. Overall verdict per (EA, symbol): PASS iff all 3 folds PASS.
7. Output:
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q04/<symbol>/F1/report.htm` (per-fold)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q04/<symbol>/folds.csv` (per-fold aggregate)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q04/report.csv` (per-symbol aggregate)

→ Runtime: `framework/scripts/q04_walkforward.py`

---

## Dashboard Display

Each Q04 (EA, symbol) row in the EA detail page expands to show the fold table:

| Fold | DEV window | OOS window | Trades | OOS Net (gross) | OOS Net (net) | PF gross | **PF net** | OOS DD% | Clean | Regime |
|---|---|---|---|---|---|---|---|---|---|---|
| F1 | 2017-01-01 → 2022-12-31 | 2023-01-01 → 2023-12-31 | … | … | … | … | … | …% | ✓ | trend/range/crisis |
| F2 | 2017-01-01 → 2023-12-31 | 2024-01-01 → 2024-12-31 | … | … | … | … | … | … | … | … |
| F3 | 2017-01-01 → 2024-12-31 | 2025-01-01 → 2025-12-31 | … | … | … | … | … | … | … | … |

**PF net** is the verdict basis (bold column). PF gross is informational — shows whether commission was the killer.

Regime label is informational (which market state dominated each OOS year) — does not affect the verdict.

---

## After Q04 PASS

- Symbol advances to Q05 Gross Full-History Robustness with the same plateau-median parameters.
- The commission-adjusted OOS PF and DD become the new baseline for downstream stress comparisons.

## After Q04 FAIL

- Symbol is removed from the EA's active universe.
- If ALL Q03-PASS symbols fail Q04, the EA is closed (terminal FAIL).
- Per-fold failure pattern goes into the lessons-learned entry (e.g. "PF > 1.0 on F1/F2 but collapsed on F3 → edge decay candidate, may not be the EA's fault but the regime shift").
