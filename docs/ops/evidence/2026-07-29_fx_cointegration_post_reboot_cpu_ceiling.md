# FX Cointegration Post-Reboot CPU-Ceiling Stop

**Observed:** 2026-07-29T07:47:55Z (2026-07-29 09:47:55 CEST)
**Branch:** `agents/board-advisor`

## Outcome

Stopped before card creation, EA build, Q02 enqueue, dispatch, or MT5 launch.

The OWNER-requested 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` yielded only two
positive-beta survivors, and both are already carded and built. The controlling
cross-ledger duplicate guard in
`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`
also establishes that the five strict sign-aware qualifiers are fully
mechanized. Creating another scan-derived pure-FX sleeve would duplicate
governed work.

Fresh canonical work-item reads confirm that neither preferred anchor is
blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, and
  terminal Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS` and terminal Q04
  `FAIL`.

The Q02 setup defects visible in their older attempts were superseded by the
logical-basket passes. Re-enqueueing either anchor would therefore be duplicate
work, not an ONINIT/NO_HISTORY repair.

## Fallback reconciliation

The legacy saturation queue currently contains four already-queued rows. Its
two pure-FX cointegration continuations are `QM5_12760` and `QM5_13119`; both
conflict with terminal canonical Q02 PASS evidence documented by the duplicate
guard. The other rows are the XBR/CADCHF cross-asset spread (`QM5_13086`) and
an XTI-only trend pullback (`QM5_12757`), not new pure-FX pairs from the
governed scan. No non-duplicate fallback Q02 row was available to add.

A current filename-based approved-card check found 15 unique EA IDs containing
`cointegration` or `coint`, and every one has a matching EA directory. This is
a bounded duplicate check, not a claim that filenames enumerate every
cointegration strategy in the repository.

## Post-reboot paced-fleet ceiling

The path-aware process scan found no factory `terminal64.exe` process and no
Strategy Farm terminal-worker daemon. The only MT5 process was the separately
excluded `T_Live` instance; it was observed but not controlled.

The canonical health check reported:

```text
2177 pending, 6 active, 0 fresh work-item logs
0/9 enabled terminal_worker daemons alive (T5 remains disabled)
```

Despite the empty factory process set, the legacy dispatch ledger still records
`running=3` for every slot T1 through T10. The canonical saturation scheduler
therefore returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

This is a post-reboot stale-ledger ceiling, not physical CPU occupancy. The
scheduler remains the binding capacity authority, so the mission's explicit
CPU-ceiling stop applies. Rewriting dispatch state, restarting workers, or
timing out active farm rows is scheduler recovery work requiring separate
authority; none was inferred here.

Machine-readable evidence:
`artifacts/fx_cointegration_post_reboot_cpu_ceiling_20260729T074755Z_board_advisor.json`.

## Safety

- No portfolio admission, KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, or AutoTrading state changed.
- No card, EA, binary, setfile, basket manifest, registry, farm database, or
  queue row changed.
- No backtest or tester process was launched.
