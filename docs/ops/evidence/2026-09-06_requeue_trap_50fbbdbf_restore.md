# 2026-09-06 09:09–09:12Z — Requeue trap on Q04 row `50fbbdbf` (QM5_41171 / XTIUSD.DWX) and byte-exact restore

**Class:** operator error (Claude, CEO loop), self-detected within 90 s, fully reversed. Recorded because a terminal verdict was overwritten in place for ~3 minutes, which the append-only rule forbids.

## What happened

1. 09:09:27Z — `farmctl enqueue-backtest --ea QM5_41171 --phase Q04 --from-work-item-id 30990e06-…` was issued **without** `--append-only-rerun-of`, intending to create the Q04 successor of the new-identity Q02 PASS (`30990e06`, EX5 `cbddfa32…`).
2. Because a terminal Q04 row already existed for (EA, symbol) — `50fbbdbf` (done, `PASS_LOWFREQ`, EX5 `828efc29…`, pre-fix binary) — the cascade path took the `existing` branch (`farmctl.py` ~L29510): `UPDATE work_items SET status='pending', verdict=NULL, attempt_count=0, evidence_path=NULL, claimed_by=NULL, payload_json=<new>, updated_at=<now>` and moved the report root `D:\QM\reports\work_items\50fbbdbf…` → `…requeued_20260906T0909270000`. The pipeline evidence dir `D:\QM\reports\pipeline\QM5_41171\Q04\XTIUSD.DWX__50fbbdbf…` was untouched.
3. The row was never claimed (checked before the restore: `pending`, `claimed_by NULL`).

## Restore (09:11:33Z)

- Pre-restore DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_restore_50fbbdbf_20260906T091133Z.sqlite` (701 MB, sqlite backup API).
- Source of truth for the prior state: `D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260906T083545Z_87d9a1cb.sqlite` (row snapshot saved as `row_50fbbdbf_backup_083545Z.json` in the session scratchpad; the row had not changed between 04:51Z and 09:09Z).
- Guarded `UPDATE … WHERE id=? AND status='pending' AND claimed_by IS NULL AND verdict IS NULL` restoring `status=done`, `verdict=PASS_LOWFREQ`, `attempt_count=0`, `evidence_path`, `payload_json` (byte-identical), `updated_at=2026-09-06T04:51:33+00:00`. rowcount = 1.
- Report root moved back (`os.rename`), all three run directories present (`20260906_044807`, `…044950`, `…045048`).
- Ledger: `work_item_transition_ledger` action `restore_after_erroneous_requeue`, idempotency key `restore-after-erroneous-requeue:50fbbdbf-…:20260906T091133Z`, run_id `claude-session-018mXkPPkaHQ2fPuduPCBcWc`.
- Verification: the six compared columns and the payload match the backup exactly.

## Correct successor

`farmctl enqueue-backtest --ea QM5_41171 --phase Q04 --from-work-item-id 30990e06-… --append-only-rerun-of 50fbbdbf-… --rerun-reason "…" --expected-current-ex5-sha256 cbddfa32…` (result recorded in OPEN_ITEMS 09:1xZ).

## Rule (re-affirmed, memory `feedback_enqueue_backtest_requeue_trap_2026-08-22`)

For **any** phase, if a terminal row exists for (EA, symbol, phase), `enqueue-backtest` without `--append-only-rerun-of` requeues that row **in place** and erases its verdict from the DB. Always pass `--append-only-rerun-of <terminal row>` (plus `--expected-current-ex5-sha256` after a rebuild). The pump does not cascade a new-identity chain past a phase that already has a terminal row — the successor must be enqueued append-only by hand.
