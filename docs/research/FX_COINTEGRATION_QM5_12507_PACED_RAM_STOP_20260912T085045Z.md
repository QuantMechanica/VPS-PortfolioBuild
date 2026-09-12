# FX cointegration QM5_12507 paced RAM stop

**Recorded:** 2026-09-12T08:50:45Z (10:50 Europe/Berlin)  
**Branch:** `agents/board-advisor`  
**Observation head:** `62ed193d8ddce41bbf0c0df5991fb096706643c9`

## Outcome

The frozen 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains exhausted. It
published only two relationships above its survivor bar, and both are already
built with terminal downstream outcomes:

- `QM5_12532` AUDUSD/NZDUSD: Q02 `PASS`, Q04 `PASS`, Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY: Q02 `PASS`, Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. Creating a
new scan-derived card, EA, compile row, or Q02 row would duplicate governed
work. The selected existing-forex fallback therefore remains the
EURUSD/GBPUSD H1 logical basket in `QM5_12507_pair-coint-z`.

Its exact continuation is still unique and correctly queued:

| Field | Value |
|---|---|
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Phase / status | Q02 / pending |
| Attempt / claimant | 0 / null |
| Verdict / active holds | null / 0 |
| Priority track | true |
| Exact open identity count | 1 |

No duplicate enqueue, requeue, priority mutation, or manual claim was made.

## Build and basket checks

No MQ5 source was generated or changed and no compile was requested. A fresh
precautionary PACER audit against the absolute source path returned exit 0,
`ok=true`, and zero `EA_FRAMEWORK_INPUT_PINNED` findings:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
```

`validate_symbol_scope.py --ea QM5_12507_pair-coint-z --json` returned
`BASKET_OK` with zero violations. The logical backtest setfile remains sealed
to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Current artifact bindings are unchanged:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

The apparent two-leg target cannot be honestly reclassified by merely
narrowing its manifest. The approved EA intentionally contains two host pairs
and `Strategy_EnsureBasketScope` selects and warms all four declared symbols:
`EURUSD.DWX`, `GBPUSD.DWX`, `NDX.DWX`, and `WS30.DWX`. Removing the index pair
from the source or manifest would change the approved card universe and build
identity, while changing the classifier would be an out-of-scope framework
repair. Both were refused.

## Binding capacity stop

The fresh five-sample whole-host CPU window was `84.376651%`, `75.576488%`,
`71.975776%`, `74.136776%`, and `72.756716%` (average `75.764481%`, maximum
`84.376651%`). The 97% CPU ceiling did not fire.

The canonical worker classifier independently assigns this work item
`heavy_or_unknown_multisymbol`: 44 GiB reservation plus the 14 GiB
post-reservation floor, requiring 58 GiB free. Only 31.513 GiB of 63.120 GiB
physical memory was free. Seven farm work items were active and 6,296 were
pending at the immediately following queue snapshot.

Normal admission therefore refuses the run. No dispatch tick, tester launch,
terminal reservation, terminal control, or queue mutation followed. The
resident paced fleet may claim the already-priority-tracked row when memory
headroom recovers.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live` terminal, AutoTrading state, or live artifact
  changed.
- No card, EA source, EX5, setfile, basket manifest, registry row, magic row,
  work-item state, payload, priority, or verdict changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded
  from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_paced_ram_stop_20260912T085045Z_board_advisor.json`.
