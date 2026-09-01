# Q09 REQUAL-8 pair 5 release and pair 6 governed-build handoff

- Recorded: `2026-09-01T08:19Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR5_RELEASED_PAIR6_BUILD_PENDING`

## Outcome

Pair 5 crossed its complete serial boundary. Its governed build, mechanical
Codex review, and append-only Orchestrator review were revalidated. The
manifest's canonical enqueue command then created exactly one Q02 seed. Only
after that seed was verified was pair 5's exact manifest hold released with the
manifest's verbatim note.

The release used the global factory-mutation lock, a fresh SQLite backup, an
exact compare-and-swap, append-only transition and event evidence, and
before/after snapshots of the protected `QM5_41162 OPT_CENSUS` program. No
historical work-item or rejected-review row was updated.

Only after the release, pair 6 passed its approved-card, registry, magic,
resolver, symbol, parent-byte, and authentic-frequency preflights. Exactly one
governed `build_ea` task was created. Pair 6 has no source, EX5, setfile,
compile row, review, or Q02 work item at this checkpoint, and its manifest hold
remains active.

No terminal was started manually, no active T1-T10 test was interrupted, and
neither AutoTrading nor `T_Live` was changed. This checkpoint creates queue
state only and asserts no pipeline verdict.

## Pair 5 build and review bindings

Pair 5 binds parent `QM5_12567_cum-rsi2-commodity`, successor
`QM5_41219_cum-rsi2-commodity-requal8`, and `XAUUSD.DWX D1`.

- Build task: `da8e6083-8e62-43a7-85f4-68d009383e96`, `done`
- Build commit: `a9767089d9`
- Build-result SHA-256:
  `1356fb70738f0f66b98bfe44436fe5b19cbd968c597f2f8f5a3f3c1d9a2ffb52`
- MQ5 SHA-256:
  `cd2a0ac6e3f4a677cbb30197e23eaeb8338f06f69d66341eeedfc45cb68746b3`
- EX5 SHA-256:
  `e9670141e89249aff7df44a10a2402e2103aa4cecf8d0a35a8cd6d6babedf108`
- SPEC SHA-256:
  `15ba5e9758af5ef557c1877dfac8a91441d7c7e44e1655c0956807e12b2f8eda`
- Backtest-set SHA-256:
  `297081b5b1e8aa70e76246b1cdaafdd38807305c5e8d05db59e5d63998fa180a`
- Mechanical Codex review:
  `572faf34-4117-48d8-b350-212358b1d9e9`, `done/PASS`, verdict artifact
  SHA-256 `42d1160581f8b67bf2e553082ce04d18aa84288678e5aacf25395c460b00fee6`
- Historical independent review:
  `a3db9bf9-5556-4599-b099-d1862b12b56e`, `done/REJECT_REWORK`, preserved
  untouched as append-only evidence
- Fresh OWNER-materialized independent review:
  `d552057d-e574-4b5f-8dbf-cadab0a30c01`,
  `done/APPROVE_FOR_BACKTEST`, verdict artifact SHA-256
  `368f9a12530ac0888f74e745aa7c6fc02ab84da7737e230329bc21c75a144d16`

The fresh review resolves only the prior authority misread. It binds the build
to the exact OWNER-approved REQUAL-8 manifest while retaining the historical
rejection. It does not overwrite any earlier verdict.

## Pair 5 append-only Q02 seed

The exact manifest command was run once:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id d552057d-e574-4b5f-8dbf-cadab0a30c01 --phase Q02
```

It created exactly one row:

- Parent task: `7c6dfe84-4d54-4b21-a0bc-c4807cb0709a`
- Q02 work item: `f3391b2d-5f61-4548-ac51-c66781545ce4`
- Identity: `QM5_41219`, `XAUUSD.DWX`, `D1`
- Verified state: `pending`, unclaimed, attempt `0`, no verdict
- Predecessor/review binding:
  `d552057d-e574-4b5f-8dbf-cadab0a30c01`
- Exact pair-5 Q02 row count: one

The enqueue did not call `dispatch-tick`, launch a tester, or infer an outcome.

## Pair 5 exact hold release

The released hold was `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` /
`Q09_AWAITING_SEALED_PLAN`. Its release note is byte-for-byte the pair-5 note
from the approved manifest and binds authentic anchor
`8f43a2f8-d0be-472f-87ca-c2fd628136e4`, the reviewed build, and Q02 seed
`f3391b2d-5f61-4548-ac51-c66781545ce4`.

- Applied pre-mutation backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_q09_requal8_pair5_release_20260901T081431Z.sqlite`
- Backup SHA-256:
  `05cd6109bcc937b53d9dda70a2c23794f9eb818b0b3ede44ec816d8b7691174a`
- Factory-mutation lock release: `released`
- Append-only transition ledger sequence: `2680`
- Audit event ID: `381321`
- WAL checkpoint: `busy=0`, `396/396` frames checkpointed
- Historical work-item rows updated: zero
- Historical rejected-review rows updated: zero
- Remaining active REQUAL-8 holds: three (pairs 6-8)

