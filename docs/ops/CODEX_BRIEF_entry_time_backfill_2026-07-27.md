# Codex brief — 70 of 189 sleeve streams cannot be evaluated for prop-firm work

Date: 2026-07-27
Priority: high. This is the cheapest available expansion of the sleeve pool.

## The problem

Q08 trade streams live at
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/<bare>_<SYMBOL>_DWX.jsonl`, one
JSON object per closed trade. Measured on 2026-07-27, **119 of 189 streams carry
`entry_time`; 70 do not.**

`entry_time` is not optional for prop-firm evaluation. Without it a position's span is
unknown, and a missing value must be treated as *unknown exposure*, not zero. Every
prop-firm model therefore excludes those sleeves outright — see the coverage
precondition in `tools/strategy_farm/portfolio/challenge_book_60d.py`. Eleven sleeves
are excluded on this ground even after all gate filters, including `12823:USDJPY`
(0 of 1548 records), which had previously slipped into a book because a missing
`entry_time` was silently read as "intraday-flat".

Sleeve supply is the binding constraint on the whole FTMO programme: only 15 sleeves are
currently gate-clean and scorable, and the best scores 0.41 against a target of 1.0
(`docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md`). Recovering excluded
sleeves is the cheapest way to widen that pool.

## What to establish

1. **Why the 70 lack it.** Old streams written before the emitter carried the field? A
   different code path? Sleeves whose EA never emitted it? Find the mechanism in
   `framework/include/QM/QM_Common.mqh` (the closing-deal emitter) and in git history.
   Report the split by cause, with counts.
2. **Whether it is recoverable without re-running backtests.** Is the entry time
   available anywhere else already on disk — the tester report, an order/deal log, a
   work-item artifact under `D:/QM/reports/work_items/`? If it is, backfilling is a
   parsing job rather than a tester job, which changes the cost by orders of magnitude.
   Answer this before proposing anything.
3. **The cost if a re-run is required.** How many of the 70 are gate-clean enough to be
   worth re-running at all? Rank them: a sleeve that failed Q08 `FAIL_HARD` is not worth
   a re-run for this. Give a concrete list of candidates worth the tester time, ordered.

## What to deliver

- If recoverable from existing artifacts: implement the backfill, fail-closed (never
  invent or infer an entry time; a record you cannot resolve stays missing and the
  sleeve stays UNSCORABLE). Report before/after coverage per stream.
- If a re-run is required: do NOT queue it yourself. Produce the ranked candidate list
  and the estimated tester cost, and stop. Queueing is a capacity decision.
- Either way, verify the emitter now writes `entry_time` for new runs, so the gap does
  not reopen. If it does not, that is the more important fix — say so.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`; do not interrupt running backtests;
  never touch `C:/QM/mt5/T_Live`.
- Do not re-import `.DWX` history under any circumstances.
- Do not modify existing stream files in place without a backup and an explicit record
  of what changed; these are evidence artifacts.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

`docs/ops/evidence/2026-07-27_entry_time_coverage_backfill.md` plus whatever fix the
evidence supports.
