# FX cointegration frontier paced-capacity stop

Date: 2026-08-12

Branch: `agents/board-advisor`

Status: no unbuilt 66-pair relationship; existing Q02 fallbacks preserved;
stopped at the paced backtest CPU ceiling

## Outcome

No Card, EA, registry row, basket manifest, setfile, or Q02 row was created or
changed. The deterministic relationship audit committed at `a80493291` covers
all 66 relationships in the frozen sign-aware scan, so another scan-derived
basket would duplicate an existing mechanization.

The requested anchor repair is not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has logical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has logical Q02 PASS, followed by
  Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

With no unbuilt relationship, the highest-ranked unfinished exact identity is
rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved
`QM5_1257_lemishko-fx-cointpair`. Its existing logical Q02 work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` remains PENDING, unclaimed, and at
attempt zero. It was preserved without a duplicate enqueue or requeue.

The lower-ranked rank-65 `USDCHF.DWX` / `AUDUSD.DWX` identity in `QM5_1156`
also remains PENDING, unclaimed, and at attempt zero. The already-enqueued
structural FX carry-unwind basket `QM5_20292` likewise remains PENDING at Q02.

## Binding paced CPU ceiling

The read-only command below sampled the fleet at `2026-08-12T18:31:23Z`:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
```

The configured paced launch maximum in
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`, while seven factory
MT5 terminals were running:

| Terminal | Active lineage |
|---|---|
| T1 | `QM5_10649`, Q04, `XAUUSD.DWX` |
| T2 | `QM5_1287`, Q04, `XAUUSD.DWX` |
| T4 | direct pipeline run for `QM5_11177` |
| T5 | `QM5_11167`, Q02, `XAUUSD.DWX` |
| T7 | `QM5_12982`, Q02, `XTIUSD.DWX` |
| T9 | `QM5_20206`, Q02, `QM5_20206_XAU_XAG_MOMIVOL_D1` |
| T10 | `QM5_10973`, Q04, `WS30.DWX` |

Seven running factory jobs exceed the active paced ceiling of one. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled. Per the mission stop rule, no enqueue,
requeue, dispatch, reservation, tester launch, terminal action, or backtest
followed the capacity sample.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T183123Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, live artifact, AutoTrading state, or terminal state
  changed.
- Existing unrelated dirty-worktree files were left untouched and are not
  part of this handoff.
