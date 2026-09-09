# QM5_12778 FX cointegration Q09 priority resume

**Observed:** 2026-09-09 19:23:06Z

**Branch:** `agents/board-advisor`

**Outcome:** advanced one existing D1 market-neutral FX continuation by applying
one guarded queue-priority mark; no duplicate work item or tester was started

## Selection

The frozen 66-pair scan is fully mechanized, so a new Card, EA, registry row,
basket manifest, or Q02 row would duplicate committed work. The preferred
anchors are not Q02-blocked: `QM5_12532` has Q02 PASS followed by Q04 PASS and
Q05 FAIL, while `QM5_12533` has Q02 PASS followed by Q04 FAIL.

The non-duplicate fallback is the existing rank-25 D1 pair
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`. It trades `AUDUSD.DWX` and
`EURJPY.DWX` as a fixed-beta log-price spread-reversion basket. The unique Q09
continuation is work item `1ba8f6c7-7725-47c5-b0e5-6a4736c4ad44`, downstream
of Q02-Q07 PASS and Q08 FAIL_SOFT.

## Guarded advancement

Immediately before the mutation the row remained pending, unclaimed, unheld,
attempt zero, with exactly one open `(ea_id, phase, logical_symbol)` identity.
The priority dry run returned `reason=dry_run` and
`already_priority_track=false`.

Five immediate one-second host CPU samples were `32.7`, `72.4`, `75.9`,
`67.8`, and `70.5` percent (average `63.86%`, maximum `75.9%`). Every sample
was below the binding `97%` ceiling, so the exact priority mutation was applied:

```powershell
python tools/strategy_farm/farmctl.py mark-priority-track `
  --work-item-id 1ba8f6c7-7725-47c5-b0e5-6a4736c4ad44 `
  --reason "FX cointegration mission: advance unique QM5_12778 AUDUSD/EURJPY D1 Q09 continuation"
```

The command returned `applied=true`, `already_priority_track=false`. The
post-write read found `priority_track=true`, one append-only mark, no active
hold, one open identity, and canonical pending rank 49 of 6,539. The row
remained pending and unclaimed; normal terminal workers own dispatch.

## Validation and safety

- Approved-card schema lint: PASS; zero ML hits.
- Framework-input pin audit: exit 0; zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No `.mq5` was generated or modified, so no compile or compile enqueue was
  requested.
- No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
  T_Live, deploy, or AutoTrading surface was touched.
- No new Card, EA, work item, queue identity, verdict, claim, terminal process,
  or tester run was created.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_q09_priority_resume_20260909T192306Z_board_advisor.json`.
