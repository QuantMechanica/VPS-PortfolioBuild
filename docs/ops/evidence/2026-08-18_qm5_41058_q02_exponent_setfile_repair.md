# QM5_41058 Q02 exponent-setfile repair

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Farm task: `9277b556-b81b-4e97-9105-3c4e84eeb551`

Outcome: `Q02 INFRA DEFECT REPAIRED; APPEND-ONLY RERUN PENDING`

## Selection and claim

No distinct approved diversity build remained safely claimable after the farm
and shared-worktree collision audit. `QM5_41058_xng-wflow-agree` was the best
unclaimed priority-2 recovery: a structural D1 natural-gas sleeve with one
terminal Q02 infrastructure failure, no economic verdict, no downstream phase,
no open work item, and no competing agent task. Its strict completed-week
close/open flow-agreement mechanic is distinct from the certified XNG
two-day cumulative-RSI pullback, although this repair makes no portfolio-
diversity or decorrelation claim.

The claim was inserted atomically only after confirming the exact source row
was terminal `done/INFRA_FAIL`. Pre-claim database backup:

- path: `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_41058_q02_exponent_claim_20260818T052711Z.sqlite`
- SHA-256: `3a30eeee7515c1522f4bab6567ed7bde60898d190c05a5eb364a09b8056f268d`

## Failure proof and root cause

Preserved source work item:
`fe2fc827-2d28-44f8-92de-8bea2681dc9c`.

Its bound MQ5, EX5, and setfile remained stable during the run. XNG history was
available and the logger reached `SYMBOL_GUARD_INIT`, `INIT`, and
`EXECUTION_CONTRACT`, excluding missing history, stale deployment, magic,
symbol, timeframe, news, and framework-execution-contract failures.

The decisive tester log is:
`D:/QM/reports/work_items/fe2fc827-2d28-44f8-92de-8bea2681dc9c/QM5_41058/20260818_050638/raw/run_01/20260818.log`.
Line 59 records:

```text
strategy_reconcile_tolerance=1.0e-1
```

Line 60 then records `OnInit reports incorrect input parameters`. The bound
setfile actually contained `strategy_reconcile_tolerance=1.0e-10`. MT5's
setfile parser truncates a multi-digit negative exponent, loading `0.1`
instead of the card-locked `0.0000000001`. `Strategy_NoTradeFilter` correctly
rejects that nine-orders-of-magnitude mismatch.

## Repair boundary

The setfile now serializes the same approved numeric value without exponent
notation:

```text
strategy_reconcile_tolerance=0.0000000001
```

The normal build validation path refreshed the setfile content hash header
from `fd0bac5af28a781d0800eb46ee8a44ad33066520dde9d1b4d7f8e9180d92740a`
to `c36714e60c8f3d1d46e4ef788e93e6c8c162f2ed8360735da7928dd79f64c709`.
The SPEC EA-ID label was brought into the mandatory Q01 validator form. No
strategy source, signal, threshold, risk, symbol, clock, lifecycle, registry,
magic, card, or framework file changed.

Current execution identities:

- MQ5 SHA-256: `e19bfaf552111c90c7db8b04f9b721dc786b55c1147c35e777002f608ccc768d`
- EX5 SHA-256: `0f7417ba89355ecba1374cfe9621aff5475a643e7e491bbcc141bf932ad73c40`
- repaired setfile SHA-256: `84357187e4fa9fccdc10970c8cf3f4f23d73808773f9ba54b03f5e87d6b02064`
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

The MQ5 and EX5 hashes are identical to the failed row. The new Q02 therefore
changes only the setfile serialization and is a causally narrow requalification.

## Verification

- `build_check.ps1 -EALabel QM5_41058_xng-wflow-agree -NormalizeExponentFloats`:
  PASS, strict compile 0 errors / 0 warnings, 0 build failures / 0 warnings.
  Report: `D:/QM/reports/framework/21/build_check_20260818_052753.json`.
- `framework/scripts/tests/test_setfile_float_serialization.ps1`: PASS,
  including the exact `1.0e-10 -> 0.0000000001` regression case.
- `validate_build_guardrails.py` on the MQ5: PASS, no findings.
- `validate_spec_doc.py` on the EA directory: PASS, 1/1.
- Active-input exponent scan on the repaired setfile: zero matches.
- Focused `git diff --check`: PASS (line-ending notice only).

## Append-only Q02 handoff

Governed `farmctl enqueue-backtest` preserved the failed source row and created
one exact Q02 rerun:

- new work item: `b4297ea5-fc48-4943-9c59-c972a86377c5`
- state at creation: `pending`
- source row: `fe2fc827-2d28-44f8-92de-8bea2681dc9c`, unchanged
- expected symbol/period: `XNGUSD.DWX` / `D1`
- expected MQ5/EX5/set hashes: exactly the identities above
- history window: `2018-07-02` through `2022-12-31`
- disposition: automatic pump/dispatcher owns the next claim

No manual backtest, smoke run, dispatcher tick, tester, terminal, or
AutoTrading action was started. The pending row consumes no backtest CPU and
remains subject to the farm's capacity gate. No `T_Live`, deploy or live
manifest, portfolio gate, portfolio admission, correlation waiver, stress
preset, optimization preset, or strategy mechanics were touched.
