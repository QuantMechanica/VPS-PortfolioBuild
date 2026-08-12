# FX Cointegration Frontier and CPU-Ceiling Stop

**Observed:** 2026-07-25T22:45:21Z (2026-07-26 00:45:21 CEST)  
**Branch:** `agents/board-advisor`

## Outcome

Stopped before card creation, build, Q02 enqueue, dispatch, or MT5 launch.

The repository's controlling duplicate guard,
`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`,
establishes that the governed 66-pair positive-beta scan and strict sign-aware
extension are fully mechanized. Creating another scan-derived pure-FX pair
would duplicate an existing card and EA.

Fresh canonical work-item reads also show that neither anchor needs the
requested Q02 infrastructure repair:

- `QM5_12532` (`AUDUSD.DWX` / `NZDUSD.DWX`) has logical-basket Q02 `PASS`,
  Q04 `PASS`, and terminal Q05 `FAIL`.
- `QM5_12533` (`EURJPY.DWX` / `GBPJPY.DWX`) has logical-basket Q02 `PASS`
  and terminal Q04 `FAIL`.

Those downstream strategy failures are not ONINIT or NO_HISTORY setup faults,
so re-enqueueing either anchor at Q02 would be duplicate work.

## Paced-fleet ceiling

The read-only `farmctl mt5-slots` scan found seven running factory terminals:

```text
T1, T2, T3, T4, T7, T9, T10
```

`T_Live` was not included and was not controlled. The separate FTMO terminal
was also excluded.

The canonical saturation scheduler dry-run independently returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Seven running factory terminals meet the documented paced-fleet CPU ceiling,
and scheduler capacity is zero. Per the mission's explicit stop condition, no
existing forex card was enqueued as a fallback.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No T_Live manifest, terminal, or AutoTrading state changed.
- No card, EA, binary, setfile, basket manifest, registry, or farm database
  changed.
- No backtest process was launched.
