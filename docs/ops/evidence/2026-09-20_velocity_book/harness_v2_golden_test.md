# Velocity harness v2 golden test

Task: `7088da77-9e03-45cf-a568-581863f03ef1`

Scope: research tooling only; USDJPY.DWX C2 placement/fill mechanics and Q04 reconciliation

Result: **mechanics PASS; economic equivalence UNKNOWN**

This golden test does not validate strategy economics, issue a pipeline verdict, or revive H-V4 / QM5_41485.  Its purpose is to
show that the corrected offline harness observes the real placement tick, fails closed on invalid facts, cancels a one-sided OCO
pair, charges first-available-price gaps, and exposes the remaining difference from the governed MT5 reports.

## Frozen rules under test

1. Decode the first real `.tkc` bid/ask tick at or after the requested placement epoch; never invent a spread.
2. A buy stop must be above Ask plus the governed tester minimum distance; a sell stop must be below Bid minus that distance.
3. If exactly one stop is accepted, cancel its peer and score no trade.
4. If price gaps through a pending, protective-stop, or target level, fill at the first available M1 open.
5. Tag an eligible 08:30 America/New_York anchor from the complete native MT5 USD-high calendar export.
6. Missing, corrupt, or inverted quotes are `UNKNOWN`, never silently repaired; a cell that trades a tagged anchor is also
   `UNKNOWN` because mandatory news blackout is unresolved.

The `.DWX` tester stop level is the recorded zero-point custom-symbol fact in
`docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md`; the shared module binds the canonical
`framework/registry/tester_defaults.json` and the loaded T1 custom-symbol catalogue by SHA-256.  Freeze distance uses the MT5
custom-symbol default of zero.  No registry or terminal state was changed.

## Synthetic release-gap fixture

The deterministic fixture uses a high-impact 08:30 New York release tick with Bid 151.790, Ask 151.858, requested buy stop
151.854, and requested sell stop 151.774.  The buy is invalid, the sell is valid, and the result is
`CANCEL_NO_TRADE_ONE_SIDED`; no trade is emitted.  Five buy/sell entry, protective-stop, and target gap cases all fill at their
first M1 open.

- Fixture: `docs/ops/evidence/2026-09-21_velocity_harness_v2/task_7088da77-9e03-45cf-a568-581863f03ef1/synthetic_release_gap_fixture.json`
- SHA-256: `726fcfc39b2ba4af6545cabe8a51edab1aeff6859f414ffb734b2e147208c20f`
- Repeated generation produced the same bytes and hash.

## Archived placement checks

Focused tests decoded the governed USDJPY tick archive and recovered the tester-observed pairs exactly:

| placement epoch | decoded Bid | decoded Ask | requested buy / sell | v2 result |
|---|---:|---:|---:|---|
| 2024-04-10 15:30 server | 151.790 | 151.858 | 151.854 / 151.774 | one-sided; cancel / no trade |
| 2024-07-11 15:30 server | 161.532 | 161.761 | bound in audit ledger | one-sided; cancel / no trade |

The Q03 logger contains 16 USDJPY `ENTRY_REJECTED` days in 2024.  C2 v2 emits
`CANCEL_NO_TRADE_ONE_SIDED` on the same 16 of 16 dates.  Across 2018-2025, C2 records 1,829 range-eligible placement events:
1,437 accepted pairs, 94 one-sided cancellations, 296 news-blocked events, and two invalid archived quotes.  The latter are
2019-03-27 (Bid 110.428 > Ask 110.425) and 2020-12-08 (Bid 104.099 > Ask 104.098); both correctly force the cell to `UNKNOWN`.

The tag source is the complete 4,189-row native MT5 USD-high export documented by
`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md`, not the defective tester seed.  It supplies 836 unique
08:30 New York anchors and is bound by SHA-256 `c1554e52d3456575f51d044cd0097e18b960c7f12485e9b45a07e36536b9ab3b`.
In VAL, 94 / 100 / 88 C2 placements fall on tagged anchors in 2023 / 2024 / 2025.  The tester-bound CSV blocks only
23 / 37 / 10; it accepts 66 / 48 / 71.  Those 185 accepted VAL placements demonstrate that mandatory news blackout remains
unresolved, so every affected C cell is fail-closed `UNKNOWN` even though its diagnostic returns remain visible.

## Trade-by-trade difficult-day comparison

`golden_comparison.json` contains 321 dated records covering the union of:

- Q03 entry rejections;
- high-impact 08:30 New York anchors;
- harness-only and tester-only trade dates;
- direction mismatches on common dates; and
- actual entry/protective gap-through trades, if present.

Each record includes the placement decision and quote, harness direction/entry/exit/R, tester direction/entry/exit/R, and reason
tags.  No actual USDJPY C2 VAL trade required a gap-through adjustment; the deterministic synthetic cases therefore remain the
golden coverage for the gap rule.

| year | harness trades | harness net R / PF | Q04 trades | Q04 net R / calculated PF | registered PF | common / direction mismatch |
|---|---:|---:|---:|---:|---:|---:|
| 2023 | 189 | +14.634 / 1.1634 | 174 | +0.550 / 1.0059 | 1.004 | 171 / 6 |
| 2024 | 170 | +10.082 / 1.1303 | 148 | -23.456 / 0.7239 | 0.724 | 147 / 8 |
| 2025 | 200 | +21.163 / 1.1968 | 200 | -10.461 / 0.9157 | 0.916 | 197 / 8 |

The corrected one-sided-placement tail is real and reconciled, but the remaining trade-direction and same-day execution
differences are material.  Consequently C2/C3 are not economic validation.  Both are `UNKNOWN` for invalid archived quote days
and the unresolved mandatory release blackout.

## Reproduction and bound evidence

Run from `C:/QM/repo`:

```text
python -m pytest tools/strategy_farm/tests/test_velocity_execution_harness_v2.py -q
python tools/strategy_farm/session_tools/velocity_family_f1_sweep_0921.py --control-only --workers 1 --out docs/ops/evidence/2026-09-21_velocity_harness_v2/task_7088da77-9e03-45cf-a568-581863f03ef1/control_usdjpy_v2.json
python tools/strategy_farm/session_tools/velocity_harness_v2_golden_0922.py
```

- Full comparison JSON: `docs/ops/evidence/2026-09-21_velocity_harness_v2/task_7088da77-9e03-45cf-a568-581863f03ef1/golden_comparison.json`
- Comparison SHA-256: `87b643125c02c60e5eac564efb896534144078730dc6c94ecdf17a824e0ab497`
- Full registered sweep: `docs/ops/evidence/2026-09-21_velocity_harness_v2/task_7088da77-9e03-45cf-a568-581863f03ef1/velocity_family_f1_sweep_v2.json`
- USDJPY control ledger: `docs/ops/evidence/2026-09-21_velocity_harness_v2/task_7088da77-9e03-45cf-a568-581863f03ef1/control_usdjpy_v2.json`

Final interpretation: the placement and gap subsystem passes its golden checks.  Economic equivalence remains `UNKNOWN`; only
pipeline evidence may supply a pipeline verdict.  H-V4 / QM5_41485 remains permanently tagged
`PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE`.
