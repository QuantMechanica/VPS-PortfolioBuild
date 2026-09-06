# G0 Decision — QM5_41365 XTI/XNG Weekly Decoupling-Shock Reversion

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41365_xtixng-decouple-rv`
- Strategy ID: `AI-CODEX-XTIXNG-DECOUPLE-RV-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41365_xtixng-decouple-rv_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_weekly_decoupling_shock_reversion_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_DECOUPLING_TRANSLATION_RISK`: complete U.S. government and
  peer-reviewed oil/gas evidence, including adverse instability; the weekly
  opposite-direction fade is an explicitly untested QM translation.
- R2 `PASS`: synchronized consecutive completed weeks, three-to-five-session
  bounds, individual returns, strict opposite signs, loser-long/winner-short
  sides, weekly attempt, aggregate risk, hard stops, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data provides every required runtime input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,845 registry rows and 1,458 repository cards and
found no exact or above-threshold fuzzy identity. The external Strategy Wiki
root was unavailable, so the tool retained its fail-closed input verdict; the
current direct OWNER mission accepts only the documented repository scopes.

`QM5_41361` requires same-sign individual weekly returns and fades their
relative dispersion. `QM5_12840` fits a rolling return-spread z-score and exits
at its fitted mean. `QM5_41358` and `QM5_41360` classify two adjacent oil/gas
ratio returns. Monthly and eighteen-month reversal systems consume different
clocks and state. This card alone requires one individual completed-week return
per leg, strict opposite signs, both moves reversed, and a fixed next-week exit.

Verdict:
`REPOSITORY_SCOPES_CLEAN_DISTINCT_XTIXNG_OPPOSITE_DIRECTION_WEEKLY_DECOUPLING_LOSER_LONG_WINNER_SHORT_BASKET`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both five-sample CPU average and
maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
