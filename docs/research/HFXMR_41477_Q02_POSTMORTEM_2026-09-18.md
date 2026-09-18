# QM5_41477 H-FXMR — Q02 canary postmortem (EURUSD.DWX M15, 2018-07-02..2022-12-31)

Status: **VERDICT — hypothesis dead as specified.** Read-only analysis, Fable, 2026-09-18.

Evidence root: `D:/QM/reports/work_items/b3977583-1f58-4bd8-9a8f-bea493fd4a41/QM5_41477/20260918_011346/`
(`summary.json`, `raw/run_01/report.htm` sha256 `47533e7e…f6541`, `logger_sample.jsonl` sha256 `3c21bf95…1ecd0`, 2,131 events).
Code: `framework/EAs/QM5_41477_fx-session-mean-reversion-m15/QM5_41477_FxSessionMrCore.mqh`.
Card: `artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md` (`card_sha256 995578ff…2b52f`).
Run: 100% real ticks, model 4, RISK_FIXED=1000 on 100k, `InpQMSimCommissionPerLot=0.0` (broker-native commission still charged).

---

## 0. Headline reconciliation

| Item | Value | Source |
|---|---|---|
| Net profit | **-32,444.09** | report Results |
| of which broker commission | **-17,871.30** (55.1%) | sum of Deals `Commission` column |
| pre-commission P&L | **-14,572.79** | sum of Deals `Profit` column |
| Trades / PF / DD | 307 / 0.79 / 35.35% | report |
| Expectancy | **-0.1057 R** (sd 0.971, se 0.0554) | per-trade reconstruction |
| t vs card kill floor (+0.10R) | **-3.71** | ditto |
| Realised density | **5.69 entries/mo, 5.4 active days/mo** | 54 months, 289 active days |
| Card claim | 18-28 entries/mo, >=15 active days/mo | card "Expected frequency" |
| Card kill trigger "<10 active days in any month" | **fires in 52 of 54 months** | ditto |

---

## 1. Where the density went

**The logger emits no rejection events at all.** Event census of `logger_sample.jsonl` (2,131 events):
`EQUITY_SNAPSHOT 1170, ENTRY_ACCEPTED 307, TM_OPEN 307, FRIDAY_CLOSE 233, TM_CLOSE 84, RISK_CLAMP 20`, plus 9 init/deinit.
There is **no `ENTRY_REJECTED` / skip-reason event of any kind**. A reason-code census per session window is
therefore **impossible from this run's evidence** — the single biggest instrumentation defect, and the first thing
to fix before any re-test. What follows is what the evidence *can* bound.

Structural ceiling and realised fill (1,175 weekdays in span, 2 windows/day):

| | windows | entries | fill rate |
|---|---|---|---|
| London (07:15-11:00 UTC) | 1,175 | 105 | **8.9%** |
| New York (12:15-16:00 UTC) | 1,175 | 202 | **17.2%** |
| any entry on the day | 1,175 | 289 days | 24.6% |

Entries-per-day histogram: **1 entry on 271 days, 2 entries on 18 days, never 3+.**

Filter verdicts:

- **`max_trades_per_day` (card range 2..6, default 4) is a silent no-op across its whole preregistered range.**
  "One entry per symbol per session window" x 2 windows caps the day at 2; the cap was never reached in 4.5 years.
- **Flat-proximity guard is a no-op at the tested config.** `minute_of_day >= flat_min - skip_first_minutes`
  evaluates to >=675 (London) / >=975 (NY) while the entry windows already close at 660 / 960.
