# FX cointegration fleet — rotated basket / hard CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T18:31:37.2584627Z`); 2026-08-28
20:31 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7e4f81e38d122af31bdafab46119a1c555725231`

Status: stopped at the explicit backtest CPU ceiling before card, build,
compile, smoke, claim, dispatch, enqueue, backtest, or queue mutation.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion selected only two relationships from the 66-pair scan:
`QM5_12532` AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY. Both are built, and
the committed sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. There is no eligible unbuilt pair without
duplicating governed coverage or weakening the reputable-source criterion.

Neither preferred anchor needs Q02 repair. Durable evidence records
`QM5_12532` at Q02 PASS, then Q04 PASS and Q05 FAIL, and `QM5_12533` at Q02
PASS, then Q04 FAIL. Their historical ONINIT/NO_HISTORY attempts do not
authorize another repair or duplicate enqueue. Consequently the Strategy Card
extraction and V5 EA-build skill gates remained closed.

## Existing FX fallback

The exact non-duplicate fallback remains
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`. The bounded canonical readback
found its three rows unchanged:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS;
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS;
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

The logical-basket setfile remains sealed with `RISK_FIXED=1000` and
`RISK_PERCENT=0`; its SHA-256 is
`b4fb11d85874f8a382c3785c16783761ec791add216a89cb3dee0a8308bf3eec`.
The basket manifest SHA-256 is
`090ef3be8e740003541bc911abb691599b28c92aa09efc557086fcc5f4ff5f17`.
No duplicate successor was created.

## Binding capacity result

Five one-second whole-host CPU samples were `98.831768%`, `99.317842%`,
`96.782523%`, `80.865849%`, and `92.383620%`. Average CPU was `93.636320%`
and maximum CPU was `99.317842%`. The governed admission ceiling binds when
either measure reaches `97%`; the maximum triggered the requested hard stop.

The supported `farmctl mt5-slots` snapshot at `2026-08-28T18:30:42Z` found
factory terminals on T1 and T10, all ten terminal-worker daemons, no duplicate
workers, and no orphaned factory terminal. T_Live and an unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

The canonical DB also contains a fresh legitimate multisymbol Q02 claim:
`QM5_41086_XAU_XAG_COMMONSHOCK_RV_D1`, work item
`4859f62b-3a57-449c-b0c0-3cef50fd7806`, active on T1. Its tester process is
visible. An initial read encountered SQLite writer contention; one bounded
retry succeeded and confirmed nine active rows overall. No absence or stale
state was inferred, and no claim was reclaimed.

## Non-duplicate delta and safety boundary

This materially differs from the preceding receipt at 12:36 UTC. The earlier
`QM5_41083` basket claim rotated out, `QM5_41086` now occupies the multisymbol
lane, the visible factory roster expanded from T10 to T1/T10, and the fresh
maximum CPU rose from `93.073652%` to `99.317842%`. The current stop is thus
both a new basket-lane occupant and a newly binding hard CPU ceiling.

No Card, EA, source, EX5, setfile, basket manifest, registry, magic row,
resolver, build result, queue row, priority, claim, status, verdict,
reservation, worker, terminal, smoke, or backtest was created or changed. The
portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`, T_Live,
AutoTrading, and live/deploy manifests were untouched. Existing unrelated
shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260828T183137Z_board_advisor.json`.

## Continuation condition

After `4859f62b-3a57-449c-b0c0-3cef50fd7806` reaches a canonical terminal
state, take a fresh five-sample CPU window. Advance exactly one already-pending
FX basket successor only when both CPU measures are strictly below 97% and no
multisymbol claim is active; do not enqueue a duplicate.
