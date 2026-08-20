# FX cointegration frontier hard CPU stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; existing rank-21 basket Q04 remains
pending; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The current scan script still has
SHA-256
`870e3c67d7c05a75f62ab9e89d421dd94d337288f5c623395cafcf03300433d6`,
the hash used by the durable 66-of-66 relationship reconciliation in commit
`a80493291`. That reconciliation leaves no unbuilt relationship in the frozen
`analyze_cross_asset_v3.py --include-negative-hedges` frontier. Creating
another pair Card or EA would therefore be duplicate work.

The preferred anchors do not need Q02 setup repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS,
  followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The highest-ranked exact relationship still awaiting its next economic
verdict is rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, implemented once as
`QM5_20203_eurusd-audjpy`. Its OWNER-approved Card is structural, deterministic,
low-frequency D1, and explicitly non-ML. Its basket manifest declares two
traded legs plus AUDUSD/USDJPY conversion history, and its logical backtest
setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The exact logical Q02 work item
`85be20b6-d19d-46a2-9084-8786d9837399` is already DONE/PASS. Its single Q04
successor `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains PENDING, unclaimed,
and at attempt zero. It was preserved without a duplicate enqueue, requeue,
or priority mutation.

## Binding CPU ceiling

The read-only operator scan at `2026-08-20T04:32:38Z` observed seven active
factory terminals: `T1`, `T2`, `T3`, `T4`, `T7`, `T8`, and `T9`. Five
two-second whole-host CPU samples were `99.66%`, `99.86%`, `100%`, `100%`,
and `99.95%` (average `99.89%`, maximum `100%`). This is above the explicit
`97%` hard ceiling.

Per the mission stop condition, no queue row, dispatch tick, backtest, tester
launch, terminal reservation, terminal control, Card, EA, registry row, magic
row, basket manifest, or setfile was changed. `T_Live` and the unrelated FTMO
terminal were observed only so they could be excluded; neither was controlled.
AutoTrading, the T_Live manifest, and all portfolio admission/KPI/Q08
contribution surfaces were untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T043400Z_board_advisor.json`.
