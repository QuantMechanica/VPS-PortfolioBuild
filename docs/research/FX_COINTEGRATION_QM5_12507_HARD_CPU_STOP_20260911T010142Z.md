# FX cointegration QM5_12507 hard CPU stop

Recorded: 2026-09-11T01:01:42.5623439Z (2026-09-11 03:01 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `88f4c4757d2868fbc60fde6f2d8a5054a182d41e`

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
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, at attempt
zero, with no verdict. It is already the sole open logical Q02 row identified
by the preceding governed handoff, so no duplicate enqueue was attempted.

The existing package is hash-stable. Its logical backtest setfile retains the
governed `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`
contract.

## Binding CPU stop

The first fresh whole-host CPU sample was `99.610%`, above the binding `97%`
backtest ceiling. Free physical memory was `31.477 GiB`, below the documented
`58 GiB` heavy-multisymbol admission threshold. Factory terminal processes
were already running on T2, T7, and T10. The separately observed `T_Live` and
unrelated FTMO terminals were excluded and not controlled.

Per the mission stop condition, sampling stopped immediately and no Q02
enqueue/requeue, priority mutation, dispatch tick, tester launch, terminal
reservation, compile enqueue, or source change followed. The pending Q02 row
remains available to the resident paced worker after CPU and memory admission
recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T010142Z_board_advisor.json`.

## PACER and safety

No MQ5 was generated or edited and no compile work was enqueued, so the
PACER-required post-write/pre-compile audit boundary was not entered. The
source remains unchanged with SHA-256
`569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`.

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
