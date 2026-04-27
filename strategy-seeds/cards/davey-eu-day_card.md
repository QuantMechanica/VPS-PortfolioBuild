# Strategy Card — Davey Euro Day (intraday mean-reversion limit-order on Euro futures, momentum-gated)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC01/raw/appC_euro_day.md` (verbatim Appendix C EasyLanguage code) + cross-references to Ch 15 (Diversification), Ch 18 (Goals, Initial and Walk-Forward Testing), Ch 19 (Monte Carlo Testing and Incubation), and Ch 7 (Detailed Analysis).
> Submitted for CEO review (Quality-Business not yet hired).

## Card Header

```yaml
strategy_id: SRC01_S02
ea_id: TBD
slug: davey-eu-day
status: APPROVED
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27
g0_verdict: APPROVED
g0_reviewer: CEO (interim until Quality-Business hire)
g0_reviewed_at: 2026-04-27
g0_issue: QUA-276

strategy_type_flags:
  - mean-reversion                            # Davey: "this makes these strategies a type of mean reversion" (Ch 18 p. 158)
  - intraday                                  # 60-minute bars; day session 7 AM-3 PM ET; flat by 3 PM ET each day
  - momentum                                  # entry-gate uses xb2-bar momentum direction (close > or < close[xb2]) — momentum-AGAINST-recent-thrust filter
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: "Appendix C 'Euro Day Strategy, TradeStation Easy Language Format', pp. 259-261 (verbatim EasyLanguage code) + Chapter 18 'Goals, Initial and Walk-Forward Testing', pp. 156-158 (strategy framing) + Chapter 19 'Monte Carlo Testing and Incubation', pp. 163-164 (performance Monte Carlo) + Chapter 15 'Diversification', Tables 15.1-15.3 pp. 135-136 (correlation, drawdown, R/D)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC01/raw/appC_euro_day.md`. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf`.

## 2. Concept

An **intraday mean-reversion strategy on Euro futures (CME `@EC`) that fires only when a fresh short-term price extreme prints AGAINST a longer-term momentum signal**. When the current bar prints a fresh xb-bar high (lows respectively) AND the close is below (above) the close `xb2` bars ago, a LIMIT order is placed `pipadd` ticks beyond the current high (low) — i.e., the strategy expects "one more price thrust" before the reversion fires. Profit target is set at $5,000 (effectively unreachable intraday on Euro futures, so the real exits are the stop-loss or the forced session-close exit at 3:00 PM ET). The day-session entry window is 7:00 AM to 3:00 PM ET; only one trade per session.

Davey's framing:

> "When a highest high of the past Y bars is hit, and the X bar momentum is down, then a limit order to sell short will be placed Z ticks above the current high. The opposite logic holds for long trades. Thus, to get filled, the strategy is planning on one more price thrust before the price reverses." (Ch 18 p. 157)

> "I feel my edge is in identifying very-short-term (for night strategy 1) and medium-term (for day strategy 2) areas where the price is likely to reverse. By having limit orders away from the current market, I liken my edge to a rubber band." (Ch 18 p. 158)

## 3. Markets & Timeframes

```yaml
markets:
  - currency_futures                          # CME Euro FX continuous contract @EC
  # V5 Darwinex re-mapping at CTO sanity-check: candidate proxy is EURUSD.DWX (spot)
timeframes:
  - 60-minute bars                            # Davey, Ch 18 p. 156: "Runs on 60-minute bars from 7 a.m. to 3 p.m. ET"
  # = 8 bars per day-session
session_window:                                # entries only:
  - 07:00-15:00 ET (Davey narrative)
  # In the code: `time < 1500` chart time. Davey's narrative says ET, but TradeStation default
  # for CME charts is CT. If chart-time = CT, then `time < 1500` = 3:00 PM CT = 4:00 PM ET, which
  # contradicts the narrative's "all trades exited by 3 p.m. ET". Likely Davey set the chart
  # session to ET explicitly. **CTO confirms timezone at sanity-check.**