- **Spread filter: unmeasurable, and self-documented as possibly inert** (core comment: ".DWX zero modeled spread
  samples as 0 and simply never blocks"); with real ticks the spread is non-zero, but with zero skip logging the
  fire count is unknown.
- **News blackout is real but small.** Deterministic recount over `D:/QM/data/news_calendar/news_calendar_2015_2025.csv`
  (high-impact EUR+USD, 3,659 events in span, +-30 min): blocks **17.2% of London and 15.2% of NY in-window M15 slots** —
  and only a fraction of those slots would have carried a signal. It cannot explain an ~85% shortfall.
- **The -1.0% daily breaker IS binding, because the run used 1% risk.** RISK_FIXED=1000 on 100k = 1.0% of starting
  equity (1.5% by the end, equity 66,339); 73% of losing trades lost >=1,000. Any full stop-out therefore ends the
  trading day. Evidence: on the 87 London-only days, **36 (41%) had a London loss >= 1% of running balance** — those
  NY windows were breaker-killed. On the 18 two-entry days, the 6 losing first trades were all **< 1%** (largest
  -796.62). The mechanism is confirmed, but it accounts for ~36 of 1,175 NY windows — real, not dominant.
- **Residual (~85% of windows): the entry condition itself never fired** — stretch (>=3 consecutive closes OR
  >1.0xATR from EMA14) + opposite-side EMA reclaim on the next bar + stop <= 2.0xATR. This is the dominant term and
  the card never measured it.

---

## 2. Trade-level economics

Win rate 43.97% (135/307). Short 169 (47.3% won), long 138 (39.9% won). Avg profit 931.51, avg loss -867.80.

By exit (net = profit + commission, R = net/1000):

| exit | n | net $ | avg R | commission $ |
|---|---|---|---|---|
| SL | 132 | -139,088 | **-1.054** | -8,032 |
| TP | 91 | +107,693 | **+1.183** (target 1.25) | -5,863 |
| time-stop / session-flat | 84 | -1,049 | -0.012 | -3,976 |

By window: London n=105 avgR **-0.059**; New York n=202 avgR **-0.130**.
By direction: sell n=169 avgR **-0.038**; buy n=138 avgR **-0.188** (longs are 80% of the loss, -25,954 of -32,444).
By year: 2018 -0.215 | 2019 **+0.023** | 2020 -0.063 | 2021 -0.160 | 2022 -0.162 R. Only 2019 is positive; the two
worst years are the two strong EURUSD trend years — unconditional reversion with no trend/regime condition.

**Cost or thesis? Both, but the thesis is decisive.**

- Commission is 0.058 R/trade (median 51.30 on median 9.00 lots). It follows mechanically from the tight stops:
  `commission_R = 0.583 / stop_pips` at Darwinex 2.913/lot/side and $10/pip/lot; median stop distance was **11.1 pips**
  (min 2.3, max 32.5), i.e. the `max_stop_atr <= 2.0 x ATR` rule selects for exactly the stops that maximise cost drag.
- **Remove commission entirely and the strategy still loses**: -14,572.79, -0.0475 R/trade.
- The clean test: among the 223 trades that reached a decision (SL or TP), **TP share = 40.8%**. At `target_r = 1.25`
  the zero-cost breakeven hit rate is **44.4%**. The reversion simply does not happen often enough.
- Truncation is not the culprit either: split by runway-to-session-flat, avg R is **-0.127 (<60 min, n=21),
  -0.088 (60-120, n=81), -0.110 (>=120 min, n=205)**. Trades with full runway lose at the same rate; TP share only
  rises from 19% to 35%.

---

## 3. Implementation vs card

The mechanics are implemented faithfully; the deviations are in **specification coherence**, not in coding:

1. **Which stretch alternative fired is unrecoverable.** `stretched_down` is `(ema2-close2 > 1.0*ATR2) || (downrun >= 3)`
   and `ENTRY_ACCEPTED.reason` is the constant `fxmr_session_reclaim_long/short`. The log carries no branch tag, no
   run length, no ATR distance. **Evidence GAP — not guessed here.**
2. **Exit reasons are conflated.** `OnTick` closes every `Strategy_ExitSignal()` with the literal `QM_EXIT_TIME_STOP`,
   so session-flat, lunch-gap and time-stop share one label. All 84 closes read `QM_EXIT_TIME_STOP`; by close-time
   reconstruction ~67 were at/after the flat minute (session-flat) and only 21 held >=149 min (true time stop).
3. **`time_stop_bars` (8..16 bars = 120..240 min) is mostly dominated by the session-flat rule.** Median runway to
   the flat minute is 150 min; **43% of entries had less runway than the 150-min time stop, 33% less than the 8-bar
   floor of the preregistered range.** Median realised hold was 48 min (3.2 bars).
4. **The card's frequency claim was an upper bound presented as an expectation.** 2 windows/day x ~21.7 weekdays =
   43.4/month ceiling; "18-28/month" silently assumed a ~50% per-window fire rate that was never measured. Realised
   8.9% / 17.2%.
5. **Risk-mode mismatch amplified two card rules.** The card specifies `risk_per_trade_pct` 0.20-0.50; the Q02 run
   used RISK_FIXED=1000 = 1.0%. That makes the -1.0% day breaker a one-loss-per-day rule and the -2.0% week breaker a
   two-loss-per-week rule, and it scales DD ~4x. Standard Q02 practice — but the card's breaker levels were
   calibrated for 0.25% risk and were never re-derived for the gate's risk mode.
6. **Correct and confirmed:** symbols are inputs (slot0/1/2), `Strategy_NewsFilterHook` returns `false` so exits are
   never news-gated, the tester/live news branches are separated (HR: live never reads the archive), no ML, no
   trailing, no martingale. The **daily-loss contract held**: worst day -1.43% of equity, zero days <= -2%, P(hit -5%
   daily) ~ 0 across 1,170 days. That is the one card claim this run validated.

---

## 4. Is there a surviving configuration inside the preregistered box?

**No. The hypothesis is dead as specified.** Reasoning, all bounded by the card's own ranges:

- Expectancy must move **+0.206 R** to reach the card's own kill floor. Observed -0.1057 R with se 0.0554 R
  (n=307) => **t = -3.71 against the floor**; this is not a sampling accident.
- Deleting *all* cost still leaves -0.0475 R. The remaining gap is a hit-rate gap: 40.8% vs the 44.4% that
  `target_r=1.25` needs at zero cost.
- `target_r` max 1.5 lowers breakeven to 40.0% — a 0.8pp margin against a hit rate whose standard error is 3.3pp,
  and raising the TP mechanically converts current TPs into flats/stops (unmeasurable here: the report carries no
  per-trade MFE). That is not a plan, it is a coin flip inside noise.
- Density and expectancy trade off adversely: the only preregistered levers that raise density
  (`stretch_bars` 3->2, `stretch_atr_mult` 1.0->0.5, `ema_period` ->10, `news_blackout_minutes` ->0,
  `skip_first_minutes` ->0, `max_stop_atr` ->2.5) all admit *weaker* stretches, i.e. lower-quality reversions.
  Reaching >=10 active days/month needs roughly a 2x density increase from signal loosening alone.
- Cost is structurally floored: `commission_R = 0.583/stop_pips`, and the card caps the stop at `2.5 x ATR(M15,14)`
  (~25 pips on EURUSD), so the box cannot get commission drag below ~0.023 R/trade.
- The loss is concentrated where no preregistered input reaches: longs (-0.188 R vs shorts -0.038 R) and trending
  years (2021/2022 at ~-0.16 R). The card has no directional or regime input, so no legal setting repairs it.

**Recommendation: RETIRE H-FXMR as specified.** Not RECYCLE: the failure is the mean-reversion premise on
session-windowed EURUSD M15, not a tuning miss. If the underlying white space (FTMO high-density session-flat FX)
is still wanted, it needs a *new* card with (a) a trend/regime condition, (b) a directional asymmetry hypothesis,
(c) a stop floor that bounds cost-to-target, and (d) a measured — not asserted — fire rate.

---

## 5. Durable prescreen lesson (experiment memory)

Two cheap gates would have killed this before a single `.ex5` was built:

1. **PILOT FIRE-COUNT ON .DWX BEFORE BUILD (mandatory).** Every card whose density claim is load-bearing must ship a
   measured fire count from a throwaway signal-only script over the real .DWX history — entry condition only, no
   sizing, no filters, no orders — reported as *entries per window opportunity*. The card asserted 18-28/month from
   its caps; the measured rate was 8.9%/17.2% per window (5.7/month). **Rule: a card may never state an expected
   frequency derived from its own caps. Caps are upper bounds; only a measurement is an expectation.**
2. **COST-TO-TARGET RATIO FLOOR (mandatory card field).** Compute `commission_R = round_turn_cost_per_lot /
   (stop_distance_pips x pip_value_per_lot)` at the card's *minimum* plausible stop and reject at G0 above ~0.03 R.
   Here: 0.583/11.1 = 0.053 R/trade = 5.3% of risk burned per round turn, 55% of the realised loss. Any strategy whose
   stop is a fraction of an intraday M15 ATR must pass this arithmetic first.

Two supporting rules:

3. **No-op filter lint at G0.** Cross-check declared controls against each other: `max_trades_per_day` was unreachable
   behind "one entry per window", the flat-proximity guard was unreachable behind the window end, and
   `time_stop_bars` was unreachable behind the session-flat minute for 33-43% of entries. A card that declares a
   control which cannot fire is over-specified and hides the real binding constraint.
4. **Skip-reason logging is a build-gate requirement, not a nicety.** An EA that can only log what it *did* makes a
   density postmortem guesswork. Require one `ENTRY_REJECTED{reason, session, branch}` event per evaluated in-window
   bar (rate-limited) plus a branch tag on `ENTRY_ACCEPTED` before a candidate may enter Q02.

**Card-level record:** kill criteria "expectancy < +0.10R" and "any single month has < 10 active days" both fired.
The card's own falsification clause is satisfied; this is a preregistered kill, executed as written.
