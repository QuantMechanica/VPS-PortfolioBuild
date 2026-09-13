# FX cointegration QM5_12712 Q08 hold release

Recorded: 2026-09-13T04:09:14Z (06:09 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `e608cbaea5136f9467099ed609357153a853523a`

## Outcome

The frozen 66-pair discovery has no unbuilt approved relationship. Its two
published strict survivors are already beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, Q04 FAIL.

The runtime approved-card reservoir contained 41 filenames matching
`cointegr|coint`; every allocated identity had a matching EA directory. No
card, identity, magic row, EA, basket manifest, compile row, or Q02 row was
duplicated.

The selected existing-forex continuation is the low-frequency EURGBP/EURAUD
D1 basket `QM5_12712`. Its authenticated chain has Q02-Q07 PASS and
current-contract Q09 PASS. The required Q08 regeneration already exists once
as work item `b68d05cd-e52c-43a5-96aa-5e0306efa60f`.

A fresh reconciliation found that this row was still parked by the
`OWNER_D5_BASKET_LEASE_HOLD` created on 2026-08-18. The current OWNER mission
explicitly asks to advance an existing forex card when no unbuilt scan pair
exists. The governed release therefore removed exactly that one hold without
changing the work-item row:

| Field | Value |
| --- | --- |
| Work item | `b68d05cd-e52c-43a5-96aa-5e0306efa60f` |
| Phase | Q08 |
| Hold active before / after | `1` / `0` |
| Released at | `2026-09-13T04:09:14+00:00` |
| Transition ledger sequence | `3278` |
| Work-item status after | pending, unclaimed, attempt 0, verdict null |

The release is append-only and used the exact compare-and-swap command. Its
pre-mutation backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_hold_release_20260913T040914Z_4494c19a.sqlite`
with SHA-256
`f0c4e4dea00c1c55fff94306593d43e66200b7b4cbc5a31df4927a50ebaed286`.

## Governed backup repair

The first release attempt refused before mutation because the 1.18 GiB online
SQLite backup exceeded the controller's hard-coded 60-second timeout. The
controller now accepts `QM_TOOL_BACKUP_TIMEOUT_SECONDS`, retains 60 seconds as
the default, rejects non-finite/non-positive values, and caps an override at
300 seconds. With a bounded 180-second override, the same governed release
completed in under one minute. No direct SQLite write or lock bypass was used.

Targeted validation:

```text
python -m pytest tools/strategy_farm/tests/test_farmctl_requal8_tools.py -q
16 passed
```

## PACER guard and package bindings

No `.mq5` source was generated or edited and no compile command was enqueued,
so the mandatory post-write/pre-compile audit boundary was not entered. The
existing source was nevertheless checked read-only and returned exit 0,
`ok=true`, and zero `EA_FRAMEWORK_INPUT_PINNED` findings.

The logical backtest set remains fixed-risk: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `afdfd1a80dbfcd2c398ddc92dffe2181e5727f3837c37df2a772f25b68e171d1` |
| EX5 | `0003ed98f590e95a28a08e7d8198639b48213e882e8c5d2428cad4422355c982` |
| basket manifest | `a15214089f0efd8564a1ee6f2d6bb09164cde12d742ad8627fa1f7870d6e773a` |
| logical backtest set | `105a23da1d33d559cff4ff19a5e8c5c51e8a72eb6cec5b7f6a92ecedaea6208c` |

## Paced dispatch boundary

Five fresh two-second whole-host samples after the release were `91.510738%`,
`83.326831%`, `80.622158%`, `88.627087%`, and `96.841550%`. Average CPU was
`88.185673%` and maximum CPU was `96.841550%`, below the binding 97% ceiling.

The resident worker did not claim the row during observation. Seven work items
were active, 5,147 were pending, and free physical RAM was 30.21 GiB of
63.12 GiB. The row declares five FX history symbols and is the
`multi_leg_fx_basket` class: its 32 GiB reservation plus the 14 GiB
post-reservation floor requires 46 GiB free. No manual dispatch, tester launch,
terminal reservation, or terminal control bypassed that admission gate. The
released row remains eligible for the resident paced worker when resources
recover.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact changed.
- No strategy card, EA source/binary, setfile, basket manifest, registry,
  magic row, work-item status/payload/verdict, or queue identity changed.
- Unrelated shared-worktree changes were preserved and excluded.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12712_q08_hold_release_20260913T040914Z_board_advisor.json`.
