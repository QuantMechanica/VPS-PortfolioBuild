# QM5_20224 FX cointegration Q03 multisymbol/RAM handoff

Date: 2026-08-29 UTC (`2026-08-29T15:32:42Z`); 17:32 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `37743dca2135955f92647c7c31de976cfed584c7`

Status: the existing EURUSD/EURJPY logical basket remains advanced exactly
once at Q03. A legitimate active multisymbol run occupies the serialized
basket lane, and free physical RAM is below the governed multisymbol admission
floor. No duplicate Card, EA, work item, queue-priority mutation, claim,
tester, or terminal action was taken.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 hard
criterion selected only two relationships from the 66-pair scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current logical-basket Q02 `ONINIT` or `NO_HISTORY`
blocker. Historical invalid per-leg rows do not supersede the later canonical
logical-basket Q02 PASS rows.

The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered. The preceding fresh
broader census found 119 approved Cards containing `cointegration` or `coint`,
119 unique EA IDs, and a matching EA directory for every Card. A new Card or
EA would therefore duplicate governed coverage. The card-extraction and EA-build
skill gates remain closed.

## Selected existing sleeve

The concrete fallback is scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only. Its approved evidence is deliberately adverse (DEV
net Sharpe `0.473267`, OOS net Sharpe `-0.118543`, OOS return `-1.026394%`,
17 OOS state changes, and a `137.788`-D1-bar half-life), so this remains a
one-shot pipeline falsification with no refit or rescue.

The sealed package was reverified:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Card schema/ML lint passed with no ML hits. The logical setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the Card and EA
remain structural, deterministic, low-frequency, and free of ML, adaptive
refit, banned indicators, grid, martingale, or portfolio feedback.

## Exact queue state

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: `done / PASS`.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed, attempt
  zero, no verdict, with `priority_track=true` and reason
  `board_advisor_fx_fallback_rank46_q03` from commit `7a4697a0f`.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  promoted ahead of Q03.

Exactly one matching open Q03 row exists. It has no active hold, supersede
relation, or active poison-pill quarantine. Re-enqueueing Q02/Q03 or rewriting
the same priority payload would be duplicate work, so neither occurred.

## Binding paced-fleet state

At `2026-08-29T15:32:42Z`, the sole active multisymbol row was
`QM5_20206_XAU_XAG_MOMIVOL_D1` Q04, work item
`ddad91a7-f1d1-4a06-a9bf-e82e1ec9558a`, claimed by T3 at
`2026-08-29T15:25:02Z` and started at `2026-08-29T15:29:44Z`. Its governed
timeout is 1,275 minutes. The worker contract serializes multisymbol loads, so
the FX Q03 row cannot be claimed concurrently.

The five one-second whole-host CPU samples at `2026-08-29T15:30:57Z` were
`49.932651%`, `51.691888%`, `52.934523%`, `33.307683%`, and `30.908918%`.
Average CPU was `43.755133%` and maximum CPU was `52.934523%`, both below the
explicit `97%` ceiling. CPU was therefore not the stop condition.

Free physical RAM was `9.611 GB`, below the governed `12 GB` multisymbol
admission floor. System commit headroom was `61.472 GB`, above the `48 GB`
multisymbol commit floor. The binding conditions were the occupied serialized
basket lane and physical-RAM guard. Bypassing either would violate paced-fleet
admission, so no manual dispatch was attempted.

## Non-duplicate delta and safety boundary

This is new state relative to the Q03 priority receipt in `7a4697a0f`: the
priority mutation is already durable, its then-active `QM5_20294` basket is no
longer the lane occupant, `QM5_20206` now holds that lane, and current free RAM
is below the multisymbol floor. This handoff records the valid reason the
already-advanced FX row remains pending; it does not manufacture another row
or verdict.

No Card, EA source, EX5, setfile, basket manifest, registry, magic row,
resolver, queue row, priority, claim, status, verdict, reservation, worker,
terminal, smoke, or backtest was created or changed. The portfolio gate,
`portfolio_admission`, `_kpi`, `_q08_contribution`, T_Live, AutoTrading, and
live/deploy manifests were untouched. Existing unrelated shared-worktree
changes were preserved and excluded from this commit.

Machine-readable evidence:
`artifacts/qm5_20224_q03_multisymbol_ram_handoff_20260829T153242Z_board_advisor.json`.

## Continuation condition

Allow the active multisymbol row to reach a canonical terminal state. On a
later paced wake, take a fresh CPU/RAM/commit window and let the resident worker
claim the existing exact Q03 row only if the basket lane is clear and all
admission guards pass. Do not enqueue another Q02/Q03 row, manually dispatch a
terminal, or prioritize Q04 ahead of its Q03 dependency.
