# QM5_10718 logical FX8 Q02 hard-CPU stop

Date: 2026-09-02 UTC (`2026-09-02T08:21:43.8220014Z`); 10:21
Europe/Berlin

Branch: `agents/board-advisor`

Status: stopped at the mission's explicit 97% host-CPU ceiling. The selected
existing forex fallback already has exactly one hash-bound, priority Q02 row,
so no duplicate row, tester, terminal, or queue mutation was created.

## Non-duplicate decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 study tested all
66 FX relationships and published only two hard qualifiers. Both are built and
beyond Q02:

| EA | Relationship | Canonical frontier |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The latest
complete reconciliation records 123 approved cointegration/coint identities,
123 matching EA directories, zero unbuilt identities, and all 66 scan
relationships accounted for. Another scan-derived Card, basket manifest, EA,
or Q02 row would duplicate governed work, so the Card-extraction and EA-build
gates remained closed.

## Existing forex fallback

The mission's fallback clause resolves to the already-approved
`QM5_10718_edgelab-regime-filtered-carry`. It is a structural, weekly
rebalanced D1 market-neutral FX8 carry basket backed by Lustig, Roussanov, and
Verdelhan (RFS 2011) and Menkhoff et al. (JF 2012). The Card and implementation
use no learned model, grid, martingale, or banned indicator.

The current package remains hash-stable:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `92fa06a272aa4805e31c6caac4f1ad9feeaf91fec18c349a616bf2cae00f8f00` |
| EX5 | `10358a8dd852cd495265fc4099dfb7d9fecc711a047d98a4ff5eafbba51a91cc` |
| Basket manifest | `8dc0776c1aac52f566b0f0b33f390f34d222bae8bc20992f7740bcce5d0b458f` |
| Logical setfile | `cbc4602cc7685d7db68e9e17603916e4b66706ba9566248bf975c2a4782bd680` |

The logical preset remains `RISK_FIXED=500`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Exact Q02 work item `31f12573-d903-4386-a857-cad2b445d63a` remains pending,
unclaimed, attempt zero, unverdict, `portfolio_scope=basket`, and
`priority_track=true`. Its MQ5, EX5, and setfile bindings match the current
files. Exactly one pending/active row exists for
`QM5_10718_FX8_BASKET_D1`; appending another would be a duplicate. The earlier
priority handoff is
`docs/research/FX_QM5_10718_LOGICAL_Q02_PRIORITY_HANDOFF_20260902T033638Z.md`.

## Binding capacity result

Five one-second whole-host CPU samples were `97.465432%`, `89.483766%`,
`93.657495%`, `95.612021%`, and `92.105415%`. Average CPU was `93.664826%`
and maximum CPU was `97.465432%`. The governed ceiling binds when either
measure reaches 97%; the maximum triggered the requested stop.

The path-aware factory snapshot found active terminal processes on T2, T3,
and T10, six active work items, and no active basket work item. T_Live and the
external FTMO terminal were observed only to exclude them and were not
controlled. The absence of an active basket lane does not override the hard
host-CPU ceiling.

## Safety and continuation

- No Card, EA source, EX5, setfile, manifest, registry, magic row, work item,
  queue payload, claim, status, priority, or verdict changed.
- No backtest, tester, manual MT5 launch, terminal control, or worker control
  was attempted.
- No portfolio admission, portfolio KPI, Q08 contribution, portfolio gate,
  T_Live manifest, live/deploy artifact, or AutoTrading state changed.
- Unrelated staged, unstaged, and untracked shared-worktree changes were
  preserved and excluded from this handoff.

After a fresh five-sample CPU window has both average and maximum strictly
below 97%, leave the existing exact priority Q02 row for the resident paced
worker. Do not enqueue a duplicate or manually launch MT5.

Machine-readable evidence:
`artifacts/qm5_10718_logical_q02_hard_cpu_stop_20260902T082143Z_board_advisor.json`.
