# QM5_1013 EURGBP Metatester-Wait Repair and Q02 Requeue — 2026-08-07

Scope: branch `agents/board-advisor`; no `T_Live`, AutoTrading, portfolio-gate, or
deploy-manifest changes.

## Selection

The strict build preflight found no unclaimed, reputable-source, low-frequency
forex/crypto/rates/pairs card that already had the required EA and magic registry rows.
This unit therefore took priority 2 and repaired the distinct FX-cross target
`QM5_1013_lien-20day-breakout` / `EURGBP.DWX` / `D1`.

The strategy is structural and low-frequency: a closed-bar 20-day breakout,
two-day failed pullback, and three-day re-break state machine. Its source is Kathy Lien,
*Day Trading and Swing Trading the Currency Market*, and the card estimates 3–8 trades
per year per symbol. The Q02 setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.

Farm coordination claim:

- Agent task: `aecba499-9b51-4f50-9dea-d27f7c0f09f0`
- Claim key: `QM5_1013|EURGBP.DWX|Q02|run_smoke_metatester_wait`
- Claimed state/owner: `IN_PROGRESS` / `codex:agents/board-advisor`
- Closed state: `PASSED` after the guarded Q02 handoff

## Diagnosis

Preserved source work item `9aac08c0-bc47-4349-a25b-0d801b9fe446` ended
`failed / INFRA_FAIL` with
`cold_cache_retries_exhausted:BARS_ZERO`. Its three reports were incomplete MT5 shell
reports: empty expert and symbol, `M0 (1970...)`, and zero bars. The summary explicitly
recorded `oninit_failure_detected=false`.

This was not an EA, binary, setfile, date-window, or symbol-history defect:

- MQ5 SHA-256: `66d73950ada79c3f843c1cd5da494bb667d49876c88cd941b586d38002ac53e2`
- EX5 SHA-256: `9a90b09d87fc3797cb6e69a923037f11f265767137cbf01579f2c1b12ca25755`
- EURGBP setfile SHA-256: `e80f74477d70fce524bfb9da465de2158e3e06e44dfa0846dd3b8bcc9ead44d2`
- Bound window/period: `2018.07.02`–`2022.12.31`, `D1`
- Recent independent Q02 runs proved `EURGBP.DWX` history was readable over the same
  window, including `QM5_11353` (H1 PASS) and `QM5_10297` (D1 PASS).

The work-item log isolated the runner fault. `terminal64.exe` exited while the same T4
root still had an active `metatester64.exe` writer. `run_smoke.ps1` treated the terminal
stub exit as test completion, published the incomplete shell, and began the next attempt
while the tester writer was still alive.

## Repair

`framework/scripts/run_smoke.ps1` now:

- keeps the run active after `terminal64.exe` exits while a metatester writer for that
  terminal root remains alive;
- allows a five-second metatester spawn grace before accepting a terminal-only exit;
- polls the exact terminal-root writer at a bounded five-second cadence to avoid a WMI
  polling storm across the paced fleet;
- preserves complete-report latching and log-bomb checks during that wait; and
- terminates a lingering terminal-root metatester only when the run reaches its bounded
  timeout, preventing contamination of the next retry.

`Test-RunSmokeWaitsForChildTerminal.ps1` now reproduces the terminal-stub-exits-first
sequence and fails unless the runner polls through metatester quiescence.

## Validation

- `Test-RunSmokeWaitsForChildTerminal.ps1`: PASS
- `Test-RunSmokeWaitForCompleteReport.ps1`: PASS
- `Test-TerminalSpawnWatchdog.ps1`: PASS
- `Test-RunSmokeRealTicksReportEvidence.ps1`: PASS
- `Test-RunSmokeOnInitTradeScope.ps1`: PASS
- `Test-RunSmokeNoHistoryScope.ps1`: PASS
- `validate_spec_doc.py framework/EAs/QM5_1013_lien-20day-breakout`: PASS
- `build_check.ps1 -EALabel QM5_1013_lien-20day-breakout -SkipCompile`: PASS,
  zero failures and zero warnings
- Build-check report: `D:\QM\reports\framework\21\build_check_20260807_141139.json`
- `git diff --check` on the repaired runner and regression test: PASS

Post-repair runner/test SHA-256 values:

- `run_smoke.ps1`: `6be5abfd12576f147a9bc98dd6523f604e92ae146e1a444673b58e200caecc2c`
- `Test-RunSmokeWaitsForChildTerminal.ps1`:
  `1b7dd2bcd13151e2aed2087d7d54fc3c7086e5f13943e09be4ed906a4bd23330`

## Append-Only Q02 Requeue

Consistent farm DB backup before the queue mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1013_eurgbp_q02_requeue_20260807T141100Z.sqlite`

`farmctl enqueue-backtest` preserved the terminal source row and inserted exactly one
authenticated replacement:

| Field | Value |
|---|---|
| New work item | `9901f718-8ad6-4994-a9bb-d87196742d8d` |
| Source work item | `9aac08c0-bc47-4349-a25b-0d801b9fe446` |
| EA / symbol / period | `QM5_1013` / `EURGBP.DWX` / `D1` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Artifact binding | exact MQ5, EX5, and setfile hashes listed above |
| Readback | `active`, claimed by paced worker `T6` at `2026-08-07T14:11:32+00:00` |

The pre-enqueue capacity sample found six governed T1–T10 terminal processes against the
seven-terminal ceiling. The raw count was eight only because the read-only inventory also
included the separate `T_Live` and FTMO GUI processes. The replacement was immediately
claimed by T6, bringing the paced fleet to its ceiling; no manual smoke/backtest was launched
and no further queue action was taken.
