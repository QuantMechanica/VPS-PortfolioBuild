# Q09 REQUAL-8 pair 6 release and pair 7 governed-build handoff

- Recorded: `2026-09-01T12:42:42Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR6_RELEASED_PAIR7_BUILD_PENDING`

## Outcome

Pair 6 crossed its complete serial boundary. Its governed build, mechanical
Codex review, and independent EA review were hash- and state-revalidated. The
manifest's exact enqueue contract then created one and only one Q02 seed for
`QM5_41220 / GBPUSD.DWX / H4`. Only after that seed was read back did the exact
pair-6 manifest hold receive the manifest's verbatim release note.

The hold release used the global factory-mutation lock, a fresh SQLite backup,
an exact compare-and-swap, and append-only transition/event records. The held
historical work-item row, both review rows, and the new Q02 row were unchanged.
All 1,159 `QM5_41162 OPT_CENSUS` rows were hashed before and after the release
inside the same write transaction and were byte-stable.

After the release, pair 7 passed the approved-card, identity, registry, magic,
resolver, parent-byte, authentic-frequency, and no-touch preflights. Exactly
one governed `build_ea` task was created. Its binding prompt explicitly
overrides the generic direct-compile text: compilation is `COMPILE_EA` queue
only, and `QM5_41162` is strict no-touch.

No tester was dispatched, no terminal was started manually, no active T1-T10
test was interrupted, and neither AutoTrading nor `T_Live` was changed. No
pipeline verdict is asserted.

## Pair 6 build and review bindings

- Build task: `e4782ee4-9fb4-4c3e-b9d5-9f9cd2ee3b8f`, `done`
- Build-result SHA-256:
  `c5cd142c6d3493e5d3b20288020313773c5327b249666d3b6eb184cb5ff1e2e5`
- MQ5 SHA-256:
  `a7dd265ed7d3a2b91bf8937451093e2285a1720b87406292e0ff4589f7ac6942`
- EX5 SHA-256:
  `497d824a7b630d9d2cc261bb8283f31af9cb8087e20be60922a5b5e52c38c431`
- SPEC SHA-256:
  `4b0dfc703793ac1f3b0dbad51cc5667d453dc8269c852b5a3864a0c4a140b24e`
- Backtest-set SHA-256:
  `045e25d62924212fa7e2d2ef3b29bfc9fec94b5cef7949854430390ed37b6cbf`
- Mechanical review:
  `d9cc81de-731a-429f-afd8-6d773faeea40`, `done/PASS`
- Mechanical-review artifact SHA-256:
  `7dedfbfc5f4e77050f3272912c92b007e31a51f700d07d9e0e5e80c94e67358a`
- Independent review:
  `e63613b6-26fd-4c78-b7b4-38f61695ef89`,
  `done/APPROVE_FOR_BACKTEST`

The independent review applied the current exact-manifest authority rule and
retained two non-blocking wiring observations. It did not rewrite source,
build, or historical review evidence.

## Pair 6 append-only Q02 seed

The exact manifest command was run once:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id e63613b6-26fd-4c78-b7b4-38f61695ef89 --phase Q02
```

It created exactly one row:

- Parent task: `a4b9d815-da0b-49c6-b38e-dae4a24135d4`
- Q02 work item: `7365a856-30d1-46d8-b557-fc9865b6699f`
- Identity: `QM5_41220`, `GBPUSD.DWX`, `H4`
- State at verification and release: `pending`, unclaimed, attempt `0`, no
  verdict
- Review/predecessor binding:
  `e63613b6-26fd-4c78-b7b4-38f61695ef89`
- Exact pair-6 Q02 row count: one

The enqueue created queue state only. This agent did not run the returned
dispatcher hint.

## Pair 6 exact manifest-hold release

The released hold was
`9639a773-b913-40a2-b12f-128a027aec98` /
`Q09_AWAITING_SEALED_PLAN`. The stored note is byte-for-byte the pair-6 note
from the approved manifest and binds anchor
`bae5710a-c610-474d-b885-3f9989f0d99a`, the reviewed build, and Q02 seed
`7365a856-30d1-46d8-b557-fc9865b6699f`.

- Released at: `2026-09-01T12:39:35+00:00`
- Pre-mutation backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_q09_requal8_pair6_release_20260901T123929Z.sqlite`
- Backup SHA-256:
  `92c054d073eb9efd7fa0dbb7944e3fdbc37424b3891d145cd2a62be6794d7a70`
- Factory-mutation lock release: `released`
- Append-only transition ledger sequence: `2687`
- Audit event ID: `381430`
- WAL checkpoint: `busy=0`, `735/735` frames checkpointed
- SQLite quick-check: `ok`
- Historical work-item rows updated: zero
- Historical review rows updated: zero
- Remaining active REQUAL-8 holds: two (pairs 7-8)

