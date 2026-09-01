# Q09 REQUAL-8 pair 4 release and pair 5 governed-build handoff

- Recorded: `2026-09-01T01:29Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR4_RELEASED_PAIR5_BUILD_PENDING`

## Outcome

Pair 4 crossed its complete serial boundary. Its governed build and both
required reviews were revalidated, exactly one append-only Q02 seed was
created, and only its manifest-bound `Q09_AWAITING_SEALED_PLAN` hold was
released. The release used the global factory-mutation lock, a SQLite backup,
exact-ID and hash revalidation, and append-only transition/event evidence. It
did not update the historical held work-item row.

After that release, pair 5 passed the approved-card, registry, magic, resolver,
and frequency preflights. One governed `build_ea` task was created for the
scheduled build lane. It remains pending: no pair-5 source, EX5, setfile,
compile row, review, Q02 seed, or hold release exists at this checkpoint.

No terminal was started manually, no active T1-T10 test was interrupted, and
no AutoTrading or live setting was changed. The factory independently claimed
pair 4's Q02 seed on T2 after the release; this record asserts no pipeline
verdict.

## Pair 4 build and review bindings

Pair 4 binds parent `QM5_1567_demark-td-reverse-sequential-h4`, successor
`QM5_41218_demark-td-reverse-sequential-h4-requal8`, and `EURUSD.DWX H4`.

- Build task: `4e026269-a3e9-4030-8c12-7dd2da788cf4`, `done`
- Build-result SHA-256:
  `6e7d2f9f8af6aa6cbc10e6fb44b4a0c958118f227b13a910ab1aa4de73dd33af`
- MQ5 SHA-256:
  `6da309ab85b209e5b2b3c739ffc75246d8f78447d47bb3eeff70a50f25b8e7de`
- EX5 SHA-256:
  `c3e6e260c14ec8b7263b35aae3380433d4c48b6b3d34199deb27b2e18eb52f10`
- SPEC SHA-256:
  `468522458de183162e44ad5e7ae8a97fcd81b85a6f4f8798b38cb676700f13fd`
- Bound setfile SHA-256:
  `acbfe9a15d24987eb70cad5289429b671f2732a57e81c14e9ec047d1cd2612f4`
- Mechanical Codex review: `a508f6f6-f798-4a6e-ad20-32947346eeef`,
  `done`, verdict `PASS`, artifact SHA-256
  `976b3830142c7757df02a37a8df79f67cf6eb8a0b1df9962a1fbcf78d81cf0df`
- Independent EA review: `724b3a4a-5e56-4c26-b85a-e6f6f0155cbd`,
  `done`, verdict `APPROVE_FOR_BACKTEST`, artifact SHA-256
  `c6c47b2a438edc5d7cdde7ee0c11c407a241b8a6af864d61d098c4d0d985b2ea`

Fresh focused verification before enqueue:

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`;
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  `qm_news_stale_max_hours=336`;
- `build_gate_hardening.py`: zero failures and the three expected warnings
  caused by the approved recovery card residing in the runtime
  `cards_review` reservoir;
- backtest risk remained `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The measured no-capacity Q01 smoke disposition remains exactly the one bound in
the build result. This verification did not launch another smoke test.

## Pair 4 append-only Q02 seed

The manifest's canonical enqueue command used the approved independent review
and created exactly one work item:

- Parent task: `296c5d2e-4d19-4216-b624-430470005917`
- Q02 work item: `7aa6cce0-e06a-4a7c-838d-e0a23a4767ac`
- Identity: `QM5_41218`, `EURUSD.DWX`, `H4`
- State immediately before hold release: `pending`, unclaimed, attempt 0,
  no verdict
- State at final read-back: `active`, claimed by the ordinary factory worker
  `T2`, attempt 0, no verdict
- Exact Q02 seed count for `QM5_41218`: one

The enqueue command only created queue state. The scheduled factory performed
the later T2 claim; this agent did not call `dispatch-tick`, start a terminal,
or infer an outcome.

## Pair 4 exact manifest-hold release

The released hold was
`2604a1f0-4f58-4597-89ef-432af9093131` /
`Q09_AWAITING_SEALED_PLAN`. Its release note is byte-for-byte the pair-4 note
from the approved manifest and binds anchor
`e460e02b-e940-49fa-ace0-e2b9c853e7d6`, the reviewed build, and Q02 seed
`7aa6cce0-e06a-4a7c-838d-e0a23a4767ac`.

- Pre-mutation backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_q09_requal8_pair4_release_20260901T012728Z.sqlite`
- Backup SHA-256:
  `f024d7e74ed2d5892f43c34bc9f736f1a72fe6b84a777fb9654be2aaab3f5d9b`
- Factory-mutation lock release: `released`
- Append-only transition ledger sequence: `2670`
- Audit event ID: `381254`
- Historical work-item rows updated: zero
- Remaining active REQUAL-8 manifest holds: four (pairs 5-8)

The protected `QM5_41162 OPT_CENSUS` program contained 1,085 rows before and
after the transaction. The selected-state SHA-256 remained
`ba29632bb715e4f62c2d732d549edbd50a6d09ae16bf5c30027fd66f1207dbcb`
inside the transaction. No protected row was updated, cancelled,
reprioritized, claimed, or interrupted by the release.

## Pair 5 governed-build handoff

The already-recorded authentic parent-frequency evidence authorizes pair 5 to
advance serially. It is a frequency-only permission; it does not change any
historical pipeline verdict or authorize new mechanics.

Skill-governed preflight for `QM5_41219_cum-rsi2-commodity-requal8`:

- recovery card:
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_41219_cum-rsi2-commodity-requal8.md`;
- card SHA-256:
  `af36edefbf33f5269da134ebd3c31de238fc0e928a67dbc26ed3ab0a2d126aba`;
- `g0_status: APPROVED` and source authority
  `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_12567`;
- exact slug match across the card, EA directory, and active EA registry row;
- active magic slot 0: `XAUUSD.DWX`, `412190000`;
- generated `QM_MagicResolver.mqh` contains EA `41219` and magic `412190000`;
- no pre-existing pair-5 build task or work item was present.

The canonical controller created:

- build task: `da8e6083-8e62-43a7-85f4-68d009383e96`;
- status at read-back: `pending`;
- prompt:
  `D:/QM/strategy_farm/queue/codex_build_da8e6083-8e62-43a7-85f4-68d009383e96.md`;
- prompt SHA-256:
  `692a7af08feab631de348ac22b1cbafa0855598d35ad2554dced61c2f422ae55`;
- prebuild warning: the expected hash-bound REQUAL-8 manifest authority.

Only `docs/strategy_card.md` exists in the pair-5 EA directory at this
checkpoint. The scheduled build lane must faithfully port the parent mechanics,
keep `RISK_FIXED=1000` and `RISK_PERCENT=0`, retain the 336-hour maximum news
staleness, and request compilation only through `COMPILE_EA`. Pair 5's manifest
hold `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` remains active. Pairs 6-8 remain
behind this serial boundary.

## Verdict

`PAIR4_RELEASED_PAIR5_BUILD_PENDING`: pair 4 has both reviews, one Q02 seed,
and its exact hold release; pair 5 is safely handed to the governed build lane
with no compile or pipeline claim yet.
