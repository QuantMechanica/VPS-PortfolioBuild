# FX cointegration QM5_12507 hard CPU stop

Recorded: 2026-09-10T22:16:29Z (2026-09-11 00:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `57ce5aa7bb6dd0195dc9385d54d4425bb21ee1e3`

## Outcome

The frozen sign-aware 66-pair FX cointegration scan remains fully mechanized:
66 relationships are covered and zero are uncovered. Creating another card or
EA from that scan would duplicate governed work. The two preferred anchors
still have no Q02 setup defect to repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The concrete existing-forex fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 market-neutral basket. Its logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is still pending, unclaimed, at attempt
zero, with no verdict. It is already the sole open Q02 row for
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`; another enqueue would be duplicate
work.

The existing package remains hash-stable. Its logical backtest setfile retains
the governed `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`
contract.

## Binding CPU stop

Four factory terminal processes were already running on T3, T5, T8, and T10.
T3 held a Q04 work item, T5 an optimization-census item, T8 a Q10_NEWS item,
and T10 a pipeline run; T4 also had a current custom-history reservation. The
observed `T_Live` and unrelated FTMO processes were excluded and not
controlled.

Five fresh whole-host CPU samples were `99.610%`, `95.708%`, `98.146%`,
`96.487%`, and `93.458%` (average `96.682%`, maximum `99.610%`). The maximum
crossed the binding `97%` backtest CPU ceiling. Free physical memory fell from
`28.133 GiB` to `26.910 GiB`, also below the documented `58 GiB`
heavy-multisymbol admission threshold.

Per the mission stop condition, no Q02 enqueue/requeue, priority mutation,
dispatch tick, tester launch, terminal reservation, compile enqueue, or source
change followed the capacity finding. The existing logical Q02 row remains
available to the resident paced worker after CPU and memory capacity recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260910T221629Z_board_advisor.json`.

## PACER and safety

No MQ5 was generated or edited and no compile work was enqueued, so the
PACER-required post-write/pre-compile audit boundary was not entered. The
source remains the already-audited file recorded by the preceding QM5_12507
receipts, with unchanged SHA-256
`569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`.

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
