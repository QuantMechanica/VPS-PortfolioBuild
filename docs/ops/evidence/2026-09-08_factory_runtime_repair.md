# Factory runtime repair acceptance — 2026-09-08

User-authorized operational implementation; no trading, AutoTrading, deployment,
risk-parameter or gate-threshold changes. Existing unrelated worktree edits preserved.

Full German report in the requested Vault:
`G:/My Drive/QuantMechanica - Company Reference/08 Current State/2026-09-08 Factory Reparaturen und Abnahme.md`.

Evidence directory: `D:/QM/reports/maintenance/factory_repair_20260908`.
Read-only receipt generator: `verify_repairs.py` there.
Latest acceptance: `acceptance_20260908T131308Z.json`.

## Verified outcomes

- Ten worker replacements verified across the rolling reload receipts; all workers
  use terminal_worker source SHA b2fb61b1e2699bb4ea8c3f9e9a99a90bcf24cfe09f9d4b4c8e1b8311ba70d162.
  No active runner was killed; protected FTMO/T_Live PIDs 15464/31728 stayed alive.
- Missing-slot watchdog refill works; census/RAM-drain mutual starvation repaired.
- Empty attributable tester logs no longer crash PowerShell report aggregation.
- Hourly backup restored, ordered before statistics; fresh backup quick_check=ok.
- 9,244 closed HTML reports and one exact closed NDX staging binary compressed
  losslessly with per-file hash, length and timestamp verification. No deletion.
  D: 113.65 GiB before first batch, 136.65 GiB after batches, 133.84 GiB with active
  tests at final snapshot. Cold full-fleet admission OPEN; early reserve warning added.
- Q05 retry b975c126-0d66-497c-a5a8-2b57c62e9195 is PASS; 91 trades; native real-tick
  report and child-output log hashes independently verified. Old INFRA_FAIL retained.
- FTMO stale calendar alarms resolved only against newer complete same-identity
  current-month evidence; pulse WARN, not ALARM. Separate KS proof warnings retained.
- 48 new completed tests/census measurements since 12:34 UTC, no new INFRA_FAIL
  in that observation window. Balke matrix 576 measured / 1 active / 508 pending.
- 214 combined regression tests plus 35 additional Q04 tests passed (249 distinct).

## Not complete / must not be represented as green

- QM5_10116 stale compiled registry: two pending jobs safely held under
  COMPILED_MAGIC_REGISTRY_STALE. Governed rebuild and fresh Q02 lineage outstanding.
- Two Balke OOS windows repaired but legacy Q09_NEWS rows remain outside the current
  Q10_NEWS selector. A bound diagnostic migration is still needed; not gate admission.
- Q04 control 53f79d3c-ce57-41a0-8247-52ba7419b7b5 produced PASS with all three native
  reports hash-verified. F3's source summary hash then drifted because the worker
  appended staged_ex5 metadata after aggregation. This defect is explicitly retained
  in acceptance evidence. Commit 5f6873c6a6 captures immutable source-summary bytes
  for NEW Q04 runs; 35 tests passed, but its fresh native runtime acceptance is pending.
  Do not rewrite the old verdict/hash or claim that old chain is fully sealed.
- The ordinary dispatcher already started the control's Q05 successor
  3f961b6d-ef42-4b54-b837-090e2cb44cba. It was not interrupted. Further qualification
  must resolve the upstream summary-integrity finding rather than treating PASS alone
  as sufficient. Three earlier Q04 repairs remain pending.
- Overall health still contains real historical backlog, evidence-loss, artifact/news
  binding and backup-continuity findings. These were not suppressed or papered over.

This is verified operational progress, not a claim of an entirely green factory,
completed strategy qualification, FTMO payout, or Darwinex allocation.
