# QM5_41095 WTI Weekly Excursion-Imbalance Source Build / CPU Stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41095_wti-wexcursion-imbalance-mom`

Outcome: `SOURCE BUILD COMMITTED; Q01 PENDING_GOVERNED_COMPILE; Q02 NOT_ENQUEUED_CPU_CEILING`

## New commodity sleeve

`QM5_41095` is a low-frequency, symmetric direct-WTI continuation candidate
on exact `XTIUSD.DWX` D1. At the first tradable bar of a normalized Monday-
anchored broker week, it aggregates the immediately completed three-to-five-
session weekly OHLC package. With `U=high-open` and `D=open-low`, it buys only
when `U > 2*D` and the final close is above the open, and sells only when
`D > 2*U` and the final close is below the open. Ratio equality, close/open
equality, disagreement, invalid data, late attachment, and retry states remain
flat. A survivor closes at the next weekly boundary.

This differs mechanically from the existing WTI body-share, two-week range-
migration, close-location, closing-channel breakout, and outside-settlement
families. It also uses a different carrier and logic from certified
`QM5_12567`, the long-only two-day XNG cumulative-RSI2 pullback. This is a
diversification hypothesis only; Q09 alone may establish realized portfolio
correlation.

## Durable artifacts

- source approval: commit `0f68d9807`;
- bounded source packet: commit `12e5ede4e`;
- deterministic EA-ID reservation: commit `07d849d91`;
- approved G0 card: commit `98f19dfad`;
- governed magic/resolver allocation: commit `d8e3ee963`;
- source-only implementation, reference suite, and one D1 backtest preset:
  commit `b74533ddb`.

The MQ5 SHA-256 bound at compile enqueue was
`04bfef934775a963c3ce3a9b45717b36a9f2352488086f8bbf90e51404f80305`.
The preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` stop, no target, and no
optimization surface.

## Source-level validation

The following target-only checks passed:

1. `python -m unittest framework/EAs/QM5_41095_wti-wexcursion-imbalance-mom/docs/test_week_excursion_imbalance_reference.py -v`
   returned 12/12 PASS.
2. `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_41095_wti-wexcursion-imbalance-mom/QM5_41095_wti-wexcursion-imbalance-mom.mq5`
   returned PASS with no findings.
3. `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41095_wti-wexcursion-imbalance-mom`
   returned PASS.
4. `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_41095_wti-wexcursion-imbalance-mom_card.md`
   returned `status=ok`, no ML hits, and no missing sections.

The reference suite covers strict long and short conditions, three/four/five-
session packages, two/six-session rejection, exact ratio equality, close/open
equality, both settlement-disagreement directions, invalid/nonadjacent/current-
week history, duplicate dates, native and uniformly shifted energy labels,
entry grace, durable weekly attempts, year boundaries, lifecycle, and the
static fixed-risk contract.

## Governed compile handoff

The direct strict compile was refused safely while `terminal64.exe` processes
were live, with failure class `INCLUDE_MIRROR_REFUSED` and detail
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. The repository contract directed the
build to the governed compile utility path; no retry or terminal control was
attempted.

The exact command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41095_wti-wexcursion-imbalance-mom`
created compile work item
`c88b39a4-1220-4894-a2c3-9818651c763e`. At handoff it is `pending` under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`, with no verdict, EX5, or build-check
claim. This activation hold is explicitly owned by the reviewed fleet-worker
rollout and release-on-restart ceremony. It was not released or bypassed.

Therefore Q01 is not claimed PASS. The setfile intentionally retains an
unbound `build_hash: pending` until the governed worker generates and binds
the final preset, performs the strict compile, and records its evidence.

## Binding capacity stop

Read-only `farmctl mt5-slots` at `2026-08-21T19:51:40Z` reported three active
governed factory terminals: T4 on Q09_NEWS, T6 on Q04, and T8 on Q07. The
separate `T_Live` and FTMO terminal processes were observed only to exclude
them; neither was accessed or controlled.

Five whole-host CPU samples at approximately four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| 2026-08-21T19:54:47.592Z | 93.17% |
| 2026-08-21T19:54:52.620Z | 91.91% |
| 2026-08-21T19:54:57.631Z | 98.35% |
| 2026-08-21T19:55:02.639Z | 100.00% |
| 2026-08-21T19:55:07.675Z | 100.00% |

Maximum CPU was `100.00%`; three samples crossed the explicit `97%` hard
ceiling. Q02 also lacks the prerequisite Q01 PASS. Per the mission stop
condition, no Q02 preview/apply, dispatcher tick, smoke, or manual backtest was
run.

## Safety and next deterministic action

No live/demo/shadow/stress/optimization preset, terminal reservation/control,
AutoTrading action, `T_Live` edit, deploy/T_Live-manifest change, portfolio-
gate mutation, portfolio admission, decorrelation claim, or correlation waiver
occurred.

After the authorized fleet restart releases the compile hold, let the governed
worker consume the exact source hash. Require strict compile PASS with zero
errors/warnings, target build-check PASS, a non-empty EX5, final setfile hash,
and static Q01 artifact validation before updating Q01 to PASS. Only then, and
only after a fresh target work-item/dedup check plus capacity samples remain
below all ceilings, may one target-only Q02 row be enqueued.