The protected `QM5_41162 OPT_CENSUS` program contained 1,159 rows immediately
before and after the transaction. Its deterministic selected-state SHA-256
remained
`1a7f66a64b1ea09b77a512d4d3eef1717809e46a6b7f0345b16ccc8186163405`.
No protected row was updated, cancelled, reprioritized, claimed, or interrupted.

One earlier guarded attempt created the retained read-only preflight snapshot
`farm_state_before_q09_requal8_pair5_release_20260901T081301Z.sqlite` and then
aborted on a review-payload shape assertion before the hold update. Its
transaction rolled back; read-back confirmed the hold remained active and no
release ledger existed. The applied transaction above used a new snapshot and
revalidated every precondition under the lock.

## Pair 5 focused verification

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: source and setfile `PASS`, zero findings,
  maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; only the three expected warnings
  caused by the approved recovery card residing in runtime `cards_review`.
- Backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Source input ceiling remains `qm_news_stale_max_hours=336`.
- SQLite `PRAGMA quick_check`: `ok`.

## Pair 6 governed-build preflight and handoff

Pair 6 binds parent `QM5_10939_grimes-context-pb`, successor
`QM5_41220_grimes-context-pb-requal8`, and `GBPUSD.DWX H4`.

Skill-governed identity preflight:

- recovery card:
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_41220_grimes-context-pb-requal8.md`;
- card and canonical EA-directory copy SHA-256:
  `0019d8c64b6379252606a4cb9109242e0ced53da80546b820287cc32ed479511`;
- `g0_status: APPROVED`, exact slug match, and source authority
  `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_10939`;
- active EA registry row: `41220,grimes-context-pb-requal8`;
- active magic slot 0: `GBPUSD.DWX`, `412200000`;
- generated `QM_MagicResolver.mqh` contains the EA ID and magic exactly once;
- `GBPUSD.DWX` is an exact DWX matrix member;
- pair-6 work-item count before handoff: zero;
- pair-6 farm-task count before handoff: zero.

Parent bytes remain the manifest-bound current bytes:

- MQ5 SHA-256:
  `619331975f50ef4a4c0a97b7feaa091d9d37a311502390387ea3a90441fdead9`
- EX5 SHA-256:
  `812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278`
- `GBPUSD.DWX H4` setfile SHA-256:
  `dc7c216b85598642b35cff10f52cd84dedb3ac069dc3a41695176e9362a9acba`

The already-recorded frequency-only stop-check was hash-revalidated:

| Evidence | Stored verdict | Trades | SHA-256 |
|---|---|---:|---|
| Q02 `ef8c152b-eb5b-4a3a-9801-ece65e833b1f` | `PASS` | 43 | `4435c58ca26c8cfd3f0d8611435f5ab35b2b5d966f63897f03143eed35db2d78` |
| Q08 `811fc617-ee41-456b-8e3a-ce672f93c73c` | `FAIL_SOFT` | 82 | `b76637d882c5e030135d5617f058c7346e315400c63667d2c865502cc2db9df8` |
| Q09 anchor `bae5710a-c610-474d-b885-3f9989f0d99a` | `PASS/DECAYED` | 92 full; 11 trailing 12m; 20 trailing 24m | `209c66ae55281e95625cfdc10dc76a51db1b38e1ce905ab343d613759556a1e8` |

This check authorizes the serial build handoff only. It preserves the Q08
`FAIL_SOFT` and Q09 `DECAYED` classifications and authorizes no mechanics or
pipeline-verdict change.

The canonical controller created exactly one governed build task:

- Build task: `e4782ee4-9fb4-4c3e-b9d5-9f9cd2ee3b8f`
- State at read-back: `pending`
- Prompt:
  `D:/QM/strategy_farm/queue/codex_build_e4782ee4-9fb4-4c3e-b9d5-9f9cd2ee3b8f.md`
- Prompt SHA-256:
  `30de509e65cacafd445f40431690e2fbe8c8d3c1ca09136dab2f6178831fd5c2`
- Prebuild warning:
  `q09_requal8_hash_bound_manifest_authority:OWNER-DEC-Q09HOLD-REQUAL-8-20260829`

Only `docs/strategy_card.md` exists in the pair-6 EA directory at this
checkpoint. The governed builder must port the parent mechanics faithfully,
use current framework wiring including the `QM5_41194` series-access pattern
and Q08 MAE hook, keep `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_news_stale_max_hours<=336`, and request compilation only through
`COMPILE_EA`.

Pair 6's manifest hold `9639a773-b913-40a2-b12f-128a027aec98` remains active.
Pairs 7-8 remain behind this serial boundary. The protected `QM5_41162`
`OPT_CENSUS` program remains strict no-touch.

## Verdict

`PAIR5_RELEASED_PAIR6_BUILD_PENDING`: pair 5 has both required reviews, one
append-only Q02 seed, and its exact hold release; pair 6 is safely handed to the
governed build lane with no compile or pipeline claim.
