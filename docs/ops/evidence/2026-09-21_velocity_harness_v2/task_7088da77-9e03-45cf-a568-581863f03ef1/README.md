# Task 7088da77 — Velocity harness v2

Router task: `7088da77-9e03-45cf-a568-581863f03ef1`

Lane: Codex review

Disposition: **REVIEW — mechanics PASS; economic equivalence UNKNOWN**

## Outcome

The research harness now uses one shared, read-only execution module for real-tick placement facts and M1 gap fills.  It decodes
the governed `.tkc` bid/ask pair at placement, applies the bound `.DWX` tester stop/freeze distance, cancels a lone accepted OCO
leg as no-trade, and fills gaps at the first available M1 open.  It fails closed as `UNKNOWN` for unavailable, corrupt, or
inverted execution facts.  Native 08:30 New York release tags are sourced independently from the complete MT5 USD-high export;
a cell that traded such an anchor is also fail-closed because mandatory news blackout remains unresolved.  The F1 and H-V
research tools both import the shared module.

No EA, Strategy Card, registry row, factory row, terminal setting, or pipeline gate was changed.  No terminal was launched and no
live or AutoTrading state was touched.

## Registered rerun

The frozen F1 universe / SEL / VAL / null sweep completed once with schema `qm.velocity-family-f1-sweep/v2`:

- 35 symbols, 315 defined cells, 314 populated cells;
- 30 cells passed the SEL rule;
- state counts: 148 `CLEAR_REJECT`, three `WORTH_MT5_TEST`, 164 `UNKNOWN`;
- all three `WORTH_MT5_TEST` cells are family-consistent: NZDJPY A2, USDJPY A3, and USDJPY A4;
- USDJPY C2: `UNKNOWN`, SEL 869 / +0.1856R / PF 1.409, VAL 559 / +0.0821R / PF 1.167;
- USDJPY C3: `UNKNOWN`, SEL 808 / +0.1518R / PF 1.369, VAL 528 / +0.0904R / PF 1.201.

C2/C3 are `UNKNOWN` because the bound archive contains inverted Bid/Ask facts on one or two historical dates and because their
tester-bound calendar allowed native high-impact release-anchor trades.  The harness does not repair or synthesize those values
or promote through a failed mandatory blackout.  These states are prescreen routing labels only, never economic validation or a
pipeline verdict.

## Golden reconciliation

- The April and July 2024 archived USDJPY ticks reproduce the tester-observed bid/ask pairs exactly.
- All 16 Q03 2024 entry-rejection dates overlap all 16 C2 v2 one-sided cancellations.
- The complete native source supplies 836 unique 08:30 New York anchors.  C2 has 94 / 100 / 88 eligible VAL placements in
  2023 / 2024 / 2025; only 23 / 37 / 10 were blocked, while 185 were accepted.
- The difficult-day ledger contains 321 dated placement/trade comparisons.
- The deterministic synthetic release-gap fixture proves one-sided cancellation and first-M1-open gap fills.
- The corrected C2 still disagrees materially with Q04 economics: harness PF 1.163 / 1.130 / 1.197 versus registered Q04 PF
  1.004 / 0.724 / 0.916 for 2023 / 2024 / 2025.  Economic equivalence therefore remains `UNKNOWN`.
- H-V4 / QM5_41485 remains permanent negative lineage `PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE`.

## Verification

```text
python -m py_compile tools/strategy_farm/session_tools/velocity_execution_harness_v2_0922.py tools/strategy_farm/session_tools/velocity_family_f1_sweep_0921.py tools/strategy_farm/session_tools/velocity_hv_prescreen_0921.py tools/strategy_farm/session_tools/velocity_harness_v2_golden_0922.py
python -m pytest tools/strategy_farm/tests/test_velocity_execution_harness_v2.py -q
# 11 passed

python tools/strategy_farm/session_tools/velocity_hv_prescreen_0921.py --years 2018-2025 --hyp HV2 --out <task-dir>/hv2_v2_smoke.json
# completed; shared v2 fill module exercised

python tools/strategy_farm/session_tools/velocity_harness_v2_golden_0922.py
# repeated generation: byte-identical golden and fixture JSON
```

The focused test suite covers the real `.tkc` quote pairs, one-sided release placement, buy/sell pending gaps, long/short
protective gaps, targets, no-gap behavior, point precision, deterministic serialization, and both prescreen imports.

## Artifacts

| file | SHA-256 |
|---|---|
| `velocity_family_f1_sweep_v2.json` | `1f4fb67ed444ad34f63ac7aa20b5341d86bbd63c10be21fceacebce6a1a49264` |
| `control_usdjpy_v2.json` | `3b3228a76567ea460632797b7b179adb05afa4ffd749a47ea22a5dff82a5d750` |
| `golden_comparison.json` | `87b643125c02c60e5eac564efb896534144078730dc6c94ecdf17a824e0ab497` |
| `synthetic_release_gap_fixture.json` | `726fcfc39b2ba4af6545cabe8a51edab1aeff6859f414ffb734b2e147208c20f` |
| `hv2_v2_smoke.json` | `83d92d7596bc4b00b373c0d07c6397348104f001a782706240c2825e563f2999` |

The fixed golden narrative is at
`docs/ops/evidence/2026-09-20_velocity_book/harness_v2_golden_test.md`; the research document contains the appended Revision 2.
