# Symbol-literal source repair — batch 2 (nine uncompiled EAs)

Date: 2026-09-13
Branch: `agents/board-advisor`
Hard Rule: "Symbols are inputs, never code literals" (OWNER 2026-09-06;
`01 Identity/Hard Rules` annex; `V5_FRAMEWORK_DESIGN.md` principle 7).
Trigger: `EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX` flagged these nine EAs after
their framework-input pins were repaired in commit `14d548c87a`.

## Scope guard (read-only DB, `farm_state.sqlite?mode=ro`)

Eligibility rule: touch an EA source only if it has no `COMPILE_OK` row and no
work item in any phase beyond `COMPILE_EA`. `work_items` phase/status/verdict:

| EA | work_items | Eligible |
|---|---|---|
| QM5_20042 | (none) | yes |
| QM5_20053 | (none) | yes |
| QM5_41135 | (none) | yes |
| QM5_41138 | (none) | yes |
| QM5_41157 | (none) | yes |
| QM5_41160 | (none) | yes |
| QM5_41181 | (none) | yes |
| QM5_41187 | COMPILE_EA / failed / COMPILE_FAIL | yes (not beyond COMPILE_EA) |
| QM5_41188 | COMPILE_EA / failed / COMPILE_FAIL | yes (not beyond COMPILE_EA) |

No compile, enqueue, terminal start, or T_Live action was taken. Only the nine
`.mq5` sources were edited. All nine existed at baseline commit
`bb584c73239c5bd9f7ba98d2bf5863bafa8cfe48`.

## Fix pattern

Two-leg baskets (41135/41138/41157/41160/41181/41187 = XAU/XAG; 41188 = XTI/XNG),
literal-free form per the QM5_41374 patch:
- Added the missing host-leg `input string strategy_<host>_symbol = "<HOST>.DWX";`
  (the foreign-leg input already existed); both defaults equal the old literals so
  backtests stay identical.
- Blanked the hardcoded globals: `string g_leg_<x> = "";` populated from the
  inputs in `OnInit` (host assignment added alongside the existing foreign one).
- `Strategy_InputsValid()` now validates via base names, no literal inside the
  canonical call: both inputs non-empty, the two legs differ, and
  `QM_MagicSymbolCanonical(<host>_symbol) == QM_MagicSymbolCanonical(_Symbol)`.

Single-symbol hosts (20042 = XBRUSD, 20053 = XCUUSD), per the QM5_41470 patch:
- Added `input string strategy_host_symbol = "<HOST>.DWX";`.
- Host-chart test rewritten to
  `QM_MagicSymbolCanonical(_Symbol) == QM_MagicSymbolCanonical(strategy_host_symbol)`
  (fails closed on an empty input; `_Symbol` is never empty).

No strategy-logic, risk, magic-slot, or numeric-pin changes.

## Verification results (all after edit)

Lint = `lint_ea_symbol_literals.py --ea-root`; Inv FAIL = FAIL-severity findings
from `ea_symbol_literal_inventory.py --ea-label` (baseline `bb584c73…`); Pin =
`audit_framework_input_pins.py --check-source` `EA_FRAMEWORK_INPUT_PINNED`
hit_count; Gate = `build_gate_hardening.py --ea-label` failures.

| EA | lint before | lint after | Inv FAIL | Pin hits | Gate failures | Gate warnings |
|---|---:|---:|---:|---:|---|---:|
| QM5_20042 | 1 | 0 | 0 | 0 | 1 (pre-existing DWX-matrix gap) | 0 |
| QM5_20053 | 1 | 0 | 0 | 0 | 1 (pre-existing DWX-matrix gap) | 0 |
| QM5_41135 | 3 | 0 | 0 | 0 | 0 | 3 |
| QM5_41138 | 3 | 0 | 0 | 0 | 0 | 3 |
| QM5_41157 | 3 | 0 | 0 | 0 | 0 | 3 |
| QM5_41160 | 3 | 0 | 0 | 0 | 0 | 3 |
| QM5_41181 | 3 | 0 | 0 | 0 | 0 | 3 |
| QM5_41187 | 3 | 0 | 0 | 0 | 0 | 3 |
| QM5_41188 | 3 | 0 | 0 | 0 | 0 | 3 |

Inventory after: two-leg EAs show 2 `ALLOW` (the two `input string` defaults),
0 FAIL; single-symbol EAs show no findings (XBRUSD/XCUUSD are outside the
inventory scanner's symbol vocabulary), 0 FAIL.

Gate warnings on the seven two-leg EAs are the three pre-existing
card-undecidable notices (`EA_CARD_LOSS_LIMIT_UNDECIDABLE`,
`EA_BROKER_TIME_WINDOW_UNDECIDABLE`, `EA_CARD_PENDING_ORDER_UNDECIDABLE`) — no
unique approved card file; unrelated to symbols.

## Remaining blockers

- **QM5_20042 — `EA_SYMBOL_NOT_IN_DWX_MATRIX` (pre-existing, out of scope).**
  `XBRUSD.DWX` is not an exact row in `framework/registry/dwx_symbol_matrix.csv`.
  `build_gate_hardening` D11 cites `magic_registry:line=15114:slot=0:status=active`,
  `setfile_content:.../QM5_20042_brent-dom17_XBRUSD.DWX_D1_backtest.set:7`, and the
  setfile name — none cite the `.mq5`, confirming the fix did not introduce it.
  Registry not changed (ROT / OWNER). D11 will keep blocking compile until
  `XBRUSD.DWX` is added to the matrix.
- **QM5_20053 — `EA_SYMBOL_NOT_IN_DWX_MATRIX` (pre-existing, out of scope).**
  `XCUUSD.DWX` missing from the matrix. D11 cites
  `magic_registry:line=15143:slot=0:status=active` and
  `setfile_content:.../QM5_20053_xcu-weekend-prem_XCUUSD.DWX_H1_backtest.set:5`.
  Same disposition: registry unchanged; compile stays blocked on D11.

The DWX matrix currently carries XAUUSD/XAGUSD/XTIUSD/XNGUSD (verified present),
so the seven two-leg EAs have no matrix gap.

## Result

Symbol-literal build gate: **all nine pass** (lint 0, inventory 0 FAIL, pin 0).
Seven two-leg EAs are fully unblocked for compile. QM5_20042 / QM5_20053 remain
blocked only by the pre-existing missing-DWX-matrix-row gap, which requires an
OWNER/registry decision outside this ticket.
