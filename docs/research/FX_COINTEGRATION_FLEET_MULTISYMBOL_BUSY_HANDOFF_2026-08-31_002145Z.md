# FX cointegration fleet — active multisymbol handoff

Date: 2026-08-31 UTC (`2026-08-31T00:21:45Z`); 02:21 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `2c6b9124b41e42f10154f5e5579fe2dfbed69189`

Status: the frozen 66-pair frontier remains exhausted; the selected existing
FX fallback is already queued exactly once, and a valid FX basket occupies the
serialized multisymbol lane.

## Governed frontier result

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 FX relationships and admitted only two under the published
criterion of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades:

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor is blocked at Q02 by `ONINIT` or `NO_HISTORY`. The durable
sign-aware reconciliation accounts for all 66 relationships, and the latest
approved-card census has 120 cointegration identities with 120 matching EA
directories and no unbuilt identity. Since the preceding receipt, the only
cointegration-path delta is an automatically generated Q06 stress setfile for
the already-built `QM5_20224` predecessor. Creating another Card, EA, or Q02
identity would duplicate governed work.

## Existing forex fallback

The next dependency-correct relationship is frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. Its Tier-A Chan-backed approved
Card, compiled basket, manifest, and logical backtest setfile remain sealed to
the same hashes as the Q02 PASS predecessor. The strategy is structural D1
fixed-beta residual reversion with no learned model, adaptive refit, banned
indicator, grid, or martingale. Its backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Fresh validation produced:

- Strategy Card schema lint: PASS, with no ML hits or missing sections.
- Basket-manifest regression suite: 47 PASS in 1.79 seconds.
- Card SHA-256: `39cd0f4bd4a0955a6c546f781b7ba0a00c3e0782048c676cccfd9025bebf9f52`.
- MQ5 SHA-256: `14ae487325f04537625eab787361b12587f483f812357c941efca54908624aff`.
- EX5 SHA-256: `dbf718900fbfdd35558e87fce20415329e8438f9cb7e5d1395734a1d0d7457b0`.
- Manifest SHA-256: `18d6f9b0c3576f27045143752405accece5faf353213610d3de1b3ead067bcc4`.
- Setfile SHA-256: `ff1801ce59cb15a2cb0b24fdfb350ddc4539dd456130720307913542a4cde641`.

The exact Q03 row `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` remains pending,
unclaimed, attempt zero, v4, priority-tracked, and canonical rank 1,544. It is
the only open exact Q03 identity and has no hold, supersession, or active
quarantine. Its predecessor `24154a28-be35-469e-a5be-58881e29733c` is Q02
PASS. The existing Q04 row remains untouched and must not advance before Q03
PASS.

## Binding serialized-lane condition

The preceding receipt observed `QM5_20224` active at Q06. That phase has now
finished PASS, and the same basket advanced to Q07 as work item
`9ba93eb9-4973-4759-9efa-f7ff224f1494` on T3. The tester was visibly making
progress at 26% of its first multiseed run. It is a valid active claim, so
starting or claiming a second multisymbol row would violate the paced basket
serialization contract.

The final five one-second CPU samples were `96.974496%`, `95.327048%`,
`94.629492%`, `93.363383%`, and `92.785013%`. Average CPU was `94.615886%`
and maximum CPU was `96.974496%`. Both remain strictly below the 97% hard
ceiling, though the maximum is close. The stop condition for this wake is the
occupied multisymbol lane, not the CPU ceiling.

## Non-duplicate work and continuation

This receipt captures a material state change from the preceding hard-CPU
stop: `QM5_20224` moved from Q06 active to Q06 PASS and Q07 active, the CPU
ceiling cleared, and the selected `QM5_20240` Q03 row improved from canonical
rank 1,562 to 1,544. No duplicate work item or speculative build was created.

No Card, EA source, EX5, setfile, basket manifest, registry, magic row, queue
row, payload, priority, claim, status, verdict, reservation, worker, terminal,
compile, smoke test, or backtest was created or changed. The portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, T_Live manifest,
AutoTrading, and all live/deploy manifests were untouched. Unrelated shared
worktree changes were preserved and excluded from the commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_multisymbol_busy_handoff_20260831T002145Z_board_advisor.json`.

On the next paced wake, first require terminal state for `QM5_20224` Q07 and
no other active multisymbol row, then take a fresh five-sample CPU window. If
both CPU measures remain strictly below 97%, allow the resident worker to
claim the unique existing `QM5_20240` Q03 row. Never enqueue a duplicate,
never advance its Q04 row before Q03 PASS, and keep rank-60 `QM5_20246` behind
rank-59 `QM5_20240`.
