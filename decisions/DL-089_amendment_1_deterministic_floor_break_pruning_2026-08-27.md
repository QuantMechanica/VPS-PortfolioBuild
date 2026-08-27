# DL-089 Amendment 1 — deterministic floor-break pruning

- Date: 2026-08-27
- Status: OWNER-authorized amendment; implementation activation remains review-gated
- OWNER receipt:
  `decisions/2026-08-27_owner_v5_no_buy_v7_pruning_ja.md` §2
- Bound predecessor evidence:
  `docs/ops/evidence/2026-08-27_dl089_v7_pruning_floor_break_measurement.md`
  (router task `4598b5eb-ff1f-4940-97a9-ead459dbb6a4`)

> **DL-089 Amendment 1 (2026-08-27) — deterministic floor-break pruning.** Extends
> decision #3 ("Frequenz-Boden fail-closed"). Once a candidate arm's measured
> `entry_trading_days` for calendar year Y is `< activity_floor` (10, pro-rata per
> CEO-MP-#4), that arm's remaining declared census cells for years > Y are **not
> dispatched**. Each skipped cell gets an append-only `skipped_as_excluded` receipt
> recording: `cell_key`, the triggering `(arm, year=Y)` cell_key, and timestamp. The
> cell's identity stays declared in the ledger (`declared_trial_count` is unchanged —
> skip is a dispatch decision, not a trial-count deflation). Selection rule #2/#3/#4
> (consistency quorum, activity floor, anchored WF) stay byte-unchanged.
