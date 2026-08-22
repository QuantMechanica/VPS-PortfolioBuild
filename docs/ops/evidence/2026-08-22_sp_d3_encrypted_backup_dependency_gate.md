# SP-D3 encrypted backup dependency gate

Date: 2026-08-22  
Disposition: DEFER — ROT-4 key-custody/recovery contract is not available

## Decision

SP-D3 says encryption must not be activated before ROT-4 and requires a separately managed recovery key. No completed ROT-4 task, ratified key-custody document, recovery ceremony receipt, key locator, or restore authority was present in the canonical repository or deterministic router records available to this worker. The referenced company ToDo index is on unavailable drive `G:` in this headless session, so it cannot establish the missing authorization.

Creating an encrypted backup now would risk producing data that cannot be recovered. Inventing a key, storing one in the repository, or choosing an unapproved external key location would violate the task's hard constraints. Consequently this cycle did not create a staging bundle, generate credentials, enable retention deletion, or install a missing-backup alarm.

## Read-only source baseline

The canonical source database was opened read-only with `PRAGMA query_only=ON`:

- Source: `D:/QM/strategy_farm/state/farm_state.sqlite`
- `PRAGMA quick_check`: `ok`
- `work_items`: 111,562 rows
- `agent_tasks`: 1,548 rows
- Check elapsed time: 1.102 seconds

This is only source-health evidence. It is not a backup receipt and must not be represented as SP-D3 acceptance.

## Missing ROT-4 contract elements

Before SP-D3 execution, an OWNER-approved ROT-4 artifact must durably specify at least:

1. encryption format and implementation;
2. key generation authority and custody locations separated from the bundle;
3. recovery principals, quorum/approval, and emergency access process;
4. key rotation, revocation, loss, and personnel-offboarding rules;
5. a tested decrypt-and-restore ceremony with durable receipt;
6. the alert destination and authority to configure it;
7. exact backup source allowlist and restore-required terminal-data allowlist;
8. retention deletion authority for 14 daily, 8 weekly, and 12 monthly generations.

## Next authorized execution

Once ROT-4 is ratified, implement an online SQLite backup into staging, run `quick_check` and core queries against the staged copy, write a content/SHA-256/schema manifest, encrypt using the approved external key reference, verify decryption and restore, atomically publish the `COMPLETE` marker, then activate retention and the missing-day/marker alarm. The receipt must distinguish source health, backup integrity, encryption verification, and restore verification.

No existing backup, scheduled task, credential store, or retention set was modified.
