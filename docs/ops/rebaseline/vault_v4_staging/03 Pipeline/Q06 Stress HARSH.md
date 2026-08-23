# Q06 — Stress HARSH

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q06 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q06 (Stress HARSH) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q05 Gross Full-History Robustness]] · → [[Q07 Multi-Seed]] |

**Herkunft:** v4 Q06 = v3 Q06 (Stress HARSH), ID und Kriterien unverändert (ROT).

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** Full history 2017 → present
**Spec version:** 2026-07-06 (re-ratified to match implementation, `decisions/2026-07-06_q06_spec_reratification.md`; supersedes 2026-05-23)

---

## Purpose

Q06 ist das Execution-Adversity-Gate des Funnels: **die einzige implementierte
Stress-Dimension ist eine geseedete 10%-Trade-Rejection** (`qm_stress_reject_probability=0.10`),
die Requotes/Connection-Drops modelliert. Kosten-Stress liegt NICHT hier: Kostenrealismus
= Q04 (Commission-Gate), Kosten-STRESS = Q08 DL-072 Cost-Cushion. (Historische Notiz:
die früher beschriebenen Slippage-/Spread-/Commission-Multiplikatoren waren nie
implementiert.) Ein EA, der Q06 übersteht, verkraftet ausfallende Fills, ohne
nachzukaufen, zu doublen oder zu hängen.

---

## Hard Gate Criteria (as implemented — `framework/scripts/q06_stress_harsh.py`)

| Criterion | Threshold |
|---|---|
| **Trade rejection** | **10% of trade attempts randomly rejected**, seeded RNG (`qm_stress_reject_probability=0.10`) — die EINZIGE Stress-Dimension |
| **Profit Factor** | **> 1.0** post-stress |
| **Max Drawdown** | **< 25%** post-stress (Schwellen importiert aus Q05; 15→25 OWNER 2026-07-15) |
| **Trades** | ≥ 20 over the full window |
| Window | Full available history 2017 → present |
| Parameters | Q03 plateau-median (locked) |

**Per-symbol verdict.** Runs per (EA, symbol) from Q05 PASS list.

---

## Trade Rejection Model

10% of trade-open attempts are randomly dropped before the order reaches MT5. The EA must handle this gracefully — it should not endlessly retry, double up, or hang.

If the EA's logic depends on every trade attempt succeeding (e.g. martingale, grid recovery), it will likely fail Q06 even if the underlying signal is good. That's intentional — such EAs are not robust enough for live deployment.

Implementation: a wrapper around `OrderSend()` that returns `false` with probability 0.10 deterministically based on a seeded RNG (so the test is reproducible).

---

## What Q06 explicitly does NOT do

- ❌ Apply cost stress (slippage/spread/commission multipliers) — war nie implementiert;
  Kostenrealismus = Q04, Kosten-Stress = Q08 DL-072 Cushion
- ❌ Re-optimise parameters
- ❌ Allow trade-rejection to be turned off "for fairness" — 10% is part of the gate
- ❌ Use a custom stress profile per EA

---

## Workflow

1. Pipeline-Op reads Q05 PASS list per EA.
2. Generate Q06 setfile from Q03 plateau-median + genau EINEM Override:
   `qm_stress_reject_probability=0.10` (seeded RNG; `gen_stress_setfile.py`).
3. Run: `python framework/scripts/q06_stress_harsh.py --ea QM5_<NNNN> --symbol <S>`
4. Single backtest per (EA, symbol) on full history with rejection stress.
5. Verdict: PF > 1.0 AND DD < 25% AND trades ≥ 20 → `PASS`. **PASS_SOFT ist LIVE seit
   2026-08-21** (OWNER Option A, commit `47f751d1d`;
   `docs/ops/Q05_Q06_FAIL_SOFT_VORLAGE_2026-08-21.md`, Band-Sizing
   `docs/ops/evidence/2026-08-21_q06_fail_soft_band_sizing.md`): ein EA mit
   **PF in [0.95, 1.0)** (`SOFT_PF_FLOOR=0.95`) AND DD < 25% AND trades ≥ 20 emittiert
   `PASS_SOFT` mit persistentem Marker `probation:q06_soft` und rückt auf Bewährung nach
   Q07 vor. DD und Trade-Frequenz bleiben harte, unveränderte Schwellen. **PF < 0.95
   bleibt `FAIL`** (ebenso PF == 1.0, außerhalb des `< 1.00`-Bands). Der Runner emittiert
   damit `PASS` / `PASS_SOFT` / `FAIL` / `INVALID`.
6. Output:
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q06/<symbol>/report.htm`
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q06/report.csv`

→ Runtime: `framework/scripts/q06_stress_harsh.py`

---

## After Q06 PASS

- Symbol advances to Q07 Multi-Seed.

## After Q06 FAIL

- Symbol removed from EA's active universe.
- If all Q05-PASS symbols fail Q06, EA is closed (terminal FAIL).
- High Q06 failure rate across an EA's universe = likely fragile execution model. Worth a card-level note about expected trade frequency vs slippage budget.
