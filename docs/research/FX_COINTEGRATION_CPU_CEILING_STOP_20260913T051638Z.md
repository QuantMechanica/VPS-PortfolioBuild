# FX cointegration frontier reconciliation and CPU-ceiling stop

Recorded: `2026-09-13T05:16:38Z` (`07:16:38` Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `77d5dfaa54a75c28a9cb5ae6476107c923b773d2`

## Outcome

The controlling 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` admits only two pairs
under its fixed rule (positive DEV Sharpe, OOS net Sharpe above 0.8, and at
least four OOS trades). Both are already built and have terminal downstream
verdicts rather than a Q02 setup blocker:

| EA | Pair | Authenticated chain |
| --- | --- | --- |
| `QM5_12532` | AUDUSD.DWX / NZDUSD.DWX | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY.DWX / GBPJPY.DWX | Q02 PASS, Q04 FAIL |

The later sign-aware strict frontier is also already fully mechanized, as
reconciled in
`docs/ops/evidence/2026-07-20_fx_cointegration_frontier_exhaustion_cpu_ceiling.md`.
Creating another card from the frozen scan would therefore duplicate a built
relationship or weaken the preregistered screen. No card, identity, magic row,
EA, basket manifest, setfile, compile row, or Q02 row was created.

The selected existing-forex fallback remains the low-frequency EURGBP/EURAUD
D1 basket `QM5_12712`. Its authenticated farm chain has Q02-Q07 PASS and a
current-contract Q09 PASS. The required current-contract Q08 regeneration is
already present exactly once:

| Field | Value |
| --- | --- |
| Work item | `b68d05cd-e52c-43a5-96aa-5e0306efa60f` |
| EA / logical symbol | `QM5_12712` / `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` |
| Phase | Q08 |
| State | pending, unclaimed, attempt 0, verdict null |
| Priority | `priority_track=true` (recorded by the preceding release evidence) |
| Hold | released by governed receipt `2026-09-13T04:09:14Z` |

Appending another Q08 would be duplicate work. Enqueuing Q10_NEWS before this
Q08 produces readable evidence would violate the controller dependency, whose
last fail-closed finding was `q08_evidence_missing_or_unreadable`.

## Binding CPU stop

Before any queue mutation, five fresh whole-host CPU samples were taken two
seconds apart:

```text
100.000000%
96.195604%
94.049399%
99.082412%
83.790755%
```

Average CPU was `94.623634%`; maximum CPU was `100.000000%`. The mission's
backtest CPU ceiling binds when any sample reaches 97%, so the maximum latched
the stop.

The canonical live query returned six active factory work items: one Q02, one
Q03, one Q04, and three OPT_CENSUS rows. Free physical memory was `35.397 GiB`
of `63.120 GiB`, also below the previously evidenced 46 GiB admission need for
the `QM5_12712` multi-leg FX basket (32 GiB reservation plus 14 GiB floor).

After the ceiling fired, no enqueue, priority mutation, claim, dispatch tick,
tester launch, terminal reservation, compile, or backtest was attempted. The
resident paced fleet retains ownership of the already eligible Q08 row.

## PACER build guard

No `.mq5` source was generated or edited, and no enqueue-compile command was
issued. The mandatory post-write/pre-compile input-pin audit boundary was
therefore not entered. No framework input was pinned or changed by this pass.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact changed.
- No strategy card, EA source/binary, setfile, basket manifest, registry,
  magic row, work-item state/payload/verdict, queue identity, or priority
  changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_cpu_stop_20260913T051638Z_board_advisor.json`.
