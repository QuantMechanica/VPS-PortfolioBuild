# QM5_20246 USDJPY/EURGBP Q02 CPU-Ceiling Handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: existing rank-60 FX basket is Q01-PASS and eligible for one logical
Q02 row; enqueue stopped at the binding paced-fleet CPU ceiling

## Outcome

The requested anchor repair is not applicable. `QM5_12532` has canonical
logical-basket Q02 PASS evidence followed by Q05 FAIL, and `QM5_12533` has
canonical logical-basket Q02 PASS evidence followed by Q04 FAIL. Neither has
a current Q02 `ONINIT` or `NO_HISTORY` blocker.

The frozen sign-aware 66-pair frontier has already been mechanized through
rank 60. The latest dedicated relationship, USDJPY/EURGBP, is built as
`QM5_20246_usdjpy-eurgbp` with an approved source-backed Card, deterministic
EA ID and two traded-symbol magic rows, compiled EA, two-leg
`basket_manifest.json`, and `RISK_FIXED=1000` backtest presets. Creating
another USDJPY/EURGBP Card or build would be duplicate work, so this paced
turn selected the existing Q01-PASS basket for the mission fallback.

No Q02 row was enqueued. The binding capacity sample at
`2026-08-06T11:46:49Z` found exactly seven running factory terminals:

```text
T3, T5, T6, T7, T8, T9, T10
```

Seven is the configured paced-fleet ceiling, leaving no admissible backtest
slot. `T_Live` and the unrelated FTMO terminal were observed separately and
excluded; neither was controlled. Per the mission stop rule, no queue apply,
dispatch tick, terminal reservation, tester launch, terminal-control action,
or AutoTrading action followed.

### Paced recheck at 13:32Z

A later path-anchored read-only sample at `2026-08-06T13:32:14Z` again
found exactly seven running factory terminals:

```text
T1, T2, T3, T5, T6, T8, T9
```

This is a new capacity observation rather than a retry: the occupied-terminal
set changed from the earlier sample, but remained at the binding ceiling.
`T_Live` and the unrelated FTMO terminal were again observed separately and
excluded. The stop rule therefore remained binding; no queue apply, dispatch,
reservation, tester launch, terminal-control action, or AutoTrading action
followed this recheck.

## Queue and duplicate audit

The canonical farm returned no work item for `QM5_20246`. A guarded dry run
of:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20246
```

selected exactly one never-tested candidate and skipped the physical host
preset with `basket_manifest_logical_setfile_preferred`. This confirms that a
future apply will target the logical basket preset rather than create two
physical-leg rows.

The same read-only audit found:

- `QM5_20238` already has one pending logical-basket Q02 work item;
- `QM5_20240` has one terminal Q02 `INFRA_FAIL` work item updated at
  `2026-08-06T11:16:44Z`; and
- `QM5_20246` has no pending, active, or terminal work item.

Therefore this turn did not duplicate either an existing basket or an
existing queue row.

## Next paced action

After a fresh path-anchored sample is below seven running factory terminals,
repeat the exact `QM5_20246` dry run and apply it only if the canonical farm
still contains no row for that EA. Verify that exactly one Q02 work item is
created for logical symbol
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. Do not dispatch or launch a tester
as part of the enqueue handoff.

Separately classify the existing `QM5_20240` `INFRA_FAIL` before any retry;
do not re-enqueue it blindly.

## Safety

No portfolio-admission, portfolio KPI, Q08-contribution, `T_Live` manifest,
live deployment, or AutoTrading state was changed. No Card, registry, magic,
EA, binary, setfile, or basket manifest was changed.
