# Governed first-Q02 intake implementation and dry-run evidence

Date: `2026-09-06`

Router task: `6a90b4af-74b1-414e-9cd3-924e572b38cc`

Implementation branch: `agents/codex-first-q02-intake-20260906`

Implementation commit: `8188d1529d`

Outcome: `REVIEW — IMPLEMENTED; NINE OF NINE CANONICAL DRY RUNS ELIGIBLE; NO Q02 MUTATION`

## Scope and safety boundary

This task added a governed, append-only `farmctl intake-first-q02` command and
the requested legacy-sweep observability repair. The command is dry-run by
default. No `--apply` invocation was made against the canonical farm. No Q02
row, deferred-cohort sidecar entry, receipt, terminal process, pipeline verdict,
T_Live setting, AutoTrading setting, or live state was changed during the nine
production-data checks.

The implementation is isolated on the branch and commit above. Canonical code
was not modified. This evidence document is the only task artifact committed on
`agents/board-advisor`, using an explicit pathspec.

## Implemented contract

`intake-first-q02 --compile-work-item-id <id>` now:

1. Requires the exact source row to be `kind=compile`, `phase=COMPILE_EA`,
   `status=done`, and `verdict=COMPILE_OK`.
2. Authenticates the payload and `qm.compile-ea-evidence/v1` document, including
   work-item/EA/phase identity, build-check PASS, compile PASS, success, and the
   recorded candidate recheck.
3. Requires one active EA-registry identity and the exact canonical EA
   directory/binary.
4. Requires the work-item, payload, evidence, and current canonical EX5
   SHA-256 values to agree.
5. Validates every canonical `_backtest.set`: `RISK_FIXED > 0` and
   `RISK_PERCENT = 0`; validates compile symbols against the DWX matrix and
   selects the logical basket set where a basket manifest exists.
6. Requires exact active magic rows for the compile target symbols, including
   slug, contiguous slot, and `ea_id * 10000 + slot` checks.
7. Applies the existing review-entry gate, requires zero existing Q02/P2 rows,
   and applies custom-history archive admission.
8. Selects exactly one canary with the existing Q02 canary policy. Any remaining
   symbols use the normal deferred sidecar. It deliberately does not add
   `priority_track` or any other priority boost.
9. On `--apply`, rechecks every predicate under the factory mutation lock,
   appends one Q02 row, records an event, writes a governed pre-mutation backup,
   and writes a receipt under
   `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/`.

The legacy `sweep_enqueue_built_eas.py` phase-blind exclusion remains a behavior
guard. A targeted EA with a COMPILE_EA row and no Q02 row is now present in
`part1_never_tested.skipped` with reason `COMPILE_ROW_PRESENT_NO_Q02`, rather
than disappearing with an empty skip list.

## Exact canonical dry-run commands

All commands ran from the isolated implementation worktree and read the
canonical checkout/database. None included `--apply`.

```text
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 2b5f0303-968c-4181-9bc8-62366035a406
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id ce864ce1-3957-49c8-97a8-048cb4dc9569
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 8cc3c581-d71a-48d9-9e79-fc2b4b53718e
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id d9949538-e279-402b-bc05-8f8199f2b8d1
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 4fd60078-4862-45ca-ab65-558b29fcb9ac
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 7b947ba4-f327-4eb2-af86-a0333e27de6a
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id e23cfbc8-3f6d-4b27-b369-c6061a6b44a5
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id f57662e7-6e12-4d96-b109-f0c437d6ce7f
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 0a80a328-3b81-4125-aa48-ed5686b7a962
```

## Nine dry-run outputs

The following one-line records preserve the decision-bearing fields from each
JSON stdout document. Every full output also listed the exact canonical EX5,
compile-evidence, setfile, and magic-registry paths and reported no magic issue.

