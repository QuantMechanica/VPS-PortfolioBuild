# FTMO M1 bootstrap — router recheck and dependency hold

Date: 2026-08-09 (Europe/Berlin)  
Router task: `1b00f708-37d1-4a9d-b344-a051cde8c809`  
Evidence class: operations only; no Q-pipeline, economic, or deployment verdict

## Outcome

`REVIEW_BLOCKED_POST_MIGRATION_DXZ_EXTRACTION`.

The FTMO side remains complete and hash-bound. The two required FTMO projections
each contain 100,000 M1 rows:

| Lane / symbol | Coverage | Projection SHA-256 |
|---|---|---|
| `FTMO_STREAM1` / `XAUUSD` | 2026-04-28T07:55Z to 2026-08-07T23:49Z; 101.6625 days | `257549cd0116c373eabe0e12ab0ab8971d042a19c6a3f8d2dcfdc1a80aa73066` |
| `FTMO_STREAM2` / `GER40.cash` | 2026-04-24T18:38Z to 2026-08-07T22:49Z; 105.174306 days | `d1b9a4af51fb9937253f1d05e77956217819e6d2cc70a871838657838a1a94cf` |

The STREAM2 receipt is `PASS`, its history handoff is `READY`, and it binds
observations for both lanes. Both receipts record
`autotrading_touched=false`, `challenge_terminal_signaled=false`, and
`t_live_signaled=false`.

The required DXZ projections are still absent:

- `D:/QM/reports/ftmo_spread_calibration/XAUUSD_DWX_M1.jsonl`
- `D:/QM/reports/ftmo_spread_calibration/GDAXI_DWX_M1.jsonl`

The latest sanctioned DXZ attempt is
`D:/QM/reports/ftmo_spread_calibration/bootstrap_runs/DXZ_FACTORY_20260808T232900Z_da004178`.
Its compile log records 0 errors and 0 warnings. The bound T2 MQL5 log records
`copied=100000`, first bar `2025-09-16T18:30:00Z`, followed by
`QM_M1_HARVEST_NO_BARS_IN_WINDOW ... kept=0` for the required 2026 window.
Repeating the same pre-migration terminal launch cannot produce admissible
evidence, so this cycle did not launch another terminal.

## Dependency check

The physical Custom-history isolation migration has not executed:

- `T2` through `T10` `Bases/Custom` paths remain junctions to
  `D:/QM/mt5/T1/Bases/Custom`.
- No Custom-history migration artifact directory or activation/ramp state was
  present under `D:/QM/strategy_farm`.
- Governed factory terminals were active on T3 and T5 during this check, so the
  OWNER-quiesced migration precondition was not met. No active test was
  interrupted.

The current Sunday runbook is explicitly an execution checklist requiring an
OWNER-signed window before the first topology mutation. This task cannot
authorize that separate migration or substitute a pre-migration retry.

## Calibration execution

The reviewed calibration command was executed against the reviewed spec:

```text
python tools/strategy_farm/portfolio/ftmo_spread_calibration.py --spec docs/ops/evidence/2026-08-02_ftmo_spread_calibration_spec.json --output D:/QM/reports/ftmo_spread_calibration/ftmo_spread_calibration_2026-08-09_router_recheck.json
```

It correctly returned `REFUSED` because
`XAUUSD_DWX_M1.jsonl` is absent. The refusal artifact SHA-256 is
`67b6652545f21ada142973c89a97455ed48055f0dd54fde7b1a240382370f588`.
No session-bucket quantile or spread delta was inferred.

The original book-plus-majors coverage acceptance is also not fully
established: the two calibration symbols above have admissible FTMO coverage,
while major-FX coverage remains unproven by the current two-symbol harvest.

## Focused verification

```text
python -m py_compile tools/strategy_farm/ftmo_m1_bootstrap.py tools/strategy_farm/portfolio/ftmo_spread_calibration.py
python -m pytest -q tools/strategy_farm/tests/test_ftmo_m1_bootstrap.py tools/strategy_farm/tests/test_ftmo_lane_runner.py tools/strategy_farm/tests/test_ftmo_spread_calibration.py
.....................................                                    [100%]
37 passed in 1.53s
```

No FTMO research-lane process was running at exit. The Program Files challenge
terminal and T_Live were observed only; neither was signalled or written by
this cycle. AutoTrading was not changed.

## Required continuation

After the separately authorized Custom-history isolation migration is complete,
produce the two DXZ M1 projections through an admissible tester-context or
primed-series route, verify that the `.DWX` spread field is nonzero and genuine,
and rerun the reviewed calibration. Until then the session-bucket quantile
table and the task's full acceptance remain blocked, not failed.
