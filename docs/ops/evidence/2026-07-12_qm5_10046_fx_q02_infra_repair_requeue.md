# QM5_10046 FX Q02 Infrastructure Repair and Requeue

Date: 2026-07-12

Agent: `codex:agents/board-advisor:qm5-10046:20260712T050048Z`

Branch: `agents/board-advisor`

## Outcome

Recovered the approved `QM5_10046_ff-momentum-div-h4` H4 sleeve from an
infrastructure-only Q02 dead end and enqueued fresh, distinct work for
`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`. The farm now shows
four pending Q02 work items under task
`be8bd717-b91f-4a6c-83b8-586a1909bef9`; no dispatch tick was invoked.

This is a forex-diversity throughput repair. It does not add build volume and
does not change the approved Momentum(28) divergence rules.

## Coordination and prior state

- Farm event: `repair_claimed` at `2026-07-12T05:00:48+00:00`
- Lease key: `manual:codex:agents/board-advisor:QM5_10046:q02-infra-recovery`
- Approved review: `9ee29ddc-b765-440a-8013-81b82ae7db95`
- Prior farm state: 48 Q02 `INFRA_FAIL` rows, zero pending rows, and no usable
  business verdict
- Consistent pre-requeue DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10046_q02_requeue_20260712T050700Z.sqlite`

## Diagnosis and repair

The EA rejected `ask == bid`. Darwinex `.DWX` Model-4 data can legitimately
model zero spread, so the following guard could silently block every entry:

```mql5
ask <= bid
```

The repair rejects only inverted quotes (`ask < bid`). It also brings the EA
back to current framework invariants by latching `QM_IsNewBar` exactly once,
sharing that event between closed-bar exits and entries, keeping management and
exits ahead of the entry-only news gate, and zero-initializing
`QM_EntryRequest`.

All four setfiles now explicitly lock the card parameters and use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, with the structural
Q02 news baseline disabled. Obsolete filter-library keys were removed.

The source mechanics remain the approved 3-left/3-right Momentum(28)
divergence, 8-28 bar pivot spacing, point-F break, point-C stop, 2R target,
breakeven at 1R, and opposite-divergence exit. The approved Strategy Card has
R1-R4 PASS and cites the source at
<https://www.forexfactory.com/thread/423512-best-trading-system-only-momentum>.

## Validation

| Check | Result | Evidence |
| --- | --- | --- |
| SPEC validator | PASS | 1 PASS, 0 FAIL |
| Strict build check | PASS | 0 failures, 0 warnings; `D:\QM\reports\framework\21\build_check_20260712_050513.json` |
| MetaEditor compile | PASS | 0 errors, 0 warnings; `D:\QM\reports\compile\20260712_050522\summary.csv` |
| Model-4 smoke | PASS | deterministic; 37 trades in both runs; `D:\QM\reports\smoke\QM5_10046\20260712_050548\summary.json` |

The 2024 smoke produced PF 0.72 and net profit -3,775.10 in both runs. Those
figures are recorded, not promoted: smoke verifies trade generation and
determinism, while Q02 owns the business verdict.

Artifact hashes:

```text
mq5  3758f7a81bbc15a20b397e3468719bda7f4b1744d08efcc6d47fda1fe03599e5
ex5  96b3bba936142621e5fe97e0da478c84e75a6470578ebbf35427a666590fc8f8
```

## Q02 enqueue

| Symbol | Work item |
| --- | --- |
| `EURUSD.DWX` | `7d971502-c148-4717-aecf-ee2b93fb6372` |
| `GBPUSD.DWX` | `7826c881-a5ba-4d57-8be8-d4954604bc5e` |
| `USDJPY.DWX` | `91510762-d36b-4753-ba44-18e2595419c8` |
| `XAUUSD.DWX` | `a42b78c6-2bb8-45e8-b1c0-4403f2269c54` |

`FACTORY_OFF.flag` remained present. No portfolio gate, T_Live artifact,
T_Live manifest, AutoTrading state, or live terminal configuration was touched.
