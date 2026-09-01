# Five blocked build lanes — governed triage

Date: 2026-09-01  
Parent task: `d8fb391d-b18b-4954-8620-c40297559f15`  
Branch: `agents/board-advisor`

## Verdict

All five named blocker rows now have either a current next-queue-state binding
or a terminal close reason. No frozen/live EA is in this cohort, no T_Live or
AutoTrading state was touched, no terminal was launched or interrupted, and no
historical work-item or verdict was mutated.

The active risk-freeze contains 24 sleeves and 21 distinct binaries. None of
`QM5_1538`, `QM5_36006`, `QM5_38005`, `QM5_41125`, or `QM5_41197` appears in
its roster. The freeze explicitly leaves factory builds and Q02-Q10 work out of
scope, but this audit still performed no live write.

## Per-row disposition

### `cdea2233-392f-4160-8158-82f57f4515d6` — QM5_1538

Disposition: **terminal-close the stale blocker row; do not compile from this
row**.

- The governed card-amendment follow-up `4ab715d1-12bc-45a2-8b59-3b3e23adbc90`
  is APPROVED. The runtime approved card now declares exactly the 13 already
  active registry symbols and `r3_data_available: PASS`; its SHA-256 is
  `3d1fbb2f3c7c463fff71ebe8a36b29ff13019336a70f6039010cb46800dc19bf`.
- The original `target_symbols` blocker is therefore resolved without a
  universe change.
- Two later append-only compile rows exist, but their payload source hashes
  (`0bbcf752...` and `78c02c2f...`) do not match the present working source
  (`f4d84bdf...`). The source also has pre-existing uncommitted edits owned by
  another lane. This triage must not overwrite, commit, or compile them.
- A future current-source compile requires that owning lane to finish review
  and bind a new exact-source successor. This old build row is not that lane.

### `827e3846-438c-4a12-b33a-ba44838037c7` — QM5_38005

Disposition: **unstuck to an append-only governed COMPILE_EA successor, held
for reviewed worker rollout**.

- The prior worker side-effect EX5 is no longer present. The three reviewed
  setfiles remain; all use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Current MQ5 SHA-256 is
  `060403f50d18d840643941c251bf80a89a0e752b2f56be56dfb6de3e8dfece1f`.
- Guardrails PASS (4 files, no findings, news stale maximum 336), SPEC PASS,
  symbol scope `SINGLE_SYMBOL_OK`, and build-gate hardening has zero failures
  or warnings.
- A one-task/one-label source-repair gate was added for this parent router task.
  It grants only an append-only current-source compile successor, not a
  backtest, gate verdict, overwrite, or live action.
- Successor work item: `10c5fd07-0804-465c-93c6-feee47ae292d`, pending,
  source-repair predecessor `8f538072-156a-4b46-9f5f-5004711e1048`, activation
  state `AWAITING_REVIEWED_WORKER_ROLLOUT`. The historical failed row and its
  SQLite-busy/candidate-recheck evidence remain unchanged.

The rollout hold is intentional. Codex does not self-approve the new authority
or infer `COMPILE_OK`; a normal worker may claim it only after review/release.

### `4d961365-2a04-427d-8a72-b9f2c8cc9f8b` — QM5_36006

Disposition: **unstuck; original blocker row is superseded by the exact-current
pending compile**.

- Current MQ5 SHA-256 is
  `014dc6e0c3d8e466a2947ae0ac1e6590ac0c491b17a67c37cbae748cc665dfb6`;
  no EX5 exists.
- Work item `ec88e76e-30a4-4f5a-a091-da380e06a7c8` is already pending and is
  bound to that exact hash, three reviewed D1 symbols, and fixed risk.
- It is held at `AWAITING_REVIEWED_WORKER_ROLLOUT`. Enqueuing a duplicate or
  manually compiling would violate serial/append-only discipline.

### `0a00fb0d-df0a-4cf4-831c-e0243324b0e1` — QM5_41125

Disposition: **terminal-close for Strategy Governance; do not build or move the
card**.

- A source-complete EA exists and historical COMPILE_EA row
  `9ea12411-fd99-4e38-9cac-a2aace69896b` has an immutable `COMPILE_OK` receipt
  for source `a568b65c...` and binary `7ded6013...`.
- The card is only in `C:/QM/repo/strategy-seeds/cards/approved/`; it is absent
  from both canonical `artifacts/cards_approved/` and runtime
  `D:/QM/strategy_farm/artifacts/cards_approved/`.
- Its R3 value is
  `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`, not the required
  exact `PASS`. That is a substantive data-admission qualification, not a file
  copy typo. Moving it into approved artifact pools would bypass the R gate.
- Strategy Governance must either prove the paired XAU/XAG calendar/basis
  contract and set R3 to exact PASS, or reject/return the card. No build action
  is admissible from this task.

### `b40654c9-6fe8-4daa-b8a1-db41876a5385` — QM5_41197

Disposition: **terminal-close as superseded; never rebuild while its census is
running**.

- The current source/binary pair is
  `9918490a...` / `98e052ec...`.
- Live ledger snapshot: 89 `MEASURED`, 6 `SKIPPED_EXCLUDED`, 989 pending, and
  one active OPT_CENSUS item claimed by T9. That is 95 terminal cells plus the
  active cell, confirming the 93+ cell condition in the parent task.
- The old build row's missing-binary premise is false. Rebuilding would change
  identity under a running program and is explicitly forbidden.

## Focused verification

- `test_compile_work_items.py`: **60 passed**.
- Exact authority regression proves the parent task authorizes only
  `QM5_38005_codetrading-ascending-triangle-breakout`; wrong task and wrong
  label are refused.
- `validate_build_guardrails.py` for QM5_38005: PASS, maximum staleness 336.
- `validate_spec_doc.py` for QM5_38005: PASS.
- `validate_symbol_scope.py --fail-on-leak` for QM5_38005:
  `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` for QM5_38005: zero failures/warnings.
- `git diff --check` over the authority and regression files: PASS.

No compile result or pipeline verdict is claimed. The two pending compile rows
remain review-held until a separate reviewer releases their worker rollout.
