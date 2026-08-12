# Q02 log-bomb subclass correction and restamp

Date: 2026-07-27

## Result

The corrected classifier from commit `8e0e81f47` was applied to the live Q02
summary-missing population. It requires a genuine artifact
(`verdict_reason=LOG_BOMB`, `LOG_BOMB` in `reason_classes`, or a
`log_bomb_journal*` payload field); attempt count alone is no longer evidence.

Pre-apply inspection found 43,037 applicable rows and 11,062 payloads requiring
a corrected stamp. The apply completed with `changed=11062` and
`skipped(row_changed_since_inspection)=0`. The resulting subclasses contain no
synthetic `log_bomb` bucket:

- `pair_has_verdict`: 29,444
- `pair_open`: 12,479
- `never_worked`: 930
- `input_missing`: 181
- `transient_token`: 3

The reversible pre-write snapshot is
`D:\QM\reports\state\classify_summary_missing_Q02_20260727T212821Z.json`.
No status, verdict, attempt count, queue state, or EA source was changed.

QM5_10923 remains a backlog item: it is the genuine latent per-tick emitter
identified by the family diagnosis and holds real verdict evidence, so any
remediation must be a new variant rather than an in-place edit.

## Verification

The classifier dry-run and apply agreed exactly on the 11,062-row delta.
Focused classifier/health tests passed as part of the follow-on verification:
`32 passed`.

