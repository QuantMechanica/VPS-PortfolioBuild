# QM5_12919 repaired basket-history Q02 requalification enqueue

Date: 2026-09-10  
Branch: `agents/board-advisor`  
Router task: `c204bef5-7dec-4a95-b16e-dc8e795e516a`  
Disposition: `Q02_ENQUEUED / RUNTIME_PENDING`

## Outcome

The accepted same-lineage history-readiness repair for
`QM5_12919_amp-value-momentum-xasset` now has one exact, append-only Q02
requalification row. The new row is pending and unclaimed; no tester or
pipeline phase was run in this unit.

This is the diversity-first priority-2 recovery selected after the canonical
build claim guard found no genuinely unbuilt, registry-complete diverse card:
every nominally claimable pending build row already had an MQ5, EX5, and farm
work-item history. QM5_12919 is a monthly, structural value/momentum basket
covering four FX pairs and four equity indices. Its repaired binary had never
received a post-repair Q02 run because the first handoff was refused by
`FACTORY_OFF` and the next handoff stopped at the paced CPU ceiling.

## Farm coordination and capacity

- The prior CPU-blocked router task was reopened through the canonical router
  writer as `IN_PROGRESS`, assigned to `codex`, before mutation.
- No pending or active QM5_12919 Q02 row existed at claim time.
- `PRAGMA quick_check` returned `ok`; `FACTORY_OFF.flag` was absent.
- Five farm work items were active.
- The immediate five-sample CPU admission was `77.08%, 69.42%, 58.21%,
  56.65%, 58.40%` (average `63.95%`, maximum `77.08%`), below the binding
  97% ceiling.

## Exact bindings and guards

| Artifact | SHA-256 |
|---|---|
| MQ5 | `c729116f626f7c6b2d930a160a070b3319f198f2a565ad5310c4d49dfa53526a` |
| EX5 | `6e915491196f60baf3d4fa98d900495be6aed295dd37605d3b6c65a6024383f9` |
| USDJPY M30 setfile | `02f18620b8b7044e462194632e6bbe9eb7c42860cbbf44aa2a80c0dca3445e0d` |

- The binding PACER audit returned `ok=true`, `hit_count=0`, and no
  `EA_FRAMEWORK_INPUT_PINNED` finding.
- The focused history-readiness contract returned `2 passed`.
- The setfile retains `qm_ea_id=12919`, `qm_magic_slot_offset=6`,
  `RISK_FIXED=1000`, and `RISK_PERCENT=0`.
- No MQ5, EX5, strategy parameter, setfile, registry, or resolver byte was
  changed in this handoff, so no compile was required or enqueued.

## Append-only enqueue

The current controller requires both `--from-work-item-id` and
`--append-only-rerun-of` to name the same exact source row, and its `--ea`
argument for this path is the registry ID (`QM5_12919`), not the full label.
Two fail-closed attempts made no mutation while those interface requirements
were resolved:

1. `q02_append_only_rerun_requires_same_exact_source_and_rerun_row`
2. `ea_dir_missing` for the incorrectly expanded full-label prefix

The final canonical call appended exactly one row:

| Field | Value |
|---|---|
| New work item | `4ae565d6-d87b-4c9e-8ac5-38f97ad95e56` |
| Phase / state | `Q02 / pending`, unclaimed |
| Symbol / timeframe | `USDJPY.DWX / M30` |
| Preserved predecessor | `1226a3d4-6c54-4123-b31e-1b9da87b56da` (`done / ZERO_TRADES`) |
| Enqueue implementation | `farmctl.append_only_exact_row_rerun` |
| History archive admission | `ACTIVE`, USDJPY.DWX selected |
| Risk binding | `RISK_FIXED=1000.0`, `RISK_PERCENT=0.0` |

The successor payload seals all three current artifact hashes, records the
predecessor evidence and payload hashes, sets
`historical_work_item_preserved=true`, and records the changed execution
bindings from the accepted repair. The predecessor row remains terminal and
unchanged.

## Zero-trades recovery record

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_12919 | `1226a3d4`, USDJPY.DWX M30 | One-shot foreign D1 warmup silently left too few eligible basket members | Exact-depth retry, fail-closed readiness, and bounded diagnostics; approved economics unchanged | Existing repaired EX5: strict PASS, 0 errors / 0 warnings | Repaired build: pending Q02 | Repaired build: pending Q02 | The queued worker must produce valid setup/entry evidence and a Q02 verdict; later gates remain untouched |

## Safety boundary

No backtest, terminal, optimizer, compile worker, or manual MetaEditor process
was started by this unit. No `T_Live` file or process, AutoTrading state,
portfolio gate, deploy manifest, or T_Live manifest was touched. The new row is
only an append-only non-live queue handoff; it makes no efficacy,
certification, decorrelation, or portfolio-admission claim.
