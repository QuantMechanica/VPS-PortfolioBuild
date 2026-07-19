# QM5_20009 ICT Liquidity Portfolio — frozen research contract v4

**EA ID:** 20009  
**Slug:** `ict-liquidity-portfolio`  
**Contract freeze:** 2026-07-19  
**Authorization:** OWNER-delegated for research, build and testing in the 2026-07-19
Codex session. This is not authorization for a paid challenge or live deployment.

## 1. Evidence boundary and provenance

No row in `Trades_some_icy_tea.xlsx` is treated as a realized result. The workbook
is a curated screenshot catalogue with strong survivorship and hindsight-label
bias: 770 rows are labelled `Trade`, but it has no systematic result field, stop,
date, or losing-signal universe. It supports vocabulary and hypothesis frequency,
not win rate, expectancy, or target selection.

Local inputs:

- `C:\Users\Administrator\Downloads\MQL5_Strategie_Spezifikation_some_icy_tea.docx`
- `C:\Users\Administrator\Downloads\Trades_some_icy_tea.xlsx`
  (SHA-256 `61e29a66c1a17511906020b4f6b99ea81b0693fb6c4e5b894df3d8fb2e231e70`)
- `D:\QM\reports\ict_intake\spec.txt`
- the local ICT cards, EAs, reports and V5 framework inspected on 2026-07-19

Primary online sources:

- Michael J. Huddleston, *2022 ICT Mentorship Episode 2*:
  https://www.youtube.com/watch?v=tmeCWULSTHc
- Michael J. Huddleston, *2023 ICT Mentorship — ICT Silver Bullet Time Based
  Trading Model*: https://www.youtube.com/watch?v=tRq1hyGGtl4
- FTMO, *Trading Objectives*: https://ftmo.com/en/trading-objectives/
- MQL5 time semantics:
  https://www.mql5.com/en/docs/dateandtime/timegmt and
  https://www.mql5.com/en/docs/dateandtime/timetradeserver

The source-supported common sequence is:

> external/session liquidity sweep -> reclaim -> a later closed-bar market-
> structure shift -> the earliest post-shift FVG -> first retracement to its
> proximal edge -> stop beyond the swept extreme -> fixed opposing liquidity.

Sleeve A has direct primary-source support for the sequence and 10:00-11:00 New
York window. Sleeve B's previous-week/session construction is an engineering
hypothesis; it must never be described as an official ICT weekly strategy.

## 2. Shared deterministic execution rules

- Signals use completed Bid bars only and run once per new execution-timeframe bar.
  Bar 0 and future bars are never read for a decision.
- New-York windows are half-open. Broker time is converted through explicit
  broker-to-UTC and US-DST rules; tester `TimeGMT()` is not historical UTC.
- A strict pivot with wing `w` is usable only after its right wing has closed.
- A low sweep penetrates a frozen level by at least one symbol tick and closes back
  above it on the sweep bar or within `reclaim_bars`; a high sweep is mirrored.
- MSS is the first bar *after* reclaim that closes through the most recent confirmed
  pre-penetration opposite pivot. Sweep/reclaim and MSS on one bar is invalid.
- Only the earliest directionally matching FVG after MSS is considered. At its
  close the proximal edge becomes an immutable virtual-limit intent. If that edge
  was already touched when eligible, the attempt is void; no later FVG may rescue
  it. On a later tick, Buy triggers only at `Ask <= edge` and Sell only at
  `Bid >= edge`; the EA then rechecks every gate and sends one market order.
- In frozen v4, the volatility term is **SMA-TR(14)**: the arithmetic mean of
  the latest 14 causal true ranges at the FVG bar, not Wilder-smoothed ATR.
  Stop padding is `max(2 * observed spread, sl_buffer_atr * SMA-TR(14))` beyond
  the swept extreme. A fixed target must lie beyond entry and meet `min_rr`.
- No partial close, break-even, trailing stop, discretionary bias, SMT, OTE, order-
  block ranking, or news-reversal logic exists in v1.
- Position management, hard time exits and orphan broker-order deletion execute
  before entry-only news, session and governor filters.
- The entry-only news gate is frozen to temporal `PRE30_POST30`, compliance
  `FTMO`, stale limit 336 hours, and minimum impact `high`; the framework's
  placeholder `DXZ` compliance profile is not admissible for this build.
- No strategy server-pending order is permitted. An armed virtual intent has an
  immutable cancel boundary equal to the earlier of session end and the next
  applicable news-blackout start. It is checked on every tick with an uncached
  news verdict and on a UI-independent one-second live timer. Any crossed boundary,
  news block, stale/locked/zero governor, live event-loop gap over five seconds,
  invalid trigger geometry, restart, or send attempt permanently voids it; it
  cannot revive after a gap or blackout.
