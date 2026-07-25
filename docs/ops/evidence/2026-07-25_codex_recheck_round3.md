# Codex Round-3 residual re-check

Date: 2026-07-25  
Branch: `agents/board-advisor`  
Reviewed base HEAD: `4106f12881cd`

Scope was limited to the five residual defects named in
`2026-07-25_codex_recheck_final.md`. I did not reopen previously accepted findings.

## Verdicts

**WP-9 — APPROVE — QM5_20123's duplicate per-member stress draw is removed; the news gate, `BASKET_PARTIAL_ABORT`, and logging input remain, while the tightened static contract passes 10 tests (plus 2 subtests).**

**WP-10 — APPROVE — in the supplied scratch copy, effective-seed parsing is Inputs-region scoped, both authentication axes resolve from one accepted run directory, and fresh evidence missing either axis is hard `INVALID`; all 40 copy tests pass.**

**WP-11 — APPROVE — normalized exact/nested live-directory checks now refuse CLI writes with exit 2 and direct function writes with `LiveBaselineGuardError` unless the `--deploy-live` route authorizes them; all 21 tests pass.**

**WP-2 — APPROVE — absent setfile hashes now refuse by default, `--allow-unverified` is a loud OWNER exception, and snapshots/revert fingerprint and guard the complete work-items/metrics/ledger triple; all 24 tests pass.**

**WP-6 — APPROVE — a v2 same-count destination is SHA-checked before admission and fails `q08_stream_sha256_mismatch` if unrepaired, while requeue requires the durable hash again during transaction-local reclassification and records `lineage_basis`; all 35 tests pass.**

No new defect was found in the Round-3 diffs.

## Commit go/no-go

**GO**, with these boundaries:

1. **WP-9 solo.**
2. **WP-5/WP-6/WP-7 as one atomic commit.**
3. **WP-2 solo.**
4. **WP-11 solo.**
5. **WP-10 only after the running Q07 batch has stopped:** apply the reviewed scratch
   implementation and tests to the repository, then commit them. Do not include scratch
   paths or batch-mutated generated setfiles.

## Verification notes

- The isolated WP-10 parser returned seed `42` from a real UTF-16 Q07 report and still
  returned `42` after an out-of-Inputs bold `qm_rng_seed=99` fragment was injected into
  a temporary copy.
- Read-only Q10 dry-runs against the current farm DB produced the claimed policy split:
  default `22` actions plus one `setfile_hash_unavailable` refusal for
  `QM5_12567/XNGUSD.DWX`; `--allow-unverified` produced `23` actions, including one loud
  unverified OWNER-exception action.

## Anything not verified

- Per instruction, I did not inspect, diff, execute, or replace the live repository
  `framework/scripts/q07_multiseed.py`, and I did not run the four new WP-10 tests against
  that live module.
- I did not compile MQL5, run a backtest, launch an MT5 terminal, or access
  `C:\QM\mt5\T_Live`.
- I did not apply or revert the live farm DB. Apply/revert behavior was exercised only by
  temporary unit-test databases.
- I did not execute a real Q08 re-export or Q09 requeue; WP-6 was verified by source
  control-flow review and the targeted unit suites.
- No commit was created.
