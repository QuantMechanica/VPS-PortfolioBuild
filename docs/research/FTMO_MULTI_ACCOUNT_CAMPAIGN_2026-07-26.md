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

### RESOLVED 2026-07-27 — FTMO's published leverage

From ftmo.com directly (blog *"A few answers to your questions"*, and the account
specifications FAQ), for the **Normal** account type:

> forex **1:100** · indices **1:50** (1:30 for HK50.cash, US2000.cash, SPN35.cash)
> · metals **1:30** · crypto/equity CFD/commodities 1:3.3
> Swing accounts: up to 1:30 throughout.

Applied per account — and separate challenge accounts share margin with nothing:

| account | exposure | FTMO leverage | margin used | margin level at −10 % equity |
|---|---|---|---|---|
| 9936/USDJPY @4 % | 65.9× | 1:100 | 65.9 % | 137 % |
| 13213/USDJPY @4 % | 73.8× | 1:100 | 73.8 % | 122 % |
| 10848/XAUUSD @5 % | 21.5× | 1:30 | 71.7 % | 126 % |
| 10553/XAUUSD @8 % | 19.9× | 1:30 | 66.3 % | 136 % |

**All four fit.** And the decisive part: at the equity where FTMO's total-loss rule
has *already* ended the challenge (90 k), every account still stands above 120 %
margin level. A broker stop-out sits far below that, so **the FTMO rule binds
before any margin call** — which means the stop-out percentage FTMO does not
publish (it tells you to read it off the platform) cannot change the verdict. The
simulation's assumption that positions are held to their modelled outcome holds.

The thin part, stated because a backtest cannot show it: free margin is only
26–34 %. A position opened while the book already sits near peak exposure could be
rejected outright. That is an execution risk, it is exactly what a demo run
surfaces, and it is the reason to demo before paying a fee.

Research task `9b7c6aaf` remains open for the `venue_cost_model.json` patch, so
this becomes a registry fact rather than a document footnote.

## Deployable artifacts

Four set files, one per challenge account, committed:

| account | set file | RISK_PERCENT | SHA256 (12) |
|---|---|---|---|
| 9936/USDJPY H1 | `..._USDJPY.DWX_H1_ftmo_challenge.set` | 4 | `9943718b23ca` |
| 13213/USDJPY H1 | `..._USDJPY.DWX_H1_ftmo_challenge.set` | 4 | `0c81c93ed2a3` |
| 10848/XAUUSD H1 | `..._XAUUSD.DWX_H1_ftmo_challenge.set` | 5 | `adbcf57b1c8f` |
| 10553/XAUUSD H4 | `..._XAUUSD.DWX_H4_ftmo_challenge.set` | 8 | `8d578b6007a0` |

Manifest: `docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json`.
All four `.ex5` binaries verified present.

**Why these are derived from the backtest sets and not regenerated.** Running
`gen_setfile.ps1 -Env demo` produced set files that would have silently run a
different strategy from the one measured:

- **10848** — the backtest set carries `qm_filter_news_enabled=1` and
  `qm_filter_news_mode=3`; the regenerated demo set omitted both, leaving the news
  filter to whatever the EA compiles in.
- **9936** — its backtest set records `card_defaults_source=not_found`, so the
  measured run used the EA's own input defaults, while a regenerated set writes
  card values over them.
- **13213** — card lookup returned null and fell back to `ea_input_defaults`.

The campaign's 81 % came from runs using the *backtest* sets, so the deployable
artifact is those files with only the risk block changed. `make_challenge_setfiles.py`
does that and verifies parameter identity: all four are byte-identical to their
source apart from `RISK_FIXED`/`RISK_PERCENT`.

Sizing translation is exact rather than fitted — `tester_defaults.json` sets
`initial_deposit = 100000` and all four EAs backtest at `RISK_FIXED = 1000`, i.e.
1 % of account, so multiplier L becomes `RISK_PERCENT = L`.

One behavioural difference that survives and should be watched on the demo:
`RISK_PERCENT` sizes off live equity, so position size drifts upward as the
account gains, while `RISK_FIXED` did not. Over a 22-day run reaching +10 % that is
second-order, but it is real.

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
2. ~~Confirm FTMO's margin leverage~~ — **done**, cited above. All four accounts
   fit, and the FTMO loss rule binds before any margin call.
3. ~~Translate multipliers into `RISK_PERCENT` set files~~ — **done**, four files
   committed with `RISK_FIXED=0`, parameter-identical to the measured runs.
4. **Run it on an FTMO demo/free-trial account.** This is now the next real step
   and it costs nothing. What the demo is actually testing, beyond "does it
   trade": whether positions fill at 26–34 % free margin, whether FTMO's spreads
   on XAUUSD and USDJPY resemble the `.DWX` history, and whether `RISK_PERCENT`
   sizing reproduces the tested lot sizes at a 100 k balance.
5. 9936/USDJPY Q08 is **active** (work item `7be51839`). Until it returns, the
   strongest member is pending rather than passed — the 3-account configuration
   excluding it (13213 + 10848 + 10553, 80.7 %) is the fully gate-backed one.
6. **OWNER money-gate**: paying for challenge accounts is OWNER's decision alone
   and is not assumed anywhere above. The demo step does not require it.
