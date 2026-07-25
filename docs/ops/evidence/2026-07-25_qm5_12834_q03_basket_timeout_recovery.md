# QM5_12834 Q03 Legacy Basket Timeout Recovery

**Observed:** 2026-07-25T06:06:11Z

**Branch:** `agents/board-advisor`

**Outcome:** `REPAIRED_AND_REQUEUED`

## Diversity-first selection

No higher-priority approved diversity build was both feasible and unclaimed at
selection time:

- the open forex build `QM5_20062` was already claimed by another paced agent;
- the rates card `QM5_1457` required unavailable Treasury/IEF/BIL/DBC inputs;
- `QM5_1459` required unavailable lumber history; and
- the remaining DAX work would add to the existing index concentration.

The next mission priority was therefore used: recover a diverse built EA stuck
at Q03 for infrastructure reasons. `QM5_12834_wti-jpy-spread` is a
low-frequency D1, market-neutral relative-value basket between `XTIUSD.DWX`
and `USDJPY.DWX`. Its approved card cites official EIA and Bank of Japan
sources, expects about 4-10 basket packages per year, and forbids ML, grids,
and martingale behavior.

The farm claim was created before diagnosis or mutation:

```text
repair task: 0645820e-8908-4946-9ae1-4d089a9175a3
claimed_by:  codex:agents/board-advisor
work item:   b46fef91-427c-4f4e-a921-cd1b3f6e46fc
phase:       Q03
```

The guarded transaction found no competing repair claim and no pending or
active Q02/Q03 row for this EA.

## Diagnosis

The existing Q03 row was `failed / INFRA_FAIL`, with two exhausted attempts
and `summary_missing_retries_exhausted`. It retained a legacy
`timeout_min=120` outer worker budget.

The retained MT5 evidence isolates that budget as the failure:

- four attempts produced a complete 363,318-byte `run_01` native report;
- on the latest attempt, run 1 finished successfully in `1:02:41.608`;
- run 2 then progressed to 74 percent;
- another job started on T4 at 06:36:02 local, almost exactly 120 minutes
  after this work item started, because the outer worker deadline had expired;
- no ONINIT or strategy verdict was published.

The latest complete first-run report has SHA256
`cbfcce398edde84a6fb9695aa03ff08237e0d9df7f2157206c7599e29967543b`.
The same EA already has Q02 PASS and early Q04, Q05, and Q06 PASS records.
This is therefore a runner-budget defect, not an alpha, initialization, or
history-availability failure. One isolated USDJPY history-lock error occurred
between attempts, but it does not explain the repeated complete-run-1 /
interrupted-run-2 signature.

Current farm code assigns logical baskets a 450-minute outer budget. This
legacy row predated that setting and had preserved 120 minutes through its
earlier stale-binary recovery.

## Repair and validation

The existing row was reopened in place; no duplicate row was inserted:

```text
status:          pending
verdict:         null
attempt_count:   0
claimed_by:      null
timeout_min:     450
open Q03 rows:   1
total Q03 rows:  1
parent task:     pending
```

Prior reports were preserved at:

```text
D:\QM\reports\work_items\b46fef91-427c-4f4e-a921-cd1b3f6e46fc.requeued_20260725T060611Z
```

The pre-mutation SQLite backup passed `PRAGMA quick_check`:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12834_q03_timeout_requeue_20260725T060611Z.sqlite
```

No strategy or build artifact changed. The already-tested artifacts remain:

| Artifact | SHA256 |
|---|---|
| MQ5 | `164b2c5309ba2828df04ca2990d58fbc80bd17a0832e3e6a911850f7077a1620` |
| EX5 | `fb2d9ffe146e37967b34d21db1e81ab9dbb2e1c22fc3d73dae5c4a81942217bd` |
| Q03 setfile | `17662d52258c5ea62cfd2b3ccf1ed8e647acb6acfb35d87f90050f625e69bf5f` |

`validate_spec_doc.py` passed. The unchanged Q03 setfile remains deterministic
fixed risk:

```text
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
```

## Capacity and safety boundary

At the handoff, `farmctl mt5-slots` reported five factory terminals running
(`T2`, `T7`, `T8`, `T9`, and `T10`), below the seven-process backtest CPU
ceiling. The Q03 row was left pending for normal paced dispatch; no manual
smoke, dispatcher tick, pipeline phase, or MT5 launch was run.

`T_Live` was excluded from the capacity count and was not controlled.
AutoTrading, the live manifest, portfolio gate, portfolio-admission state, and
Q08 contribution artifacts were not touched.

A separate Q07 `INFRA_FAIL` remains outside this deliberately single-unit Q03
recovery.
