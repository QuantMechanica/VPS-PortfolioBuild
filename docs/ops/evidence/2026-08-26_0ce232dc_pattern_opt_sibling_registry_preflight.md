# DL-089 pattern `_opt` sibling build preflight — task `0ce232dc`

- Date: 2026-08-26
- Router task: `0ce232dc-d56b-4bce-af96-8cc436bd6d85`
- Canonical checkout: `C:/QM/repo`
- Branch: `agents/board-advisor`
- Verdict: `REVIEW_BLOCKED_REGISTRY_PREFLIGHT`

## Outcome

The three parent cards and their existing parent identities are valid, but no
governed identities or magic rows exist for the required new `_opt` siblings.
The `qm-build-ea-from-card` preflight therefore stops before implementation:
Development may not invent or allocate an EA ID or magic row.

No parent source, parent binary, parent setfile, registry, resolver, terminal,
work item, or pipeline verdict was changed. No compile was attempted, because a
compile before deterministic sibling allocation would not be valid build
evidence.

## Parent preflight

| Parent | Approved card | EA registry | Required parent symbol magic |
|---|---|---|---|
| `QM5_10706_tv-mon-ls` | `g0_status: APPROVED` | active, exact slug | `GBPUSD.DWX`, slot 1, magic `107060001`, active |
| `QM5_11421_ohlc-daily-squeeze-reversal-d1` | `g0_status: APPROVED` | active, exact slug | `EURUSD.DWX`, slot 0, magic `114210000`, active |
| `QM5_11422_williams-18ma-outside-bar-entry-d1` | `g0_status: APPROVED` | active, exact slug | `USDCAD.DWX`, slot 4, magic `114220004`, active |

Approved cards of record:

- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10706_tv-mon-ls.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11421_ohlc-daily-squeeze-reversal-d1.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11422_williams-18ma-outside-bar-entry-d1.md`

The canonical EA registry has no exact row for the conventional sibling slugs
`tv-mon-ls-opt`, `ohlc-daily-squeeze-reversal-d1-opt`, or
`williams-18ma-outside-bar-entry-d1-opt`; the matching sibling directories are
also absent. Consequently there can be no valid `(sibling ea_id, symbol_slot)`
magic rows yet.

## Q12 binding and the 10706 header

The three append-only Q12 declarations remain pending and instrument-blocked:

| Parent pair | Q12 row | Current blocker |
|---|---|---|
| `QM5_10706 / GBPUSD.DWX` | `dfca24fa-28df-5f5e-818f-8dcf53611822` | `PATTERN_FILTER_INSTRUMENTATION_REQUIRED` |
| `QM5_11421 / EURUSD.DWX` | `d0e53004-659c-563c-8314-c24ad4ab2a68` | `PATTERN_FILTER_INSTRUMENTATION_REQUIRED` |
| `QM5_11422 / USDCAD.DWX` | `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` | `PATTERN_FILTER_INSTRUMENTATION_REQUIRED` |

The 10706 declaration authenticates an archived CRLF representation of the
parent Q10 setfile by SHA-256
`275e66e9e6151277ba180b4d7c3a786804a9a7346687dd034ee6d9c8d3e444ac`.
The current tracked parent file declares
`environment: q10_full_history_confirmation`, not the explicit
`environment: backtest` header required by `opt_census.py`. Editing the current
parent file would neither create the required sibling subject nor preserve the
intended append-only parent boundary. The header repair must therefore be made
in the future 10706 `_opt` sibling's canonical fixed-risk base setfile.

## Required governed continuation

The registry-writer lane must first allocate three distinct active sibling EA
identities, using the parent strategy lineage, then allocate the single required
active magic row for each target pair and regenerate `QM_MagicResolver.mqh`
without dropping rows. Once those identities are durable, the router can return
a build task that:

1. copies each parent mechanic without changing it;
2. adds exactly `opt_pp_buy1..3` and `opt_pp_sell1..3`;
3. wires `QM_PatternPermissionEvaluate` with symmetric BUY/SELL vetoes;
4. authors fixed-risk backtest sets (`RISK_FIXED > 0`, `RISK_PERCENT = 0`) with
   `qm_news_stale_max_hours <= 336`, including the explicit 10706 backtest
   environment header;
5. obtains governed `COMPILE_EA` receipts and clears each sibling's Q02
   prerequisite before any declared pattern matrix is materialized.

This preflight does not authorize a Q12 measurement, a pipeline verdict, live
deployment, T_Live, or AutoTrading.

## Focused verification

Read-only checks performed against the canonical checkout and farm state:

- parent approved-card frontmatter: all three `g0_status: APPROVED`;
- exact parent registry and target-symbol magic rows: present and active;
- proposed sibling registry rows/directories: absent;
- Q12 rows: all three `pending`, with the preserved instrumentation blocker;
- 10706 parent setfile: archived CRLF bytes authenticated by the Q12 payload;
  current tracked file lacks the required explicit backtest environment
  declaration;
- parent risk sets: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- existing pattern reference implementation:
  `QM5_41097_balke-gmt3-range-breakout-opt` carries the six-input/profile wiring
  pattern, but its allocated identity and strategy lineage cannot be reused.
