# FX Cointegration Exhaustion And Q02 CPU Ceiling — 2026-07-20

## Mission

Grow the certified V5 portfolio with a new low-frequency, structural forex
cointegration sleeve. Prefer repairing `QM5_12532` / `QM5_12533` if either is
still blocked at Q02; otherwise select one non-duplicate next-best pair from
the OWNER-requested 66-pair scan, build it with a basket manifest, and enqueue
Q02.

## Fresh repository and farm audit

The mission's Q02-blocker premise is stale:

| EA | Pair | Current farm evidence |
|---|---|---|
| `QM5_12532` | AUDUSD / NZDUSD | logical-basket Q02 `PASS`; Q04 `PASS`; Q05 `FAIL` |
| `QM5_12533` | EURJPY / GBPJPY | logical-basket Q02 `PASS`; Q04 `FAIL` |

Neither anchor has an open Q02 `ONINIT` or `NO_HISTORY` blocker.

The original positive-hedge 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` certified only those
two pairs. The later sign-aware reproduction identified two additional strict
rows, both already built and already through Q02:

| EA | Pair | Current farm evidence |
|---|---|---|
| `QM5_13117` | EURGBP / AUDJPY | Q02-Q07 `PASS`; Q08 `FAIL_HARD` |
| `QM5_13119` | USDJPY / EURAUD | Q02-Q03 `PASS`; Q04 `FAIL` |

All four EAs have an `.mq5`, compiled `.ex5`, `RISK_FIXED` logical backtest
setfile, and `basket_manifest.json`. The wider set of follow-up cointegration
cards visible under `framework/EAs/` is also already built; creating another
card from the same rows would be duplicate work. Relaxing the scan threshold
or changing fixed betas/z-score rules would be an unauthorized research
ablation and would not satisfy the reputable-source/non-p-hacking constraint.

## Paced fleet state

Read-only query of
`D:/QM/strategy_farm/state/farm_state.sqlite` at approximately 2026-07-20
22:58 Europe/Berlin:

- Q02 active: **1**, worker-owned by T3 (`QM5_1910`, `UK100.DWX`).
- Q02 pending: **3,382**.
- The existing forex fallback `QM5_11755` already has three pending Q02 rows
  (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`) plus completed hard failures on
  its other FX symbols; enqueueing another row would not advance a unique
  candidate.

This is the mission's explicit backtest CPU-ceiling stop. No Q02 row was
inserted and no MT5 process was launched.

## Safety and scope

- No `T_Live` access and no AutoTrading change.
- No portfolio admission, KPI, Q08-contribution, or T_Live manifest change.
- No strategy parameter, registry, EA, setfile, or farm-state mutation.
- Unrelated dirty worktree files were left untouched.

## Conclusion

There is no qualifying unbuilt pair remaining in the approved strict scan,
the anchors are not Q02-infrastructure blocked, and already-built forex work
is queued behind a material paced-farm backlog. Stop at the CPU ceiling rather
than manufacture a duplicate or below-threshold sleeve.
