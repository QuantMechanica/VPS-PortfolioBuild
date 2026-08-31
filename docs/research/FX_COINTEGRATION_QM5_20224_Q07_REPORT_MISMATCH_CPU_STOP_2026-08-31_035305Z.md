# FX cointegration fleet — QM5_20224 Q07 report mismatch / hard CPU stop

Date: 2026-08-31 UTC (`2026-08-31T03:53:05Z`); 05:53 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d50d5f559d9c608a0b4ff738688ecc1914e537ce`

Status: the frozen 66-pair frontier remains fully mechanized, the preferred
anchors remain past Q02, and the most advanced existing FX fallback now has a
hash-bound Q07 harness failure rather than a genuine zero-trade result. The
explicit CPU ceiling bound before an append-only recovery could be enqueued.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 FX relationships and admitted only `QM5_12533` EURJPY/GBPJPY and
`QM5_12532` AUDUSD/NZDUSD under the published survivor criterion. The durable
sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. A fresh approved-card census found 120
files containing `cointegr` or `cointpair`; after normalizing the four numeric
`ea_id` spellings, all 120 identities have matching EA directories. There is
no approved unbuilt identity.

Neither preferred anchor has the Q02 blocker named by the mission:

| EA | Current canonical chain |
|---|---|
| `QM5_12532` | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | Q02 PASS; Q04 FAIL |

Creating another Card, registry allocation, EA, manifest, or Q02 row would be
duplicate work. The card-extraction and EA-build skill gates therefore remain
closed.

## Existing FX fallback selected

The selected concrete fallback is frozen-scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. Its canonical chain is Q02 PASS,
Q03 PASS, Q04 PASS_SOFT, Q05 PASS, and Q06 PASS. Q07 work item
`9ba93eb9-4973-4759-9efa-f7ff224f1494` completed at
`2026-08-31T03:36:55Z` as `INFRA_FAIL` with reason
`seed_zero_trades_outlier:seeds=[2026]:median=182:floor=20`.

The four sound seed reports are internally consistent:

| Seed | PF | Trades | Drawdown | Net profit |
|---:|---:|---:|---:|---:|
| 42 | 1.08 | 185 | 3,251.45 | 1,366.29 |
| 17 | 1.40 | 182 | 2,719.90 | 6,280.09 |
| 99 | 1.26 | 187 | 2,790.60 | 4,375.35 |
| 7 | 1.35 | 182 | 2,741.71 | 5,734.54 |

The sealed implementation remains a structural, fixed-beta, learned-model-free
D1 basket. Its logical setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Card schema lint passed with no ML hits or missing
sections, and the FX basket-manifest regression suite passed 47/47 tests.

## Seed-2026 zero-trade recovery classification

The first failed layer is the tester/report harness, not setup, entry logic, or
economics:

- `summary.json` and the 32,378-byte MT5 report say `Total Trades: 0`.
- The same bound agent log contains 208 successful `deal #... done` records,
  an `INIT_OK`, synchronized EURUSD/EURJPY/USDJPY history, a real-tick marker,
  and no ONINIT failure.
- The same structured logger contains 55 `ENTRY_ACCEPTED`, 49
  `BASKET_ORDER_ACCEPTED`, 69 `TM_OPEN`, and 158 `TM_CLOSE` events. Its final
  equity snapshot is 103,208.91, which is incompatible with the report's flat
  100,000 account and zero trades.
- The requested window was 2018-07-02 through 2025-12-31, but the structured
  stream stops on 2023-01-24 and the terminal had reported only 58% progress.
  The agent nevertheless emitted `Test passed` after 1,188 bars. This is a
  truncated result/materialization fault, not an economic no-signal outcome.
- Source/deployed EX5 and setfile hashes were stable throughout the run. The
  report, summary, agent log, and structured log are separately hash-bound in
  the machine-readable receipt.

No strategy threshold, pair definition, risk rule, or EA implementation was
changed. The correct next operation is one append-only Q07 rerun from Q06 PASS,
preserving the terminal INFRA evidence rather than rewriting it in place.

## Binding capacity stop

A fresh five-sample whole-host CPU window returned 75.61%, 95.91%, 100.00%,
86.54%, and 95.13%. Average CPU was 90.64%, but the 100.00% maximum exceeded
the strict 97% ceiling. Per the mission, no recovery row, claim, dispatch tick,
tester launch, compile, smoke test, or backtest followed.

The serialized multi-symbol lane is independently occupied by
`QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1` Q03 work item
`eb3993b7-e477-4236-9cb6-385c1a8e7392` on T3. It was active at 42% and was not
stopped, reprioritized, or otherwise controlled.

## Exact continuation contract

After the current multi-symbol lane is terminal, take a new five-sample CPU
window. Only when both average and maximum are strictly below 97%, create one
append-only Q07 rerun using Q06 predecessor
`d13cf596-44a4-429d-92a7-2de6b1a3e7f0`, terminal Q07 target
`9ba93eb9-4973-4759-9efa-f7ff224f1494`, and current EX5 SHA-256
`d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b`.
Do not reclassify the old raw evidence, enqueue a second recovery, or dispatch a
second basket while another multi-symbol row is active.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest or terminal, AutoTrading state, live/deploy
manifest, Card, EA, EX5, setfile, basket manifest, registry row, magic row, or
farm queue row was changed. Unrelated shared-worktree edits were preserved and
excluded from this handoff.

Machine-readable evidence is in
`artifacts/fx_cointegration_qm5_20224_q07_report_mismatch_cpu_stop_20260831T035305Z_board_advisor.json`.