- One position and one virtual intent per symbol/magic. Filled-trade and consumed-
  attempt budgets are reconstructed from bounded bars, historical orders/deals,
  and a persistent live-terminal marker containing `event_bar_time` plus both
  frozen hashes. State `CONSUMED` lets only that identical event progress on later
  bars; the immutable intent fields and state `SUBMITTED` are flushed when armed.
  At touch the intent is durably removed before `OrderSend`, blocking every retry,
  including rejects. A restart always voids an armed intent because missed ticks
  and gate transitions cannot be disproved. Same-budget event/hash drift and
  partial or unreadable persistence fail closed. Tester markers are process-local
  so duplicate tester runs cannot contaminate one another.
- Arm-time validation applies no server-pending stop-level or quote-to-entry
  distance because no pending request exists. It checks one atomic quote, an
  untouched edge and directional stop/target geometry only. At touch, executable
  entry economics and RR use Ask for buys and Bid for sells; broker SL/TP distance
  uses the closing side (Bid for buys, Ask for sells). The shared trade layer is
  explicitly placed in `SEND_ONCE` mode for both tester and live paths, so Requote
  and Price-Off cannot generate a second `OrderSend`.
- Position volume is risk-sized at the freshly resolved executable price and then
  capped to 90% of free margin with `OrderCalcMargin` for that exact market side.
  Calculation failure returns zero lots; no notional/leverage estimate may rescue
  the entry.

## 3. Sleeve A — `INDEX_MSS_FVG_AM`

**Primary:** `NDX.DWX`, M1, both directions.  
**Transport:** `GDAXI.DWX`, M1, reported separately and never used to tune NDX.

1. Build and freeze the New-York cash-opening range from `[09:30,10:00)` each day.
2. Only `[10:00,11:00)` is an entry/setup window. The first chronological
   penetration/reclaim of either frozen boundary consumes the day. If both sides
   penetrate in the same bar, consume the day as ambiguous with no trade.
3. Require the shared later-MSS sequence using the pre-sweep opposite pivot.
4. Use the earliest post-MSS FVG and immediately arm its proximal edge as a
   virtual limit. All sweep, reclaim, MSS, FVG creation, and intent arming complete
   inside `[10:00,11:00)`.
5. Long target is the frozen opening-range high; short target is its low. Invalid
   target direction or insufficient R means no trade; never jump to a farther pool.
6. The virtual intent expires at 11:00 or the next news-blackout start, whichever
   is earlier. Maximum one consumed attempt and one fill per NY day. Any filled
   position hard-flats at 15:55 NY.

State machine: `PREOPEN -> RANGE_FROZEN -> PENETRATED -> RECLAIMED -> MSS ->
VIRTUAL_LIMIT -> TRIGGERED/FILLED/DONE`. The key is NY date + symbol + mode; restart replay hashes the
frozen opening range. Missing/incomplete range, same-bar MSS, no pre-sweep pivot,
ambiguous sweep, touched/absent FVG, invalid target/R, or expiry are explicit
no-trade outcomes.

## 4. Sleeve B — `FX_WEEKLY_SESSION_SWEEP`

**Locked development universe:** `EURUSD.DWX` and `GBPUSD.DWX`, M5, both
directions. Both symbols and both London/NY cells are always reported; neither may
be dropped after results are seen.

1. Define the prior NY trading week as Sunday 17:00 inclusive through Friday 17:00
   exclusive from observed bars, not broker D1. At the next Sunday 17:00 freeze
   PWH/PWL. If it contains fewer than three distinct trading dates, skip the week.
2. Eligible sessions are London `[02:00,05:00)` NY and New York `[07:00,10:00)` NY.
   All sweep/reclaim/MSS/FVG/intent-arm events finish in the same active session.
3. The completed reference range is Asian `[20:00,00:00)` before London and London
   `[02:00,05:00)` before New York. Incomplete reference data invalidates a session.
4. A long candidate begins only with a PWL penetration/reclaim; a short candidate
   only with PWH. Then apply the shared later-MSS and earliest-FVG sequence.
5. London long targets Asian high, London short Asian low; NY long targets London
   high, NY short London low. Invalid direction or insufficient R means no trade;
   never substitute a farther target.
6. The first chronological PWH/PWL reclaim in an eligible session consumes that
   symbol-week even if no later pivot, MSS, FVG, order, or fill occurs. A same-bar
   double-side penetration consumes it as ambiguous with no trade.
