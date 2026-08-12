# QM5_12580 FX Q08 Multisymbol Runtime Repair — 2026-07-25

## Decision

The approved 66-pair FX cointegration frontier is exhausted. The repository
reconciliation in
`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`
shows that every strict survivor is already carded, built, and has terminal Q02
evidence. In particular, QM5_12532 and QM5_12533 are no longer blocked at Q02;
they reached Q05 FAIL and Q04 FAIL respectively. Creating another card from
that scan would duplicate an existing build or admit a below-screen relation.

The OWNER-authorized fallback was therefore used to advance
`QM5_12580_fx-usd-exhaustion-reversal`. It is an existing structural D1
shared-signal basket over seven USD majors. Its AUDUSD carrier has Q04
PASS_LOWFREQ and Q05-Q07 PASS evidence, while Q08 remained infrastructure
invalid. The canonical Q08 baseline itself passed with 75 trades and profit
factor 1.43.

## Root Cause

The 2026-07-19 setfile repair worked: Q08.5 recognized all eight perturbable
strategy inputs. The subsequent aggregate still became INVALID because its
generated nominal run and perturbations did not publish bound summaries.

The EA's `basket_manifest.json` intentionally uses the legacy `symbols` schema:
each physical-symbol instance trades only its host but reads the same seven
symbols to calculate the USD-basket signal. Q08.5 recognized only logical
basket manifests with `logical_symbol` / `basket_symbols`, so it classified
this workload as single-symbol and assigned a 900-second child timeout.

Retained T2 evidence shows the identical canonical full-history baseline needed
about 17 minutes. The 15-minute neighborhood cap therefore expired before
completion, while retries launched behind the still-running tester. The
resulting `perturbations.json` recorded missing summaries/timeouts rather than
an economic neighborhood result.

## Repair

Commit `f39b860ed50556d9e1d9b5b2ddd368754fc33e23`:

- Q08.5 now recognizes both canonical `basket_symbols` and legacy `symbols`
  dependency manifests, but only when the tested carrier is a declared member.
- A shared-signal carrier remains a physical-symbol test (no logical-symbol
  routing or date-window change), while its child timeout receives the existing
  3600-second multisymbol floor.
- Farm promotions now preserve legacy multisymbol dependency metadata:
  manifest path, seven symbols, carrier, and D1 timeframe.
- Both automatic and explicit Q08 promotion paths now apply the bounded Q08
  timeout calculator. For this five-child neighborhood workload, the outer
  timeout rises from the inherited 120 minutes to 418 minutes.
- Focused regression tests lock the real QM5_12580 fixed-risk setfile,
  seven-symbol dependency universe, physical AUDUSD carrier semantics, child
  timeout, promotion payload, and outer timeout.

No EA source, strategy rule, parameter value, risk amount, or setfile changed.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q`:
  PASS, 20 tests and 4 subtests.
- `python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q`:
  PASS, 67 tests.
- `python -m pytest framework/scripts/tests/test_qm5_12580_q08_readiness.py tools/strategy_farm/tests/test_qm5_12580_q08_runtime.py -q`:
  PASS, 2 tests.
- `python -m py_compile framework/scripts/q08_5_neighborhood_runner.py tools/strategy_farm/farmctl.py`:
  PASS.

No backtest was launched as part of verification.

## Guarded Queue Action

Coordination claim:
`59ce76f9-7b27-4e9b-815f-773feb6b8dbb`.

Database backups:

- before claim:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12580_q08_runtime_repair_20260725T051640Z.sqlite`;
- before requeue:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12580_q08_requeue_20260725T051958Z.sqlite`.

Command:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12580 --phase Q08
```

The idempotent cascade reopened one existing row and created none:

- work item: `92e319b4-b40d-4db1-961c-e212c3f93d67`;
- symbol/timeframe: `AUDUSD.DWX` / D1;
- state: `pending`, unclaimed, verdict cleared;
- parent: Q07 PASS work item
  `6d6501bb-af6c-490e-89f6-2c1dedce45dc`;
- dependency count: 7;
- timeout: 418 minutes;
- prior work-item evidence archived recoverably at
  `D:/QM/reports/work_items/92e319b4-b40d-4db1-961c-e212c3f93d67.requeued_20260725T0519590000`.

At the queue boundary, `farmctl mt5-slots` reported zero running factory MT5
terminals and no orphaned factory processes. `FACTORY_OFF.flag` was present.
Only the separately scoped T_Live terminal was observed; it was not touched.
The database retained eight stale active rows from the prior factory session,
but no corresponding factory terminal or metatester process existed. No pump,
dispatch tick, tester, or phase runner was started.

## Safety

The change is backtest infrastructure only. It did not touch T_Live,
AutoTrading, live/deploy manifests, portfolio admission, portfolio KPI,
portfolio gate code/data, or Q08 contribution artifacts. The pending Q08 row
is a queue handoff, not a Q08 verdict or certification claim.
