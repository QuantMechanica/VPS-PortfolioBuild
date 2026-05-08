## ZT Root Cause Draft — QM5_SRC04_S03 (2026-05-05)

- EA: `QM5_SRC04_S03_lien_fade_double_zeros` (`ea_id=1009`)
- Strategy Card: `SRC04_S03` (`strategy-seeds/cards/lien-fade-double-zeros_card.md`)
- Drafted by: CTO (for Strategy-Analyst/R-and-D signoff chain)
- Protocol: `qm-zero-trades-recovery`

### Detection

- P2 probe reports produced valid artifacts (no compile/setup failure), but no trades.
- Latest 5-symbol mini-cohort (expected-to-trade baseline slice) returned:
  - `MIN_TRADES_NOT_MET` on all symbols
  - trade counts `0/0` (two runs, both zero) on all symbols

### Cohort Table (5-symbol baseline slice)

| Symbol | Period | Runs | Trades (run1/run2) | Verdict class |
|---|---|---:|---:|---|
| EURUSD.DWX | M15 | 2 | 0 / 0 | MIN_TRADES_NOT_MET |
| GBPUSD.DWX | M15 | 2 | 0 / 0 | MIN_TRADES_NOT_MET |
| USDJPY.DWX | M15 | 2 | 0 / 0 | MIN_TRADES_NOT_MET |
| XAUUSD.DWX | M15 | 2 | 0 / 0 | MIN_TRADES_NOT_MET |
| AUDUSD.DWX | M15 | 2 | 0 / 0 | MIN_TRADES_NOT_MET |

ZT cohort count = **5/5** (threshold met for full dispatch chain).

### Disambiguation Notes

- Prior infra-modal failures (`REPORT_MISSING/METATESTER_HUNG/INCOMPLETE_RUNS`) were reduced by toolchain fixes in:
  - `framework/scripts/p2_baseline.py`
  - `framework/scripts/run_smoke.ps1`
- Current blocker is strategy-level no-fill/zero-trade behavior, not build or report export failure.

### Hypothesis (v2 candidate)

Primary hypothesis:
- Entry staging lifecycle is too restrictive for live fills in this implementation profile:
  - stop-entry offset + proximity gate + short order expiration (`order_expiration_minutes=60`) likely causes staged stops to expire before trigger.

Proposed v2 change (single-axis, entry-side only):
- Increase `order_expiration_minutes` default from `60` -> `240` while keeping exit logic unchanged.

Rationale:
- This is a minimal entry-module adjustment aligned with zero-trade recovery and Enhancement Doctrine boundaries (no simultaneous exit rewrite).
- If fills appear after this change, follow-on sweeps can tune offsets/proximity; if still 5/5 ZT, escalate to next iteration hypothesis.

### Required Signoff / Dispatch

- R-and-D verdict required: `acknowledged` or `reject-<reason>`.
- On `acknowledged`, CEO dispatches `v2` build sub-issue for CTO.
- If rejected as session-bound/not-repairable, mark terminal recommendation explicitly.

### Evidence References

- `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/report.csv`
- `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/p2_QM5_SRC04_S03_result.json`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QUA-743_EXECUTION_UNBLOCKED_MINTRADES_2026-05-05.md`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QUA-743_P2_RETRY_PROBE_2026-05-05.md`