7. Virtual intents expire at session end or the next news-blackout start, whichever
   is earlier. Maximum one consumed attempt and one fill per symbol/week. Filled
   positions hard-flat at 16:00 NY on the same day.

State machine: `WEEK_FROZEN -> FIRST_SWEEP -> RECLAIMED -> MSS -> VIRTUAL_LIMIT
-> TRIGGERED/FILLED/DONE`. State is keyed by NY trading-week start + symbol + mode and records
PWH/PWL and reference-range hashes for deterministic restart replay.

Sleeve B is a low-frequency diversifier candidate, not an asserted independent
factor. Until synchronized return evidence proves otherwise, both sleeves count as
the same ICT-reversal family for portfolio risk caps.

## 5. Preregistered parameter neighbourhood

Categorical rules above are frozen. Each sleeve has a 13-point one-axis-at-a-time
star: center plus low/high substitutions for six dimensions, never a Cartesian
search and never winner-picking.

| Dimension | A center `{low,high}` | B center `{low,high}` |
|---|---|---|
| pivot wing | `2 {1,3}` | `2 {1,3}` |
| reclaim bars | `3 {1,5}` | `3 {1,5}` |
| max bars after reclaim to MSS | `9 {6,12}` | `12 {6,18}` |
| minimum FVG / SMA-TR(14) | `0.05 {0,0.10}` | `0.05 {0,0.10}` |
| stop buffer / SMA-TR(14) | `0.10 {0.05,0.15}` | `0.10 {0.05,0.15}` |
| minimum R | `2.0 {1.5,2.5}` | `2.0 {1.5,2.5}` |

Penetration is exactly one tick and is not optimized. Plateau pass requires the
center to pass the binding baseline, at least 9/13 variants net-profitable, and on
each axis both neighbors retaining at least 70% of center trade count with net
PF >= 1.0. The deployed value remains the preregistered center. A failed center
cannot be rescued by a neighbor without a new contract/version/hash.

Replay depth is not a research dimension and is locked exactly to 2,500 closed M1
bars for Sleeve A and 10,000 closed M5 bars for Sleeve B.

## 6. Partitions, holdout and anti-overfit rules

All implementation debugging and parameter-neighbourhood work remains inside DEV.
Source, binary, contract and center-set hashes freeze before a later partition is
read. No symbol/session/direction may be dropped after observing its result.

| Sleeve | DEV / plateau | six fixed OOS blocks | final locked retrospective holdout |
|---|---|---|---|
| A / NDX M1 | 2021-01-01..2022-12-31 | 2023-H1 through 2025-H2 | 2026-01-01..2026-06-30 |
| B / EURUSD+GBPUSD M5 | 2017-10-01..2022-12-31 | 2023-H1 through 2025-H2 | 2026-01-01..2026-06-30 |

NDX cannot honestly use the framework's 2017 start because its canonical registry
coverage begins in 2021. It is reported as a documented coverage exception, not
backfilled from unregistered raw files.

EURUSD and GBPUSD Model-4 tick files begin in October 2017. Their January through
September 2017 interval is therefore excluded as a documented coverage exception,
never synthesized or backfilled from a different data source.

For the six OOS blocks: aggregate net PF >= 1.10, at least 4/6 net-positive,
aggregate DD < 15%, and no block contributes more than 50% of gross positive P/L.
Existing V5 Q05/Q06+ rules remain binding where stricter. These blocks are
OOS-like, not epistemically pristine, because related 2022-2025 examples and EA
results were already present locally.

The 2026-H1 interval is a final locked retrospective holdout for this newly frozen
contract and is read only after hashes are recorded. It is not relabelled or tuned
if it fails. A separate prospective operational holdout starts 2026-07-20 00:00 NY
and ends 2027-07-17 00:00 NY; adequacy is A >= 50 fills and B >= 30 pooled fills,
otherwise its verdict is `UNDERPOWERED`, never a relaxed pass.

All MT5 tests use registered `.DWX` symbols, Model 4 / real ticks, deterministic
duplicate runs, explicit spread/commission/swap/slippage costs, and unchanged gate
thresholds. Gross-only or zero-commission output cannot establish profitability.

## 7. FTMO and deployment boundary

The EA fails closed outside the tester unless the exact FTMO governor policy,
challenge-instance ID, fresh heartbeat, percent-risk mode, and USD hedging account
are present. A paid-challenge-ready claim additionally requires synchronized
portfolio equity replay with floating P/L, commission, swap, CE(S)T midnight reset,
current FTMO product rules, targets, minimum trading days and any Best-Day rule.
Closed-daily or bar-only approximations are research screens only. Historical
profitability cannot guarantee a future challenge pass.
