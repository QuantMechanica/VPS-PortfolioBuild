# Open Topics Closeout 2026-05-21

Status: Codex closeout note
Scope: Company Reference open operational items that can be handled without OWNER-only decisions or Claude availability.

## Closed / Improved

### QM5_1056 Q08 failure documented

Closeout exists at `docs/ops/QM5_1056_Q08_P5C_FAIL_2026-05-21.md`.

Decision recorded: `QM5_1056` is blocked at Q08 and must not be presented as Q11 proof or Q12 candidate without a fresh Q08 PASS.

### Framework test drift cleaned up

`framework/scripts/tests` broad discovery is now meaningful again.

Verification:

```powershell
python -m pytest framework/scripts/tests -q
```

Result: `111 passed, 1 skipped`.

The skipped test is the retired `run_phase` `phase_runner_log.jsonl` contract; current runners use result JSON and orchestrator metadata instead.

### Build / registry gates hardened

The previously missing `.ex5` examples from the audit now have matching binaries on disk:

- `QM5_2010`
- `QM5_3001`
- `QM5_3002`
- `QM5_3003`
- `QM5_3004`
- `QM5_3005`

Upstream and worker-side gates now reject:

- missing EA dir
- ambiguous EA dirs
- missing expected `.ex5`
- duplicate `.ex5` files in an EA dir
- missing setfile path

Touched gate paths:

- `tools/strategy_farm/farmctl.py`
- `tools/strategy_farm/terminal_worker.py`

Verification:

```powershell
python -m pytest tools/strategy_farm/tests -q
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/terminal_worker.py framework/scripts/p2_baseline.py
```

Result: `47 passed, 3 subtests passed`; py_compile PASS.

## Still Intentionally Open

### Dashboard UX overhaul

Still blocked by policy until Claude is available and OWNER/quota guardrails allow it.

Artifact: `G:/My Drive/QuantMechanica - Company Reference/Agent Tasks/Claude_Dashboard_UX_Overhaul_Task_2026-05-20.md`.

### Physical artifact cleanup

The gates now prevent bad rows from entering or consuming MT5 capacity, but two known filesystem drifts remain physically present and should be removed only in a dedicated cleanup pass:

- `QM5_1002`: duplicate/legacy EA directories
- `QM5_1003`: duplicate `.ex5` file

Current operational behavior: these are deterministic preflight/enqueue failures, not silent MT5-slot consumers.

### T1-T10 factory saturation

Live check after changes: 10/10 factory terminals active, no duplicate workers, no orphaned terminal processes.

### OWNER-only decisions

Not touched:

- YouTube #2
- public dashboard claims/go-live
- T6/DXZ live actions
- Anthropic spend/org-cap actions
