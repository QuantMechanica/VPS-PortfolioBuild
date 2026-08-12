# USDCAD/EURJPY FX Cointegration Preflight CPU Stop

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: next non-duplicate pair identified; no Card, allocation, build, or Q02 enqueue because the binding backtest CPU ceiling was reached

## Outcome

The frozen sign-aware 66-pair scan was reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

After the rank-55 `USDCHF.DWX` / `NZDUSD.DWX` sleeve was mechanized as
`QM5_20232`, the first exact-pair build gap is rank 57,
`USDCAD.DWX` / `EURJPY.DWX`. Rank 56, `USDCHF.DWX` / `EURGBP.DWX`, already
has the dedicated `QM5_12786` Card, EA, and logical basket manifest.

A read-only exact-pair audit found no Strategy Card, EA directory, EA-registry
row, dedicated logical basket manifest, or frozen-scan strategy ID for
USDCAD/EURJPY. `QM5_11055_pst-assettrend` mentions both symbols inside a broad
cross-asset trend universe; it is not a two-leg cointegration relationship and
does not duplicate this candidate.

## Anchor triage

The requested anchor-repair preference does not apply:

- `QM5_12532` has canonical logical-basket Q02 PASS evidence and later failed
  Q05.
- `QM5_12533` has canonical logical-basket Q02 PASS evidence and later failed
  Q04.
- Neither anchor is currently blocked at Q02 by ONINIT or NO_HISTORY.

Re-enqueueing either anchor would duplicate terminal Q02 work.

## Candidate evidence

| Measure | Frozen value |
|---|---:|
| sign-aware rank | 57 of 66 |
| DEV net Sharpe | -0.006562345356 |
| OOS net Sharpe | -0.403385422796 |
| OOS return | -2.696283405216% |
| OOS state changes | 13 |
| DEV beta | -0.243266890557 |
| half-life | 66.784057177571 D1 bars |

This is adverse frontier evidence, not a performance claim. The pair is only
eligible as the mission-requested next-best, one-shot falsification sleeve.
If later authorized and capacity-cleared, its fixed DEV beta must not be
refitted and a failed gate must retire the exact pair without a rescue filter
or parameter substitution.

The reputable structural method remains the OWNER-ratified Tier-A extraction
of Ernest Chan's pair-trading examples at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the market-neutral spread method, not a USDCAD/EURJPY performance claim. The
pair-specific evidence is the OWNER-requested Darwinex D1 scan recorded in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and reproduced by the
checked-in script above.

## Binding CPU ceiling

The read-only `farmctl.py mt5-slots` sample at
`2026-08-06T00:03:28Z` found nine factory terminals running:

```text
T1, T2, T4, T5, T6, T7, T8, T9, T10
```

Nine exceeds the paced-fleet seven-terminal backtest ceiling. `T_Live` and an
unrelated FTMO terminal were observed separately and excluded from the factory
count; neither was controlled.

Per the mission stop rule, no source/card mutation, ID or magic allocation,
compile, queue mutation, dispatch tick, tester launch, terminal-control action,
AutoTrading action, portfolio-gate action, or live artifact followed.

## Next paced action

After a fresh capacity sample is below the binding ceiling, repeat the exact
duplicate guard. If USDCAD/EURJPY remains unbuilt, create its durable G0
authorization and approved Card, reserve the next deterministic EA ID and two
traded magic slots, build a fixed-beta D1 two-leg EA with
`basket_manifest.json` and `RISK_FIXED=1000` backtest setfile, pass strict Q01,
and enqueue exactly one logical-basket Q02 row. Do not launch a manual tester.

No portfolio-admission, portfolio KPI, Q08-contribution, `T_Live` manifest, or
live-deployment path was changed.
