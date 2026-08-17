# QM5_20177 guarded-run status — mandatory Codex review

Date: 2026-08-17

Review task: `da7f2cdc-7fbf-45e8-9fa5-c73b47d4fec9`

Gemini source task: `141b8518-0be0-4c1d-87a3-3e8a2f20e14b`

Reviewed artifact: `docs/ops/evidence/141b8518_qm5_20177_guarded_run_status_2026-08-17.md`

Reviewed commit: `55788fb9c404a74a6f56cd977a8820d4cf0240d2`

## Verdict

`RECYCLE_WAITING_PIPELINE_EVIDENCE`

The artifact is acceptable as a statement that the guarded Q02 canary is still
pending, but it is not accurate enough to approve as the eventual comparison
record. Two baseline values are materially wrong, and its zero-trade decision
rule asserts a conclusion that a single backtest cannot establish. The guarded
row has no pipeline evidence or verdict, so neither this review nor the Gemini
task may advance to PIPELINE.

## Evidence checked

- `farmctl.py work-items --ea QM5_20177` reports guarded row
  `af79d508-0959-4a93-bd2d-f3178a68f633` as Q02 `pending`, with no evidence
  path and no verdict.
- The same operator view reports all six completed pre-fix rows as
  `DRAFT_DEFECT`. This is the current governed state after the defective-binary
  reconciliation; the Gemini note's single-predecessor description is now
  incomplete.
- The repaired identities stated in the Gemini note match the bound canary:
  MQ5 `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71`,
  EX5 `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796`,
  and setfile
  `20e75b585034f0af6e1b6c0b3b16aaf9d50c1eb10b2abc3519c999e72fdb584b`.
- The bound USDJPY setfile remains compliant: `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- Focused build-guardrail validation passed seven files with the enforced
  stale-news ceiling of 336 hours and no findings.
- Commit `55788fb9c` changes only the status document; it contains no source,
  binary, setfile, or pipeline mutation.

## Required corrections

The canonical pre-fix USDJPY evidence is:

`D:/QM/reports/work_items/c7f7a083-837c-470e-9501-fec5eb566f28/QM5_20177/20260816_181004/summary.json`

Its first run records:

| Metric | Evidence value | Gemini artifact value | Review |
|---|---:|---:|---|
| Trades | 8 | 8 | correct |
| Profit factor | 0.00 | 0.00 | correct |
| Net profit | -$73.01 | -$8,000.00 | incorrect |
| Drawdown | $73.01 / 0.07% | 7.8% | incorrect |

The note's explanation of a `$1,000` loss per trade is therefore unsupported
by the cited run. Fixed risk is a sizing input, not evidence that every trade
realized the full fixed-risk amount.

The decision rule must also be narrowed. A zero or near-zero trade count in the
guarded window would establish only that the repaired binary observed no or few
qualifying entries in that test interval. It would not prove that the entry
rule mathematically precludes valid target reachability. The corrected static
reachability fixture independently demonstrates valid bullish and bearish
formations for the current mechanics. Any card amendment remains a separate,
explicitly governed decision and cannot be inferred or silently implemented
from this pending run.

## Close condition

Keep the Gemini task and this mandatory review in REVIEW. When row `af79d508`
has terminal pipeline evidence, replace the placeholders with the four exact
reported metrics, compare them with the corrected baseline above, and make no
economic claim beyond the pipeline verdict. No terminal was started and no
backtest was interrupted during this review.
