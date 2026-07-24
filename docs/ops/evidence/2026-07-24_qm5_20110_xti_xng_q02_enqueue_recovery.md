# QM5_20110 XTI/XNG Friday Relative-Value Q02 Enqueue Recovery

Date: 2026-07-24  
Branch: `agents/board-advisor`

## Outcome

Recovered the already-built, diversity-first `QM5_20110_xti-xng-fri-rv`
logical basket from a false build block and enqueued exactly one paced Q02
work item. The EA is a low-frequency, jointly sized long-XTI/short-XNG Friday
package sourced from the peer-reviewed Meek and Hoelscher (2023) petroleum
weekday paper.

The earlier build task was blocked only because the paced fleet had reached
seven active factory testers before smoke/enqueue. Its source, binary, SPEC,
logical setfile, basket manifest, EA registry, and two magic rows were already
present. Rebuilding a different card would have duplicated completed build
work while leaving the higher-diversity basket outside the funnel.

## Collision and CPU guards

Canonical farm DB:
`D:/QM/strategy_farm/state/farm_state.sqlite`.

- Build task: `d057ac14-8af6-494f-b2bb-5cc190c763ce`.
- The atomic claim required the task to be `blocked`, zero competing
  pending/active build tasks for `QM5_20110`, and zero pending/active work
  items for the EA.
- Claim owner: `codex:agents/board-advisor`.
- Claim event: `q02_enqueue_recovery_claimed` at
  `2026-07-24T21:40:57Z`.
- The pre-claim path-anchored MT5 scan saw one factory tester, below the
  seven-terminal ceiling.
- The post-enqueue scan at `2026-07-24T21:42:00Z` saw zero factory testers
  and only the separate `T_Live` process.

No terminal was started, stopped, or otherwise mutated.

## Artifact validation and refresh

- Card: G0 `APPROVED`, R1-R4 `PASS`, expected 48 paired packages/year.
- Registry: EA ID `20110`, magic slots `201100000` (`XTIUSD.DWX`) and
  `201100001` (`XNGUSD.DWX`) are active and present in the generated resolver.
- `validate_spec_doc.py`: `PASS`.
- `validate_symbol_scope.py`: `BASKET_OK`, zero violations.
- `build_check.ps1`: `PASS`, zero failures and zero warnings.
- Strict compile: `PASS`, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260724_213938/QM5_20110_xti-xng-fri-rv.compile.log`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260724_213938.json`.

The validation compile refreshed the committed EX5 against the current
framework includes and refreshed the canonical setfile build-hash receipt.

| Artifact | SHA256 |
|---|---|
| MQ5 | `BBD3988EE828D10C8C10F11992DBC732F7A5F571C781D9E39645EF47C81B4F11` |
| Refreshed EX5 | `5CE77918A8AEE5A18952A49D6D24629B5252F176310E9911EEEC7990FD5E9E68` |
| Logical Q02 setfile | `FED0239E3CB74738FAB534A8095B5624F61A7A9A59B5D25C3AF68FA2AFC3FFC4` |

Backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete package.

## Farm transition

The truthful recovery result is recorded in
`docs/ops/evidence/2026-07-24_qm5_20110_q02_enqueue_build_result.json` with
`smoke_result=deferred_p2_smoke`. `farmctl record-build` then:

1. moved the claimed build task from `active` to `done`;
2. validated the SPEC and non-stub entry implementation;
3. selected the basket manifest instead of standalone leg setfiles; and
4. inserted one priority-track Q02 work item.

Q02 work item:

- ID: `88ce3d68-f207-4c9c-97d4-860bec13505f`
- Status at handoff: `pending`
- Logical symbol: `QM5_20110_XTI_XNG_FRI_RV_D1`
- Host: `XTIUSD.DWX`, D1
- Basket: `XTIUSD.DWX` + `XNGUSD.DWX`
- Window: `2018.01.02` through `2024.12.31`
- Tester: USD 100,000
- `priority_track=true`

The stale task-level `fail_code=smoke_failed` was cleared and preserved as
`recovered_from_fail_code=smoke_failed`. No duplicate Q02 row and no
standalone XTI/XNG row was created.

## Safety boundary

No manual backtest, live setfile, AutoTrading action, `T_Live` mutation,
deploy/T_Live manifest change, portfolio admission, portfolio-gate change,
or correlation waiver occurred. The paced worker queue owns Q02 execution.
