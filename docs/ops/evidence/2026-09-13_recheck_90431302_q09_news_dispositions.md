# Cycle re-check 2026-09-13 — task 90431302 (DEC E2-Mittel): state changed, conclusion unchanged

Task `90431302` requires a new `Q09_NEWS` PASS among the 12 named Q10/Q14-relevant
EA/symbol pairs before an append-only `Q10_NEWS` rerun can be minted for any of them.
The last recorded check (`docs/ops/evidence/2026-09-12T1118Z_recheck_90431302_1721f3a1_49a8c88b_no_change.md`)
found 6 of 12 `done/REVIEW_REQUIRED`, 5 `pending`, 1 `done/PENDING_RUNNER`.

## What changed

A same-day disposition campaign
(`docs/ops/evidence/2026-09-13_q09_news_review_lane_dispositions.md`, via
`tools/strategy_farm/apply_q09_news_review_dispositions.py`) closed the 64
historical `Q09_NEWS` `REVIEW_REQUIRED` rows with append-only disposition receipts
(no historical row edited). 9 of the 12 named pairs are among the affected rows:
their latest `Q09_NEWS` row now reads `INVALID_EVIDENCE` (class B
`RUN_SMOKE_MISLABEL` or class C `EVIDENCE_AGED_OUT`, per that doc), not
`REVIEW_REQUIRED`.

| ea/symbol | work_item_id (latest) | verdict now |
| --- | --- | --- |
| QM5_10440/NDX | 29c8e503-ad5c-5bb7-9905-17716e9a118a | INVALID_EVIDENCE |
| QM5_10692/NDX | cd7c4076-55e1-4ca2-8e47-69d1966b74b8 | PENDING_RUNNER (unchanged) |
| QM5_10706/GBPUSD | a09c700c-7999-5eb6-be70-06acf1379f6c | INVALID_EVIDENCE |
| QM5_10919/XTIUSD | 130c2bd6-7487-50d1-918e-9a6e397493fc | INVALID_EVIDENCE |
| QM5_10939/GBPUSD | cbc438e3-9db8-5d89-9c1f-13d36abf7eb1 | INVALID_EVIDENCE |
| QM5_11165/EURUSD | dedbd91a-2b8f-5966-921a-0c2e6ed441a7 | INVALID_EVIDENCE |
| QM5_12969/USDJPY | 2c1dc400-a22b-52a9-8bd0-c2501c0b9fcc | INVALID_EVIDENCE |
| QM5_12989/XAUUSD | 60a86866-74e5-5863-bc06-35ac500be12a | INVALID_EVIDENCE |
| QM5_13013/NDX | 6607ae07-b581-586f-9374-ec2673ad42b8 | pending (unchanged) |
| QM5_13128/NDX | 033e7bc3-715e-5c71-b368-c00ea2594598 | pending (unchanged) |
| QM5_13213/USDJPY | 590b7691-1558-5fb6-8adc-65572e673c1c | INVALID_EVIDENCE |
| QM5_1567/EURUSD | b43f4c18-b6f4-5835-969f-b4ae4943fbdc | INVALID_EVIDENCE |

Cross-checked against `2026-09-13_q09_news_review_lane_dispositions.md`: none of
the 9 flipped pairs' EA ids appear in that doc's own disposition tables (class A
lists QM5_11294/1354/20266/21505/12849/1537/11881/12855 — a disjoint set), so the
disposition rows for these 9 belong to classes B/C (mislabeled run_smoke evidence
or evidence aged out under DL-090), consistent with the `INVALID_EVIDENCE` label
observed directly in `work_items`.

## Why the task's blocking condition is unchanged

`INVALID_EVIDENCE` and `REVIEW_REQUIRED` are both non-`PASS`. **Zero of the 12
pairs carry a `Q09_NEWS` PASS**, before or after this campaign — the dispositions
close out the open-review backlog, they do not adjudicate a pass. The Q10_NEWS
append-only rerun this task is chained on therefore still has no PASS predecessor
to mint from. `repair-oos-window`/hold-release logic is untouched by this finding.

No `update-task` call made; task `90431302` stays `IN_PROGRESS`. No hold released,
no rerun minted, no calendar or gate state touched.

Dedupe reservation: `dedupe-no-change-task 90431302-dfa8-4f27-ad0a-c826dbda77cf`,
state hash `0551c37403d23f3acdb3e70a5215b0b781e5f22ddacb1f777652e70fe10637d0`.

## 1721f3a1 / 49a8c88b (OOS-2026 window repair) — unchanged, no new artifact

Re-verified the same calendar gap directly (`D:/QM/data/news_calendar/news_calendar_2015_2025.csv`,
48,718 rows): 0 rows with `datetime` in `2026-01`..`2026-04`, last 2025 date
`2025-04-07`, first 2026 date `2026-07-20` — identical to
`docs/ops/evidence/2026-09-13_recheck_1721f3a1_no_change.md` and
`docs/ops/evidence/2026-09-13_recheck_49a8c88b_no_change.md`, both already
recorded earlier today. Per the no-change dedupe rule, no new artifact is written
for these two; the existing same-day files remain the record. `repair-oos-window
--apply` remains withheld. No `update-task` call made on either.