exit_at_session_close: true                   # setexitonclose; chart session ends 3:00 PM ET per Ch 18
primary_target_symbols:
  - "@EC (continuous Euro FX futures, CME) — Davey's deployment"
  - "EURUSD.DWX — V5 Darwinex spot proxy (proposed; CTO confirms tick-size + session mapping)"
```

## 4. Entry Rules

```text
PARAMETERS (Davey's final-walk-forward-window defaults; per-period parameters in § 8 below):
- xb       = 5         // bar count for highest(high, xb) / lowest(low, xb) — short-term breakout window
- xb2      = 80        // bar count for close[xb2] reference — longer-term momentum window
- pipadd   = 8         // pip offset added/subtracted from the current high/low for limit placement
                       //   (in price units: pipadd/10000 e.g. 8/10000 = 0.0008 = 8 pips on EURUSD-style decimal)
- Stopl    = 425       // stop loss in USD per contract
- proft    = 5000      // profit target in USD per contract — effectively unreachable intraday;
                       //   real exit is stop-loss or session-close
                       //   (Davey: "there has never been a $5,000 intraday move in euro", Ch 18 p. 157)

EACH-BAR PRECOMPUTE (only inside session, before 1500 chart time):
- session_changed = (currentsession(0) != currentsession(0)[1])
- if session_changed: tradestoday = 0; capture starting NetProfit + TotalTrades for change-detection
- if any change since session start: tradestoday = 1   // i.e., trade already taken today

ENTRY GATE (all must hold):
- tradestoday == 0                            // no trade taken today yet
- time < 1500                                  // before 3:00 PM chart time (= 3 PM ET per narrative)
- date >= 2009-11-18                           // strategy activation date

ENTRY RULE — SHORT LIMIT (mean-reversion on upthrust against down-momentum):
- if (high >= highest(high, xb))   AND        // current bar prints fresh xb-bar high
- if (close < close[xb2]):                     // longer-term momentum is DOWN (close below close xb2 bars ago)
  → sellshort next bar at high + pipadd/10000 limit

ENTRY RULE — LONG LIMIT (mirror):
- if (low <= lowest(low, xb))      AND
- if (close > close[xb2]):
  → buy next bar at low - pipadd/10000 limit
```

## 5. Exit Rules

```text
PROFIT TARGET:
- setprofittarget(proft) where proft = $5,000 (USD per contract, fixed across all walk-forward windows)
  // Effectively unreachable intraday — Davey's intent is "ride the trade until session close"

STOP LOSS:
- setstoploss(stoplo) where stoplo = Stopl (per-walk-forward-window: $225-$425)
  // Davey's framework cap: max stop $450 incl. $17.50 commission/slippage = 34 ticks (Ch 18 p. 157)

POSITION-PROTECTIVE STOP MODE:
- Setstopposition                             // TS keyword: stop applies on the entire position

TIME EXIT:
- setexitonclose                               // forced flat at session close (~3:00 PM ET)
  // Daily flatness avoids overnight gap risk and doesn't interfere with the Euro Night strategy
```

## 6. Filters (No-Trade module)

```text
- Date guard: do nothing for bars dated before 2009-11-18 (Davey's own activation date in App C).
  // For V5 deployment, this is a historical artifact of Davey's walk-forward dataset; drop it.

- Time-of-day guard (PRIMARY): only enter while `time < 1500` chart time (= 3:00 PM ET per Davey).
  // Equivalent to entry window 07:00-14:59 ET (chart starts at 7 AM per Ch 18).
  // V5 Darwinex deployment: map to broker-time equivalents.

- One-trade-per-day guard: tradestoday == 0 (reset on session change).

- Implicit flat-only entry: the trade-day-state tracker sets tradestoday=1 the moment a position
  opens, so re-entries within the same session are blocked (no scaling, no pyramiding).

- Framework defaults (V5):
  - QM_NewsFilter (news pause) — apply per V5 default. The 07:00-15:00 ET window CONTAINS the
    08:30 ET / 10:00 ET / 14:00 ET US scheduled-data releases. Default news filter ON.
  - Friday Close — see § 12 hard_rules_at_risk. Day strategy exits at 3 PM ET = 14:00-15:00 ET
    every weekday including Friday, well BEFORE V5's Friday 21:00 broker force-flat. **No
    Friday-Close conflict** for this strategy (unlike App B Euro Night).
  - Kill-switch — V5 default; not affected.
```

## 7. Trade Management Rules

```text
- One open position at a time per session.
- No move-to-break-even rule in source.
- No partial close in source.
- No trailing stop in source — only fixed setstoploss + $5,000-effectively-never profit target +
  forced session-close exit.
- Pyramiding: NOT used in source (and disallowed by V5 one_position_per_magic_symbol).
- Gridding:   NOT used in source.
```

## 8. Parameters To Test (P3 Sweep)

Davey's appendix ships **five walk-forward-discovered parameter blocks** (one per ~1-year window from 2009-11-18 to 2014-01-01). Reproduced verbatim in `raw/appC_euro_day.md`. P3 baseline candidates:

```yaml
- name: xb                                    # bar count for highest(high, xb) / lowest(low, xb)
  default: 5                                  # final-walk-forward-window value (2013-08-12 → 2014-01-01)
  fallback_default: 2                         # EasyLanguage `vars:` default
  sweep_range: [2, 3, 4, 5]                   # union of values Davey used across all 5 walk-forward windows
- name: xb2                                   # close[xb2] reference for momentum direction
  default: 80
  fallback_default: 50
  sweep_range: [50, 70, 72, 74, 80]
- name: pipadd                                # pip offset for limit-order placement
  default: 8
  fallback_default: 1
  sweep_range: [1, 2, 5, 8, 11]
- name: Stopl                                 # $ per contract stop
  default: 425                                # final-walk-forward-window value
  fallback_default: 400                       # EasyLanguage `vars:` default
  sweep_range: [225, 275, 400, 425]
  # Davey constraint: max stop $450 incl. commission/slippage. P3 must respect this ceiling.
- name: proft                                 # $ per contract profit target
  default: 5000                               # constant across all walk-forward windows
  sweep_range: [3000, 5000, 7500]             # marginal — Davey's design intent is "effectively unreachable", so sweeping below 5000 might shift strategy character
- name: time_cutoff                           # entry window end (chart time HHMM)
  default: 1500
  sweep_range: [1400, 1500, 1530]
```

V5 deployment will need to convert `Stopl` and `proft` from "USD per Euro futures contract" to a pip-based or risk-percent-based equivalent on Darwinex EURUSD.DWX (spot) — see § 12 `dwx_suffix_discipline`. First-cut tick-equivalence ($12.50/tick @EC ≈ 1 pip EURUSD spot): Stopl=425 ≈ 34 pips; proft=5000 ≈ 400 pips (intraday EURUSD rarely moves 400 pips, confirming Davey's "effectively never" framing).

## 9. Author Claims (verbatim, with quote marks)

```text
"For the day strategy, if I keep the risk of ruin below 10 percent (my personal threshold for ruin),
I find I need $6,250 to begin trading this system, and in an 'average' year I can expect:
   23.7 percent maximum drawdown
   129 percent return
   5.45 return/drawdown ratio" (Ch 19, p. 164)

"I have a 4 percent chance of ruin in that first year, where my equity would drop below $3,000.
I also have a 94 percent probability of making money in that first year (i.e., ending the year
with more than $6,250)." (Ch 19, p. 164)

Table 15.2 (Maximum Drawdown for Diversification Check):
   "Euro day                                   $3,523" (Ch 15, p. 136)

Table 15.3 (Return/Drawdown and Probability of Profit for Diversification Check):
   "Euro day          5.2  97%" (Ch 15, p. 136)
   // Returns/Drawdown = 5.2; Probability of Profit in One Year = 97%

Table 15.1 (R² Correlation Coefficient for Diversification Check, equity-curve linearity):
   "Euro day          0.9745" (Ch 15, p. 135)

"to lose no more than $450 per trade, after slippage and commission of $17.50 per trade.
This equates to a loss of 34 ticks." (Ch 18, p. 157)

"For profit, with both strategies I will allow the profit target to be optimized for euro night
strategy, and fixed at $5,000 for the euro day strategy. Since there has never been a $5,000
intraday move in euro, the $5,000 limit is effectively saying, 'Go for as much profit as you can,
and hold until the end of the trading session.'" (Ch 18, p. 157)
```

**Discrepancy between Ch 15 and Ch 19 — same pattern as App B Euro Night:** Ch 15 Table 15.3 records Euro Day R/D as **5.2** with **97%** probability-of-profit; Ch 19's narrative cites **5.45** R/D and **94%** probability. Both are Monte Carlo outputs from different/refined runs. Card records both verbatim; reviewers should not synthesize a single number from these. P2 Baseline Screening on V5 data will produce a single, traceable number.

**Crucial scope note (same as App B):** all of Davey's quantified figures above are **Monte Carlo simulation outputs**, NOT raw historical-backtest stats.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Davey reports return/drawdown not PF
expected_dd_pct: 23.7                         # Davey Ch 19 Monte Carlo
expected_trade_frequency: TBD                 # Davey does not explicitly state per-year trade count for App C; estimable as ~250 trading days × ~25-30% trigger rate per day → ~60-75/yr (rough)
risk_class: medium
gridding: false
scalping: false                               # 60-minute bars; intraday but not scalping
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — entry/SL/TP/session-exit all driven by highest/lowest/close-comparison + fixed-dollar values, no discretion.
- [x] No Machine Learning required.
- [x] Gridding: N/A (single-position-per-session).
- [x] Scalping: N/A (60-minute bars; not high-frequency).
- [x] Friday Close compatibility — strategy exits at session close (~3:00 PM ET) every weekday. **No Friday-Close conflict** with V5's 21:00 broker force-flat.
- [x] Source citation precise (book + ISBN + appendix + page numbers + chapter cross-references with page numbers).
- [x] No near-duplicate of existing approved card. Distinct from App B Euro Night via: timeframe (60min vs 105min), session (day 7AM-3PM ET vs night 6PM-7AM ET), entry trigger (fresh-xb-bar-extreme + xb2-momentum-filter vs ATR-band-offset-from-Avg), profit-target style (effectively-unreachable $5000 vs TR-fraction). Same instrument (Euro futures), same family (mean-reversion limit orders), but mechanically distinct strategies per OWNER Rule 1.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Time-of-day window (entry only while time < 1500 chart time); session-change-resetting one-trade-per-day flag (tradestoday); flat-only entry implicit; news/kill-switch/Friday-close framework defaults. NEWS FILTER especially important — 07:00-15:00 ET window contains all major US scheduled releases."
  trade_entry:
    used: true
    notes: "Limit orders at high+pipadd/10000 (short) or low-pipadd/10000 (long) when fresh xb-bar extreme is hit AND close-direction-vs-close[xb2] confirms longer-term momentum AGAINST the new extreme. The pipadd offset means the order only fills if price overshoots the recent extreme by pipadd ticks, then reverts."
  trade_management:
    used: true
    notes: "Asymmetric: fixed dollar SL (per-walk-forward-window) AND fixed $5,000 profit target (effectively never hit) AND forced session-close exit. No BE-move, no trail, no partial close. Position-protective stop via Setstopposition."
  trade_close:
    used: true
    notes: "setexitonclose forces flat at session close — distinct from the stop-loss / never-hit profit target / Friday-close exits."
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # source uses CME @EC (Euro futures continuous); V5 deploys on Darwinex EURUSD.DWX (spot). Tick-size + session-time mapping required.
  - darwinex_native_data_only                  # @EC futures price will diverge from EURUSD.DWX spot. Walk-forward parameter values from Davey will likely NOT transfer 1-for-1; full re-optimization on EURUSD.DWX data required at P3.
  - news_pause_default                         # 07:00-15:00 ET window CONTAINS major US scheduled releases (08:30 / 10:00 / 14:00 ET). Default news filter ON is critical for this strategy.
  - kill_switch_coverage                       # this strategy holds for short durations (≤8 hours within day session) and uses fixed stops + forced exits; kill-switch coverage is straightforward.
  - enhancement_doctrine                       # entry-side parameters (xb, xb2, pipadd) and money-mgmt-side (Stopl) all change across walk-forward windows; entry params especially likely to need re-tuning over time.
at_risk_explanation: |
  - dwx_suffix_discipline: same caveat as App B Euro Night — Davey trades CME Euro FX continuous
    futures (`@EC`); V5 deployment targets Darwinex EURUSD.DWX (spot). At first cut, 1 tick on
    `@EC` ($12.50) ≈ 1 pip on EURUSD.DWX, so Stopl=$425 ≈ 34 pips and proft=$5000 ≈ 400 pips.
    CTO confirms exact mapping at sanity-check.

  - darwinex_native_data_only: walk-forward parameters (xb=5, xb2=80, pipadd=8, Stopl=425) were
    discovered on @EC futures continuous from 2009-11-18 to 2014-01-01. Re-optimize at P3 on
    Darwinex EURUSD.DWX tick-data. Davey's parameters serve only as a sanity-check baseline.

  - news_pause_default: this strategy is WAY more news-exposed than App B Euro Night because
    its entry window 07:00-15:00 ET overlaps the entire heavy US-data calendar. The fact that
    Davey reports 23.7% max DD and 5.45 R/D WITHOUT a news filter is striking; V5's default
    news pause may IMPROVE these stats by filtering out 8:30 ET non-farm-payroll, 14:00 ET FOMC
    minutes, etc. Or it may HURT them by removing some of the strategy's edge if Davey's
    reversal-after-thrust pattern is partly news-event-driven. Both possibilities should be
    tested at P8 News Impact.

  - kill_switch_coverage: trivial; daily forced exits + fixed stops + max-8-hour holds make
    this an easy strategy to monitor with V5 kill-switch tooling.

  - enhancement_doctrine: Davey's xb varies 2-5, xb2 varies 50-80, pipadd varies 1-11 across
    walk-forward windows. Entry-parameter instability is high. Per V5 enhancement doctrine,
    post-PASS tuning of these triggers a _v2 rebuild. Pipeline-Operator should expect frequent
    _v<n> rebuilds for this strategy.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: small                   # ~50 lines of EasyLanguage; mechanical port to MQL5
estimated_test_runtime: TBD
data_requirements: standard                   # Darwinex EURUSD.DWX 60-minute bars; standard P3 grid
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | TBD | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | APPROVED (CEO interim, QUA-276) | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |
| P5b Calibrated Noise | TBD | TBD | TBD |
| P5c Crisis Slices | TBD | TBD | TBD |
| P6 Multi-Seed | TBD | TBD | TBD |
| P7 Statistical Validation | TBD | TBD | TBD |
| P8 News Impact | TBD | TBD | TBD |
| P9 Portfolio Construction | TBD | TBD | TBD |
| P9b Operational Readiness | TBD | TBD | TBD |
| P10 Shadow Deploy | TBD | TBD | TBD |
| Live Promotion | TBD | TBD | TBD |

## 16. Lessons Captured

```text
- 2026-04-27: Davey ships FIVE walk-forward parameter blocks for App C Day (vs ten for App B Night).
  Coarser cadence, suggesting fewer trades per window for reliable optimization. Final-window
  baseline: xb=5, xb2=80, pipadd=8, Stopl=425.
- 2026-04-27: App C source contains an 8-digit date typo (`< 11400101` instead of `1140101`).
  Effectively means the final block never deactivates within Davey's coverage; Research preserved
  the typo verbatim in the raw evidence, normalized to 1140101 in the card's interpretation.
- 2026-04-27: $5,000 profit target is symbolic ("effectively never hit"); P3 sweeping below 5000
  changes the strategy character from "ride to session close" to "explicit fixed-target take-profit".
  Reviewers should consider whether to keep proft as a separate sweep dimension or hold it constant.
- 2026-04-27: Same Ch 15 vs Ch 19 metric discrepancy as Euro Night — Ch 15 R/D=5.2 / 97% vs
  Ch 19 R/D=5.45 / 94%. Both Monte Carlo, recorded verbatim, no synthesis.
- 2026-04-27: News-filter dependency is high for App C Day (entry window contains all US scheduled
  releases) vs negligible for App B Night. P8 News Impact should test whether default news pause
  helps or hurts each strategy.
```
