# Phase Evidence JSON Schema

Each autonomous phase runner writes a `<phase_token>_<EAId>_result.json` plus an orchestrator-canonical `phase_orchestrator_last.json` to `D:\QM\reports\pipeline\<EAId>\<phase_token>\`.

## phase_orchestrator_last.json (canonical)

Written by `framework/scripts/run_phase.ps1`. Stable across phases.

```json
{
  "criterion": "string — the gate criterion as the runner reports it (e.g. 'P7 PBO < 5%')",
  "ea_id": "string — QM5_<NNNN> form",
  "evidence_path": "string — absolute path to <phase_token>_<EAId>_result.json",
  "phase": "string — one of P3.5 / P5 / P5b / P5c / P6 / P7 / P8",
  "symbols": ["string", "..."],
  "ts_utc": "string — ISO 8601 UTC, e.g. 2026-04-27T16:30:00Z",
  "verdict": "string — PASS | FAIL | YELLOW | NO_REPORT | SETUP_DATA_MISSING | SETUP_DATA_MISMATCH"
}
```

## Per-runner result JSON

Each phase runner under `framework/scripts/p*_*.py` writes its own result file. Common fields (not all present in all phases):

| Field | Type | Required | Notes |
|---|---|---|---|
| `verdict` | string | yes | PASS / FAIL / YELLOW / NO_REPORT etc. |
| `criterion` | string | yes | Plain-English gate description |
| `ea_id` | string | yes | `QM5_<NNNN>` form |
| `phase` | string | yes | Matches caller's `-Phase` |
| `symbols_run` | array | yes | Subset of `magic_numbers.csv` active symbols actually executed |
| `metrics` | object | phase-specific | E.g. `{ "PF": 1.42, "DD": 0.084, "T": 312 }` |
| `gate_checks` | array | yes | Per-criterion pass/fail records |
| `htm_paths` | array | when MT5 reports exist | Absolute paths to MT5 strategy-report HTM files |
| `setup_classification` | string | optional | If verdict ∈ `SETUP_DATA_*`, names the missing/mismatched input |

## NO_REPORT disambiguation rule

A size-0 `.htm` is `NO_REPORT`, not `FAIL`. The runner must `Test-Path` + check file length:

```
if (Test-Path $htm) {
    if ((Get-Item $htm).Length -eq 0) -> verdict = NO_REPORT
    else parse the HTM normally
}
```

Per `docs/ops/PIPELINE_PHASE_SPEC.md` § Hard Rules.

## SETUP_DATA_* never = strategy FAIL

If a phase fails because of missing news seed (`SETUP_DATA_MISSING`) or DST mismatch (`SETUP_DATA_MISMATCH`), the verdict stays in the SETUP class. Strategy PASS / FAIL evaluation is suspended until the setup quality is fixed.
