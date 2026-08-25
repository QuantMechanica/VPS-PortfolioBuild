# Q10_NEWS expansion-autopilot census and recovery (2026-08-25)

Router task: `90ed5df2-ae7b-47ea-81d4-1269996bfec8`.

## Result

The expansion reason was already classified correctly. The production gap was
stage starvation: `news_gate_service.EXPANSION_REASON` is exactly
`expanded_7x4_matrix_required`, `verified_expansion_adjudication()` requires an
authenticated `REVIEW_REQUIRED` aggregate whose only reason is that value, and
`author_news_expansion_continuations()` creates an append-only held child with
`force_expanded_news_matrix=true`.

The pump called that author only after build dispatch and promotions. The last
complete diagnostic cycle in
`D:/QM/strategy_farm/logs/pump_task_20260823T235301Z.log` records a 270-second
cycle budget, 456.062 seconds elapsed, and 366.719 seconds in `build_dispatch`
against its 60-second stage budget. It then returned with
`review_stage.skipped=cycle_budget_exhausted`; `news_expansions` never appears in
the stage timings. Subsequent scheduled logs generally contain only the opening
kill-safety record before the scheduler's 30-minute ceiling. This explains why
authenticated requests were visible to the read-only command but received no
child for more than nine hours.

Fix: `farmctl._pump_unlocked()` now performs the bounded, append-only
`news_expansions` stage immediately after its initial deterministic maintenance
and before build dispatch. The late autoseal remains after promotions. If the
cycle is exhausted later, the next cycle's leading dispatch/autoseal path can
seal the already-authored child. No reason, gate, threshold, verdict, terminal,
or trading setting changed.

Focused verification:

- `python -m pytest tools/strategy_farm/tests/test_news_gate_service.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py -q`
- Result: `29 passed`.
- The added regression assertion requires expansion authoring to occur before
  build-dispatch budget accounting.
- A governed dry-run with the committed pair allowlist selected
  `QM5_11881/GBPUSD.DWX` first and `QM5_1537/XAGUSD.DWX` second.

## Terminal census since 2026-08-24 18:00Z

Scope is `q09_news_tests.created_at >= 2026-08-24T18:00:00Z`, joined to terminal
`Q10_NEWS` work items. This deliberately uses test creation time, not a later
work-item update. Every aggregate below exists and its current SHA-256 equals
the stored `q09_news_tests.aggregate_sha256`.

| test UTC | work item | EA / symbol | verdict | reason code | aggregate SHA-256 | action |
|---|---|---|---|---|---|---|
| 2026-08-24 18:13:43 | `e58b8c4c-3894-4aa7-8c9f-fd2d34ac3ebe` | QM5_12849 / XTIUSD.DWX | REVIEW_REQUIRED | `cell_execution_failed` | `05f76add8481e8d5f27db6c108735ddbdbf2003898960d9a72ff6d239d8b67e4` | Preserve; this is an expanded pre-fix run. Continue the governed small-batch recovery below; do not overwrite it. |
| 2026-08-24 19:53:53 | `9416f0ce-ede3-457e-bf9a-5ed9f892e177` | QM5_20266 / XTIUSD.DWX | CONFIG_LOCKED | `off_fallback_no_robust_improvement` | `8794d6af2dc4683fefb27076c5f23b963a42e335be07d322fd7326093ec93219` | Genuine gate outcome; no requeue. |
| 2026-08-24 21:01:53 | `6e8dcc3a-ed3f-4314-82b0-3bfd7238969f` | QM5_11754 / USDCAD.DWX | REVIEW_REQUIRED | `control_or_policy_off_not_qualifiable` | `ea053117234aca41e80764756c539ba9e3ec643d0d6083993c88717189a101b6` | Genuine gate outcome; no requeue. |
| 2026-08-24 22:15:43 | `42b0c995-7fac-415d-a08e-80581da2db33` | QM5_1537 / XAGUSD.DWX | REVIEW_REQUIRED | `expanded_7x4_matrix_required` | `aa79a56aac41300dac974942432c8e09f75db7422b8dceb89c49ffbd14416643` | Expansion child enqueued. |
| 2026-08-24 23:21:01 | `dddcd4a5-5fc3-4568-9527-73286819a1a2` | QM5_11881 / GBPUSD.DWX | REVIEW_REQUIRED | `expanded_7x4_matrix_required` | `6a681fd77c1b9430df3281f2d444839d81e56ac879c8526526f32e33e532bfda` | Expansion child enqueued first. |
| 2026-08-25 09:09:37 | `8f760c32-a6d2-4088-9106-d406de466fbb` | QM5_13054 / XTIUSD.DWX | REVIEW_REQUIRED | `expanded_7x4_matrix_required` | `d7f62ec5e40b8441aa9f1e8cab7ebb5ec37cef260b0ac811dc9d0303dab079c1` | Deferred to the next expansion wave by the two-row cap. |
| 2026-08-25 12:21:00 | `174e2b8f-53b4-401b-ac61-f581f948b7ab` | QM5_13036 / GDAXI.DWX | REVIEW_REQUIRED | `control_or_policy_off_not_qualifiable` | `ea053117234aca41e80764756c539ba9e3ec643d0d6083993c88717189a101b6` | Genuine gate outcome; no requeue. |

