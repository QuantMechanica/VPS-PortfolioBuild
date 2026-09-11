# FX cointegration QM5_12507 non-duplicate Q02 hold

Recorded: 2026-09-11T22:19:07Z (2026-09-12 Europe/Berlin)

Branch: `agents/board-advisor`

## Status

The frozen 66-pair sign-aware FX scan is fully mechanized: the durable
coverage artifact accounts for 66 covered relationships and zero uncovered
relationships. Creating another card or EA would duplicate governed work.

The preferred anchors are not blocked at Q02:

- `QM5_12532` has Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has Q02 PASS, followed by Q04 FAIL.

The concrete existing-forex fallback remains the EURUSD/GBPUSD H1 basket
`QM5_12507_pair-coint-z`. Its single logical Q02 row
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, at attempt zero,
verdict-free, and already `priority_track=true`. No duplicate enqueue, requeue,
or priority restamp was made.

## PACER guard and build state

The binding source audit was run against the absolute MQ5 path:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

`validate_symbol_scope.py` returned `BASKET_OK` with zero violations. A
read-only `build_check.ps1 -SkipCompile` attempt was itself refused by the
live-factory guard (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`), as designed. No
compile retry and no compile enqueue followed.

The logical setfile remains in the mandated backtest mode:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1`

Bindings:

- MQ5 SHA256: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5 SHA256: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest SHA256: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile SHA256: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Capacity and legacy-manifest constraint

Five one-second whole-host CPU samples were 69.24%, 67.37%, 80.48%, 83.21%,
and 85.35% (average 77.13%, maximum 85.35%). The explicit 97% CPU ceiling did
not fire. The farm had six active rows, 7,221 pending rows, and only 22.811 GiB
free physical RAM.

Recent worker claim scans reported `multisymbol_commit_skipped` while continuing
to claim other eligible work. The selected Q02 payload is conservatively a
four-symbol basket (`EURUSD.DWX`, `GBPUSD.DWX`, `NDX.DWX`, `WS30.DWX`), matching
the manifest and the EA's deliberate four-symbol warmup. Reclassifying it as an
exact two-leg basket would understate real dependencies unless the existing EA
were split and recompiled. That is a materially different source change, not a
safe metadata-only correction, so it was not performed.

## Outcome and safety

No Strategy Card, EA source, EX5, setfile, manifest, registry row, magic row,
work-item state, verdict, priority, queue identity, tester process, or terminal
state changed. The existing priority Q02 row is the sole non-duplicate next
action and remains available to the paced workers when its full multisymbol
admission conditions clear.

No portfolio-admission, portfolio-KPI, Q08-contribution, T_Live manifest,
T_Live terminal, or AutoTrading surface was touched.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_nonduplicate_hold_20260911T221907Z_board_advisor.json`.
