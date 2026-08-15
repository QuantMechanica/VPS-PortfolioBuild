# QM5_12430 FX Q02 stale compiled-resolver recovery

Date: 2026-08-15

Branch: `agents/board-advisor`

EA: `QM5_12430_ea31337-stoch`

Disposition: `REBUILT_AND_ENQUEUED`

## Outcome

The unchanged approved Stochastic-reversal MQ5 was force-recompiled against
the current synchronized V5 include tree. The rebuilt binary passed strict
compilation and the focused build gates, and exactly one authenticated,
append-only EURUSD.DWX H1 Q02 successor was enqueued. No signal, exit, sizing,
symbol, timeframe, or execution parameter was changed.

- Farm coordination task: `01b28885-8606-4169-89ee-1e24aa5b2e16`, assigned
  to `codex:agents/board-advisor` after an atomic collision recheck.
- Preserved predecessor: `11b235c4-65ca-489b-ae7d-e2c3826f2fb8`.
- New pending work item: `ce01d890-2c39-4756-803e-0e4939a7b099`.
- Host: `EURUSD.DWX`, H1, `2022.07.01` through `2022.12.31`.
- Risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Selection and source quality

The live router had no eligible unclaimed diverse approved build in its build
backlog. `QM5_12430` had no open work item, no prior agent task, and no Q03 or
later result when claimed. Its retained Q02 rows were infrastructure-only
failures rather than economic verdicts.

The approved card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_12430_ea31337-stoch.md`.
It records `g0_status: APPROVED`, R2-R4 PASS, 60 expected trades/year/symbol,
and an exact public source pointer to EA31337's
`Strategy-Stochastic/Stg_Stochastic.mqh`. The implementation is a closed-bar,
one-position oscillator-reversal rule with fixed SL/TP/time exits and no ML,
grid, martingale, or adaptive PnL sizing. Its EURUSD, GBPUSD, and USDJPY hosts
add FX diversity to the index/metal/energy-heavy survivor cohort.

Pre-claim online database snapshot:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12430_q02_stale_resolver_claim_20260815T175700Z.sqlite`

The completed snapshot is 386,187,264 bytes, opens with schema version 1 and
32 tables, and contains zero pre-existing `QM5_12430` agent tasks.

## Bound failure and diagnosis

The retained EURUSD predecessor is terminal `done / INFRA_FAIL`, with reason
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. Its canonical summary is:

`D:\QM\reports\work_items\11b235c4-65ca-489b-ae7d-e2c3826f2fb8\QM5_12430\20260811_152341\summary.json`

Summary SHA-256:
`c7de58b4ea0965762b8a704e4627a8c6b3343ed54abf9d3e32f83a8c99c819f4`.

The failed execution identity was stable:

- old EX5 SHA-256:
  `0f264ecd5431f523ae189ddb8696ceaa15b63f7115bab531d2a7fa0717165538`;
- MQ5 SHA-256:
  `d019f5f9c2af15847d7592b078c2ddef5964030406c6469c4cbd14502fe85d5b`;
- old EURUSD H1 setfile SHA-256:
  `a0fbe7415ef0c32bb9dd5b4a4b406ebec3b202aed437360d0b563d6d30f9b8fc`.

The report authenticated `EURUSD.DWX / H1`, 100% real ticks, the correct EA ID
and slot 0, then returned zero bars because `OnInit` failed. The structured
logger never initialized. In the V5 initialization order, fixed-risk and
portfolio inputs are validated and `QM_MagicChecked` runs before
`QM_LoggerInit`; the preset has valid `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The canonical registry contains all four active tuples, including
`12430 / slot 0 / EURUSD.DWX / 124300000`. The canonical resolver regeneration
kept 15,966 rows, dropped zero, and produced registry SHA-256
`FB104114D16D98A546F973B4ADB79944117D9B5E8BB565895414AFA226430AD2`.
The failed binary's initialization behavior was therefore inconsistent with
the valid canonical mapping. As with the companion EA built by the same pump
commit, the narrow infrastructure diagnosis is a stale compiled include or
resolver binding. No strategy mechanic was relaxed to force a pass.

## Repair and verification

`compile_one.ps1 -Strict` force-deleted the old binary, synchronized current
framework includes into the build terminal trees, and rebuilt the unchanged
source.

- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260815_181449\QM5_12430_ea31337-stoch.compile.log`.
- Compile-log SHA-256:
  `145f7b4e495f758491ae4d6fa61b97c1cee89c94e0b75330f8a2ad72b9938227`.
- Compile summary:
  `D:\QM\reports\compile\20260815_181449\summary.csv`.
- Compile-summary SHA-256:
  `df10fb7696d8fe941b566efc6191ef1150b83e279e9e94356a6ec21d8810d961`.
- Rebuilt EX5 SHA-256:
  `c95a74aefef7e3f632cc40797842a1bc886d79cc3ebecde6480cb478c4fd6560`.
- Rebuilt EX5 size: 373,524 bytes.
- SPEC validation: PASS.
- Build guardrails: PASS, zero findings across the MQ5 and eight presets.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero leaks.
- EA-scoped strict build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260815_181608.json`.
- Build-check SHA-256:
  `4364467bb097d781de0319a79503377a2a11af2ef56d4593ff08b9121863a0fe`.

The build checker changed only the `build_hash` comments in the eight existing
H1/M15 presets. Every preset retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.
The queued EURUSD H1 preset SHA-256 is
`372253c89c2a2a26835a58032ac59d6f1bc004ddedaab24b4ad0854b1b6e6a0a`.

## Append-only Q02 handoff

`farmctl enqueue-backtest` authenticated the retained predecessor and current
artifacts, preserved the historical row, and created exactly one successor:

- work item: `ce01d890-2c39-4756-803e-0e4939a7b099`;
- initial state: `pending`, unclaimed, attempt 0, no verdict;
- `append_only_rerun_of_work_item`:
  `11b235c4-65ca-489b-ae7d-e2c3826f2fb8`;
- `repaired_infra_rerun=true` and `historical_work_item_preserved=true`;
- expected MQ5 SHA-256:
  `d019f5f9c2af15847d7592b078c2ddef5964030406c6469c4cbd14502fe85d5b`;
- expected EX5 SHA-256:
  `c95a74aefef7e3f632cc40797842a1bc886d79cc3ebecde6480cb478c4fd6560`;
- expected setfile SHA-256:
  `372253c89c2a2a26835a58032ac59d6f1bc004ddedaab24b4ad0854b1b6e6a0a`.

Immediately before handoff, two factory work items were active against the
seven-job ceiling. Five host CPU samples averaged 48.1%, 7,899 MB physical
memory was free, and the factory flag was absent. The successor was enqueued
only; no pump, dispatch tick, smoke test, terminal, or backtest was started by
this recovery.

## Safety boundary

No `T_Live` file, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, or portfolio KPI artifact was changed. This is an infrastructure repair
and Q02 queue handoff, not a Q02 result or live-use authorization.
