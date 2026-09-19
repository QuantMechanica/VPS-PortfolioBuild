# Current-source compile and rollout reconciliation — task 5a98a339

Verdict: **PASS / REVIEW**. The landed defect repairs for QM5_41179,
QM5_41189, and QM5_41142 are complete for the compile blocker in scope. Each
EA received one newly authorized, current-source governed compile and reached
`COMPILE_OK`. The stale rollout reconciliation then closed the exact 13-row
wave atomically; the post-apply recheck reports zero active rollout holds.

## Repair review

| EA | Landed repair | Current MQ5 SHA-256 | Focused finding |
|---|---|---|---|
| QM5_41179 | `14d548c87a` | `ed6f54885c9455bcd5f9c5d7c45125fc59d1a4acc02213ddcb5ad801609e7412` | Framework-owned inputs are no longer pinned by the EA; source/input-pin audit and build guardrails pass. |
| QM5_41189 | `14d548c87a` | `b6c0052a0fae01e86abd1e9766da99c705197159cd25f0bfdbb2e4c3ec971efe` | Framework-owned inputs are no longer pinned by the EA; source/input-pin audit and build guardrails pass. |
| QM5_41142 | `d0433c1c1d` | `bd65d86feafb660aee79a9e4e483f62679788383595d6a80bbd5204db50d23f0` | The host symbol is an input and the runtime comparison is canonical; symbol-literal lint and build guardrails pass. |

The three repair authorities are new, narrowly bound
`compile_fail_repair:*:20260919:*` entries. They were committed as
`56102957b3`. The spent
`router_ops_issue:e9944090-1e0f-4dea-af90-e74f8079d1c8` source-repair
authority was not passed to or reused by any enqueue.

## Current-source compile results

| EA | Work item | Verdict | EX5 SHA-256 | Evidence SHA-256 |
|---|---|---|---|---|
| QM5_41179 | `263c348b-24a9-4562-9d9c-0f79ce4f6483` | `COMPILE_OK` | `7dc7bbf08195f41c8e22e9c035e0abdf507c57cb9baa5061990b0fdf84eb525b` | `5b8f57dadf6333345499cfb9d244bcd8f7ed57e220a0305eff890f2e4950b317` |
| QM5_41189 | `62639587-7b80-4842-89b7-d14c6787412d` | `COMPILE_OK` | `f579dc0c9181a0cf4c80c711a7f618c4d8240f1ca457a5c85f761ddc7ff09b7f` | `c1841ce6cd3744e7902b79f5d5c300bbf9c2dc03204f3933edc39177ebe01295` |
| QM5_41142 | `dfbc514f-c183-49aa-afb4-a7bf78fdbce1` | `COMPILE_OK` | `38ba8891522b0bbdaac5a41a24fe52219cd41cb1e4c08340fb23d6390c64913c` | `bd6f26a83a35fbca1ba7e06ec56a9613d5ed9fad1158694a8a93a816ed5c11c5` |

All three compile evidence documents report `compile_result=PASS`,
`build_check_result=PASS`, an empty `failure_classes` list, and zero compiler
errors/warnings. Generated backtest sets use `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

The bounded three-item release receipt is
`compile_current_source_release_apply.json`. Its pre-apply database backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260919T183622Z_cfd74b38.sqlite`
with SHA-256
`3a0e46e5c9bb8e555201cf34d6fd15b115dd1f298e158e18001ad9b0267cddd9`.

## Stale rollout reconciliation

The pre-apply inspection classified all 13 active rows as
`ROLLOUT_PREDECESSOR_CURRENT_SUCCESSOR_EXISTS`, with zero rows needing a
successor, zero manual-review rows, and zero terminal-result holds. Apply was
guarded by `--expected-predecessor-count 13` and this evidence path.

The apply receipt
`compile_rollout_reconcile_postcompile_apply.json` records:

- `applied=13`
- `inserted_supersessions=13`
- `post_active_hold_count=0`
- `post_stale_hold_count=0`
- `post_source_fresh_hold_count=0`
- mutation backup
  `D:\QM\strategy_farm\state\backups\farm_state_before_compile_rollout_reconcile_20260919T184313Z_934d0974.sqlite`
  with SHA-256
  `7e03c38ca6cd99d28bbaaf1536abda91a64e62041dd0ad0a6ee1f6e2f77be3f0`.

A fresh dry-run after apply is bound in
`compile_rollout_reconcile_postapply_verify.json`; it reports zero active,
stale, source-fresh, ready, manual-review, and needs-successor rows.

## Focused verification

- EA reference tests for the three repaired sources: **22 passed**.
- Compile-repair registry tests: **14 passed**.
- Build guardrails: **PASS** for all three sources; news-staleness ceiling
  remains 336 hours.
- Framework-input pin source audit: **0 hits** for QM5_41179 and QM5_41189.
- Symbol-literal lint: **OK** for QM5_41142.
- Current-source work-item query: all three new rows are `done / COMPILE_OK`.
- Post-apply reconciliation inspection: **0 active rollout holds**.

This receipt records compile and control-plane evidence only. It makes no
pipeline or live-use verdict.
