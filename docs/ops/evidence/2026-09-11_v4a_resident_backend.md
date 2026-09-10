# V4a resident-session backend — T10 technical-impossibility proof

Date: 2026-09-11
Router task: `31b8255e-03f8-4242-b26d-c24d526f79e9`
Verdict: **REVIEW — TECHNICAL_IMPOSSIBILITY_CURRENT_MT5_COMMAND_SURFACE**

## Decision

No resident T10 backend or T10 parity run was implemented. This is an
engineering impossibility within the governed MT5 command surface presently
available to the factory, not a lack of authorization to build a component:
that surface has only process-start configuration, while the requested backend
needs a supported command to submit a *second* independently rendered tester
cell to an already-running terminal.

The only existing concrete backend remains
`GovernedDev2RestartBackend` (`tools/strategy_farm/warm_cell_runner.py:938`),
which records `terminal_restarts` for each cell. `ResidentSessionBackend`
(`:134`) is a Python Protocol used by unit tests, not a terminal command
surface. There is no safe implementation that can turn the Protocol into an
MT5 IPC endpoint without inventing an undocumented control channel.

## Reproducible evidence

| Boundary | Evidence | Result |
|---|---|---|
| Official MT5 command surface | [MetaTrader 5 Platform Start](https://www.metatrader5.com/en/terminal/help/start_advanced/start) documents `/config` as a command-line startup configuration (lines 141–158) and the Tester fields as parameters of testing that starts automatically (lines 225–255). | No command is documented for submitting another tester job to a running terminal. |
| One portable instance | The same official page states that two platform copies cannot run from one directory (lines 99–104). | A second `/config` process is not a resident-cell command and cannot coexist safely in T10. |
| Existing cold path | `framework/scripts/run_smoke.ps1:1095` renders `ShutdownTerminal=1`; `:2239–2243` starts `terminal64.exe /portable /config:<ini>` for each cell. | The canonical tester operation is one process per rendered cell. |
| Evidence integrity | `run_smoke.ps1:90–91` rejects `-AllowRunningTerminal` with `-RequireFreshLoggerSample`; `:2973–2975` otherwise requires an idle terminal. | Using the flag to evade exclusivity would defeat the fresh-logger receipt contract. |
| Current runner | `warm_cell_runner.py:1702,1752,1857` states that it has an injected interface only and no MT5 launcher; `:1326` increments a restart count in the governed DEV2 adapter. | The repository agrees with the observed cold-path behavior. |

The official page documents the closest supported multipass facility:
`Optimization` and `UseLocal`/`Port` under `[Tester]` (lines 235 and 248–252).
It is not a drop-in resident-cell adapter: the existing V4b assessment records
that an optimization pass does not emit the native report bytes, closed-trade
bytes, entry-day evidence, and logger sample required by the current cold
receipt contract. Substituting it would therefore violate exact-parity
acceptance rather than satisfy it.

## Closest safe alternative

Create a separately governed **MetaTester local-agent optimization lane**,
Default-OFF and outside T1–T10 production workers. It must first define a new
pass-level evidence contract, prove its exports against cold receipts on a
disposable canary, and receive OWNER approval before use. It may improve
throughput but must never be presented as V4a resident-session parity until it
can authenticate all required receipt fields. No terminal process, T10 reload,
worker, queue row, state database, policy, T_Live setting, or AutoTrading
setting was changed by this proof.

## Required runbook if a supported API later appears

1. Keep `QM_ENABLE_WARM_CELL_RUNNER` absent (Default-OFF) until a documented
   MT5 next-cell API is independently reviewed.
2. Bind the API version, terminal binary SHA-256, 20 immutable cold references,
   custom-history re-audit per program, CPU/RAM/commit-headroom guards, and
   process ownership under the T10 worker job object.
3. After orchestrator-led, idle-only T10 reload, run all 20 cells; stop on the
   first identity, report-field, canonical-trade-byte, logger, or native-report
   delta. Fall back to the unmodified cold path for that cell.
4. Publish a timing CSV and exact comparison table; only an OWNER activation
   seal can allow T10 -> T5 -> fleet staging. Rollback is flag removal plus the
   orchestrator's staggered idle-worker reload.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_warm_cell_runner.py \
  tools/strategy_farm/tests/test_warm_cell_phase3.py -q
```

This proof is not pipeline evidence and authorizes neither a terminal start nor
any production activation.
