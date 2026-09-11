# QM5_41405 Balke stage-2 — build pre-flight refusal

Date: 2026-09-11

Router task: `dee2fc76-67c5-408e-9b05-e6a0271ea81c` (priority 89).

## Deterministic pre-flight

| Gate | Observation | Result |
|---|---|---|
| EA allocation | `framework/registry/ea_id_registry.csv` row 4887: `41405,balke-clock-audit-opt,...,active` | PASS |
| Magic tuple | `framework/registry/magic_numbers.csv` defines `41405,balke-clock-audit-opt,0,USDJPY.DWX,414050000,...,active` | PASS |
| Approved card status | `D:/QM/strategy_farm/artifacts/cards_review/QM5_41405_balke-clock-audit-opt.md` has `status: DRAFT` | FAIL |
| Approved card scope | its `g0_status: APPROVED` authority specifies only `strategy_clock_mode`, `strategy_outside_range_rule`, and `strategy_entry_buffer_pct` (0/5/10), with H1 range bars | FAIL for the assigned stage-2 expansion |
| Assigned source scope | task requires `strategy_entry_buffer_points` (0/20), `strategy_range_band_enabled`, `strategy_range_bar_period` (H1/M30/M5), and minute-granular `strategy_range_end_minute` | Not represented in the card’s approved build scope |
| Existing sibling | the reserved scaffold contains only `docs/strategy_card.md`; no QM5_41405 `.mq5` or `.ex5` exists | NOT_STARTED |

## Verdict

**Q-BUILD REVIEW — CARD_SCOPE_NOT_APPROVED.** The V5 build procedure does not
permit building from a DRAFT card or silently adding unapproved strategy inputs.
Registry and magic allocation are ready, but they do not substitute for an
approved card that exactly declares the stage-2 mechanism and 350-cell matrix.

No EA source, EX5, setfile, compile queue, work-item row, or backtest was
created. QM5_41398 remains untouched. No terminal was started or interrupted;
T_Live and AutoTrading remain untouched.

Required hand-back: replace or amend the card under the appropriate OWNER/G0
authority with `status: APPROVED`, exact input semantics, the fixed matrix and
selection/refutation criteria, and a backtest risk contract (`RISK_FIXED > 0`,
`RISK_PERCENT = 0`). The next build cycle can then create the sibling, submit
only a governed `COMPILE_EA` claim, prove the default cell identity, and
declare/enqueue the matrix without changing pipeline thresholds or verdicts.
