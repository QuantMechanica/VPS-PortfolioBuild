# QM5_20240 FX cointegration Q04 CPU-ceiling stop

Date: 2026-08-31 UTC (`2026-08-31T19:47:58.4981316Z`); 21:47
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `5ae456a6c53154cc5212596b8f137eec83960dad`

Status: the frozen 66-pair frontier remains fully mechanized, the sole
nonterminal FX continuation remains one priority-bound Q04 row, and the
explicit 97% backtest CPU ceiling is binding. No Card, EA, queue row, payload,
claim, tester, terminal, or portfolio object was created or changed.

## Non-duplicate reconciliation

The controlling research remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion selected only `QM5_12532` AUDUSD/NZDUSD and `QM5_12533`
EURJPY/GBPJPY. Both anchors already have canonical Q02 PASS and neither is
blocked by `ONINIT` or `NO_HISTORY`; their later chains end at Q05 FAIL and
Q04 FAIL, respectively.

The committed sign-aware coverage audit accounts for all 66 frozen
relationships. A fresh case-insensitive approved-card census found 123
cointegration/coint EA identities, 123 matching EA directories, and zero
unbuilt identities. Creating a Card, EA, basket manifest, magic allocation,
or Q02 row would therefore duplicate governed work. The Card-extraction and
EA-build gates remained closed, and the authorized existing-forex fallback
applied.

## Existing forex fallback

The exact continuation is frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. Its approved Tier-A Chan-backed
Card, structural fixed-beta D1 implementation, compiled basket, manifest, and
logical setfile already exist. The setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; there is no learned model, banned
indicator, beta refit, rescue filter, grid, or martingale.

Its canonical lineage is unchanged:

| Phase | Work item | State |
|---|---|---|
| Q02 | `24154a28-be35-469e-a5be-58881e29733c` | done / PASS |
| Q03 | `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` | done / PASS |
| Q04 | `85e98029-14f6-4f73-a991-b814d4f3c151` | pending, priority-bound, unclaimed, attempt 0 |

The Q04 payload SHA-256 remains
`855dcffd54c7e28ec66576fbc43b5ce419011b59ce45338191ab9571c30aa14b`.
There is already exactly one intended successor, so no duplicate enqueue or
payload restamp was performed.

## Binding capacity stop

The mandatory five-sample host window was `97%`, `86%`, `97%`, `94%`, and
`94%`: average `93.6%`, maximum `97.0%`. The stop rule binds when either
measure is at least 97%; the maximum therefore triggered the explicit CPU
ceiling.

The serialized multisymbol lane is also occupied by the active governed
`QM5_20294_XAU_XAG_LOWMAX_D1` Q03 work item
`9437109a-799b-4f29-a501-89e6b4a3809c` on T8. Starting or claiming
`QM5_20240` concurrently would violate basket pacing. The mission stopped
before any queue mutation, claim, dispatch tick, reservation, tester launch,
compile, smoke test, backtest, or terminal control.

## Safety and resume contract

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- Existing unrelated staged and unstaged worktree changes were preserved and
  excluded from this receipt.

After a fresh five-sample window has both average and maximum strictly below
97% and the multisymbol lane is clear, let the resident paced worker claim the
existing Q04 row. Do not enqueue a duplicate or manually force a second
basket.

Machine-readable evidence is
`artifacts/qm5_20240_q04_cpu_ceiling_stop_20260831T194758Z_board_advisor.json`.
