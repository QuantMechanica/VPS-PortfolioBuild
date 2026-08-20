# QM5_41071 WTI Weekly Resumption Q01 / Q02 CPU-Ceiling Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41071_wti-wresume-dom`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## New Structural Sleeve

`QM5_41071` is a direct-WTI, low-frequency completed-week resumption edge on
`XTIUSD.DWX` D1. On the first tradable bar of each Monday-anchored broker week,
it reconstructs four consecutive completed week-end closes and three disjoint
weekly log returns. It trades only when the oldest and newest returns have the
same strict sign, the middle return has the opposite strict sign, and the
newest move strictly dominates the middle move in absolute magnitude. Direction
is the resumed outer sign. Equality, zero returns, malformed chronology, and
all other paths are flat.

This is a new direct physical-energy carrier outside the certified
XAU/SP500/NDX/XNG book. It is not a decorrelation claim: only Q09 can establish
realized portfolio correlation.

## Research, Approval, And Identity

- Source packet:
  `strategy-seeds/sources/MOP-WTI-WRESUME-DOM-2026/source.md`.
- Source basis: Moskowitz, Ooi, and Pedersen, *Time Series Momentum*, Journal of
  Financial Economics 104(2), DOI `10.1016/j.jfineco.2011.11.003`; the weekly
  three-leg resumption/dominance rule is explicitly disclosed as a QM timing
  hypothesis rather than a transferred paper result.
- Durable source approval:
  `decisions/2026-08-20_wti_weekly_resumption_dominance_source_approval.md`.
- G0 decision:
  `decisions/2026-08-20_qm5_41071_wti_weekly_resumption_dominance_g0.md`.
- Canonical dedup check returned `VERDICT: CLEAN`; manual family review separated
  immediate pullback, generic sign handoff, same-sign acceleration/deceleration,
  monthly, basket-relative, range, and volatility-ranked WTI identities.
- Registry allocation: EA ID `41071`, slot `0`, magic `410710000`.

The research, registry, magic, card, and build commits are respectively
`b3f0cbd8e`, `de5e96fa5`, `04d77da18`, `150444b8f`, and `4fee6452d`.

## Q01 Build Evidence

The V5 EA implements one persisted attempt per broker week before fallible
gates, no current-week price leakage, a frozen `3.5 * ATR(20,D1)` hard stop,
next-week exit, ten-day stale repair, and no target, trail, scale-in, grid,
martingale, or partial exit. The only tester preset is D1 `RISK_FIXED` with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF.

- Reference suite: 9 tests passed.
- Strict compile: 0 errors, 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260820_153602/QM5_41071_wti-wresume-dom.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260820_153631.json`.
- Static P1 validation: PASS; evidence
  `D:/QM/reports/pipeline/QM5_41071/P1/P1_QM5_41071_result.json`.
- Card and EA-local card SHA-256:
  `079174A5C8344E5CE3946D6D4E1F501BE39D162BDC4A9AC8A3645C1745E2469F`.
- MQ5 SHA-256:
  `61A22CCEC2B69F0FB663A1CD6779E7424B07E6F6C8B438D686CF6FB3BD6EDB39`.
- EX5 SHA-256:
  `A1A29F9F74BCA215FD4CA63BE30E993F26B3D4EC1018474CB58F8173E262734D`.
- Sealed setfile byte SHA-256:
  `F209DDF604C90A04057C11A1E72ABE32117B79108CEE000A9C037E3FEC332E8C`;
  normalized build hash
  `3d65ec0ab228598572eff372e4b9b78dee5da0c92f9f8308322e482a6194eee3`.

## Target-Only Q02 Preflight

Before and after the capacity check:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41071
count=0
```

The target-only dry run was:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41071 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

This proves the built identity is eligible for one fresh Q02 row. No `--apply`
command was issued, so no row was inserted and there is no duplicate.

## Binding Capacity Stop

The read-only terminal census at `2026-08-20T15:42:09+00:00` found four
running governed research terminals: `T2`, `T3`, `T5`, and `T10`. Four farm
work items were active: `QM5_20234` Q04, `QM5_11881` Q05, and `QM5_10148` plus
`QM5_10229` Q08. The separate `T_Live` and unrelated FTMO processes were
observed only so they could be excluded. No orphaned or duplicate terminal
worker was reported, and none was touched.

The binding five-sample `GetSystemTimes` whole-host CPU check ran from
`2026-08-20T15:41:26.517760+00:00` through
`2026-08-20T15:41:36.562905+00:00`. Two-second samples were `97.75`, `97.66`,
`98.83`, `95.46`, and `97.08` percent; average was `97.36` and maximum was
`98.83`. Four samples and the average crossed the explicit `97%` hard CPU
ceiling.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, backtest, terminal reservation or control, requeue, priority change,
cancellation, or attempt to accelerate the candidate.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim, correlation
waiver, live/demo/shadow/stress/optimization preset, or live use occurred.

A later paced worker may rerun the exact target-only dry run and enqueue one
fresh row only after a fresh governed-terminal and host-CPU check is below all
ceilings. It must first confirm `work-items --ea QM5_41071` is still empty.
Q02 must retire this identity on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive baseline economics, or any
hard-rule violation.
