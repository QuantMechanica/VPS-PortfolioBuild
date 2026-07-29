# MNT-023 — ratified DXZ next-book trigger

Date: 2026-07-29
Authority: OWNER

`BETTER` is deterministic and requires a like-for-like sealed OOS comparison with:

- OOS Sharpe delta **at least +0.06**; and
- MaxDD worsening **at most +0.05 percentage points**; and
- a PASS robustness status for the challenger evidence.

The classifier is `tools/strategy_farm/portfolio/dxz_next_book_trigger.py`. A mismatched
comparison-basis hash fails closed. Live/probation observations remain a separate output
axis and cannot be mixed into either OOS metric block. Correlation contribution and
operational complexity remain visible review axes; they are not silently blended into the
ratified numeric thresholds.

`BETTER` unlocks an OWNER review. It never changes weights, manifests, presets, T_Live,
AutoTrading, or deployment state. The remaining deterministic classes are
`MATERIAL_BUT_REVIEW` and `NO_MATERIAL_GAIN`.
