# QM5_11900 governed compile/Q02 continuation — CPU-ceiling stop

Date: 2026-08-25

Branch: `agents/board-advisor`

EA: `QM5_11900_kobasfx-4ema-macd-sentiment-h1`

Farm task: `46e34047-c661-462c-96d5-b4f9d76914db`

Outcome: **NO MUTATION — GOVERNED COMPILE AND USDCHF Q02 CANARY REMAIN
DEFERRED AT THE 97% WHOLE-HOST CPU CEILING**

## Selection and collision preflight

The live farm backlog was audited before any write. The nominal pending build
rows did not contain a genuinely unbuilt, collision-free, registry-ready
forex, crypto, rates, energy-beyond-XNG, or market-neutral-pairs card:

- the recent diverse candidates already had an MQ5/EX5 and pipeline evidence;
- the reserved-only candidates remained blocked by deterministic card or
  registry preconditions;
- current router build rows assigned to other agents were not claimed.

The existing priority-100 `q02_infra_repair` task for QM5_11900 therefore
remained the highest valid mission unit. It is assigned uniquely to
`codex:agents/board-advisor`, has an approved ten-symbol H1 FX repair, and has
no open `pending` or `active` work item for this EA.

The reviewed repair commit `59149dfad4ce230a9528ae91f7475530b0b0e966`
is an ancestor of the current branch HEAD. The EA directory, the exact scoped
compile authority, its tests, and the 2026-08-24 handoff evidence had no local
worktree changes at preflight.

## Binding CPU-ceiling evidence

At `2026-08-25T20:34:47Z`, `farmctl mt5-slots` reported six running factory
terminals (`T2`, `T3`, `T4`, `T6`, `T7`, and `T9`), with no duplicate terminal
workers and no orphaned terminal processes.

Five consecutive `Processor(_Total)\\% Processor Time` samples were:

```text
100.0000
98.2988
98.3404
92.1393
100.0000
```

The average was `97.7557%` and the peak was `100.0000%`. This exceeds the
mission's governed 97% ceiling and triggers the explicit stop condition.

## Actions intentionally not taken

No farm or router database row was inserted, updated, claimed, or enqueued.
No `COMPILE_EA` work item, compile process, build-check, smoke test, Q02 canary,
dispatcher tick, terminal reservation, tester launch, or manual terminal action
was performed. No AutoTrading action, `T_Live` write, live/deploy-manifest
change, portfolio-gate change, or portfolio admission occurred.

## Safe continuation

After sustained whole-host CPU is below 97%, recheck that QM5_11900 still has no
open compile/Q02 successor, then use the already-reviewed source-repair authority:

```powershell
python tools/strategy_farm/farmctl.py enqueue-compile `
  QM5_11900_kobasfx-4ema-macd-sentiment-h1 `
  --source-repair-authority router_q02_infra_repair:46e34047-c661-462c-96d5-b4f9d76914db
```

Require `COMPILE_OK`, strict build-check PASS, zero compile errors/warnings, a
new EX5 hash, and final setfile build bindings. Then append exactly one USDCHF
Q02 canary from the immutable infrastructure-only row:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11900 --phase Q02 `
  --append-only-rerun-of fe21ca57-20eb-44af-90f1-d961618b2900 `
  --rerun-reason "stale pre-magic-allocation EX5 and slot-0 setfiles repaired" `
  --expected-current-ex5-sha256 <NEW_COMPILE_OK_EX5_SHA256>
```
