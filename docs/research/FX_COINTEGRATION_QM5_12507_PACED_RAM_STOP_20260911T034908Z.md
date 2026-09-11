# FX cointegration QM5_12507 paced RAM stop

Recorded: 2026-09-11T03:49:08Z (05:49 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `84bcbb3446c9a9b08d22dbe37db4dfc67cc37305`

## Outcome

The frozen sign-aware 66-pair FX cointegration scan remains fully mechanized:
66 relationships are covered and zero are unbuilt. Creating a new Card, EA,
registry identity, basket manifest, or Q02 row would duplicate governed work.

The preferred anchors do not have a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The concrete existing-forex fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 market-neutral basket. Its sole logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
hold-free, and already `priority_track=true`. Exactly one open work-item
identity exists for the EA, phase, and logical symbol. No duplicate enqueue or
priority mutation was performed.

## Binding and package checks

The source is hash-stable at
`569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`.
The binding PACER audit passed with exit 0, `ok=true`, and zero
`EA_FRAMEWORK_INPUT_PINNED` findings:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
```

The basket-manifest regression also passed:

```text
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q -k qm5_12507
1 passed, 46 deselected
```

The logical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No `.mq5` was generated or modified, so no compile work
was eligible or enqueued.

A read-only current-binary rebind dry run refused with
`source_ex5_sha256_missing`. That is expected for this pre-execution-binding
legacy pending row and does not authorize rewriting it or appending a second
open identity. The unique existing row was preserved.

## Paced capacity stop

Five one-second whole-host CPU samples were `87.895%`, `84.810%`, `79.990%`,
`74.822%`, and `76.758%` (average `80.855%`, maximum `87.895%`). The explicit
97% CPU ceiling did not fire.

Free physical memory was only `43.805 GiB` of `63.120 GiB`, below the
repository's `58 GiB` heavy-multisymbol admission floor. Four factory testers
were active on T1, T2, T4, and T10, while the serialized launch gate remained
`1`. A manual dispatch was therefore inadmissible. The priority Q02 row remains
available for the resident paced worker after memory and launch capacity
recover.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No work item, verdict, priority, claim, queue identity, tester, reservation,
  or terminal process changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
  `T_Live`, deploy, AutoTrading, or live-manifest surface was touched.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_paced_ram_stop_20260911T034908Z_board_advisor.json`.
