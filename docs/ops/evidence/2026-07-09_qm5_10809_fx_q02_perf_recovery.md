# QM5_10809 FX Q02 performance recovery

Date: 2026-07-09
Operator: Codex paced fleet (`agents/board-advisor`)
Status: repaired, registry/build clean, one priority Q02 item pending

## Selection

The diverse approved-card backlog was checked before taking recovery work:

- `QM5_1457_as-predict-bonds` remains blocked because its Treasury yield,
  IEF, BIL and DBC inputs have no approved DWX feed.
- `QM5_1459_as-lumber-gold` remains blocked because lumber and IEF have no
  approved DWX feed.
- `QM5_13031_wayward-bbrsi-stopmr` is buildable but adds another XAU/NDX
  sleeve, the already-concentrated survivor class.

`QM5_10809_tv-dual-st-adx` was therefore selected under mission priority 2.
It is an approved H1/H4 structural trend EA with FX registrations, no Q02 PASS,
no later gate work, and no active farm or agent-task claim at selection time.

The completed EURUSD infrastructure row
`af231a1e-7429-45dd-99ae-4c19b59c8553` was atomically claimed as
`codex:agents/board-advisor`. The pre-claim DB backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10809_perf_repair_claim_20260709_203426Z.sqlite`

## Diagnosis

Prior Q02 evidence:

`D:\QM\reports\work_items\af231a1e-7429-45dd-99ae-4c19b59c8553\QM5_10809\20260625_110959\summary.json`

The real-MT5 verdict was
`REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`. `OnInit` did not fail. The
tester log shows the EA making progress and trading, but the implementation
rebuilt the fast and slow 80-bar SuperTrend paths in both management and exit
hooks on every tick. While the market was closed it also retried the same
trailing-stop modification repeatedly within the same bar, producing a log
bomb and preventing the report from completing inside the worker ceiling.

## Repair

In `QM5_10809_tv-dual-st-adx.mq5`:

- the bespoke fast/slow SuperTrend and ADX state is reconstructed once from
  closed bars when the framework admits a new bar;
- entry, management and exit share that immutable per-bar cache;
- a trailing-stop update is attempted at most once per cache generation, so a
  market-closed rejection cannot become a per-tick retry loop;
- management and exits now run before the news entry gate, matching the
  current framework ordering; and
- `QM_EntryRequest` is zero-initialized before use.

No strategy parameters, signal formula, registered symbols, risk sizing or
card-authorized entry/exit rules were changed.

Repository artifact commits created by the deterministic farm dirty-worktree
guard:

- `7ca4809ee4cf1ef039944bbc2fa4a29c271276d2` — repaired source and compiled EA
- `fc09de2acc877109680d0794fa0c852e5ee7b767` — final strict-compile binary and
  refreshed setfile build hashes

## Validation

- Strategy spec validation: PASS (`1 PASS, 0 FAIL`).
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260709_203812\QM5_10809_tv-dual-st-adx.compile.log`
- Compile summary: `D:\QM\reports\compile\20260709_203812\summary.csv`
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260709_203812.json`
- Final EX5 SHA256:
  `D37FE76803368B672D1AD9D3C5241A8C083FB39E91B14AC205580286053A46D8`
- EURUSD H4 setfile environment/risk contract: `backtest`, `FIXED`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Setfile build hash:
  `9c93ca217783cdbd137a14e1e3ddf616571d312a5ee08bbf88f35abacfbe6812`.

No manual MT5 backtest was launched. No T_Live path, process, manifest or
AutoTrading setting was touched.

## Q02 enqueue

Exactly one priority work item was inserted for the repaired path; no dispatch
command was run:

| Field | Value |
|---|---|
| Work item | `21ba3a0f-fa45-4525-b61e-f1b4345cface` |
| Phase | `Q02` |
| Symbol / timeframe | `EURUSD.DWX` / `H4` |
| Initial status | `pending` |
| Setfile | `framework/EAs/QM5_10809_tv-dual-st-adx/sets/QM5_10809_tv-dual-st-adx_EURUSD.DWX_H4_backtest.set` |
| Window | `2018.07.02` through `2024.12.31` |
| Frequency floor | 35 trades across the seven-year window |
| Parent | `qm5-10809-eurusd-h4-perf-repair-q02-20260709_204112Z-21ba3a0f` |

Pre-enqueue DB backup:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10809_eurusd_h4_q02_requeue_20260709_204112Z.sqlite`

The next evidence must come from the paced terminal fleet. Until that row
finishes, this is an infrastructure-repair/build PASS, not a Q02 strategy PASS.
