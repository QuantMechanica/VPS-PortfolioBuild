# Q08 equity export gap — task a5768d03

Date: 2026-07-27 (Europe/Berlin)

## Verdict

REVIEW — NOT MEASURED. The requested 80.7% campaign re-measurement cannot be
produced from the current durable evidence without inventing intratrade equity.

## Verified state

- The four requested durable files exist under
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/`:
  `13213_USDJPY_DWX.jsonl`, `10848_XAUUSD_DWX.jsonl`,
  `10553_XAUUSD_DWX.jsonl`, and `9936_USDJPY_DWX.jsonl`.
- These are `TRADE_CLOSED` streams. `framework/include/QM/QM_Common.mqh`
  emits closing-deal records containing close-time P/L and trade MAE; it does
  not emit a sampled account-equity series.
- `tools/strategy_farm/portfolio/challenge_campaign.py` consumes only those
  closed-trade streams. Its daily-cap calculation therefore cannot be changed
  to a tester-observed intraday equity minimum without a new evidence stream.
- At inspection time, farm work item
  `7be51839-1a9e-421c-a6bc-fd2bcb76733c` for
  `QM5_9936 / USDJPY.DWX / Q08` was `active`, claimed by T10. The orchestration
  hard rule forbids interrupting active T1–T10 backtests.
- No `D:/QM/reports/portfolio/sleeve_streams/QM/q08_equity/` directory or
  matching equity artifacts existed.

## Consequence

The previously reported 80.7% remains an upper bound. Its floating-P/L delta is
**unknown**, not zero. No Factory mode was run, no terminal was started or
interrupted, and no commission, swap, or equity values were inferred.

## Required follow-up

Add a bounded tester-only equity sampler to the common framework (at minimum one
sample per bar plus every new intraday low), persist deterministic JSONL rows to
`FILE_COMMON/QM/q08_equity/<bare>_<SYMBOL>_DWX.jsonl`, compile the four EAs, and
enqueue clean full-history tester work through the normal worker queue after the
active T10 item completes. Only after all four streams are provenance-bound may
`challenge_campaign.py` evaluate the daily cap against each day's sampled equity
minimum and publish the measured movement from 80.7%.

