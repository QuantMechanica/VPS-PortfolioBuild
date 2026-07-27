# FTMO Phase 1 — a measured route to P(pass) ≈ 0.80

Date: 2026-07-26
Author: Claude
Status: measured, pending OWNER money-gate and one deployment check
**CORRECTED 2026-07-27** after three adversarial reviews (corrections block directly
below). Several claims are withdrawn or downgraded; the originals are left in place,
struck or annotated, so the record of what was wrong survives.
Supersedes the recommendation in `FTMO_BOOK_STATE_2026-07-26.md` ("no challenge
account against this book")

## CORRECTIONS — 2026-07-27 adversarial review

Review prompts: `scratchpad/challenge_A_campaign.md`, `challenge_B_deploy.md`,
`challenge_C_gates.md`. Five claims did not survive review and are corrected below.

- **A. This book is NOT pipeline-admitted today.** `Q09_PORTFOLIO = FAIL_PORTFOLIO`
  is the current farm-state verdict on 13213/USDJPY (2026-07-25), 10848/XAUUSD
  (2026-07-14) and 10553/XAUUSD (2026-07-16); 13036/GDAXI is `Q09_PORTFOLIO = pending`
  (never judged). **None of the four sleeves is Q09-admitted.** Whatever the merit of
  the "Q09 judges a shared-equity book, not separate accounts" argument (§"Why one
  book fails and three accounts work"), the pipeline has not admitted this material.
  This document is a research proposal, not a gate-cleared deployment, and no number
  in it changes that.
- **B. "Target awareness is worth +28.8pp" was a strawman.** That claim never appeared
  in this file's tables, but it drove the earlier six-account framing
  (`tools/strategy_farm/portfolio/challenge_final.py`: 86.3 % "with" vs 57.5 % "must
  END ≥ +10 %"). FTMO does **not** close the account at target — per ftmo.com, once the
  objectives are met the account is "set for review" (1–4 business days). The
  **touch-based** measure this file already uses (`scratchpad/parallel_accounts.py:154`
  — the window passes the instant equity ≥ +10 %) is the correct one; the
  "must END ≥ +10 %" counterfactual does not describe an unmodified EA. Flattening at
  target is a **safety measure to protect the review window, not a probability lever.**
- **C. The margin verdict is unsupported, not proven** — FTMO's broker stop-out level
  was never captured, so "the FTMO rule binds before any margin call" is undetermined.
  See §"The binding constraint is now margin, not statistics".
- **D. The margin/notional tables are a gross-exposure approximation, not a margin
  proof** — `notional` is a closing-price product and "exposure ÷ leverage" is not the
  MT5 margin formula. The authoritative figure is `OrderCalcMargin` on the real
  account. See the same section.
- **E. 10848 is deployed at @4×, not @5×, and the tables mix measurement runs.** The
  committed set files / manifest are the ground truth (13213@4, 10848@4, 10553@8,
  13036@8; no 9936 set file exists). See the corrected "Deployable artifacts" table
  and the inline notes on the pass-rate and margin tables.

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

> **CORRECTION 2026-07-27 (run attribution, per correction E).** This table is the
> **touch-based upper measurement** (`scratchpad/parallel_accounts.py`) with
> **10848 at @5×** and 12823 as the fourth account. The **deployed** book (manifest
> `2026-07-27_ftmo_challenge_deploy_manifest.json`, set files verified) is
> **13213@4× · 10848@4× · 10553@8× · 13036@8×** — 10848 is @4× not @5×, and 13036
> replaces both 9936 and 12823. These pass rates were therefore **not** measured on
> the deployed set files and cannot be attributed to them without a re-run at
> 10848@4× with 13036. They stand only as the figures for the book/leverage stated in
> the "books" column.

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

> **CORRECTION 2026-07-27 (per correction A).** This is an argument, not an admission.
> `Q09_PORTFOLIO = FAIL_PORTFOLIO` is the live verdict on 13213/USDJPY, 10848/XAUUSD
> and 10553/XAUUSD, and 13036/GDAXI is `Q09_PORTFOLIO = pending` — so **as of today
> not one book sleeve is pipeline-admitted**, whether or not the transfer argument is
> correct. There is no "Q09-for-separate-accounts" gate that has passed this
> structure; the claim that the verdict "does not transfer" has not itself been
> adjudicated by the pipeline. Treat the book as un-admitted research material.

## Method

`scratchpad/parallel_accounts.py` and the gate-strict variant. Per sleeve, daily
trade streams from `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades`.

- **Rules per window**: +10 % target, −5 % daily cap, −10 % total cap, 22 trading
  days ≈ 30 calendar days (OWNER's constraint; FTMO itself dropped the time limit
  in 2024, so this is the harder test).
- **Pass = equity *touches* +10 % at any instant, not "ends ≥ +10 %"**
  (`scratchpad/parallel_accounts.py:154` breaks the window the moment `eq ≥ TARGET`).
  This is deliberate and correct (CORRECTION 2026-07-27, per correction B): FTMO sets
  the account "for review" once objectives are met (ftmo.com, 1–4 business days) — it
  does not liquidate at target. An earlier six-account analysis reported a
  "+28.8pp target-awareness" lever (86.3 % touch vs 57.5 % "must END ≥ +10 %"); the
  "must END" branch was a strawman counterfactual — no unmodified EA is forced to end
  a window exactly at +10 % — and it is **withdrawn**. Flattening at target is a safety
  measure protecting the review window, not a probability lever.
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

> **CORRECTION 2026-07-27 (run attribution, per correction E).** This MAE-bounds run
> (`tools/strategy_farm/portfolio/challenge_campaign_mae.py`) uses **10848 at @5×** and
> takes **9936/USDJPY** as its first account — 9936 whose Q08 is still `INFRA_FAIL`
> and pending re-run (see below). The deployed book is 10848**@4×** with **13036** in
> place of 9936. So neither the 81.1 % lower bound nor the 85.4 % four-account figure
> was measured on the deployed set files; both belong to the book in the "books"
> column, not to the artifact that ships.

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

> **CORRECTION 2026-07-27 (exposure method, per correction D).** These `notional`
> figures are a **gross-exposure approximation, not a margin proof.** Per-trade
> `notional` is `QM_Common.mqh:753` = `volume × contract_size × close_price` — it uses
> the trade's **closing** price and is then applied retroactively across the whole
> holding interval, so it is neither the entry exposure nor the mark-to-market
> exposure at each instant. When the profit-currency→account-currency rate is
> unavailable it falls through **unconverted** at `QM_Common.mqh:767` (a
> `Q08_NOTIONAL_CONVERSION_FALLBACK` warning), so for non-USD-profit symbols the
> account-currency scale can be wrong. Summed peak-concurrent notional therefore
> mis-times and can mis-scale true exposure. Separately, **10848's "@5×" row (4.3× →
> 21.5×) is stale**: the deployed set file is @4×, i.e. 4.3× → **17.2×**.
>
> **"Margin required = exposure ÷ broker leverage" is not the universal MT5 margin
> formula.** MT5 margin depends on the symbol's calculation mode, margin-rate tiers,
> and hedged/netting rules; it is not simply notional/leverage. The authoritative
> per-account figure is `OrderCalcMargin` (or the platform-reported margin) on the
> **real FTMO account** — the table below is an estimate to be confirmed there, not a
> proof.

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

_Table as originally written (SUPERSEDED, per correction E — mixes 9936, which is
not in the deployed book, with 10848 at @5×; margin figures use the exposure÷leverage
estimate flagged above):_

| account | exposure | FTMO leverage | margin used | margin level at −10 % equity |
|---|---|---|---|---|
| 9936/USDJPY @4 % | 65.9× | 1:100 | 65.9 % | 137 % |
| 13213/USDJPY @4 % | 73.8× | 1:100 | 73.8 % | 122 % |
| 10848/XAUUSD @5 % | 21.5× | 1:30 | 71.7 % | 126 % |
| 10553/XAUUSD @8 % | 19.9× | 1:30 | 66.3 % | 136 % |

**CORRECTED 2026-07-27 to the deployed book** (from
`docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json`; still the
exposure÷leverage estimate, to be confirmed with `OrderCalcMargin` on the real
account, per correction D):

| account | exposure | FTMO leverage | margin used | margin level at −10 % equity |
|---|---|---|---|---|
| 13213/USDJPY @4 % | 73.8× | 1:100 | 73.8 % | 122 % |
| 10848/XAUUSD @4 % | 17.2× | 1:30 | 57.3 % | 157 % |
| 10553/XAUUSD @8 % | 19.9× | 1:30 | 66.3 % | 136 % |
| 13036/GDAXI @8 %  | 5.2×  | 1:50 | 10.4 % | 865 % |

~~**All four fit.** And the decisive part: at the equity where FTMO's total-loss rule
has *already* ended the challenge (90 k), every account still stands above 120 %
margin level. A broker stop-out sits far below that, so **the FTMO rule binds
before any margin call** — which means the stop-out percentage FTMO does not
publish (it tells you to read it off the platform) cannot change the verdict. The
simulation's assumption that positions are held to their modelled outcome holds.~~

> **CORRECTION 2026-07-27 (stop-out unsupported, per correction C).** The struck claim
> does not stand. FTMO's broker **stop-out level was never captured** — "a broker
> stop-out sits far below 120 %" has no measurement behind it. Until
> `ACCOUNT_MARGIN_SO_SO` and `ACCOUNT_MARGIN_SO_CALL` are read from a real FTMO
> account, whether the −10 % loss rule or a margin call binds first is
> **undetermined**; and (per correction D) the margin-level column above is itself an
> approximation, not the true MT5 margin. "The unpublished stop-out cannot change the
> verdict" is withdrawn pending those two account values.

The thin part, stated because a backtest cannot show it: free margin is only
26–34 %. A position opened while the book already sits near peak exposure could be
rejected outright. That is an execution risk, it is exactly what a demo run
surfaces, and it is the reason to demo before paying a fee.

Research task `9b7c6aaf` remains open for the `venue_cost_model.json` patch, so
this becomes a registry fact rather than a document footnote.

## Deployable artifacts

Four set files, one per challenge account, committed.

_Table as originally written (SUPERSEDED, per correction E — 9936 has no committed
set file, and 10848 was listed at @5× with a SHA that is not the committed file):_

| account | set file | RISK_PERCENT | SHA256 (12) |
|---|---|---|---|
| 9936/USDJPY H1 | `..._USDJPY.DWX_H1_ftmo_challenge.set` | 4 | `9943718b23ca` |
| 13213/USDJPY H1 | `..._USDJPY.DWX_H1_ftmo_challenge.set` | 4 | `0c81c93ed2a3` |
| 10848/XAUUSD H1 | `..._XAUUSD.DWX_H1_ftmo_challenge.set` | 5 | `adbcf57b1c8f` |
| 10553/XAUUSD H4 | `..._XAUUSD.DWX_H4_ftmo_challenge.set` | 8 | `8d578b6007a0` |

**CORRECTED 2026-07-27** — the actually committed set files (SHA256 recomputed from
disk; matches `2026-07-27_ftmo_challenge_deploy_manifest.json`). There is **no 9936
challenge set file**; the fourth deployed sleeve is **13036/GDAXI @8×**, and 10848 is
**@4×**:

| account | set file | RISK_PERCENT | SHA256 (12) |
|---|---|---|---|
| 13213/USDJPY H1 | `..._USDJPY.DWX_H1_ftmo_challenge.set` | 4 | `0c81c93ed2a3` |
| 10848/XAUUSD H1 | `..._XAUUSD.DWX_H1_ftmo_challenge.set` | 4 | `a094d0ea125d` |
| 10553/XAUUSD H4 | `..._XAUUSD.DWX_H4_ftmo_challenge.set` | 8 | `8d578b6007a0` |
| 13036/GDAXI M15 | `..._GDAXI.DWX_M15_ftmo_challenge.set` | 8 | `7e4c87af0561` |

Manifest: `docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json`.
All four deployed `.ex5` binaries verified present. **Note (per correction E):** the
pass-rate tables above were measured on an earlier book (10848@5×, with 9936/12823 as
members), so they do not describe these deployed set files; a re-run at 10848@4× with
13036 is required before any pass rate can be attributed to what actually ships.

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
2. ~~Confirm FTMO's margin leverage~~ — leverage **values** are confirmed from
   ftmo.com (forex 1:100 / metals 1:30 / indices 1:50). But ~~All four accounts fit,
   and the FTMO loss rule binds before any margin call~~ is **withdrawn**
   (corrections C, D): the "fit" rests on a gross-exposure approximation
   (`notional` = closing-price product, `QM_Common.mqh:753`) and the stop-out level
   was never captured, so margin adequacy is **unconfirmed pending `OrderCalcMargin`
   and `ACCOUNT_MARGIN_SO_SO`/`ACCOUNT_MARGIN_SO_CALL` on a real FTMO account.**
3. ~~Translate multipliers into `RISK_PERCENT` set files~~ — **done**, four files
   committed with `RISK_FIXED=0`, parameter-identical to the measured runs.
4. **Run it on an FTMO demo/free-trial account.** This is now the next real step
   and it costs nothing. What the demo is actually testing, beyond "does it
   trade": whether positions fill at 26–34 % free margin, whether FTMO's spreads
   on XAUUSD and USDJPY resemble the `.DWX` history, and whether `RISK_PERCENT`
   sizing reproduces the tested lot sizes at a 100 k balance.
5. 9936/USDJPY Q08 is **active** (work item `7be51839`). Until it returns, the
   strongest member is pending rather than passed — the 3-account configuration
   excluding it (13213 + 10848 + 10553, 80.7 %) is ~~the fully gate-backed one~~
   **NOT gate-backed** (correction A): all three sleeves carry `Q09_PORTFOLIO =
   FAIL_PORTFOLIO`, so no configuration in this file is pipeline-admitted today.
6. **OWNER money-gate**: paying for challenge accounts is OWNER's decision alone
   and is not assumed anywhere above. The demo step does not require it.
7. **Re-measure the campaign on the deployed book** (correction E): the pass-rate
   tables were computed with 10848 at @5× and with 9936/12823 as members, but the
   committed set files are 10848**@4×** with **13036** replacing them. No pass rate
   in this file describes the artifact that ships until that re-run exists.