Counts: 3 `expanded_7x4_matrix_required`, 2
`control_or_policy_off_not_qualifiable`, 1 `cell_execution_failed`, and 1
`CONFIG_LOCKED`. Work item `463fa52a-33fa-4d23-b318-dda3d73b12e1` is excluded:
its work-item row was updated after the cutoff, but its test was created at
17:25Z.

## Append-only successors

The expansion command used
`docs/ops/evidence/90ed5df2_news_expansion_wave1_allowlist_2026-08-25.csv`,
`--limit 2`, and the canonical `enqueue-news-expansions --apply` path. The first
two apply attempts acquired no writer and inserted nothing (`database is
locked`); the idempotent retry created exactly these two rows, in required
order:

| order | source | successor | EA / symbol | initial state |
|---|---|---|---|---|
| 1 | `dddcd4a5-5fc3-4568-9527-73286819a1a2` | `9e9a0963-2c3a-4b87-8cba-d572788881ea` | QM5_11881 / GBPUSD.DWX | pending, `AWAITING_SEALED_PLAN`, active activation hold |
| 2 | `42b0c995-7fac-415d-a08e-80581da2db33` | `fac4d930-13b6-469e-8fe2-51ce06907f02` | QM5_1537 / XAGUSD.DWX | pending, `AWAITING_SEALED_PLAN`, active activation hold |

Both children retain the source aggregate hash, exact Q08 dependency, and
`force_expanded_news_matrix=true`. The wave contains exactly two expansions;
neither was active at verification time. A pre-existing QM5_11422 expansion is
pending with a released activation hold and was not modified.

For the remaining standard-scope reservation-race burns in the approved
`cb50e7c8-8d0f-490b-9a18-3231987c93c7` rerun plan, `farmctl mt5-slots` showed
six of ten T1-T10 workers occupied. One two-row append-only batch was therefore
enqueued, leaving the other plan rows for later headroom checks:

| preserved source | authenticated Q09 PASS predecessor | successor | EA / symbol |
|---|---|---|---|
| `1e3b7aa9-6a2d-466b-bea2-198964fda73f` | `3f0ad7ef-eb79-4cb1-ae38-3a7970ecea28` | `ac63944c-f16f-4307-a51b-f66ce4a6c310` | QM5_20010 / XAUUSD.DWX |
| `c5260944-a106-4c5f-a4f6-3f4aefcd5bb4` | `b11b8340-1666-454a-861d-a7917b48b60e` | `0d58a55a-4cb1-4d99-b10e-31af3b625f51` | QM5_21507 / XAUUSD.DWX |

Each rerun is bound to the current canonical EX5 SHA-256 and starts pending
behind the ordinary sealed-plan activation hold. The attempted QM5_1328 row was
correctly refused without mutation because its current exact Q09 predecessor is
`FAIL`, not `PASS`; it was not bypassed. The QM5_9936 EA-defect row and genuine
gate outcomes remain excluded exactly as required by the approved rerun plan.

No prior row, verdict, aggregate, terminal process, AutoTrading setting, or
live-trading setting was changed.
