# FX cointegration frontier: Q03 progression / hard CPU stop

Date: 2026-08-27 UTC (`2026-08-27T01:17:32Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `91f77dca2b7b67197c90a91ae413359d5d65530a`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; one existing FX basket newly reached Q03
PASS but already has its unique Q04 successor pending; stopped at the explicit
hard CPU ceiling

## Frontier and anchor decision

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. The published scan's only strict survivors are already built as
`QM5_12533` and `QM5_12532`. A new scan-derived Strategy Card or EA would
duplicate governed work or relax the reputable-source threshold.

Fresh supported `farmctl work-items --ea` queries confirm that the requested
anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has a current `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Concrete existing-pair fallback

`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1` is the concrete existing
low-frequency fallback for this observation. Its Q02 work item
`ca72ac7d-162c-4c54-b2e4-d7765c15efeb` remains terminal PASS. Its Q03 work
item `73d11c4c-0542-4828-9631-1954799a87a5`, observed active in the preceding
FX receipt, completed PASS at `2026-08-27T00:47:35Z`. Its sole Q04 successor
`bfad4436-ae19-4b7d-a7cf-1c02a0324d67` is already pending, so inserting
another Q02, Q03, or Q04 row would be duplicate work.

The unchanged build satisfies the mission constraints: its APPROVED card cites
the OWNER-ratified Tier-A Chan source; its mechanics are deterministic,
fixed-beta, learned-model-free, and low-frequency D1; it has a
`basket_manifest.json`; and its logical backtest setfile contains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T01:17:06Z`
observed three governed factory terminals actively testing: T1, T6, and T7.
All ten terminal-worker daemons were alive, five terminal reservations were
active, and no orphaned factory terminal process was reported. The paced
launch gate remained `1`. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them; neither was controlled.

Five fresh whole-host CPU readings ending at `2026-08-27T01:17:32Z` were
97.07%, 95.58%, 96.78%, 96.29%, and 94.63%. Their average was 96.07% and their
maximum was 97.07%. The binding rule applies when either the average or
maximum reaches 97%; the maximum therefore triggered the mission's immediate
stop condition.

No Card, EA, registry, magic, compile, build check, queue, priority, dispatch,
reservation, terminal, tester, or backtest mutation followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T011732Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-27T00:16:33Z` observed six running
factory terminals and 100% average CPU while QM5_20232 Q03 was active. This
receipt records three running factory terminals, a lower 96.07% average with a
still-binding 97.07% maximum, and the subsequent terminal Q03 PASS plus the
already-existing Q04 successor. It is changed governed evidence, not a
repeated queue insert.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
