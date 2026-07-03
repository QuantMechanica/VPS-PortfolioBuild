# QM5_12728 Card Localization and CPU Stop - 2026-07-03

Branch: `agents/board-advisor`

## Scope

Mission: grow the V5 portfolio book with market-neutral FX cointegration
baskets, preferring `QM5_12532` / `QM5_12533` Q02 unblocks if either strict
survivor was still blocked.

No `T_Live`, AutoTrading, portfolio gate, portfolio admission, portfolio KPI,
Q08 contribution, or deploy manifest files were touched.

## Decision

The controlling research source remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

It documents only two strict 66-pair FX cointegration survivors:

| Pair | EA | Current state checked |
|---|---|---|
| `AUDUSD~NZDUSD` | `QM5_12532` | Q02 `PASS`, Q04 `PASS`, latest Q05 strategy `FAIL` |
| `EURJPY~GBPJPY` | `QM5_12533` | Q02 `PASS`, later Q04 strategy `FAIL` |

`QM5_12978` GBPUSD/USDCAD, the current non-duplicate negative-hedge sleeve, has
also advanced beyond Q02: Q02 `PASS`, Q03 `PASS`, then Q04 strategy `FAIL`
with `F1:pf_net=1.136;F2:pf_net=0.848`.

No unbuilt approved strict-survivor pair remains, and the current factory has
five active work items. Per the CPU-ceiling constraint, no new backtest was
enqueued and no manual MT5 tester run was launched.

## Repo Work

`QM5_12728` NZDUSD/GBPJPY remains an existing forex basket fallback with Q02
`PASS` and a pending Q04 retry:

- EA: `framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration`
- Logical symbol: `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1`
- Pending Q04 work item: `6a1a390b-7380-407e-a75d-6c64cec9a63f`
- Current issue: worker-owned pending row still carries stale preflight metadata
  from the orchestration checkout (`ea_dir_missing`) while canonical artifacts
  exist under `C:/QM/repo`.

The EA folder was verified against the local strategy-card reference at
`framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/docs/strategy_card.md`.
That file already matches the tracked HEAD copy. The committed artifact update
is in `SPEC.md`: it now records the 2026-07-03 Q04 pending-row triage, the
factory CPU ceiling, and the worker claim-time stale-preflight cleanup behavior.

I also added a read-only queue-status field in
`framework/scripts/mt5_queue_status.py`: pending `work_items` now expose
`preflight_failure_reason` when the reason is present in `payload_json`. This
does not change queue ordering or mutate the farm DB; it makes stale
`ea_dir_missing` rows visible through the normal status command instead of
requiring ad hoc SQL during future forex-basket triage.

## Current Factory State

Read-only queue check from `D:/QM/strategy_farm/state/farm_state.sqlite` showed
five active worker-owned backtests:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| `T2` | `QM5_10919` | Q07 | `XTIUSD.DWX` |
| `T3` | `QM5_10926` | Q05 | `GDAXI.DWX` |
| `T5` | `QM5_10115` | Q05 | `XAUUSD.DWX` |
| `T1` | `QM5_12712` | Q06 | `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` |
| `T4` | `QM5_1061` | Q07 | `NDX.DWX` |

## Verification

```powershell
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12728_edgelab-nzdusd-gbpjpy-cointegration --verbose
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12728_edgelab-nzdusd-gbpjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q
python -m unittest framework.scripts.tests.test_mt5_queue_status
python framework/scripts/mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 12
```

Results:

- Symbol scope: `BASKET_OK`, 0 violations.
- Build check: `PASS`, 0 failures, 16 existing shared-framework advisory
  warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260703_110750.json`
- Refreshed backtest setfile build hash:
  `752a72292271c2f022a65571880143ace6528dac0026ca5480a438c7a596976f`
- Manifest tests: `9 passed`.
- Queue-status unit tests: `2 passed`.
- Live read-only queue snapshot: `schema=work_items`, `active=5`,
  `pending=6249`, and pending rows include `preflight_failure_reason`.
