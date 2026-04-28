---
name: qm-run-pipeline-phase
description: Use when Pipeline-Operator is executing P3.5 / P5 / P5b / P5c / P6 / P7 / P8 on a built EA (compile-PASS, registry-clean). Don't use on incomplete builds (no `.ex5`), don't use for P1 / P2 / P3 / P4 (those are upstream gates with separate runners), and don't use for P9+ (manual OWNER phases).
owner: Pipeline-Operator
reviewer: Quality-Tech
last-updated: 2026-04-27
basis: framework/scripts/run_phase.ps1 (verbatim wrapper) + docs/ops/PIPELINE_PHASE_SPEC.md
---

# qm-run-pipeline-phase

Procedure for running a single autonomous-gate pipeline phase on a built EA via the canonical orchestrator `framework/scripts/run_phase.ps1`. Mirrors the V5 / V2.1 pipeline phase spec.

## When to use

- EA has compile-PASS via `compile_one.ps1 -Strict` (a `.ex5` exists)
- EA is registered in `framework/registry/magic_numbers.csv` with at least one `status=active` symbol row
- The phase you want to run is one of: `P3.5`, `P5`, `P5b`, `P5c`, `P6`, `P7`, `P8`

## When NOT to use

- No `.ex5` exists (build first via `qm-build-ea-from-card`)
- Phase is `P1` / `P2` / `P3` / `P4` — those use separate runners (`run_smoke.ps1` / baseline / sweep / WF), not `run_phase.ps1`
- Phase is `P9` / `P9b` / `P10` — those are **manual OWNER** phases, not autonomous; this skill does not apply
- Phase is `G0` (Research Intake) — that is `qm-strategy-card-extraction`, not a backtest gate

## Phase map (autonomous gates only)

Per `docs/ops/PIPELINE_PHASE_SPEC.md`:

| Phase | Name | Gate |
|---|---|---|
| P3.5 | Cross-Sectional Robustness | V2.1 additive — orthogonal asset-class robustness |
| P5 | Stress Test | Single calibrated stress, `PF > 1.0`, full history |
| P5b | Calibrated Noise | MC noise/latency/jitter, ≥70% proxy compliance |
| P5c | Crisis Event Slices | Optional, report-first |
| P6 | Multi-Seed | 5-seed stability gate (seeds: 42, 17, 99, 7, 2026) |
| P7 | Statistical Validation | DSR + MC + FDR + **PBO < 5% hard gate** |
| P8 | News Impact | 7 modes: OFF / PAUSE / SKIP_DAY / FTMO_PAUSE / 5ers_PAUSE / no_news / news_only |

## Procedure

### 1. Pre-flight verification

```text
- .ex5 exists:         framework/EAs/QM5_<NNNN>_<slug>/QM5_<NNNN>_<slug>.ex5
- Magic registry:      framework/registry/magic_numbers.csv has rows for ea_id with status=active
- Setfiles for env:    .set files exist in framework/EAs/.../sets/
- Disk space:          D:\QM\reports\pipeline\ has ≥ 2 GB free per phase run
- Terminal availability: T1-T5 not all busy (Pipeline-Operator distributes across factory)
```

### 2. Invoke the runner

The orchestrator is `framework/scripts/run_phase.ps1`. Canonical invocation:

```powershell
framework/scripts/run_phase.ps1 -EAId QM5_<NNNN> -Phase <P3.5|P5|P5b|P5c|P6|P7|P8> [-Symbols <list>] [-OutRoot D:\QM\reports\pipeline]
```

Notes on the parameter contract (verified against the actual script):

- `-EAId` accepts `QM5_<id>` or numeric `<id>` (e.g. `QM5_1001` or `1001`)
- `-Phase` is validated against the set above; unknown phases fail at parse time
- `-Symbols` is optional; if omitted, the runner uses **every** active symbol from `magic_numbers.csv` for that ea_id
- If `-Symbols` is provided, every symbol must be in `magic_numbers.csv` with `status=active` for this ea_id, else the runner throws
- `-OutRoot` defaults to `D:\QM\reports\pipeline`

### 3. Output layout

The runner writes per-phase JSON evidence to:

```text
D:\QM\reports\pipeline\<EAId>\<phase_token>\
  <phase_token>_<EAId>_result.json     # runner output (criterion, verdict, evidence)
  phase_orchestrator_last.json         # canonical orchestrator summary record
  ...                                  # phase-specific artifacts (logs, charts, etc.)
```

`<phase_token>` replaces `.` with `_` (e.g. `P3.5` → `P3_5`).

### 4. Post-phase aggregation

`run_phase.ps1` automatically runs `aggregate_phase_results.py` after a successful phase. It rolls phase results into the EA's aggregated history. If aggregation fails, the phase is **not** considered complete.

### 5. Capture evidence path on the issue

Post the phase result path back to the parent Paperclip issue as a comment:

```text
Phase: <phase>
EA: QM5_<NNNN>_<slug>
Symbols: <list>
Verdict: <PASS|FAIL|YELLOW|NO_REPORT>
Evidence: D:\QM\reports\pipeline\<EAId>\<phase_token>\
Orchestrator record: phase_orchestrator_last.json
```

### 6. Distribute across T1-T5 (de-dup queue)

For multi-symbol phases that take long, distribute the symbol list across T1-T5 with a de-duplication queue (per QUA-236 child #5). Never run the same (ea_id, phase, symbol) on two terminals simultaneously — it produces duplicate evidence and wastes wall-clock.

### 7. Verdict handling

| Verdict | Meaning | Next step |
|---|---|---|
| `PASS` | All gate criteria met | Move to next phase |
| `FAIL` | Hard-gate broken (e.g. P7 PBO ≥ 5%) | Stop pipeline; file `_v2` per `qm-zero-trades-recovery` if structural |
| `YELLOW` | Soft-gate breach, calibrated waiver candidate | Quality-Tech reviews; OWNER decides |
| `NO_REPORT` | Size-0 `.htm` (no trades produced) | Disambiguate via file-size check; may trigger `qm-zero-trades-recovery` if cohort threshold met |
| `SETUP_DATA_MISSING` / `SETUP_DATA_MISMATCH` | Setup-quality failure (data, not strategy) | Fix setup; do not classify as strategy FAIL |

## Boundary

- This skill does **not** decide go / no-go between phases — that is autonomous via verdict + Pipeline-Operator orchestration; YELLOW reviews escalate to Quality-Tech + OWNER.
- This skill does **not** modify `framework/scripts/*` — that is CTO + Quality-Tech.
- This skill does **not** touch T6 — autonomous phases run on T1-T5 only.
- `NO_REPORT` and `SETUP_DATA_*` are never strategy PASS/FAIL signals.

## References

- `framework/scripts/run_phase.ps1` — orchestrator (source of truth for parameter contract)
- `docs/ops/PIPELINE_PHASE_SPEC.md` — full phase definitions + gates
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` — V5 sub-gate detail (default thresholds)
- `docs/ops/PIPELINE_AUTONOMY_MODEL.md` — who is allowed to change gate thresholds
- `references/phase_evidence_schema.md` — expected JSON schema of phase result files
- `decisions/2026-04-25_pipeline_15_phase_override.md` — why the 15-phase map supersedes the older 10-phase map
