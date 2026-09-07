# Stranded infrastructure deterministic-retry guard

Date: 2026-09-07

Router task: `b2b17c4f-35b3-4755-9295-b716bac58882`

Disposition: **REVIEW — code and tests complete; no factory mutation or worker reload**

## Outcome

`sweep_enqueue_built_eas.py` now reads the newest row-bound
`payload_json.verdict_reason` before re-enqueueing a stranded `INFRA_FAIL`.
It refuses these narrow deterministic classes:

| Source reason | Triage class |
|---|---|
| `run_smoke_fail:*ONINIT_FAILED*` | `run_smoke_oninit_failed` |
| `run_smoke_fail:*INPUTS_INVALID*` | `run_smoke_inputs_invalid` |
| `compile_gate:COMPILE_FAILED*` | `compile_gate_failed` |
| Current Q02/Q03 setfile does not satisfy `RISK_FIXED > 0` and `RISK_PERCENT = 0` | `setfile_fixed_risk_contract` |

Each refused row is present both in
`part2_stranded.skipped` and `part2_stranded.triage`. The sweep also atomically
writes the actionable daily list to
`docs/ops/evidence/YYYY-MM-DD_stranded_infra_sweep_triage.json`. Rows carry the
source work-item ID, source status/time, exact verdict reason, setfile, and the
required repair/retire or governed-requalification action.

The classifier is intentionally narrow. `NO_HISTORY`, timeouts,
`worker_crashed_handling_item`, launch faults, and bare `INCOMPLETE_RUNS` remain
retryable. The existing attempt cap is unchanged. No historical verdict or
source payload is rewritten. The Q08-specific strategy-parameter parser remains
Q08-only because its neighborhood grammar is not a Q02/Q03 admission rule; the
shared fixed-risk invariant is the sound cheap Q02/Q03 setfile check.

## Verification

```powershell
Set-Location C:\QM\repo
python -m pytest -q tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py
python -m py_compile tools/strategy_farm/sweep_enqueue_built_eas.py
git diff --check -- tools/strategy_farm/sweep_enqueue_built_eas.py tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py docs/ops/evidence/2026-09-07_stranded_infra_sweep_triage.json docs/ops/evidence/2026-09-07_stranded_infra_deterministic_retry_guard/README.md
```

Result: `15 passed in 6.51s`; compile and whitespace checks passed. The new
end-to-end fixture uses an SH3-era schema, runs the real sweep in apply mode
against an isolated temporary farm, and proves:

- ONINIT, compile, inputs, and fixed-risk setfile defects create no successor;
- NO_HISTORY, worker-crash, launch-fault, and bare-INCOMPLETE rows still create
  successors;
- all source verdicts remain `INFRA_FAIL`;
- the regular sweep report and daily triage artifact contain the same four
  deterministic rows; and
- the attempt cap remains 12.

## Production-state observation

A targeted production dry-run was attempted without `--apply`. The sweep's
existing safety guard returned immediately because
`D:/QM/strategy_farm/state/FACTORY_OFF.flag` is set. The flag was not changed or
bypassed. Consequently no queue row, verdict, sweep report, or factory process
was changed.

The adjacent daily JSON is a clearly marked, read-only SQLite preview of the 11
current-day deterministic rows among the five EAs named in the task. It is not
an eligibility verdict because the guarded sweep did not run its full
pending/active, terminal-disposition, deeper-stage, review-entry, and registry
filters. The next ordinary scheduled sweep with Factory ON will atomically
replace it with the authoritative filtered triage list.
