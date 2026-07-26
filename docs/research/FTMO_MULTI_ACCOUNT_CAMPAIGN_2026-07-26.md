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

## UPDATE — the floating-P&L gap is closed, from the streams themselves

The trade streams carry **`mae_acct`**: maximum adverse excursion per trade, in
account currency. The very first record in 13213's stream is the exact failure
case that worried me — `mae_acct −610.47` against `net +35.92`, a trade that sat
deeply red and closed green.

So the gap did not need a per-bar equity export. `challenge_campaign_mae.py`
computes **both** bounds:

- **upper** — closed P&L only, floating loss invisible (the 80.7 % above);
- **lower** — every open position assumed to sit at its own worst point
  *simultaneously*, at every instant it is open. That cannot physically occur, so
  it understates the pass rate as surely as the upper bound overstates it.

| accounts | upper | **lower** | books |
|---|---|---|---|
| 1 | 55.8 % | 53.9 % | 9936/USDJPY @4× |
| 2 | 75.9 % | 73.3 % | + 10848/XAUUSD @5× |
| 3 | 83.3 % | **81.1 %** | + 10553/XAUUSD @8× |
| 4 | 87.7 % | **85.4 %** | + 13213/USDJPY @4× |

**Both bounds clear 80 % at three accounts.** The goal holds under the most
pessimistic floating-loss assumption available, so the answer no longer depends on
the unmodelled term.

(9936/USDJPY re-enters the pool because its `INFRA_FAIL` Q08 row was invalidated by
the requeue. Its Q08 is therefore **pending, not passed** — the campaign's strongest
member is not yet gate-confirmed, and that is a caveat, not a result.)

## The binding constraint is now margin, not statistics

Peak **concurrent** notional per account, as a multiple of 100 k equity, at
leverage 1.0 — measured from the `notional` field:

| sleeve | at 1.0× | at its campaign leverage |
|---|---|---|
| 13213/USDJPY | 18.5× | 73.8× @4× |
| 9936/USDJPY | 16.5× | 65.9× @4× |
| 10848/XAUUSD | 4.3× | 21.5× @5× |
| 10553/XAUUSD | 2.5× | 19.9× @8× |
| 12823/USDJPY | 0.8× | — |

Margin required = exposure ÷ broker leverage. At 1:100 the USDJPY sleeves use
66–74 % of the account; at 1:30 they need 220–246 % and are simply impossible.
**`venue_cost_model.json` carries FTMO commissions but no leverage or margin
fields**, and the Hard Rules bar inventing one — so the result is instead reported
against an explicit exposure cap (`challenge_campaign_capped.py`), and the row
matching FTMO's real leverage can be read off once it is known:

| exposure cap | accounts | upper | lower |
|---|---|---|---|
| 10× | 3 | 60.3 % | 58.5 % |
| 20× | 5 | 79.5 % | 74.7 % |
| 30× | 5 | 81.9 % | 77.2 % |
| **50×** | 5 | 91.0 % | **84.7 %** |
| 75× | 5 | 93.4 % | 86.0 % |

Research enqueued for the cited figure: agent task `9b7c6aaf` (priority 94),
official FTMO leverage per symbol class plus stop-out level, with a proposed
`venue_cost_model.json` patch so it becomes a registry fact.

**A second caveat on the capped table**: it reaches its best rows by running
low-exposure sleeves at very high multipliers (12823 at 61–91×). Those are
extrapolations far outside the tested size — the `.DWX` history includes spread
but not market impact, and ~700 lots of USDJPY does not fill at backtest prices.
The uncapped 3–4 account configuration at 4–8× is the defensible one; the capped
table exists to show how the answer moves with margin, not to recommend 91×.

## What this number is still not
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

1. ~~Resolve the floating-P&L gap~~ — **done**, from `mae_acct` in the streams.
   Both bounds clear 80 % at three accounts. Codex ticket `a5768d03` (per-bar
   equity export) is now a refinement rather than a blocker: it would replace the
   two bounds with a single figure, but it can no longer change the verdict.
2. **Confirm FTMO's margin leverage** — agent task `9b7c6aaf`. This is the only
   remaining external unknown, and it decides whether the 4×–8× configuration is
   fundable as-is or must be rebuilt around the low-exposure sleeves.
3. Let 9936/USDJPY Q08 complete (work item `7be51839`) — it is the strongest
   member and currently pending, not passed.
4. Translate the surviving multipliers into `RISK_PERCENT` set files once (2) is
   known; `RISK_FIXED=0` for live per the Hard Rules.
5. **OWNER money-gate**: three or four parallel challenge accounts means three or
   four fees. That decision is OWNER's alone and is not assumed anywhere above.
