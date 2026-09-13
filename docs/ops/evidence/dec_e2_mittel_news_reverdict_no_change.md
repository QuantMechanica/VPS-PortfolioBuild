# DEC E2-Mittel — mint action still blocked (task 90431302)

Canonical, non-timestamped evidence artifact for the recurring
orchestration-cycle recheck of task `90431302-dfa8-4f27-ad0a-c826dbda77cf`
("DEC E2-Mittel: re-adjudicate news-exposed verdicts append-only"). Per the
no-change dedupe protocol, written once per distinct blocker-state hash and
reused across cycles that observe the same state.

## What is already done (unchanged since 2026-09-12)

`news_calendar_scoped_activation.py` binding `069b467f8db31eeb...0baa1d` (see
`candidate_manifest_sha256: 5f28c2f3bba9...` in the state JSON) is
byte-identical to the 2026-09-07/08 B-prime binding: **11 ADMISSIBLE / 17
EXCLUDED**, same split as before. Of the 11 ADMISSIBLE rows:

- 2 already released this cycle-chain (`0f7f63e4`, `2641d5cf`, both
  2026-09-12T08:41Z, governed `farmctl.py release-hold`).
- 1 already unblocked independently (`f15ac955`).
- 8 remain ADMISSIBLE-by-calendar but blocked by an unrelated infra defect
  (`NEWS_RUNNER_SPAWN_SILENT_ABORT`) that a calendar-hold release would not
  clear: `745671a4`, `c18cf1fa`, `ca96d7bf`, `136b0e0f`, `450fb9f6`,
  `abea4df5`, `6d528b09`, `b6e02932`.

## What remains blocked (stable fact, re-verified 2026-09-13)

The "mint append-only Q10_NEWS reruns" step needs a `done`/`PASS` `Q09_NEWS`
predecessor per pair. Of the 12 Q10/Q14-relevant pairs named in
`docs/ops/evidence/2026-09-05_news_defect_blast_radius/blast_radius.csv`,
**zero carry a PASS Q09_NEWS predecessor** today. Status shifted since
2026-09-12 (most moved from `REVIEW_REQUIRED` to terminal `INVALID_EVIDENCE`
via the 2026-09-13T16:01Z Q09_NEWS review-lane closure, an unrelated
concurrent workstream) but the blocking fact for this task's own authority
(`enqueue-backtest --phase Q10_NEWS --append-only-rerun-of` requires a PASS
predecessor) is unchanged — still 0 of 12. `QM5_10692/NDX` sits at
`done/PENDING_RUNNER` (unchanged since 2026-07-31); `QM5_13013/NDX` and
`QM5_13128/NDX` remain `pending`, no verdict yet.

No `repair`/`mint`/`release-hold` action was forced against this state. No
`update-task` call made this cycle; task correctly stays `IN_PROGRESS`.

## Machine-readable state

See the reserved dedupe marker for the exact canonical JSON bound to this
artifact: `D:/QM/strategy_farm/state/orchestration_no_change/claude/90431302-dfa8-4f27-ad0a-c826dbda77cf/<state_sha256>.json`.

Unsticking the remaining mint step requires either (a) Q09_NEWS pipeline
throughput carrying one of the 12 pairs to a genuine PASS, or (b) an explicit
OWNER queue-order prioritization of those 12 — both outside a single
orchestration cycle's `allowed_actions`.
