# Q09 REQUAL-8 pair 3 release, pair 4 build handoff, and pair 5/6 frequency pre-check

- Recorded: `2026-08-31T16:52Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR3_RELEASED_PAIR4_BUILD_IN_FLIGHT`

## Outcome

Pair 3 completed its manifest-authorized serial boundary. Its governed build has
one passing mechanical Codex review, one independent Claude
`APPROVE_FOR_BACKTEST` review, exactly one append-only Q02 seed, and its exact
manifest hold is released. The release used a global factory-mutation lock, a
pre-mutation SQLite backup, append-only transition/event evidence, and no update
to a historical work-item row.

Only after that release, pair 4's governed build task was created and atomically
claimed by a managed Codex build process. No pair-4 compile, review, Q02 seed,
hold release, or pipeline verdict is claimed by this checkpoint.

The required parent-frequency pre-check for pairs 5 and 6 passes on authentic
pipeline evidence. It authorizes neither build yet: both remain behind pair 4's
serial completion boundary.

## Pair 3 governed build and controller reconciliation

Pair 3 binds parent `QM5_10815_tv-post-vwap`, successor
`QM5_41217_tv-post-vwap-requal8`, and `GDAXI.DWX H1`.

- Build task: `b958b565-e847-49e1-8ec9-6575f67b0d7f`, generation 0, `done`
- Compile work item: `24ab1d53-bff1-493c-a59b-eef83ab732f7`, authentic `COMPILE_OK`
- MQ5 SHA-256: `7ce436082f36df9924ec2d50bb39b05261507e52203bf255a3cbe10522e5c07e`
- EX5 SHA-256: `5f91c66cf86ffe9d607c199bc3b8ef7c033fb1071ccc8aea8703977ec2503fed`
- SPEC SHA-256: `98a8d12f5a535977c18b9c409da993c4fd7ebc3a796567cde7bf712f299bbe6c`
- Bound setfile SHA-256: `1f4d97802b02e5e352cd4d1fb2f663e6583a78755c24285731333a775fbab433`
- Build-result SHA-256: `576343ca4b1a6ac6c884f08da0f34b9e0b29cf7432b2441a1ca52315c74f52b3`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- News staleness ceiling: `qm_news_stale_max_hours=336`
- Smoke disposition: `deferred_p2_smoke`, backed by the recorded
  `status=no_capacity` terminal census; no terminal was launched manually and
  no active tester was interrupted.

The build had been stranded before review because the controller rejected every
non-empty `blocked_reason`, although `SCHEMAS.md` expressly admits the
saturation-backed `deferred_p2_smoke` case. Retry reconciliation had also moved
the durable result to an attempt-suffixed name while the reviewer prompt still
hard-coded the canonical name. The following fail-closed controller corrections
were committed with focused pathspecs:

- `c375f7e353` — admit only a durable saturation-backed smoke waiver at the
  pre-review boundary;
- `e73ea92d83` — restore a reviewable pre-review block without consuming another
  build retry or changing build artifacts;
- `a2de5cd8d6` — bind review prompts to the controller's resolved build-result
  artifact and exclude explicitly invalidated review evidence.

The canonical and attempt-suffixed build-result copies are byte-identical at the
SHA-256 above. The latest focused regression run of
`test_zero_trade_prevention.py` passed all 8 tests. The current EA also passed
`validate_spec_doc.py` and `validate_build_guardrails.py` with zero findings at
the 336-hour ceiling; `build_gate_hardening.py` reported zero failures and only
the expected card-location warnings for a runtime recovery card.

## Pair 3 mandatory reviews

- Mechanical Codex review: `cebea320-1a86-4e8a-ab77-7a85fe6086d8`
  - recorded verdict: `PASS`
  - findings: zero
  - verdict SHA-256: `ceb1ac277a0373ab7ed93c5bff548a28c4bdc7591c64091658fb36d00b8fb096`
- Independent Claude review: `f27dd95a-ce7a-49ea-aad3-d1408e01985b`
  - recorded verdict: `APPROVE_FOR_BACKTEST`
  - rework directives: none
  - verdict SHA-256: `907bfa71cbd784a9bdd75a876ae7f0a63570de7be590e693d3bc700c94e6b759`

Claude's warnings were documentation/process observations: the reservation card
itself disclaims compile authority and refers to a missing parent card copy. The
controlling compile authority is instead the hash-bound OWNER manifest above,
which the canonical controller recorded as a prebuild warning. Claude directly
diffed the parent and port sources and found the strategy inputs and executable
mechanics faithful; the remaining differences are current framework wiring.

## Pair 3 append-only seed and exact hold release

The manifest's canonical enqueue command created exactly one seed:

- Parent task: `2ef0cf0c-e1dc-4204-b3bc-ac6b9b26055b`
- Q02 work item: `511a1c64-6577-4fc5-9bba-9f6b6d72ba43`
- Identity: `QM5_41217`, `GDAXI.DWX`, `H1`
- Verified state before release: `pending`, unclaimed, attempt 0, no verdict
- Bound setfile: the single setfile hashed above
- Fixed-risk verification: `RISK_FIXED=1000`, `RISK_PERCENT=0`

