# FX cointegration QM5_12507 stale-priority repair and capacity stop

Recorded: 2026-09-12T03:38:14Z (05:38 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `bfeaf7cd828bbf722b6151a41d598b7366bbe37c`

## Outcome

The frozen 66-pair FX cointegration scan remains fully mechanized. The
controlling research record, `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`,
reports only two relationships above its published survivor bar, and both are
already built:

- `QM5_12532` AUDUSD/NZDUSD has Q02 `PASS`, Q04 `PASS`, then terminal Q05
  `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has Q02 `PASS`, then terminal Q04 `FAIL`.

No new Strategy Card, EA identity, basket manifest, compile row, or Q02 row was
created. The non-duplicate existing-forex fallback remains the EURUSD/GBPUSD H1
logical basket `QM5_12507_pair-coint-z`, whose exact Q02 row
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
verdict-free, and `priority_track=true`.

## Stale competing priority repaired

A prior paced wake had marked the old `QM5_20195` NZDUSD/EURGBP Q03 row
`59fa650c-22f2-4608-bb98-15180abc2aca` as priority. That continuation is no
longer valid: the same tested identity already has terminal Q04 economic
`FAIL` in work item `b14b5edf-ffdd-4439-a2ed-dc4930d65029`, with stored reason:

`F1:pf_net=0.919;F2:pf_net=0.860;F3:pf_net=0.752 || lowfreq:FAIL:lowfreq_pooled_pf_below_floor;pool:pf_net=0.868,pooled_trades=42,active_years=3/3`

The canonical reversible queue controller first returned a clean dry run and
then set only that stale row's `payload.priority_track=false` at
`2026-09-12T03:36:56Z`. Its phase, status, verdict, evidence pointer, attempt
count, and identity were preserved. No row was deleted, requeued, superseded,
or appended. In the post-action canonical selector snapshot, the live 12507
Q02 target ranks 30th of 3,395 eligible rows while the terminally-obsolete
20195 Q03 row ranks 2,921st. This removes invalid competition for scarce FX
basket capacity and leaves the one valid fallback on its governed claim path.

## PACER audit and artifact bindings

No MQ5 source was generated or modified and no compile was requested. A fresh
precautionary execution of the binding guard against the absolute source path
returned exit 0, `ok=true`, and zero `EA_FRAMEWORK_INPUT_PINNED` findings:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
```

`validate_symbol_scope.py --ea QM5_12507_pair-coint-z --json` returned
`BASKET_OK` with zero violations and matched all four source references to the
manifest: `EURUSD.DWX`, `GBPUSD.DWX`, `NDX.DWX`, and `WS30.DWX`.

The logical backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Current bindings are:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Capacity stop

The post-action five-sample whole-host CPU window was 45%, 56%, 55%, 42%, and
62% (average 52%, maximum 62%), so the binding 97% CPU ceiling did not fire.
The farm held six active and 6,610 pending work items.

Free physical memory was only 29.809 GiB of 63.120 GiB. The canonical admission
classifier assigns 12507 `heavy_or_unknown_multisymbol` with a 44 GiB flat
reservation plus the 14 GiB post-reservation floor, requiring 58 GiB free.
Launching it would violate the governed RAM guard, so no dispatch tick, tester
launch, terminal reservation, or terminal control followed. The resident paced
workers may claim the existing priority Q02 row when memory admission recovers.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live` terminal, AutoTrading state, or live artifact
  changed.
- No Strategy Card, EA source, EX5, setfile, manifest, registry row, magic row,
  work-item status, verdict, or historical evidence was changed.
- Pre-existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_stale_priority_repair_20260912T033656Z_board_advisor.json`.
