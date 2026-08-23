# Q05 — Gross Full-History Robustness (formerly "Stress MEDIUM")

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q05 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q05 (Gross Full-History Robustness) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q04 Walk-Forward + Commission]] · → [[Q06 Stress HARSH]] |

**Herkunft:** v4 Q05 = v3 Q05 (Gross Full-History Robustness), ID und Kriterien unverändert (ROT).

---

> **Fail-Soft-Status (2026-08-21):** Q05 besitzt zwei dokumentierte Nicht-Hard-Kill-Pfade —
> die Salvage-Lane (unten) und den `FAIL_DD_PORTFOLIO_REVIEW`-Park (DL-082 §4). Eine
> generelle PASS_SOFT-Weiterleitung ist als OWNER-Vorlage eingereicht:
> `docs/ops/Q05_Q06_FAIL_SOFT_VORLAGE_2026-08-21.md` (ROT — wartet auf Freigabe).

**Gate Owner:** Pipeline-Op (automated)
**Data window:** Full history 2017 → present
**Spec version:** 2026-07-05 (re-ratified to match implementation; supersedes 2026-05-23)

---

## ⚠️ Spec re-ratification 2026-07-05

The 2026-05-23 spec described cost stress (slippage +2 pips, spread ×2,
commission ×2) that was **never implemented** — discovered 2026-07-05 during the
Q05 salvage analysis (evidence: `docs/research/Q05_SALVAGE_TRACK_PROPOSAL_2026-07-05.md`,
correction section; decision record `decisions/2026-07-05_q05_spec_reratification.md`).
OWNER ratified option (b): the spec now describes what the gate actually does —
which is a meaningful test in its own right. Genuine cost stress turned out to
**already exist at Q08** via the DL-072 cost-cushion gate (PASS requires the gross
edge to survive **2× worst-case per-instrument commission**; 1–2× = EDGE_SOFT →
feeds Q10 news). All historical Q05 verdicts remain valid under this spec.

---

## Purpose

Q05 tests whether the EA's edge survives **outside its tuned parameter point and
across the full history**: the run uses the Q03 plateau-median parameters (not the
card/backtest-optimal set) over the entire 2017→present window at gross (.DWX)
costs. An EA that cannot stay profitable gross, on robust parameters, across the
full window is too fragile to advance.

Real commission realism is applied earlier, at **Q04 (commission gate via the
tester groups file)** — Q05 adds the parameter-robustness + full-window dimension.

---

## Hard Gate Criteria (as implemented — `framework/scripts/q05_stress_medium.py`)

| Criterion | Threshold |
|---|---|
| **Profit Factor** | > 1.0 (gross, full history) |
| **Max Drawdown** | < **25%** (standalone, RISK_FIXED sizing; 15→25 OWNER 2026-07-15, `decisions/2026-07-15_dd_ceiling_25pct_portfolio_rationale.md`) |
| **Trades** | ≥ 20 over the full window |
| Window | Full available history 2017 → present |
| Parameters | Q03 plateau-median (locked from Q03; not re-optimised) |
| Costs | Gross .DWX basis (no synthetic stress) |

**Per-symbol verdict.** Runs per (EA, symbol) from Q04 PASS list.

---

## What Q05 explicitly does NOT do

- ❌ Apply cost stress (slippage/spread/commission multipliers) — never implemented;
  cost realism = Q04 commission gate; cost STRESS = Q08 DL-072 cost-cushion
  (2× worst-case commission for PASS)
- ❌ Apply trade-rejection (Q06 HARSH only — implemented, `qm_stress_reject_probability`)
- ❌ Re-optimise parameters

---

## Workflow

1. Pipeline-Op reads Q04 PASS list per EA.
2. Generate the Q05 setfile from the Q03 plateau-median (header relabel +
   `qm_stress_reject_probability=0.0`; no cost overrides).
3. Run: `python framework/scripts/q05_stress_medium.py --ea QM5_<NNNN> --symbol <S>`
4. Single backtest per (EA, symbol) on full history.
5. Verdict: PF > 1.0 AND DD < 25% AND trades ≥ 20 → PASS. Mögliche Verdikte:
   `PASS` / `FAIL` (pf/trades unter Floor) / `INVALID` (Infra) /
   `FAIL_DD_PORTFOLIO_REVIEW` (DD-Bruch bei PF > 1.0 → geparkt für
   Portfolio-Marginalbewertung, DL-082 §4 — kein Auto-RETIRE, kaskadiert nicht
   nach Q06).

---

## After Q05 PASS

- Symbol advances to Q06 Stress HARSH.

## After Q05 FAIL

- Symbol removed from EA's active universe (all-fail ⇒ EA terminal FAIL).
- **Salvage lane (OWNER-ratified 2026-07-05):** `dd_above_ceiling` fails with
  gross PF > 1.0 may enter the documented direct-to-Q08 salvage lane (probation
  weights, portfolio-level DD judgment) — see
  `docs/research/Q05_SALVAGE_TRACK_PROPOSAL_2026-07-05.md`. `pf_below_floor`
  fails are gross-unprofitable and stay terminal.
