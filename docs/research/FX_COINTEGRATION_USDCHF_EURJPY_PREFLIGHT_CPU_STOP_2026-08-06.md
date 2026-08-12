# USDCHF/EURJPY FX Cointegration Preflight CPU Stop

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: next non-duplicate pair identified; no Card, allocation, build, or Q02
enqueue because the binding backtest CPU ceiling was reached

## Outcome

The frozen sign-aware 66-pair scan was reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The dedicated relationship frontier is built through rank 63,
`USDCHF.DWX` / `EURAUD.DWX`, as `QM5_20252`. Rank 64,
`USDCHF.DWX` / `EURJPY.DWX`, is the first current exact-pair build gap.

A read-only duplicate guard found no exact `usdchf-eurjpy` slug,
`AI-CODEX-FX-COINT66-20260609-USDCHF-EURJPY` strategy ID, Strategy Card, EA
directory, EA-registry row, dedicated pair preset, or two-leg basket manifest.
The current inventories contained 4,311 EA-registry rows, 427 direct Card
files, and 262 tracked basket manifests.

Five broad manifests contain both symbols as unrelated universe members:
`QM5_10717`, `QM5_10718`, `QM5_11012`, `QM5_11055`, and `QM5_12821`. None
declares USDCHF/EURJPY as its dedicated traded relationship. The dynamic
cointegration umbrellas `QM5_1156` and `QM5_1257` do not contain EURJPY in
their candidate universes, so neither mechanizes this pair slot.

## Anchor triage

Current canonical Strategy Farm queries resolve the requested repair priority:

- `QM5_12532` has a logical-basket Q02 PASS and Q04 PASS, followed by Q05
  FAIL.
- `QM5_12533` has a logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has a pending or active Q02 ONINIT / NO_HISTORY blocker.

The older physical-leg and infrastructure failures are superseded by the
logical-basket Q02 passes. Repairing or re-enqueueing either anchor would
duplicate completed funnel work.

## Candidate evidence

| Measure | Frozen value |
|---|---:|
| sign-aware rank | 64 of 66 |
| DEV net Sharpe | -0.045661686086 |
| OOS net Sharpe | -0.547994298753 |
| OOS return | -5.473566746133% |
| OOS state changes | 15 |
| DEV beta | -0.075286902527 |
| half-life | 97.411859950023 D1 bars |

The negative DEV and OOS results, small absolute beta, and slow half-life are
adverse frontier evidence, not a performance claim. The pair is eligible only
as the mission-requested next-best one-shot falsification sleeve. A later
terminal economic, cadence, or minimum-volume failure must retire the exact
pair without a beta refit, rescue filter, or parameter substitution.

The reputable structural method remains the OWNER-ratified Tier-A extraction
of Ernest Chan's pair-trading examples at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the fitted-spread, standardized-deviation entry, mean-reach exit, and
low-frequency daily method; he makes no USDCHF/EURJPY performance claim.
Pair-specific evidence is limited to the OWNER-requested Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and its reproducible
checked-in script above.

## Binding CPU ceiling

The path-aware canonical sample used:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
```

At `2026-08-06T21:10:37Z`, nine factory terminals were running:

```text
T1, T3, T4, T5, T6, T7, T8, T9, T10
```

Nine exceeds the paced-fleet seven-terminal backtest ceiling. A preceding
path-exact process sample at `2026-08-06T21:09:42Z` observed all ten factory
terminals, so both immediately adjacent observations bind the same stop.
`T_Live` and an unrelated FTMO terminal were observed separately and excluded
from the factory count; neither was controlled.

Per the mission stop rule, no source/Card mutation, EA-ID or magic allocation,
compile, queue mutation, dispatch tick, tester launch, terminal-control action,
AutoTrading action, portfolio-gate action, or live artifact followed.

## Next paced action

After a fresh path-aware sample is below the binding ceiling, repeat the exact
duplicate guard. If USDCHF/EURJPY remains unbuilt, create its durable G0
authorization and approved Card, reserve the next deterministic EA ID and two
traded magic slots, build a frozen-beta D1 two-leg EA with
`basket_manifest.json` and `RISK_FIXED=1000` backtest presets, pass strict Q01,
and enqueue exactly one logical-basket Q02 row. `USDJPY.DWX` is the expected
conversion-history-only dependency and must receive no order or magic slot.
Do not launch a manual tester as part of the enqueue handoff.

No portfolio-admission, portfolio KPI, Q08-contribution, `T_Live` manifest,
live deployment, or AutoTrading state was changed.
