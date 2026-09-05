# QM5_12778 FX cointegration stale-hold release and CPU stop

Recorded: 2026-09-05T23:23:16.5283105Z (2026-09-06 01:23 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

The existing AUDUSD/EURJPY D1 cointegration basket `QM5_12778` is runnable
again. Its unique priority-bound `Q09_NEWS` row was absent from the canonical
claim selector because the `NEWS_CALENDAR_TIMESTAMP_DEFECT` hold still had
`active=1`, despite carrying a prior `released_at` timestamp and release note.
The governed `farmctl release-hold` CAS set the hold inactive under the global
factory-mutation lock, after taking and hashing a database backup. It did not
change the work item, its payload, its priority, or its verdict.

The repaired row re-entered the canonical selector at rank 149 of 9,739
eligible rows. A post-repair five-sample capacity check then reached 100% CPU,
above the explicit 97% hard ceiling, so no claim, dispatch, terminal, compile,
or backtest was started.

## Why this existing pair was selected

The frozen 66-pair discovery is fully mechanized; creating another card or EA
would duplicate governed work. The two preferred anchors also need no Q02
setup repair:

- `QM5_12532` has logical-basket Q02 PASS, followed by Q04 PASS and Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS, followed by Q04 FAIL.

`QM5_12778` is the strongest clean existing continuation with a concrete
control-plane blocker. Its approved Card is source-backed by Ernest P. Chan's
cointegration method and the reproducible in-house FX scan. The sealed design
is structural and low-frequency: a fixed-beta D1 log spread, fixed z-score
thresholds, no adaptive refit or ML, and a two-leg basket manifest.

## Exact continuation state

- Pair: `AUDUSD.DWX` / `EURJPY.DWX`
- Logical symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- Work item: `24acc5d4-3e34-526e-a7a8-12640a2e759f`
- Phase: `Q09_NEWS`
- State after repair: pending, unclaimed, attempt 0, no verdict
- Open identical `(EA, phase, symbol)` rows: 1
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Binding: `q09-news-dispatch-binding/v1`
- Priority: retained; no queue-order rewrite

The repair changed only the hold record:

- Before: `active=1`, while `released_at=2026-09-04T22:49:53+00:00`
- After: `active=0`, `released_at=2026-09-05T23:22:04+00:00`
- Event: `386111`, `work_item_hold_released`
- Ledger key: `hold_release:24acc5d4-3e34-526e-a7a8-12640a2e759f:NEWS_CALENDAR_TIMESTAMP_DEFECT:2026-09-05T23:22:04+00:00`
- Backup: `D:/QM/strategy_farm/state/backups/farm_state_before_hold_release_20260905T232204_823047Z.sqlite`
- Backup SHA-256: `60b7f8bba7bca146fa784f55130e2a75ff12f468635fcbc7dc68a63a47335559`

## Capacity and safety

Post-repair whole-host CPU samples were 94%, 91%, 91%, 93%, and 100%
(average 93.8%, maximum 100%). The hard ceiling therefore bound. Free physical
memory was 27.904 GiB of 63.120 GiB; the farm had five active and 12,880
pending work items.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live manifest/file, live/deploy, or AutoTrading surface was touched.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12778_stale_hold_release_20260905T232204Z_board_advisor.json`.

## Resume contract

After CPU capacity recovers, leave the unique priority-bound row to the
resident paced worker. Do not append a duplicate, rewrite its sealed diagnostic
order, or manually dispatch while the 97% ceiling binds.
