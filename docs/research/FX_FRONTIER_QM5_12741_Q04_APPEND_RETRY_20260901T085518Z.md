# FX frontier: QM5_12741 append-only Q04 continuation

Date: 2026-09-01 UTC (`2026-09-01T08:55:55Z`); 10:55
Europe/Berlin

Branch: `agents/board-advisor`

Status: one existing low-frequency FX basket has been advanced through the
funnel with a hash-bound append-only Q04 retry. The row is pending for normal
paced-fleet dispatch.

## Outcome

No new pair Card or EA was created. The controlling reputable-source record,
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, has no unbuilt
relationship left: the latest durable census records 123 approved
cointegration/coint identities, 123 matching EA directories, and zero unbuilt
identities. The requested anchors are already past Q02:

| EA | Pair | Canonical chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. Creating a
new scan-derived Card, basket manifest, allocation, build, or Q02 row would be
duplicate work.

The mission's existing-card fallback was therefore applied to
`QM5_12741_nnfx-fx-basket-pooled`. This is an existing OWNER-approved,
closed-bar D1 pooled FX trend sleeve, not a new cointegration performance
claim. Its four members are `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, and
`USDCHF.DWX`; `AUDUSD.DWX` is the D1 host. The checked-in logical setfile
remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The
Card records fixed legal indicators, no ML, no online refit, no grid, and no
martingale, with about three trades per member per year.

## Exact funnel advancement

The immutable predecessor chain was:

| Phase | Work item | State | Verdict |
|---|---|---|---|
| Q02 | `cab41d73-7573-4648-b58d-ce9fa6df26b3` | done | PASS |
| Q03 | `bf4f1a14-2d2f-4caf-9d94-8076560d8b8d` | done | PASS |
| Q04 | `fc9e29f1-9729-478f-96fb-dd7dcdb5978d` | done | INFRA_FAIL |

The historical Q04 failure is infrastructure-only and confined to fold F3:
`BARS_ZERO`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`, `HISTORY_CONTEXT_INVALID`,
`INCOMPLETE_RUNS`, `M0_1970_PERIOD`, `NO_HISTORY`, and
`RUN_STATUS_INVALID`. There was no strategy verdict, open Q04 row,
append-only descendant, or Q05 successor.

After exact duplicate reconciliation, canonical `farmctl enqueue-backtest`
created one row:

| Field | Value |
|---|---|
| work item | `4776406a-a34e-4867-983c-8f3b420e9e92` |
| phase / status | Q04 / pending |
| predecessor | `bf4f1a14-2d2f-4caf-9d94-8076560d8b8d` |
| append-only target | `fc9e29f1-9729-478f-96fb-dd7dcdb5978d` |
| gate contract | v4 |
| timeout | 316 minutes |
| MT5 identity | `AUDUSD.DWX`, D1, `QM\\QM5_12741_nnfx-fx-basket-pooled` |

The historical Q04 row remains `done / INFRA_FAIL`. Post-enqueue state has
exactly one open Q04 row and exactly one descendant of that historical row.

The new row binds the current artifacts:

| Artifact | SHA-256 |
|---|---|
| EX5 | `47c92e1a7f3ba5ef3578f11065368d581b1f7385768eb716371a95b5b57853be` |
| MQ5 | `72bea21c0237c38f79053148515e12d33c8b806483c16b30e23cc19cb5e8157f` |
| logical setfile | `1d6cc31f683f27598a4a8a31d960a2c2a43fff0b394dc9280dff2e1fb30f0c51` |
| basket manifest | `c4e3e1629364122d7f267e8ee911f3e9b36718a9aebbb3487c2afd385c22119d` |

All four members are admitted by the active OWNER-approved custom-history
archive manifest, with 432 selected archive rows.

## Resource and dispatch discipline

The immediate five-sample preflight CPU window was `92.481259%`,
`86.670332%`, `93.074082%`, `85.953019%`, and `89.264302%`: average
`89.488599%`, maximum `93.074082%`. A post-enqueue window averaged
`85.568809%` and peaked at `88.706566%`. Neither observation reached the
explicit 97% ceiling.

Before the mutation, an online SQLite backup passed `integrity_check` at:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12741_q04_append_retry_20260901T085518Z.sqlite`

Its SHA-256 is
`6368286688696a5711b75ce700bc3155526ffd96ec4350784c715c8f333cf495`.

No manual dispatch, tester, terminal reservation, or terminal control was
started. The serialized multisymbol lane remained occupied by
`QM5_20233_XAU_XAG_SKEW_RANK_D1` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427` on T8, so the target row correctly
remained pending for normal workers.

## Validation and safety

The append-only, current-binding, Q04 history-clamp, and FX basket regression
selection passed 52/52 tests. A non-compiling `build_check` invocation was
refused by its live-factory safety guard because terminal processes were
active; no compile or retry followed. The MQ5, EX5, setfile, and manifest
hashes remain identical to the prior hash-stable build validation recorded in
`docs/ops/evidence/2026-08-17_qm5_12741_q04_append_retry_cpu_stop_182604Z.md`.

- No portfolio-admission, portfolio-KPI, Q08-contribution, or other portfolio
  gate surface changed.
- No T_Live manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- No Card, EA source, EX5, setfile, basket manifest, registry, magic row,
  historical verdict, claim, or priority was changed.
- Pre-existing unrelated staged, unstaged, and untracked worktree changes are
  excluded from this evidence commit.

Machine-readable evidence is
`artifacts/qm5_12741_q04_append_retry_20260901T085518Z_board_advisor.json`.
