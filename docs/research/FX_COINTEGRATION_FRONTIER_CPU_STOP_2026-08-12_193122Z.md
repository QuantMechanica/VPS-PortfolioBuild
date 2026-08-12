# FX cointegration frontier paced-capacity stop

Date: 2026-08-12

Branch: `agents/board-advisor`

Status: no unbuilt 66-pair relationship; selected existing FX fallback remains
queued; stopped at the paced backtest CPU ceiling

## Outcome

The frozen sign-aware 66-pair scan remains fully mechanized. The deterministic
relationship audit at `a80493291` accounts for all 66 relationships, so a new
Card, EA, registry allocation, magic row, basket manifest, or setfile would be
duplicate work.

The requested anchor repair is still not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has logical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has logical Q02 PASS, followed by
  Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

Following the existing-card fallback, the concrete selected pair is frozen
scan rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, implemented as slot 8 in approved
`QM5_1257_lemishko-fx-cointpair`. Its exact logical Q02 work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` remains PENDING, unclaimed, and at
attempt zero. The existing row was preserved without duplicate enqueue or
requeue.

The rank-65 `USDCHF.DWX` / `AUDUSD.DWX` identity in `QM5_1156` and the
structural FX carry-unwind basket `QM5_20292` also remain PENDING at Q02. They
were not duplicated or reprioritized.

## Binding paced CPU ceiling

The following read-only sample completed at `2026-08-12T19:30:30Z`:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
```

The configured paced launch maximum in
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`, while five factory
MT5 terminals were running:

| Terminal | Active lineage |
|---|---|
| T1 | `QM5_10649`, Q04, `XAUUSD.DWX` |
| T2 | `QM5_1287`, Q04, `XAUUSD.DWX` |
| T4 | direct pipeline run for `QM5_11177` |
| T5 | `QM5_20236`, Q02, `QM5_20236_XAU_XAG_VOV_D1` |
| T10 | `QM5_12552`, Q02, `XAUUSD.DWX` |

Five running factory jobs exceed the active paced ceiling of one. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled. Per the mission stop rule, no enqueue,
requeue, dispatch, reservation, tester launch, terminal action, or backtest
followed the capacity sample.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T193122Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, live artifact, AutoTrading state, or terminal state
  changed.
- Existing unrelated dirty-worktree files were left untouched and are not
  part of this handoff.
