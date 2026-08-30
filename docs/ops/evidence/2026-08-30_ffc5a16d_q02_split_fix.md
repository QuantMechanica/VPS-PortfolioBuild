# Q02 evidence-loss split correction — execution evidence

- Router task: `ffc5a16d-3045-4eab-a351-bacd554545a0`
- OWNER decision: `OWNER-DEC-Q02-SPLIT-FIX-20260830` (`YES`, receipt `46a35bd9`)
- Controlling classification: `2026-08-29_q02_stranded_pairs_classification.csv`
- Classification SHA-256: `ca1fe0da1f7ccb7560bcd641776a7e6bbe1090685933cbd825abed4ecadbe84e`
- Derived manifest rows SHA-256: `3b5137776590c06422840f67a70bcaccc1f166737823317d7bef194676a311e0`
- Execution plan: `2026-08-30_ffc5a16d_q02_split_fix_plan.json`
- Execution plan SHA-256: `230d6236d2d1e880f26cc265c366fb9e394ec29eb978ef65a46b919ec38220fb`
- Apply receipt: `2026-08-30_ffc5a16d_q02_split_fix_receipt.json`
- Apply receipt SHA-256: `6c80daada00f229d95a164a430b0293e8673fddc3a9b845f7a277f504237aa24`
- Applied at: `2026-08-30T07:03:13+00:00`

## Mechanical derivation

The CSV contains exactly 34 unique EA/symbol rows. The OWNER mapping was
applied verbatim, with no discretionary selection:

- `RESTART` (20): `ACTIVE_TIMEOUT` (16),
  `TIMEOUT_METATESTER_HUNG` (2), `NO_HISTORY_TRANSIENT` (2).
- `RETIRE` (14): `SETFILE_MISSING` (6), `ONINIT_FAILED` (4),
  `SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE` (3), `LOG_BOMB` (1).

The manifest contains four five-row restart batches. All 20 successors are
append-only. Batch 1 is claimable; batches 2–4 carry active
`Q02_SPLIT_FIX_STAGED_BATCH` item holds, so no more than five decision rows can
be in flight. These recovery rows do not receive `priority_track`, preserving
the opt-census claim lane's precedence.

The bounded missing-predecessor-evidence exception is explicit in every restart
payload and binds the successor to the exact classification CSV path and hash.
Every restart also binds the current MQ5, EX5, and fixed-risk setfile bytes;
`RISK_FIXED > 0` and `RISK_PERCENT = 0` were required before plan creation.

The 14 structural rows receive append-only, canonical `status=done`,
`verdict=RETIRE`, `verdict_taxonomy=strategy`, `sh3_enforced=0` disposition
successors. Source work-item verdicts, evidence paths, payloads, and statuses
are not updated. Both restart and retirement successors receive canonical
`work_item_supersedes` edges to the immutable source rows.

## Verification contract

The apply is one `BEGIN IMMEDIATE` transaction under the shared Factory
mutation lock after an online SQLite backup. It revalidates all 34 source rows,
artifact hashes, absence of open pair rows, and absence of prior supersession.
Postconditions require exactly 20 restart successors, 14 RETIRE successors,
five claimable restart rows, 15 held restart rows, zero historical work-item
updates, and `PRAGMA quick_check=ok`. The JSON receipt is the durable per-batch
readback.

Apply passed all postconditions: 34 new rows (20 pending backtests and 14 done
RETIRE dispositions), five claimable restart rows, 15 active staged-batch holds,
zero historical work-item updates, and `PRAGMA quick_check=ok`. The online
pre-mutation backup is hash-bound in the receipt.