The exact manifest hold `57d8bacd-2805-45a6-ac51-156e22bb3a65` was then
released with the manifest's verbatim pair-3 release note.

- Pre-mutation backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_q09_requal8_pair3_release_20260831T164539Z.sqlite`
- Backup SHA-256:
  `f5e5af40a21a0fc3d0934fc983cbb0e3ea93bb2fc69bb296bd4baa6d239dbb8e`
- Append-only transition ledger sequence: `2657`
- Audit event ID: `381165`
- Historical work-item rows updated: zero
- Remaining active REQUAL-8 manifest holds: five (pairs 4-8)

The protected `QM5_41162 OPT_CENSUS` program had 1,085 rows immediately before
and after the transaction. A deterministic snapshot over its selected row state
remained `b4481f09d0065fc2c17d78b19ce05343959f32075e6af70388987887154f508b`
through the commit. No protected row was updated or interrupted.

## Parent-frequency pre-check for pairs 5 and 6

This is a frequency-only stop-check. It preserves every recorded pipeline
verdict, including pair 6 parent's Q08 `FAIL_SOFT` and Q09 recency classification
`DECAYED`; it does not reinterpret profitability or robustness.

| Future pair | Authentic Q02 evidence | Q02 trades / floor | Later Q08 evidence | Q08 trades | Latest Q09 evidence | Full / trailing 12m / trailing 24m trades |
|---|---|---:|---|---:|---|---:|
| Pair 5 parent `QM5_12567 / XAUUSD.DWX D1` | `0a88a559-17a5-4a22-a195-7a8d534e1fa1`, SHA `35c139caf74d009e2966ea4ad8084cfd87c2685b6f27978d446864aad9a11c2c` | 32 / 25 | `dc267677-1cec-4ec4-9a44-d5c45dd01876`, SHA `9e3d3026f3901d5d0266ab1acf0d1b15696c6c4aa48419e3727d17e31b7f37ac`, `PASS` | 72 | anchor `8f43a2f8-d0be-472f-87ca-c2fd628136e4`, SHA `b08dd4e4cecb1f3cb66b3f1011dc946dc3430989d2ba012471b0aa308d7d1318`, `PASS/CURRENT` | 73 / 12 / 25 |
| Pair 6 parent `QM5_10939 / GBPUSD.DWX H4` | `ef8c152b-eb5b-4a3a-9801-ece65e833b1f`, SHA `4435c58ca26c8cfd3f0d8611435f5ab35b2b5d966f63897f03143eed35db2d78` | 43 / 25 | `811fc617-ee41-456b-8e3a-ce672f93c73c`, SHA `b76637d882c5e030135d5617f058c7346e315400c63667d2c865502cc2db9df8`, `FAIL_SOFT` | 82 | anchor `bae5710a-c610-474d-b885-3f9989f0d99a`, SHA `209c66ae55281e95625cfdc10dc76a51db1b38e1ce905ab343d613759556a1e8`, `PASS/DECAYED` | 92 / 11 / 20 |

Both parents cleared the authentic Q02 25-trade floor, retained substantially
larger Q08 samples, and recorded at least 11 trades in the latest Q09 trailing
12-month slice. Unlike the genuine low-frequency parents behind pairs 1 and 2,
neither pair 5 nor pair 6 presents a pre-build frequency-collapse warning.
Frequency verdict: `PASS_TO_SERIAL_BUILD_AFTER_PAIR4`; no mechanics change is
authorized.

## Pair 4 governed build handoff

Pair 4 binds parent `QM5_1567_demark-td-reverse-sequential-h4`, successor
`QM5_41218_demark-td-reverse-sequential-h4-requal8`, and `EURUSD.DWX H4`.

- Build task: `4e026269-a3e9-4030-8c12-7dd2da788cf4`
- State at checkpoint: `pending`, with a live managed Codex build dispatch
- Managed build PID / lease: `4824` / `2b8c3b2e4d28401191f8d2a041d5723b`
- Recovery-card SHA-256: `5d5b5b902e98c8030a0b8432020f4a06e6d7f62bc80bc817b446bdf8b7d666bb`
- Generated build-prompt SHA-256: `4e26e56b43ceb592442ac118e4e8e60a25579cc5682e79e1a72bc47985900c64`
- Active identity binding: EA `41218`, slot 0, `EURUSD.DWX`, magic `412180000`
- Pair-4 Q02 seed count: zero
- Pair-4 manifest hold `2604a1f0-4f58-4597-89ef-432af9093131`: active

The managed builder remains subject to the build-only skill contract. It may
author source/SPEC/setfile and request the governed `COMPILE_EA` queue; it may
not run a direct compiler, start a terminal manually, dispatch a backtest, or
release a hold. Pairs 5-8 remain untouched behind this serial boundary.
