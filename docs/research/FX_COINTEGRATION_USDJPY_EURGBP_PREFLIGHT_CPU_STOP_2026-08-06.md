# USDJPY/EURGBP FX Cointegration Preflight CPU Stop

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: next apparent relationship gap identified; no Card, allocation, build,
or Q02 enqueue because the binding backtest CPU ceiling was reached

## Outcome

The frozen sign-aware 66-pair scan was reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The current frontier is:

- rank 57, `USDCAD.DWX` / `EURJPY.DWX`, is built as `QM5_20238`;
- rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, is already an explicit relationship
  in `QM5_1156_caldeira-cointegration-pairs-fx`;
- rank 59, `USDCHF.DWX` / `GBPJPY.DWX`, is built and Q01-PASS as
  `QM5_20240`; and
- rank 60, `USDJPY.DWX` / `EURGBP.DWX`, is the next apparent dedicated
  relationship gap.

A bounded filename, Card, and basket-manifest search found no dedicated
USDJPY/EURGBP Strategy Card, EA directory, or exact two-leg manifest. Because
capacity stopped the mission, a later paced turn must repeat the full semantic
duplicate guard, including umbrella pair slots, before creating any governed
artifact.

## Anchor triage

The requested anchor-repair preference does not apply:

- `QM5_12532` has canonical logical-basket Q02 PASS evidence and later failed
  Q05.
- `QM5_12533` has canonical logical-basket Q02 PASS evidence and later failed
  Q04.
- Neither anchor is currently blocked at Q02 by ONINIT or NO_HISTORY.

Re-enqueueing either anchor would duplicate completed terminal work.

## Candidate evidence

| Measure | Frozen scan value |
|---|---:|
| sign-aware rank | 60 of 66 |
| DEV net Sharpe | 0.25 |
| OOS net Sharpe | -0.46 |
| OOS return | -6.37% |
| OOS state changes | 13 |
| DEV beta | -1.28 |
| half-life | 133 D1 bars |

These rounded values are adverse frontier evidence, not a performance claim
or build authorization. If the exact relationship remains unbuilt after the
next duplicate audit, the frozen full-precision beta must be recovered from
the checked-in scan before Card approval and must not be refitted. Any future
Card remains a one-shot falsification test with retirement, not a rescue
filter or parameter substitution, after a terminal failure.

The reputable structural method remains the OWNER-ratified Tier-A extraction
of Ernest Chan's pair-trading examples at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the mechanical market-neutral spread method, not a USDJPY/EURGBP performance
claim. Pair-specific evidence is limited to the OWNER-requested Darwinex D1
scan recorded in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and
the reproducible checked-in script above.

## Binding CPU ceiling

The read-only path-aware sample was taken with:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
```

At `2026-08-06T05:49:23Z`, every factory terminal was running:

```text
T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
```

Ten exceeds the paced-fleet seven-terminal backtest ceiling. `T_Live` and an
unrelated FTMO terminal were observed separately and excluded; neither was
controlled.

Per the mission stop rule, no source/Card mutation, EA-ID or magic allocation,
compile, queue mutation, dispatch tick, tester launch, terminal-control action,
AutoTrading action, portfolio-gate action, or live artifact followed.

## Next paced action

After a fresh path-aware sample is below the binding ceiling:

1. Prefer advancing the already Q01-PASS `QM5_20240` by guarded dry-run and
   exact enqueue of one logical-basket Q02 row if it remains not enqueued.
2. If the mission still requires a new relationship, repeat the full duplicate
   guard for rank-60 USDJPY/EURGBP, recover the exact frozen row, then apply
   the governed Card, registry, magic, build, manifest, strict-Q01, and Q02
   sequence.
3. Do not dispatch or launch a tester as part of the enqueue handoff.

No portfolio-admission, portfolio KPI, Q08-contribution, `T_Live` manifest,
live deployment, or AutoTrading state was changed.
