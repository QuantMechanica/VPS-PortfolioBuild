# FX cointegration frontier: six-terminal hard CPU stop

Date: 2026-08-27 UTC (`2026-08-27T00:16:33Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d7f1ffa9b7a1424c97a9ff434c146b307f21613d`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; the selected existing FX fallback already
has one Q04 successor pending; stopped at the explicit hard CPU ceiling

## Frontier and anchor decision

The sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for every relationship produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. The published scan's only strict survivors are already built as
`QM5_12533` and `QM5_12532`. A new scan-derived Strategy Card or EA would
duplicate governed work or relax the published threshold.

Fresh supported `farmctl work-items --ea` queries confirm that the requested
anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has a current `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Existing-pair fallback

`QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1` remains the selected structural D1
fallback. Its Q02 work item `61e7d1af-35a2-48f4-8602-afcf94949118` and Q03
work item `2e797aa8-42ef-479e-875f-da93436ca528` are terminal PASS. Its sole
Q04 successor `0961cfd5-4831-4ef9-bf5b-cab4bfcab089` remains pending, so
inserting another Q02, Q03, or Q04 row would be duplicate work.

The unchanged build satisfies the mission constraints: the Strategy Card is
APPROVED and cites OWNER-ratified Tier-A Chan source material; the mechanics
are deterministic, fixed-beta, no-ML, and low-frequency D1; the basket has a
`basket_manifest.json`; and its logical backtest setfile contains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T00:16:08Z`
observed six governed factory terminals actively testing: T1, T2, T4, T7,
T8, and T9. All ten terminal-worker daemons were alive, six terminal
reservations were active, and no orphaned factory terminal process was
reported. The paced launch gate remained `1`. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them; neither was controlled.

T9 was already advancing the separate existing FX basket
`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1` at Q03 under work item
`73d11c4c-0542-4828-9631-1954799a87a5`. No competing or duplicate work was
inserted.

Three sequential whole-host CPU readings from `00:16:25Z` through
`00:16:33Z` were 100%, 100%, and 100%. Their average and maximum were both
100%. The binding rule applies when either the average or maximum reaches
97%; both triggered the mission's immediate stop condition.

No Card, EA, registry, magic, compile, build check, queue, priority, dispatch,
reservation, terminal, tester, or backtest mutation followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T001633Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-26T23:31:20Z` observed five running
factory terminals. This receipt records the later six-terminal state at 100%
CPU, observes an existing FX cointegration Q03 already active on T9, and
confirms that the same QM5_20220 Q04 successor remains pending. It is a
changed governed-capacity observation, not a repeated queue insert.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from
  this receipt.