The protected program snapshot used a canonical JSON serialization of every
column from `work_items`, ordered by row ID and filtered to
`QM5_41162 / OPT_CENSUS`. Before and after the release it contained 1,159 rows
with SHA-256
`1667eada0a31433761cf9061f8c4b9e5825233e81c8de74974afd725d553cf3a`.
The same count and hash remained after creation of the pair-7 build task.

## Pair 6 focused verification

- `validate_spec_doc.py` with the EA directory: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; only the three expected warnings
  caused by the approved recovery card residing in runtime `cards_review`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Manifest JSON hash revalidated to the approved SHA-256 above.

An earlier verification invocation supplied `SPEC.md` instead of its EA
directory and returned the validator's expected usage failure. It made no
mutation. The corrected directory invocation is the result recorded above.

## Pair 7 governed-build preflight and handoff

Pair 7 binds parent `QM5_11421_ohlc-daily-squeeze-reversal-d1`, successor
`QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8`, and `EURUSD.DWX D1`.

Skill-governed identity preflight:

- Recovery card:
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8.md`
- Recovery-card and canonical-copy SHA-256:
  `6a7a6bd10ab45b9253d6a52feaa285ed2a3c61d3727a745f1a555c44fe3457e9`
- Card state: `g0_status: APPROVED`
- Source authority:
  `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_11421`
- Active EA registry row:
  `41221,ohlc-daily-squeeze-reversal-d1-requal8`
- Active magic row: slot `0`, `EURUSD.DWX`, `412210000`
- Generated magic resolver: EA identity present; exact magic present once
- `EURUSD.DWX`: exact current custom-symbol matrix member
- Pair-7 farm-task count before handoff: zero
- Pair-7 work-item count before and after handoff: zero

Parent bytes remain the manifest-bound current bytes:

- MQ5 SHA-256:
  `b5dfd159b46281cdb30dae3ae12a12fd67cdf810941b82a4a5f7e11a9dce6a15`
- EX5 SHA-256:
  `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b`
- `EURUSD.DWX D1` backtest-set SHA-256:
  `7b87dbf2a4a6b6e6d8cea39e9123ebf9e06f61e53e2215eed24afde7923d74cf`
- Parent approved-card SHA-256:
  `0412522f8419732b49a11089e44d10e31bcef649c65260ae3a26db1b36449f1b`

Authentic current-family frequency evidence:

- Q09 anchor: `a2b39c48-4845-4b49-9e84-9e88616a5862`, `done/PASS`
- Evidence SHA-256:
  `607562e8ba682785e820eb811830e88961d10f35080df823c4e65d45dbb00fa7`
- Metrics: 92 trades, PF `1.15`, drawdown `6.44662%`
- Recency shadow: `CURRENT`, 14 trailing-12-month trades, 24
  trailing-24-month trades

This is a frequency-only build permission. It does not replace or promote any
pipeline verdict.

The canonical controller created exactly one governed build task:

- Build task: `0f36f1bb-924b-4126-b682-c30ba1edfa41`
- State at read-back: `pending`
- Prompt:
  `D:/QM/strategy_farm/queue/codex_build_0f36f1bb-924b-4126-b682-c30ba1edfa41.md`
- Binding prompt SHA-256 after task-specific override:
  `4f341be18c6fb37e1eb24cd3596c1556736f69495c0b61a6ee11d79dddedd1ed`
- Prebuild warning:
  `q09_requal8_hash_bound_manifest_authority:OWNER-DEC-Q09HOLD-REQUAL-8-20260829`

The binding override requires a faithful parent port, already-allocated
registry verification, current bounded series access, the Q08 MAE-first hook,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_news_stale_max_hours<=336`. It prohibits all direct compiler/terminal/smoke
invocations and requires the exact queued compile request bound to build task
`0f36f1bb-924b-4126-b682-c30ba1edfa41`.

Pair 7's manifest hold `30584122-b7b3-41eb-8e1a-b03517554d4d` remains active.
Only `docs/strategy_card.md` exists in the pair-7 directory at this checkpoint;
source, EX5, SPEC, setfile, compile row, review, and Q02 are absent. The
`QM5_41162 OPT_CENSUS` program and its artifacts/processes were not targeted.

## Verdict

`PAIR6_RELEASED_PAIR7_BUILD_PENDING`: pair 6 has both required reviews, one
append-only Q02 seed, and its exact manifest-hold release. Pair 7 is safely
handed to the governed build lane with its strict no-touch and queued-compile
contract bound; no pair-7 compile or pipeline claim is made.
