# USDCHF/NZDUSD FX Cointegration Preflight CPU Stop

Date: 2026-08-05

Branch: `agents/board-advisor`

Status: next non-duplicate pair identified; no Card, allocation, build, or Q02 enqueue because the binding backtest CPU ceiling was reached

## Outcome

The frozen sign-aware 66-pair scan was reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The first current gap after the newly built rank-50 USDCAD/GBPJPY sleeve is
rank 55, `USDCHF.DWX` / `NZDUSD.DWX`. Ranks 51 through 54 already have
dedicated builds (`QM5_12776`, `QM5_12778`, `QM5_12781`, and `QM5_12783`),
and rank 56 has `QM5_12786`. No Card, EA directory, EA registry row, or
dedicated exact-pair basket was found for USDCHF/NZDUSD.

The binding capacity sample at `2026-08-05T19:01:57Z` found every factory
terminal `T1` through `T10` running. `T_Live` and an unrelated FTMO terminal
were observed separately and excluded from the factory count. Per the mission
CPU-ceiling rule, work stopped before any source/card write, ID or magic
allocation, compile, queue mutation, dispatch tick, tester launch, terminal
control, AutoTrading action, or portfolio-gate action.

## Anchor triage

The requested anchor preference does not apply:

- `QM5_12532` has a canonical logical-basket Q02 PASS, Q04 PASS, and later
  Q05 FAIL.
- `QM5_12533` has a canonical logical-basket Q02 PASS and later Q04 FAIL.
- Neither anchor has a pending or active Q02 ONINIT/NO_HISTORY blocker.

Historical physical-leg failures are superseded by the logical-basket Q02
passes; repairing or re-enqueueing them would be duplicate work.

## Candidate evidence

| Measure | Frozen value |
|---|---:|
| sign-aware rank | 55 of 66 |
| DEV net Sharpe | 0.035539255135 |
| OOS net Sharpe | -0.387375764096 |
| OOS return | -3.267369013120% |
| OOS state changes | 16 |
| DEV beta | -0.270458913150 |
| half-life | 108.268319129809 D1 bars |

The row is OOS-negative and slow. It is eligible only as the explicitly
requested next-best one-shot falsification sleeve; terminal cadence or
economic failure must retire the exact pair without beta refit, rescue filter,
or parameter substitution.

The reputable structural method remains the OWNER-ratified Tier-A extraction
of Ernest Chan's pair-trading examples at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the method, not a USDCHF/NZDUSD performance claim. Pair-specific evidence is
the OWNER-requested Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and its reproducible
script above.

## Duplicate guard

The deterministic research check used candidate slug `usdchf-nzdusd` and
strategy ID `AI-CODEX-FX-COINT66-20260609-USDCHF-NZDUSD`:

- 4,287 EA registry rows: no exact collision.
- 403 Strategy Cards: no exact collision.
- One fuzzy hit, `usdjpy-nzdusd`, was manually resolved as a different first
  leg, beta, residual, and logical basket.
- Exact repository text and the current EA-directory frontier contained no
  dedicated USDCHF/NZDUSD pair build.

## Next paced action

After a fresh capacity sample is below the binding ceiling, re-run the exact
duplicate guard. If the pair remains unbuilt, create the durable G0 decision
and approved Card for slug `usdchf-nzdusd`, reserve the next deterministic EA
ID, register only the two traded magic slots, build a fixed-beta D1 basket with
`basket_manifest.json` and `RISK_FIXED=1000` backtest presets, pass strict Q01,
and enqueue exactly one logical-basket Q02 row. Do not launch a manual tester.

No portfolio admission/contribution path or `T_Live` manifest was changed.

## 20:04Z paced-fleet continuation audit

A fresh path-anchored process sample at `2026-08-05T20:04:29Z` found seven
factory terminals running:

```text
T1, T2, T3, T4, T5, T8, T9
```

Seven equals the binding seven-terminal backtest ceiling. `T_Live` and other
non-factory terminals were excluded from the count and were not controlled.
A repeated exact duplicate guard still found zero matching EA directories,
Strategy Cards, EA-registry rows, or two-leg basket manifests for
`USDCHF.DWX` / `NZDUSD.DWX`.

The rank-55 candidate therefore remains the next unbuilt pair, but capacity
has not cleared. Per the mission stop rule, this continuation made no Card or
source change, ID or magic allocation, compile, queue mutation, dispatch,
tester launch, terminal-control action, AutoTrading action, live artifact, or
portfolio-gate change.