```jsonl
{"ea_id":"QM5_41164","compile_work_item_id":"2b5f0303-968c-4181-9bc8-62366035a406","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"QM5_41164_XAU_XAG_MREPMEDIAN_RV_D1","canary_setfile_sha256":"70121821b8bcaa875ea1cb91e7775c99a9029d757eb89defc943180d38809ca8","ex5_sha256":"2992eac18012548c22ac5c8823609fd546b0195e950b25ca5fbe621721cd669f","setfile_checks":3,"active_magic_rows":2}
{"ea_id":"QM5_41165","compile_work_item_id":"ce864ce1-3957-49c8-97a8-048cb4dc9569","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"XTIUSD.DWX","canary_setfile_sha256":"f73bc2d3f8500b9c0b4b68db215e13f05d13f0d4d1d0e1b7279e285a4b41d0c1","ex5_sha256":"196c37ed88a4aba954d31adc566da38c47f8df9787b02df82d6768b32a57a1d5","setfile_checks":1,"active_magic_rows":1}
{"ea_id":"QM5_41166","compile_work_item_id":"8cc3c581-d71a-48d9-9e79-fc2b4b53718e","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1","canary_setfile_sha256":"960fd8011f42d1722c2a17a486efe2a9bbf7d84ae4bd16a9b0e8ab6e9a0ce024","ex5_sha256":"f9e0354ebf4c731da193f95c553db9547848caa72b5011cd35c759e82197b11c","setfile_checks":3,"active_magic_rows":2}
{"ea_id":"QM5_41172","compile_work_item_id":"d9949538-e279-402b-bc05-8f8199f2b8d1","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"XTIUSD.DWX","canary_setfile_sha256":"8b8908146652286e972381c2d9db4b7ab53f877a2cbbddf6bd0618e88a1fb883","ex5_sha256":"53fbffa7d147c779a403df23dc3d26d3d6bc034a7d545395971777be3ca50769","setfile_checks":1,"active_magic_rows":1}
{"ea_id":"QM5_41176","compile_work_item_id":"4fd60078-4862-45ca-ab65-558b29fcb9ac","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"XTIUSD.DWX","canary_setfile_sha256":"417228e22dae4477441d05f4be46396ee76196d167fa4cd86b358cdc17e0207f","ex5_sha256":"663eca68c975bacffbd74c6c8670df9a6ed8a070094ad3b98407da0e2d9a5300","setfile_checks":1,"active_magic_rows":1}
{"ea_id":"QM5_41224","compile_work_item_id":"7b947ba4-f327-4eb2-af86-a0333e27de6a","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"XTIUSD.DWX","canary_setfile_sha256":"1d28d8663210fee057b592a27728909ea68f509a519b24b65fb11920fee63a14","ex5_sha256":"ae19548f7fc338a260b01ea574808040a9efed2ef08ddc4d9ce76b12a577d965","setfile_checks":1,"active_magic_rows":1}
{"ea_id":"QM5_41285","compile_work_item_id":"e23cfbc8-3f6d-4b27-b369-c6061a6b44a5","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"QM5_41285_XAU_XAG_JT_RV_D1","canary_setfile_sha256":"4b74ad036e91c597344938a7f98afd3c820be41c06eb6b0173fb76ed30f0e573","ex5_sha256":"c5eaa6ac55c2d8e3ca4dc361b626c939022ffbabe3bdf1f1838ad6d3c4f34187","setfile_checks":3,"active_magic_rows":2}
{"ea_id":"QM5_41312","compile_work_item_id":"f57662e7-6e12-4d96-b109-f0c437d6ce7f","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"XTIUSD.DWX","canary_setfile_sha256":"81d88201759dc0b6f87fcc870e822465f2035b092106983ac267cd461f84418e","ex5_sha256":"bddf06f7700055ce6f81a5d0ea190917a2d54c37e9c929d717dd3304232cfa1c","setfile_checks":1,"active_magic_rows":1}
{"ea_id":"QM5_41336","compile_work_item_id":"0a80a328-3b81-4125-aa48-ed5686b7a962","eligible":true,"reason":"ELIGIBLE","dry_run":true,"applied":false,"would_enqueue":true,"priority_boost":false,"canary_symbol":"XTIUSD.DWX","canary_setfile_sha256":"9f5c156865742068db9c40b98d918615d9b2499b65ec6cc8f1176adc82ca41b0","ex5_sha256":"c62f35222d069bb4f1cb81a545f2fec1ad61058141d2a5920ca91d42fb2e9f6d","setfile_checks":1,"active_magic_rows":1}
```

## Verification

Focused command and affected-surface suites:

```text
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/sweep_enqueue_built_eas.py
PASS

python -m pytest tools/strategy_farm/tests/test_first_q02_intake.py tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py -q
32 passed in 14.95s

python -m pytest tools/strategy_farm/tests/test_owner_review_first_q02.py tools/strategy_farm/tests/test_q02_evidence_binding.py tools/strategy_farm/tests/test_build_guardrails.py tools/strategy_farm/tests/test_first_q02_intake.py tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py -q
67 passed in 17.17s

git diff --check
PASS
```

The new fixture suite covers the dry-run no-mutation contract, the apply path,
exactly-one-row behavior, receipt creation, deferred sidecar behavior, absence
of a priority boost, repeat-call refusal, custom-history refusal, and explicit
refusals for missing/wrong compile rows, malformed payload/evidence, non-PASS
evidence, failed candidate recheck, inactive identity, missing/mismatched EX5,
invalid fixed-risk settings, missing DWX symbol authority, invalid magic rows,
review-entry block, and any existing Q02 row.

`ruff` was not installed in the headless environment; syntax, diff, and pytest
checks above were used instead.

## Review verdict

`REVIEW — code and evidence complete on isolated commit 8188d1529d. The CEO may
apply at most two exact compile work-item IDs per scheduler tick after the
commit is independently reviewed and integrated. No apply or pipeline verdict
is claimed here.`
