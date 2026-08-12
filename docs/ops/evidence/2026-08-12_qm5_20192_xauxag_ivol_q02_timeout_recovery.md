# QM5_20192 XAU/XAG Q02 timeout recovery

Date: 2026-08-12
Branch: `agents/board-advisor`
EA: `QM5_20192_xauxag-ivol`
Scope: Q02 infrastructure repair and append-only re-enqueue; no economic verdict

## Selection and coordination

- The highest-diversity approved build-backlog cards were not build-eligible:
  the rates candidate `QM5_1457` and lumber/gold candidate `QM5_1459` require
  governed symbols that are absent from the Darwinex `.DWX` inventory, retain
  `R3: UNKNOWN`, and do not have their required deterministic magic rows.
  The mission therefore moved to its priority-2 diverse-instrument repair lane.
- `QM5_20192` is an APPROVED, structural D1 market-neutral XAU/XAG residual-
  volatility pair. Its card records R1-R4 PASS and a peer-reviewed source
  basis (Fuertes et al., 2015). It targets about twelve packages per year.
- Approved-card SHA-256:
  `cbe07fe7445d9a0f9df64268dd5c8cd4d0f38bc707aee3548b5f61503fd36f47`.
  Full-card SHA-256:
  `2595c8e2026f5f28daa5cc1035364422868f067ca3ee4b8c2f315cc4d9c7d91a`.
- EA registry row `20192` was active before the repair. The farm claim was
  acquired before source changes as
  `agent_tasks.id=9db2085f-3c85-49b6-9825-b1ecd35f3133`, assigned to
  `codex:agents/board-advisor`. No competing open claim existed for this EA.
- Pre-claim SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20192_q02_perf_claim_20260812T030345Z.sqlite`.

## Diagnosed infrastructure defect

The farm history contained nine Q02 `INFRA_FAIL` attempts on seven terminals
(T1, T3, T5, T6, T7, T9, and T10). All were bound to the same prior artifacts:
MQ5 SHA-256
`82d036a0a9279516235d23a512ce423414625986111efb40f8ad4bad82d0e1f8`
and EX5 SHA-256
`c5b2dcfa4107e819d77690d101689705fd4d9ba4c7101115793c9a0004741f13`.
Their reasons were `TIMEOUT;INCOMPLETE_RUNS`; three also recorded
`METATESTER_HUNG`.

The latest predecessor,
`463530a7-e029-4c97-8fd2-0c85f6f72e00`, reached the 7,200-second timeout.
Its terminal/tester journals showed deterministic simulation progress and
trades rather than an initialization failure: the T5 run advanced only to
May 2020 before forced termination. The active-position hot path performed
several complete account-position scans per XAU real tick and repeatedly
invoked collision-safe magic resolution, whose implementation also scans
positions. The fixed-input filter was likewise evaluated before the
closed-D1-bar fast exit. This explains the recurrent incomplete-run signature
without reinterpreting it as an economic result.

## Repair

- Resolve and cache the two immutable registered leg magics once at framework
  initialization. Register XAG slot 1 explicitly so framework kill-switch,
  Friday-close, and accounting ownership covers both traded legs.
- Consolidate pair count, direction, stop, and earliest-entry checks into one
  broker snapshot. Any `OnTradeTransaction` invalidates that snapshot; the
  next tick refreshes it, while intervening ticks retain the card's invariant
  guard with O(1) checks.
- Move the immutable fixed-input filter behind the existing new-D1-bar gate.
- Preserve the approved universe, signal, ranking, sizing, stops, monthly
  cadence, 35-day stale exit, and entry-attempt semantics. The change is an
  execution-cost and framework-ownership repair only.
- Keep the canonical backtest contract at `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Current artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `8b63d0b8856fa4a89226e4ceb879fc257de03f3740fd1089358874a3d4340ed9` |
| EX5 | `e2d0a50cf675f4bc476547e2574ef1f433e2187a948079ac7ab4ee67c486395d` |
| Canonical backtest set | `6a89dadb1759fd7aaf263da94ecac5072a6a3e6dd32a5bc97c086cede044cf21` |

## Verification

- `validate_spec_doc.py`: PASS.
- `validate_build_guardrails.py`: PASS, two files checked, no findings.
- Canonical `build_check.ps1`: PASS, zero failures and zero warnings.
- Strict compile: PASS, zero errors and zero warnings. Log:
  `C:\QM\repo\framework\build\compile\20260812_031339\QM5_20192_xauxag-ivol.compile.log`.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260812_031339.json`.
- Target-scoped `git diff --check`: PASS.

No manual smoke test or backtest was launched. At the enqueue decision, three
exact factory terminals and four active database rows were observed against
the paced-fleet ceiling of seven. A five-sample CPU reading averaged 87.2%
and peaked at 100%, so execution was left to the existing factory scheduler.

## Q02 handoff

The supported target-only sweep dry run selected exactly one stranded Q02
requeue. The append-only apply created successor work item
`0219d518-61ba-4a3b-9d81-b1e83ca30d47` for logical basket
`QM5_20192_XAU_XAG_IVOL_D1`, preserving predecessor
`463530a7-e029-4c97-8fd2-0c85f6f72e00`. Immediate readback showed `pending`,
priority-track enabled, and no verdict. The enqueue receipt is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`.

Q02 is enqueued, not passed. No certification, efficacy, diversification, or
portfolio-admission claim follows from this repair.

## Safety boundary

- No manual dispatch, smoke test, downstream phase, live, shadow, or
  optimization run was started.
- No terminal setting or AutoTrading state was changed.
- `T_Live`, its deploy manifest, and the portfolio gate were not touched.
