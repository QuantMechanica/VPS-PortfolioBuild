# DL-054 Integration Plan — Pipeline-Op launcher wiring

**Author:** Board Advisor 2026-05-01 — draft for CTO review/merge Tuesday post-Codex-restore.
**Authority:** DL-054, OWNER directive 2026-05-01.
**Companion:** `framework/scripts/dl054_gates.py` — gate library.

This is a candidate integration plan. Codex (CTO) was offline when authored, so this stays as a review-and-merge artifact rather than a direct edit to production runners. CTO ratifies / refines / merges Tuesday.

## Goal

Wire the five DL-054 gates into Pipeline-Op's existing launcher stack so every `(ea_id, phase, symbol)` row that reaches `report.csv` has all five gates passed. Any gate fail → `verdict = INVALID` (not PASS, not FAIL) with `invalidation_reason`.

## Existing launcher stack

| File | Role | Gate touch |
|---|---|---|
| `framework/scripts/pipeline_dispatcher.py` | top-level matrix dispatch + dedup + state | G1, G5 (pre-launch dispatch refusal) |
| `framework/scripts/run_phase.ps1` | per-phase orchestrator (P3.5..P8) | G2 (assert tester profile + setfile) |
| `framework/scripts/run_backtest_smoke.ps1` | smoke / P0..P2 path | G2, G3, G4 |
| `framework/scripts/run_smoke.ps1` | older smoke fixture | G2, G3, G4 |
| `framework/scripts/p35_csr_runner.py` … `p8_news_impact.py` | per-phase python runners | G3, G4 (post-launch parse) |
| `framework/scripts/gen_setfile.ps1` | RISK_FIXED setfile generator | G2 inputs |
| `framework/scripts/resolve_backtest_target.py` | per-row terminal/setfile resolution | calls gates pre-dispatch |

## Splice points

### A. Pre-dispatch gates (pipeline_dispatcher.py)

```python
# At job/matrix submission time, before fanning out to terminals:
from dl054_gates import apply_pre_launch_gates

def dispatch_or_invalidate(job, *, terminal, window_start, window_end, launch_config, report_csv_path):
    prev = apply_pre_launch_gates(
        ea_id=job["ea_id"], phase=job["phase"], symbol=job["symbol"], terminal=terminal,
        window_start=window_start, window_end=window_end, launch_config=launch_config,
    )
    if prev.verdict == "INVALID":
        write_invalid_row(report_csv_path, prev)
        return None  # do NOT launch tester
    return prev  # caller proceeds to launch + post-launch gates
```

### B. Post-launch gates (per-phase runner closeout)

After tester finishes, before writing `verdict = PASS` to `report.csv`:

```python
from dl054_gates import apply_post_launch_gates

post = apply_post_launch_gates(
    pre_verdict,
    journal_path=Path(rf"D:\QM\mt5\{terminal}\Tester\logs\{date}.log"),
    report_path=run_dir / "report.htm",
)
write_csv_row(report_csv_path, post.to_csv_row(evidence_path=str(run_dir / "summary.json")))
if post.verdict == "INVALID":
    # do NOT advance to next phase for this EA
    return False
```

### C. report.csv schema extension

Add two columns:

```
ea_id,phase,symbol,terminal,verdict,invalidation_reason,evidence
```

`verdict` enum: `PASS | FAIL | INVALID | ZERO_TRADE`. The earlier QUA-662 audit (`docs/ops/QUA-662_PHANTOM_PASS_AUDIT_2026-05-01.md`) and `D:/QM/reports/pipeline/QM5_1003/P2/INVALIDATION_NOTICE.md` use `INVALID` as the gate-fail verdict.

## Ratification path Tuesday

1. **CTO** (`241ccf3c-...`) — review `dl054_gates.py` for parser correctness on actual MT5 `report.htm` shape (G4). The `parse_trade_count` patterns are a starter set; CTO refines against real reports from QM5_1003 P2_postfix2 (the only known good run).
2. **Pipeline-Op** (`46fc11e5-...`) — refactor `pipeline_dispatcher.py` per Splice A; adapt `run_phase.ps1` to call gate library after every per-symbol run per Splice B.
3. **Quality-Tech** (`c1f90ba8-...`) — gate-of-record per DL-054. Reviews any subsequent P2/P3.5/P5/P5b/P5c/P6/P7/P8 matrix and rejects if `report.csv` row count doesn't match all-five-gates-passed count.
4. **Doc-KM** (`8c85f83f-...`) — DL recording the integration once committed; updates `processes/16-backtest-execution-discipline.md` with the gate workflow.

## Acceptance test for the integration

Run a single deliberate gate-fail to verify the path:

```powershell
# Force a deliberate G2 fail by using a setfile WITHOUT RISK_FIXED token:
.\framework\scripts\run_backtest_smoke.ps1 -EA QM5_1003 -Symbol EURUSD.DWX `
    -SetfilePath '...\set_without_risk_fixed.set' -Terminal T1
```

Expected: `report.csv` row written with `verdict=INVALID`, `invalidation_reason=G2:risk_fixed_token_missing`. No tester launch occurred.

Repeat with deliberate G3 fail (force a no-history symbol e.g. XBRUSD.DWX with 2024 window) — should fail G1 pre-launch.

## Out of scope for this draft

- Refactor of run_phase.ps1's PowerShell to call into Python gate library — CTO designs the bridge (likely via `python -m framework.scripts.dl054_gates ...` subprocess or via the existing `_phase_utils.py` helper).
- Per-phase ADR templates for `decisions/<date>_zero_trade_<ea>_<symbol>.md` — Doc-KM authors a template at `decisions/_TEMPLATE_zero_trade.md` once the gate library lands.
- QUA-687 D3 follow-up (DL-054 gap triage doc) — superseded by this integration; CTO links closeout.

## Cross-references

- `decisions/DL-054_anti_theater_pass_criteria.md` — gate spec
- `framework/registry/tester_defaults.json` — G2 inputs
- `D:\QM\mt5\T1\dwx_import\logs\hourly_<latest>.log` — G1 + G5 inputs
- `docs/ops/QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md` — context for G1
- `docs/ops/QUA-662_PHANTOM_PASS_AUDIT_2026-05-01.md` — origin failure mode
- QUA-687 — earlier D3 triage doc, superseded by this artifact
