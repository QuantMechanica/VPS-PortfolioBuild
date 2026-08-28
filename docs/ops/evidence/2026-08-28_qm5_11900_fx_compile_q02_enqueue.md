# QM5_11900 stale-binary FX repair — governed compile and Q02 handoff

Date: 2026-08-28

Branch: `agents/board-advisor`

EA: `QM5_11900_kobasfx-4ema-macd-sentiment-h1`

Farm task: `46e34047-c661-462c-96d5-b4f9d76914db`

Outcome: **COMPILE_OK; ONE USDCHF Q02 REQUALIFICATION SEED ENQUEUED**

## Selection and collision control

The live build backlog had no collision-free, genuinely unbuilt G0-approved
card. The only nominal unbuilt candidates were already claimed on another
agent lane. The existing priority-100 `q02_infra_repair` task for QM5_11900 was
therefore advanced instead. It is assigned to `codex:agents/board-advisor` and
covers ten H1 FX symbols, adding instrument diversity relative to the current
index/metal/energy Q08 survivors. No strategy mechanics or source decision was
changed in this unit; the card retains its durable OWNER approval.

The repaired source/spec/set work was already reviewed in commit `59149dfad`.
The historical EX5 SHA-256 was
`16c7f328707e6e530360090a4e91e319bab02518dccd0b8cd5c0e65d787e2cfa`.
It predates QM5_11900's active magic allocation and produced infrastructure-only
`ONINIT_FAILED` / `INCOMPLETE_RUNS` Q02 evidence.

## Governed compile

The exact source-repair authority
`router_q02_infra_repair:46e34047-c661-462c-96d5-b4f9d76914db` admitted one
`COMPILE_EA` work item:

- work item: `32c7be48-1585-4011-949c-52644c598780`;
- MQ5 SHA-256:
  `261570f12ae7708e58c64f008a9029df35e147882b716cc4143e807ebb41a656`;
- activation hold released at `2026-08-28T15:41:03Z`;
- claimed by canonical worker T5 at `2026-08-28T16:19:48Z`;
- completed at `2026-08-28T16:22:17Z` as `done / COMPILE_OK`;
- new EX5 SHA-256:
  `befa7d6b8877434ea5d376429507d171ed48feaa02f2b5574ea2b55a9c637e76`;
- strict build check: PASS, zero failures and zero warnings;
- MetaEditor compile: PASS, zero errors and zero warnings;
- failure classes: empty.

The governed receipt is
`D:\QM\reports\work_items\32c7be48-1585-4011-949c-52644c598780\QM5_11900\COMPILE_EA\compile_evidence.json`.
The successful hold release was backed by
`D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260828T154015Z_b01a82bb.sqlite`
(SHA-256
`20d81b0eb5cd7100df73b712951c49bb5394a5c6acd2c9d1621022d165cb497d`).
An earlier lock-contended release attempt wrote a separate recoverable backup
but made no database transition.

All ten H1 backtest setfiles were regenerated and finally bound. They retain
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and registered
magic slots 0–9. No setfile retains `build_hash: pending`. The USDCHF slot-8
setfile used by the canary has SHA-256
`6b186956e5220de07fd9ca7b9ba1adb6bd8bc1fd1ec472ba233728652b1f4db4`.

### Commit-provenance portability

The governed worker correctly bound the exact raw Windows MQ5 bytes supplied
to MetaEditor (`261570f1...`), while Git staged the same text as its durable
LF-normalized blob (`a73d12dd75d4afd463539341090eef2ef1df67dcdb369b1df95587cb8eb45586`).
The pre-commit EX5 guard originally treated those byte representations as a
source mismatch. Its fallback is now restricted to the established
CRLF-to-LF text contract: the receipt must bind the exact raw working-copy
hash, and replacing only CRLF byte pairs must reproduce the staged blob
byte-for-byte. BOMs, standalone CRs, whitespace, and all semantic bytes remain
significant. The real staged EX5 now passes against governed receipt
`32c7be48-1585-4011-949c-52644c598780`; a regression test proves that a
semantic working-copy change is still rejected.

## Append-only Q02 handoff

The first ordinary append-only command omitted the now-required identical
`--from-work-item-id` selector and was rejected without mutation. The corrected
ordinary command then failed closed because the July timeout row's referenced
runtime log had been pruned. No missing evidence was recreated or bypassed.

The sanctioned `seed-fresh-q02` path was used instead. It authenticated the
preserved terminal pre-binding USDCHF row
`cc20795e-fa50-4a65-9107-f205308593c2` (`done / INFRA_FAIL`,
`ONINIT_FAILED;INCOMPLETE_RUNS`), the current canonical binary, the current
fixed-risk setfile, and the unchanged execution identity. The first seed
attempt encountered a transient SQLite writer lock and made no row; the
bounded retry created exactly one successor:

- work item: `4d8a8d50-0756-434d-84be-721098f8bb78`;
- initial state: `pending`, unclaimed, attempt 0, no verdict;
- phase/contract: `Q02 / v4`;
- symbol/timeframe: `USDCHF.DWX / H1`;
- expected MQ5/EX5/setfile hashes exactly match the repaired artifacts above;
- payload: `fresh_q02_seed=true`, `pre_binding_source_verified=true`, and
  `historical_work_item_preserved=true`;
- risk binding: `risk_fixed=1000.0`, `risk_percent=0.0`;
- custom-history archive admission: `ACTIVE`, bound to `USDCHF.DWX`.

Readback found one and only one successor for the predecessor. The predecessor
remains unchanged as `done / INFRA_FAIL`. Execution is left to the paced farm;
no manual dispatch or tester launch was performed.

## Verification

- `skill_build_ea_guard.py`: PASS for EA registry, magic rows, and EA directory.
- `validate_spec_doc.py`: 1 PASS, 0 FAIL.
- `validate_build_guardrails.py`: PASS across 11 files, zero findings.
- `test_compile_work_items.py`: 26 passed.
- `test_release_compile_wave.py`: 3 passed.
- `test_candidate_repair_enqueue.py`: 42 passed.
- `test_validate_ex5_commit_guard.py`: 8 passed, including CRLF/LF acceptance
  and semantic-drift rejection.
- `validate_ex5_commit_guard.py`: PASS for the staged QM5_11900 EX5 and exact
  governed compile receipt.
- Pre-enqueue whole-host CPU samples at `2026-08-28T16:23:05Z`:
  61.74%, 53.93%, 69.16%, 72.63%, 72.65% (average 66.02%, maximum
  72.65%). The 97% stop ceiling was not reached.
- The corresponding slot scan reported zero running factory terminals, zero
  duplicate workers, and zero orphaned work-item processes.

The ambient T_Live and external FTMO terminal processes were only observed by
the read-only slot scan. No AutoTrading action, T_Live write, deploy-manifest
change, portfolio-gate change, portfolio admission, or certification claim was
made.

Machine-readable receipt:
`artifacts/qm5_11900_fx_compile_q02_enqueue_20260828T162732Z.json`.
