# FX cointegration QM5_12507 paced RAM-admission stop

Recorded: 2026-09-12T15:17:29Z (17:17 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `e60b99086789930fc0216029f361333e5375624c`

## Outcome

The governed 66-pair scan has no unbuilt relationship. Its two published
survivors are already built and beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has Q02 PASS and later Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY has Q02 PASS and later Q04 FAIL.

The selected existing-forex fallback is therefore the EURUSD/GBPUSD H1
logical basket in `QM5_12507_pair-coint-z`. Its exact canonical continuation
is present once:

| Field | Value |
| --- | --- |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Phase / status | Q02 / pending |
| Attempt / claimant | 0 / null |
| Verdict / active holds | null / 0 |
| Priority track | true |
| Exact open identity count | 1 |

Appending another Q02 row would duplicate governed work, so the existing row
was preserved for the resident paced workers.

## PACER and basket checks

No MQ5 source was generated or changed and no compile was requested. A fresh
precautionary execution of the binding input-pin audit returned exit 0,
`ok=true`, and zero `EA_FRAMEWORK_INPUT_PINNED` findings:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
```

`validate_symbol_scope.py --ea QM5_12507_pair-coint-z --json` returned
`BASKET_OK` with zero violations and matched all four source references to the
manifest: `EURUSD.DWX`, `GBPUSD.DWX`, `NDX.DWX`, and `WS30.DWX`.

The logical backtest setfile remains bound to `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Artifact hashes remain:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Capacity refusal

The five fresh whole-host CPU samples were `87.897873%`, `82.653723%`,
`78.827042%`, `71.194609%`, and `69.632147%` (average `78.041079%`, maximum
`87.897873%`), so the mission's 97% CPU ceiling did not fire.

The canonical admission class for this four-symbol EA is
`heavy_or_unknown_multisymbol`: 44 GiB reservation plus a 14 GiB
post-reservation floor requires 58 GiB free. Only 28.880 GiB of 63.120 GiB
physical memory was free. The farm concurrently held five active and 5,945
pending work items, with factory terminals T1, T5, T7, T9, and T10 running.

Normal admission therefore refuses the run. No dispatch tick, tester launch,
terminal reservation, terminal control, enqueue, requeue, or queue mutation
followed. The resident paced fleet may claim the existing priority row when
memory headroom recovers.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- The observed `T_Live` terminal was excluded and not queried or controlled;
  no deploy manifest, AutoTrading state, or live artifact changed.
- No card, EA source, EX5, setfile, basket manifest, registry row, magic row,
  work-item state, payload, priority, or verdict changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded
  from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_paced_ram_stop_20260912T151729Z_board_advisor.json`.
