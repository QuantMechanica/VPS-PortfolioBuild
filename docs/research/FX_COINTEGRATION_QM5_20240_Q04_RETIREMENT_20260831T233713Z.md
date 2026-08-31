# QM5_20240 FX cointegration Q04 retirement

Date: 2026-08-31 UTC (`2026-08-31T23:37:13Z`); 2026-09-01 01:37
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `0413d829a3817b0501c7896b12bd8d62c1541340`

Status: the last dependency-correct relationship-level FX continuation from
the frozen 66-pair scan completed Q04 with an authenticated economic `FAIL`.
The exact USDCHF/GBPJPY sleeve is retired without refit or rescue. No new
Card, EA, queue row, tester, terminal, or downstream phase was created.

## Non-duplicate frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 FX relationships. The durable sign-aware audit accounts for all 66, and a
fresh case-insensitive repo census found 123 approved cointegration/coint EA
identities, 123 matching EA directories, and no unbuilt identity.

The preferred anchors remain past Q02:

| EA | Pair | Canonical chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither has a current Q02 `ONINIT` or `NO_HISTORY` blocker. Creating another
scan-derived Card, basket manifest, EA, magic allocation, or Q02 row would be
duplicate work, so the Strategy Card extraction and EA-build gates remain
closed.

## Existing forex sleeve reached a terminal verdict

The concrete fallback is frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. It trades `USDCHF.DWX` and
`GBPJPY.DWX`; `USDJPY.DWX` supplies conversion history only. Its approved
Tier-A Chan-backed Card and sealed implementation remain structural,
fixed-beta, D1, low-frequency, and learned-model-free. The logical backtest
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The dependency-correct lineage is now terminal:

| Phase | Work item | State |
|---|---|---|
| Q02 | `24154a28-be35-469e-a5be-58881e29733c` | done / PASS |
| Q03 | `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` | done / PASS |
| Q04 | `85e98029-14f6-4f73-a991-b814d4f3c151` | done / **FAIL** |

All three Q04 folds produced substantive native reports:

| Fold | Net PF | Trades | Result |
|---|---:|---:|---|
| F1 | 0.561 | 38 | below floor |
| F2 | 1.003 | 40 | complete |
| F3 | 0.478 | 16 | below floor |

The canonical reason is
`F1:pf_net=0.561;F2:pf_net=1.003;F3:pf_net=0.478`. This is an economic
walk-forward failure, not an initialization, history, or zero-trade setup
defect. The aggregate is:

`D:/QM/reports/pipeline/QM5_20240/Q04/QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1__85e98029-14f6-4f73-a991-b814d4f3c151/aggregate.json`

Its SHA-256 is
`eb0c0f91fe602357e7e7b74a120c06802888c279afd7bf9b75e6c4249ab651ed`.
There is no Q05 successor. The Card's one-shot falsification boundary requires
retirement without beta refit, threshold tuning, added filter, pair
substitution, or append-only rerun.

## Continuation and capacity reconciliation

No lower-ranked governed relationship can advance:

- rank 60 `QM5_20246` USDJPY/EURGBP is terminal at Q04 `FAIL`;
- rank 61 `QM5_20250` USDCHF/AUDJPY is terminal at Q03 `FAIL`;
- the rank-58 `QM5_1257` GBPUSD/USDJPY umbrella identity is terminal at Q04
  `FAIL`; and
- the rank-65 `QM5_1156` USDCHF/AUDUSD umbrella identity is terminal at Q02
  `FAIL`.

A fresh five-sample whole-host CPU window was `48.859188%`, `42.504121%`,
`43.267921%`, `49.444590%`, and `49.517197%`: average `46.718603%`, maximum
`49.517197%`, both below the explicit 97% ceiling. CPU was not binding.
The serialized multisymbol lane was independently occupied by
`QM5_20161_XAUUSD_XAGUSD_OLS_D1` Q03 work item
`11cbafc9-5452-45d6-8a11-a81bc33473c1` on T8. More importantly, no valid FX
successor remains to enqueue or claim.

Static revalidation passed: Strategy Card schema lint returned no missing
sections or ML hits, and the basket manifest/work-item regression suite passed
65/65 tests. The Card, MQ5, EX5, manifest, and logical setfile stayed
hash-stable.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- No Strategy Card, EA source, EX5, basket manifest, setfile, registry, magic
  row, work item, payload, priority, claim, status, or historical verdict was
  mutated by this receipt.
- Pre-existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this commit.

Machine-readable evidence is
`artifacts/qm5_20240_q04_retirement_20260831T233713Z_board_advisor.json`.
