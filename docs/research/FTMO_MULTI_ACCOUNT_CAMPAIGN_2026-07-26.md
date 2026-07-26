# FTMO Phase 1 — a measured route to P(pass) ≈ 0.80

Date: 2026-07-26
Author: Claude
Status: measured, pending OWNER money-gate and one deployment check
Supersedes the recommendation in `FTMO_BOOK_STATE_2026-07-26.md` ("no challenge
account against this book")

## Summary

A campaign of **three parallel challenge accounts, each running a different
sleeve**, passes **80.7 %** of out-of-sample 22-trading-day windows. Earlier today
I recommended against buying a challenge on the grounds that the best book we
could assemble sat in the low tens of percent. That recommendation was wrong, and
it was wrong for a specific, correctable reason: it scored books with `speed`
= (%/yr)/maxDD, a proxy that divides by the worst drawdown in fifteen years,
when the question is a single 22-day draw.

Measured directly, with FTMO's rules applied window by window:

| accounts | P(at least one passes) | 95 % CI | books |
|---|---|---|---|
| 1 | 48.3 % | 32–65 % | 13213/USDJPY @ 4× |
| 2 | 71.8 % | 57–86 % | + 10848/XAUUSD @ 5× |
| 3 | **80.7 %** | 68–94 % | + 10553/XAUUSD @ 8× |
| 4 | 81.8 % | 69–94 % | + 12823/USDJPY @ 8× |

## Why one book fails and three accounts work

Every multi-sleeve **book** scored *worse* than its best single member — without
exception across the whole search. That is not noise, it is structural, and it
inverts the portfolio intuition I had been applying:

> The +10 % target sits far above the expected 22-day return. Reaching it depends
> on an upward excursion. Merging sleeves averages excursions away. Diversification
> protects an account that must **survive**; it works against an account that must
> **sprint**.

The fix is to diversify across *accounts* rather than inside one. Separate
accounts do not share a drawdown limit, so each keeps its own variance, and the
campaign succeeds if any one of them reaches target. This is also why
`Q09_PORTFOLIO = FAIL_PORTFOLIO` on all four sleeves does **not** transfer: that
gate judges sleeves sharing a single equity curve and a single 10 % cap. The
campaign proposes the opposite structure.

## Method

`scratchpad/parallel_accounts.py` and the gate-strict variant. Per sleeve, daily
trade streams from `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades`.

- **Rules per window**: +10 % target, −5 % daily cap, −10 % total cap, 22 trading
  days ≈ 30 calendar days (OWNER's constraint; FTMO itself dropped the time limit
  in 2024, so this is the harder test).
- **Daily cap checked intraday.** An earlier cut checked it against the day's
  *closed* P&L, which silently survives any day that sinks 6 % at midday and
  recovers by the close. Re-checked at trade-close granularity, the single-sleeve
  figure moved 63.2 % → 61.7 %.
- **Selection is in-sample only.** Books and leverages are chosen on
  2017-10-09 … 2022-09-14; every number above is scored on 2022-09-14 … 2025-12-30,
  which the selection never saw.
- **Joint probability is counted, never assumed.** Accounts are run through the
  same windows and windows where at least one passed are counted directly. This
  matters: the first two-account pair measured 69.4 % against an independence
  prediction of 72.5 % — they share failure days, and assuming independence would
  have overstated the campaign.

## What this number is not

- **Floating P&L on open positions is still not modelled.** A position 4 % under
  water at noon breaches FTMO even if it closes green, and no closed-trade record
  can show that. 80.7 % remains an upper bound; closing this gap needs per-bar
  equity from the tester, not the trade stream. **This is the single largest
  remaining uncertainty and should be resolved before any fee is paid.**
- **The confidence interval reaches below the goal.** ~37 independent windows give
  68–94 %. The point estimate meets 80 %; the lower bound does not.
- **Two of the three accounts are XAUUSD** (10848, 10553). Their joint behaviour
  is captured in the 80.7 % because outcomes were counted rather than modelled,
  but the campaign is concentrated in one underlying.
- **Leverage 4×–8× is relative to backtest sizing**, not a `RISK_PERCENT` value.
  It must be translated and margin-checked per symbol before deployment.
- **Sleeve pre-filtering used gate verdicts computed over full history**, which
  includes the scoring period. The gates select for robustness rather than 22-day
  pass rate, so the leak is second-order — but it is a leak, and it is named here
  rather than left implicit.

## Gate semantics — a correction worth recording

My first gate-strict pass concluded "zero sleeves survive, the campaign is dead".
That was a filter bug, not a finding. `farmctl.py:9637` promotes on
`verdict IN ('FAIL_SOFT','PASS')` (DL-082 §3c), and `farmctl.py:9592` shows
`FAIL_SOFT` means tier `EDGE_SOFT` or `LOW_SAMPLE` — "edge soft or sample small",
an advancing state, not a rejection. Q08 `FAIL`/`FAIL_HARD`/`INVALID` are the real
rejections.

The unfiltered version of this analysis reached 88.4 % — but on sleeves that
included **12475/NDX with Q04 = FAIL** outright. That is the same trap as the
WS30 speed outlier caught earlier today, entered from the opposite direction, and
it is why every number in this document is gate-filtered.

Farm-wide Q08 verdicts: 174 `FAIL_SOFT`, 163 `INFRA_FAIL`, 122 `FAIL_HARD`,
18 `PASS`. **34 % of all Q08 runs are infrastructure failures**, not verdicts.

## Immediate consequence

**9936/USDJPY is the strongest sleeve measured (55.6 % solo, out-of-sample) and it
is excluded from the campaign for no merit reason.** It passes Q02, Q03, Q04, Q05,
Q06 and Q07 cleanly; its only Q08 row is `INFRA_FAIL` at 2026-07-26T18:07:51 —
inside the window when the fleet was pinned by the commit-reservation defect.

Requeued: work item `7be51839-1a9e-421c-a6bc-fd2bcb76733c`, Q08, USDJPY.DWX.

If it returns `PASS` or `FAIL_SOFT`, it replaces the weakest campaign member and
the three-account figure rises materially — 9936 scored 55.6 % solo against
13213's 48.3 %.

## Recommended next steps

1. **Resolve the floating-P&L gap** before any money moves: re-run the three
   campaign sleeves with per-bar equity export and re-measure the daily-cap
   breaches. This can only lower the 80.7 %; the question is by how much.
2. Let 9936/USDJPY Q08 complete and re-run the campaign measurement.
3. Translate 4×–8× into `RISK_PERCENT` per symbol with a margin check.
4. **OWNER money-gate**: three parallel challenge accounts means three fees. That
   decision is OWNER's alone and is not assumed anywhere above.
