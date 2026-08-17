# FX cointegration frontier — 17:20Z hard CPU-ceiling stop

Date: 2026-08-17 Europe/Berlin (`2026-08-17T17:20:14Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; the highest-ranked open FX
successor remains enqueued exactly once; no queue mutation because the
explicit backtest CPU ceiling is binding

## Outcome

The committed sign-aware reconciliation at `a80493291` still accounts for all
66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`. There is no unbuilt frozen-scan relationship for a
non-duplicate Strategy Card and EA.

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

## Binding resource stop

Five two-second whole-machine CPU samples were `98.49%`, `94.93%`, `95.51%`,
`90.97%`, and `87.60%` (average `93.50%`, maximum `98.49%`). The maximum
crossed the explicit `97%` hard ceiling.

The canonical database reported seven active work-item claims on `T1`, `T2`,
`T3`, `T5`, `T8`, `T9`, and `T10`: one Q02, four Q04, one Q07, and one Q08.
A simultaneous exact-path process snapshot saw factory terminal processes on
`T1`, `T2`, `T3`, and `T9`. The transient database/process roster difference
was recorded read-only and was not reconciled. No process outside an exact
`D:/QM/mt5/T<n>/terminal64.exe` path was selected for the roster.

Per the mission stop condition, no Card, EA, registry row, magic row, basket
manifest, setfile, queue row, dispatch tick, backtest, terminal reservation,
priority mutation, Factory state, or terminal state was created or changed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260817T172014Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- Concurrent unrelated staged and untracked work was left untouched.
