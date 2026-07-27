# Q02 log-bomb subclass correction and restamp

Date: 2026-07-27

The corrected classifier from commit `8e0e81f47` was applied to the live Q02
summary-missing population. Pre-apply inspection found 43,037 applicable rows
and 11,062 payloads requiring correction. Apply completed with
`changed=11062`, `skipped=0`.

Resulting subclasses: pair_has_verdict 29,444; pair_open 12,479; never_worked
930; input_missing 181; transient_token 3. No synthetic log_bomb bucket
remains. Revert snapshot:
`D:\QM\reports\state\classify_summary_missing_Q02_20260727T212821Z.json`.

No status, verdict, attempt count, queue state, or EA source changed. QM5_10923
remains a variant-only backlog item because it holds real verdict evidence.
Focused classifier/health verification: 32 tests passed.

