# FX cointegration frontier — 22:47Z hard CPU-ceiling stop

Date: 2026-08-18 Europe/Berlin (`2026-08-17T22:47:14Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; the highest-ranked open FX
successor remains enqueued exactly once; no queue mutation because the
explicit backtest CPU ceiling is fully saturated

## Outcome

The committed sign-aware reconciliation at `a80493291` remains an ancestor of
HEAD and accounts for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`. There is no unbuilt
frozen-scan relationship for a non-duplicate Strategy Card and EA.

The two preferred anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: canonical Q02 `PASS`, Q04 `PASS`,
  Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: canonical Q02 `PASS`, Q04
  `FAIL`.

The fallback remains frozen-scan rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, in
approved and built `QM5_20203`. Its canonical Q02 row is `PASS`. Q04 work item
`113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains `pending`, unclaimed, and at
attempt zero. Because that successor already exists exactly once, another
enqueue, requeue, timestamp change, or priority mutation would be duplicate
work.

Fresh SHA-256 hashes confirm that the EX5, basket manifest, fixed-risk
setfile, and approved Card snapshot are unchanged. The backtest setfile
remains bound to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Binding resource stop

Five one-second whole-machine CPU samples were all `100%`, above the explicit
`97%` hard ceiling.

The path-aware operator scan found seven active factory terminals: `T1`,
`T2`, `T3`, `T4`, `T5`, `T6`, and `T8`. Four terminals owned Q02 work items
and three owned Q08 pipeline runs. `T_Live` and the unrelated FTMO terminal
were observed only so they could be excluded; neither was controlled.

Per the mission stop condition, no Card, EA, registry row, magic row, basket
manifest, setfile, queue row, dispatch tick, backtest, terminal reservation,
priority mutation, Factory state, or terminal state was created or changed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260817T224714Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- Concurrent unrelated staged, modified, and untracked work was left
  untouched.

## 23:48Z continuation audit

A fresh read-only audit at repository head
`f9aecc9f17ece7a695faa53b041939a92a735c16` found a materially changed
factory roster but the same binding hard-CPU condition. Five one-second
whole-machine samples were `100%`, `99.81%`, `99.03%`, `99.52%`, and
`99.71%` (average `99.61%`, maximum `100%`). Both the average and maximum
exceed the explicit `97%` ceiling.

The path-aware operator scan observed six active factory terminals on `T1`,
`T3`, `T5`, `T7`, `T8`, and `T9`, down from seven at 22:47Z. All six were
already occupied by governed pipeline runs. The separately visible `T_Live`
and FTMO terminals were excluded and neither was controlled.

The frozen 66-pair frontier remains fully covered by governed work. Fresh
supported operator reads confirm both anchors are downstream of Q02 PASS:
`QM5_12532` at Q05 FAIL and `QM5_12533` at Q04 FAIL. The non-duplicate
fallback remains rank-21 `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`: Q02 is
PASS, and Q04 item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains pending,
unclaimed, at attempt zero. A second enqueue or requeue would duplicate that
open successor.

Fresh hashes confirm the MQ5, EX5, basket manifest, approved Card snapshot,
and fixed-risk logical-basket setfile are unchanged. The setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Per the mission stop condition, no Card, EA, registry row, magic row, queue
row, dispatch tick, backtest, tester launch, terminal reservation, priority
mutation, Factory state, portfolio surface, or live surface was changed.
Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260817T234822Z_board_advisor.json`.

## 00:48Z continuation audit

A fresh read-only audit at repository head
`d51ed3bb5b26feb6ecc95db06bc2069003aa0ae8` found a materially changed
factory roster and a fully saturated hard-CPU condition. Five one-second
whole-machine samples were all `100%`, above the explicit `97%` ceiling.

The supported path-aware operator scan observed eight active factory
terminals on `T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T9`, and `T10`, up from
six at 23:48Z. `T1` and `T10` owned Q04 work items; the other six terminals
were occupied by governed pipeline runs. The separately visible `T_Live`
and FTMO terminals were observed only so they could be excluded; neither was
controlled.

The frozen 66-pair frontier remains fully covered by governed work, and the
coverage reconciliation commit `a80493291` remains an ancestor of the
observed head. Supported operator reads again confirm both anchors are
downstream of Q02 PASS: `QM5_12532` at Q05 FAIL and `QM5_12533` at Q04
FAIL. The non-duplicate fallback remains rank-21
`QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`: its canonical Q02 is PASS, and
Q04 item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains pending,
unclaimed, at attempt zero. A second enqueue, requeue, priority change, or
dispatch would duplicate or improperly overtake that open successor.

Fresh hashes confirm the MQ5, EX5, basket manifest, approved Card snapshot,
and fixed-risk logical-basket setfile are unchanged. The setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Per the mission stop condition, no Card, EA, registry row, magic row, queue
row, dispatch tick, backtest, tester launch, terminal reservation, priority
mutation, Factory state, portfolio surface, or live surface was changed.
Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260818T004844Z_board_advisor.json`.
