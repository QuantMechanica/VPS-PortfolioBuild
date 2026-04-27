# Strategy Card — Davey Euro Night (overnight mean-reversion limit-order on Euro futures)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC01/raw/appB_euro_night.md` (verbatim Appendix B EasyLanguage code) + cross-references to Ch 15 (Diversification), Ch 18 (Goals, Initial and Walk-Forward Testing), and Ch 19 (Monte Carlo Testing and Incubation).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per OWNER directive).

## Card Header

```yaml
strategy_id: SRC01_S01
ea_id: 1002
slug: davey-eu-night
status: APPROVED
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27
g0_verdict: APPROVED
g0_reviewer: CEO (interim until Quality-Business hire)
g0_reviewed_at: 2026-04-27
g0_issue: QUA-276

strategy_type_flags:
  - mean-reversion                            # Davey's own term: "this makes these strategies a type of mean reversion" (Ch 18)
  - intraday                                  # 105-minute bars; overnight session 6 PM-7 AM ET; flat by 7 AM ET each day
  - news-pause                                # entries gated to overnight 18:00-23:59 chart time (~1 AM ET) when scheduled news impact is lighter; not strictly news-driven
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: "Appendix B 'Euro Night Strategy, TradeStation Easy Language Format', pp. 255-258 (verbatim EasyLanguage code) + Chapter 18 'Goals, Initial and Walk-Forward Testing', pp. 156-162 (strategy framing) + Chapter 19 'Monte Carlo Testing and Incubation', pp. 165-166 (performance Monte Carlo) + Chapter 15 'Diversification', Tables 15.1-15.3 (correlation, drawdown, R/D)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC01/raw/appB_euro_night.md`. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf`.

## 2. Concept

A **mean-reversion overnight strategy on Euro futures (CME `@EC`)** that places limit orders well above the recent average low (short) and well below the recent average high (long), each offset by a multiple of recent ATR. The strategy assumes that during the overnight session, large excursions away from the average price tend to revert before turning into a trend in the opposite direction. Only one of the two limits is sent each bar — whichever is closer to the current close is the active entry. Profit target is a fraction of recent True Range (small, fast); stop loss is a fixed dollar amount per contract. All open positions are closed at session end (~7 AM ET).

Davey describes the edge as a "rubber band":

> "By having limit orders away from the current market, I liken my edge to a rubber band. It keeps stretching and stretching until I get my limit fill, then it bounces back, giving me profit. Of course, if the rubber band keeps stretching after my order is filled, that means my premise was wrong, and I pay the price with a full stop-loss or a loss at the end of the trading session." (Ch 18, p. 158)

## 3. Markets & Timeframes

```yaml
markets:
  - currency_futures                          # Davey's deployment: CME Euro FX continuous contract @EC
  # V5 Darwinex re-mapping at CTO sanity-check: candidate proxy is EURUSD.DWX (spot)
timeframes:
  - 105-minute bars                           # Davey, Ch 18 p. 156: "Runs on 105-minute bars"
                                              # ~M105; nonstandard. Maps to 7 bars per 12-hour session.
session_window:                                # entries only:
  - 18:00-23:59 chart time (CME chart default = America/Chicago / Central Time)
  # = 19:00-00:59 ET (matches Davey's narrative "1 a.m. ET" entry cutoff in Ch 18 p. 156)
  # = 23:00-04:59 UTC (winter; CT = UTC-6) — flag DST-shift handling at CTO sanity-check
exit_at_session_close: true                   # SetExitOnClose; chart session for @EC overnight ends ~7 AM ET = 06:00 CT next morning
primary_target_symbols:
  - "@EC (continuous Euro FX futures, CME) — Davey's deployment"
  - "EURUSD.DWX — V5 Darwinex spot proxy (proposed; CTO confirms tick-size + session mapping)"
```

## 4. Entry Rules

Pseudocode — verbatim where possible from the appendix EasyLanguage; structural translation where EasyLanguage-specific (e.g., `EntriesToday`, `MarketPosition`) needs spelling out.

```text
PARAMETERS (Davey defaults; per-period walk-forward parameters in § 8 below):
- Nb        = 10        // bar count for Average(High,Nb) and Average(Low,Nb)
- NATR      = 60        // ATR length for AvgTrueRange(NATR)
- ATRmult   = 3.0       // multiplier for ATR offset from average
- TRmult    = 0.5       // multiplier for True Range used in profit target
- Stoplo    = 275       // stop loss in USD per contract (TradeStation setstoploss convention)
- FirstTime = 1800      // chart time HHMM
- LastTime  = 2359      // chart time HHMM

EACH-BAR PRECOMPUTE:
- LongPrice  = Average(High, Nb) - ATRmult * AvgTrueRange(NATR)
- ShortPrice = Average(Low,  Nb) + ATRmult * AvgTrueRange(NATR)
- diff1 = |close - LongPrice|
- diff2 = |close - ShortPrice|
- if diff1 <= diff2 then EntryToPick = 1 (long)
- else                EntryToPick = 2 (short)

ENTRY GATE (all must hold):
- MarketPosition == 0                         // currently flat
- EntriesToday(Date) < 1                      // no entry already taken today
- Time >= FirstTime and Time < LastTime       // entry window open

ENTRY ORDER:
- if EntryToPick == 1:  Buy("Long Entry") next bar at LongPrice limit
- if EntryToPick == 2:  Sell short("Short Entry") next bar at ShortPrice limit
```

## 5. Exit Rules

```text
PROFIT TARGET (fired each bar while in a position):
- if MarketPosition == +1: LongTarget  = EntryPrice + TRmult * TrueRange[1]
                           Sell("Long Exit") next bar at LongTarget limit
- if MarketPosition == -1: ShortTarget = EntryPrice - TRmult * TrueRange[1]
                           Buy to cover("Short Exit") next bar at ShortTarget limit
  // TradeStation TrueRange refers to the prior bar's range; TRmult ~0.5 means
  // target ≈ half of recent True Range (small, fast profit)

STOP LOSS:
- setstoploss(stoplo)                        // fixed dollars-per-contract stop
  // Davey: max stop = $450 incl. $17.50 commission/slippage = 34 ticks (Ch 18 p. 157)
  // Walk-forward range: $275-$425 across 2009-07 → 2014-01

TIME EXIT:
- SetExitOnClose                              // forced flat at session close (~7 AM ET)
- Davey: "All trades are exited by 7 a.m., so they do not interfere with strategy 2"
  (Ch 18 p. 156)
```

## 6. Filters (No-Trade module)

```text
- Date guard: do nothing for bars dated before 2009-07-21 (Davey's own activation date in App B)
  // For V5 deployment, this guard is a historical artifact of Davey's walk-forward dataset and
  // can be dropped; V5 will use its own backtest start date.

- Time-of-day guard (PRIMARY filter): only enter between FirstTime (18:00 CT) and LastTime (23:59 CT).
  // CT = TradeStation chart default for CME contracts. ET equivalent: 19:00-00:59.
  // V5 Darwinex deployment: map to broker-time equivalents; Darwinex server time is GMT+2/+3 (Cyprus).

- One-trade-per-day guard: EntriesToday(Date) < 1.

- Flat-only entry: MarketPosition == 0 (no scaling, no pyramiding).

- Framework defaults (V5):
  - QM_NewsFilter (news pause) — apply per V5 default; cross-check whether ECB / Fed scheduled
    overnight events fall inside the 18:00-23:59 CT window (most do not for the major
    8:30 AM ET releases, but ECB / Asian-session events may).
  - Friday Close — see § 12 hard_rules_at_risk; this strategy holds across Friday overnight
    if entered Thursday evening; verify Friday-Close interaction at CTO sanity-check.
  - Kill-switch — V5 default; not affected.
```

## 7. Trade Management Rules

```text
- One open position at a time; flat-only re-entry per § 6.
- No move-to-break-even rule in source.
- No partial close in source.
- No trailing stop in source — only fixed setstoploss + fixed-multiple-of-TR profit target +
  forced session-close exit.
- Pyramiding: NOT used in source (and disallowed by V5 one_position_per_magic_symbol).
- Gridding:   NOT used in source.
```

## 8. Parameters To Test (P3 Sweep)

Davey's appendix ships ten **walk-forward-discovered parameter blocks** (one per ~6-month window from 2009-07-21 to 2014-01-01) plus a default block. Reproduced verbatim in `raw/appB_euro_night.md`. For V5 P3, the most-recently-walk-forward-derived block (the 2013-08-26 to 2014-01-01 window) is the natural starting baseline; the default block is the secondary baseline.

```yaml
- name: Nb                                    # bar count for Average(High|Low, Nb)
  default: 14                                 # Davey final-window value (2013-08-26 → 2014-01-01)
  fallback_default: 10                        # Davey EasyLanguage `vars:` default
  sweep_range: [9, 10, 14, 19]                # union of values Davey used across all 10 walk-forward windows
- name: NATR                                  # ATR length
  default: 93
  fallback_default: 60
  sweep_range: [60, 73, 83, 93]
- name: ATRmult                               # offset multiplier
  default: 2.55
  fallback_default: 3.0
  sweep_range: [2.55, 2.75, 2.95, 3.0, 3.15]
- name: TRmult                                # profit-target multiplier on prior-bar TrueRange
  default: 0.71
  fallback_default: 0.5
  sweep_range: [0.51, 0.56, 0.61, 0.66, 0.71]
- name: Stoplo                                # $ per contract stop
  default: 425                                # Davey final-window value
  fallback_default: 275                       # Davey EasyLanguage `vars:` default
  sweep_range: [275, 375, 425]
  # NOTE: Davey constraint "to lose no more than $450 per trade, after slippage and
  # commission of $17.50" => max stop = $432.50 effective. P3 must respect this ceiling
  # OR explicitly override with CEO + CTO approval.
- name: FirstTime                             # entry window start (chart time HHMM)
  default: 1800
  sweep_range: [1700, 1800, 1900]
- name: LastTime                              # entry window end (chart time HHMM)
  default: 2359
  sweep_range: [2300, 2359, 0030]             # last value is 30 min past midnight; flag time wrap-around handling
```

V5 deployment will need to convert `Stoplo` from "USD per Euro futures contract" to a pip-based or risk-percent-based equivalent on Darwinex EURUSD.DWX (spot) — see § 12 `dwx_suffix_discipline`. As a first cut: 1 tick on `@EC` ($12.50) ≈ 1 pip on EURUSD.DWX, so Stoplo=425 ≈ 34 pips.

## 9. Author Claims (verbatim, with quote marks)

Davey's quantified claims live primarily in Ch 15 (Diversification, Tables 15.1-15.3), Ch 18 (entry / exit framing), and Ch 19 (Monte Carlo). Verbatim:

```text
"For the night strategy, if I again keep the risk of ruin below 10 percent, I find I need
$6,250 to begin trading this system, and in an 'average' year I can expect:
   25.0 percent maximum drawdown
   52 percent return
   2.0 return/drawdown ratio" (Ch 19, pp. 165-166)

"I have a 6 percent chance of ruin in that first year, where my equity would drop below
$3,000. I also have an 85 percent probability of making money in that first year (i.e.,
ending the year with more than $6,250)." (Ch 19, p. 166)

"the night strategy by itself meets my goals, although the return/drawdown ratio of only
2.0 is on the low end of acceptability." (Ch 19, p. 166)

Table 15.2 (Maximum Drawdown for Diversification Check):
   "Euro night                                 $3,008" (Ch 15, p. 136)

Table 15.3 (Return/Drawdown and Probability of Profit for Diversification Check):
   "Euro night        2.2  89%" (Ch 15, p. 136)
   // Returns/Drawdown = 2.2; Probability of Profit in One Year = 89%

Table 15.1 (R² Correlation Coefficient for Diversification Check, equity-curve linearity):
   "Euro night        0.9370" (Ch 15, p. 135)

"to lose no more than $450 per trade, after slippage and commission of $17.50 per trade.
This equates to a loss of 34 ticks." (Ch 18, p. 157)

"Strategy 1: Euro Night. Trades overnight session, has high winning percentage, lots
[of trades]" (Ch 22 strategy summary, p. 195 area; see TOC)
```

**Discrepancy noted between Ch 15 and Ch 19:** Ch 15 Table 15.3 records the Euro Night return/drawdown ratio as **2.2** with a probability-of-profit of **89%**, while Ch 19's narrative cites **2.0** R/D and **85%** probability. Both are Monte Carlo results but evidently from different / refined runs. The card records both verbatim; reviewers should not synthesize a single number from these. P2 Baseline Screening on V5 data will produce a single, traceable number for V5's purposes.

**Crucial scope note:** all of Davey's quantified figures above are **Monte Carlo simulation outputs**, NOT raw historical-backtest stats. Davey's Monte Carlo perturbs trade order and (in some passes) trade magnitudes; the figures represent risk-of-ruin-bounded expectations rather than realized historical performance. V5 reviewers should treat these as risk-profile estimates, not as P2-equivalent backtest outcomes.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Davey does not state PF; he reports return/drawdown instead
expected_dd_pct: 25                           # Davey Ch 19 Monte Carlo
expected_trade_frequency: TBD                 # Davey hints "lots [of trades]" (Ch 22) but does not quantify in App B/Ch 18-19
risk_class: medium
gridding: false
scalping: false                               # 105-minute bars; intraday but not scalping
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — entry/SL/TP all driven by Average + ATR + TR formulas, no discretion.
- [x] No Machine Learning required.
- [x] Gridding: N/A (single-position).
- [x] Scalping: N/A (105-minute bars; not high-frequency).
- [x] Friday Close compatibility — strategy holds for at most one overnight session (~13 hours) and forces flat at session close. Friday-evening entries close Saturday morning ET, well after Friday 21:00 broker time → **likely binds** `friday_close` Hard Rule for Friday overnight; see § 12.
- [x] Source citation precise (book + ISBN + appendix + page numbers + chapter cross-references with page numbers).
- [x] No near-duplicate of existing approved card (this is the first under V5).

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Time-of-day window 18:00-23:59 CT (entry-only); one-trade-per-day cap; flat-only entry; news/kill-switch/Friday-close framework defaults."
  trade_entry:
    used: true
    notes: "Limit orders at LongPrice = Avg(High,Nb) - ATRmult*ATR(NATR) and ShortPrice = Avg(Low,Nb) + ATRmult*ATR(NATR); whichever is closer to current close becomes the active entry."
  trade_management:
    used: true
    notes: "Symmetric: TR-based profit-target limit (TRmult * TrueRange[1]) AND fixed dollar-per-contract stop (Stoplo) AND forced session-close exit. No BE-move, no trail, no partial close."
  trade_close:
    used: true
    notes: "SetExitOnClose forces flat at session close — distinct from the profit-target / stop / Friday-close exits."
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # source uses CME @EC (Euro futures continuous); V5 deploys on Darwinex EURUSD.DWX (spot). Tick-size + session-time mapping required.
  - friday_close                               # Friday overnight entries cross Friday 21:00 broker; forced session-close exit ≈ Saturday 06:00 CT happens AFTER framework's Friday 21:00 force-flat. Strategy must either skip Friday-evening entries or accept earlier forced-flat.
  - darwinex_native_data_only                  # @EC futures price will diverge from EURUSD.DWX spot (futures premium, contract roll, settlement-vs-tick-data mismatch). Walk-forward parameter values from Davey will likely NOT transfer 1-for-1; full re-optimization on EURUSD.DWX data required at P3.
  - news_pause_default                         # entry window 18:00-23:59 CT typically avoids the major 8:30 AM ET / 14:00 ET news releases, but Asian-session and ECB-overnight news can fall inside; default news filter should be ON.
  - kill_switch_coverage                       # this strategy holds for short durations (≤13 hours) and uses fixed stops + forced exits; kill-switch coverage is straightforward.
at_risk_explanation: |
  - dwx_suffix_discipline: Davey trades CME Euro FX continuous futures (`@EC`). V5 deployment
    targets Darwinex EURUSD.DWX (spot). At first cut, 1 tick on `@EC` ($12.50) corresponds to
    ~1 pip on EURUSD.DWX, so Stoplo=$425 ≈ 34 pips. CTO confirms exact mapping at sanity-check;
    P3 sweep re-derives optimal stop on Darwinex tick-data.

  - friday_close: V5 framework forces flat at Friday 21:00 broker time. The Davey strategy enters
    between 18:00-23:59 chart time (CT) and exits at session close (≈ 06:00 CT next day). On
    Friday evening, an entry at e.g. 19:00 CT Friday would naturally exit Saturday 06:00 CT —
    well past V5's Friday 21:00 cut-off. Two compliant options for V5: (a) add Friday-evening
    entry block to the No-Trade module (skip Friday entries entirely); (b) override session-close
    with framework's Friday 21:00 force-flat. Recommend (a) — fewer Friday-night trades but
    cleaner risk profile. Decision deferred to CEO + CTO at G0 intake.

  - darwinex_native_data_only: Davey's walk-forward parameters (Nb=14, NATR=93, ATRmult=2.55,
    TRmult=0.71, Stoplo=425) were discovered on @EC futures continuous from 2009-07-21 to
    2014-01-01. They will NOT transfer to Darwinex EURUSD.DWX spot data without re-optimization,
    because: (1) tick-data structure differs (futures has settlement, spot doesn't);
    (2) overnight gap profile differs between futures and spot; (3) typical bid-ask spread differs.
    P3 sweep re-derives parameters on Darwinex data. Davey's parameter set serves only as a
    sanity-check baseline ("would Davey's exact params have worked on Darwinex EURUSD?").

  - news_pause_default: 18:00-23:59 CT mostly avoids the heavy US-data window (08:30 ET, 10:00 ET,
    14:00 ET releases all in ET-day session). It does NOT avoid Asian-session news (Tokyo 19:50 ET
    Tankan, RBA 22:30 ET, BOJ 22:00 ET) or some ECB late-evening updates. Default news filter ON.

  - kill_switch_coverage: trivial; daily forced exits + fixed stops + max-13-hour holds make
    this an easy strategy to monitor with V5 kill-switch tooling.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: "Session window 18:00-23:59 with one-entry-per-day guard; Friday-entry block enabled to preserve framework Friday-close semantics."
  entry: "Compute LongPrice/ShortPrice from Avg(High|Low,Nb) +/- ATRmult*ATR(NATR); submit only the closer-side limit order (BUY_LIMIT or SELL_LIMIT)."
  management: "Recompute TRmult*TrueRange[1] target each bar and refresh TP; keep fixed Stoplo mapped to EURUSD.DWX pip-distance approximation (Stoplo/12.5 pips)."
  close: "Daily session-close force flat at SessionCloseHHMM plus framework Friday-close hook (default enabled)."
estimated_complexity: small                   # ~80 lines of EasyLanguage; mechanical port to MQL5
estimated_test_runtime: "P1 smoke ~15-25 min (2 deterministic runs, EURUSD.DWX M105, model 4); full P2-P8 runtime TBD by Pipeline-Operator capacity."
data_requirements: standard                   # Darwinex EURUSD.DWX 105-minute bars; standard P3 grid
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-27 | initial build from APPROVED card + CTO implementation notes + ea_id allocation | P1 | BLOCKED (smoke harness `REPORT_MISSING` while all T1-T5 terminals are already running) |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | APPROVED (CEO interim, QUA-276) | this card |
| P1 Build Validation | 2026-04-27 | BLOCKED (`REPORT_MISSING`, `INCOMPLETE_RUNS`, `MODEL4_MARKER_REQUIRED`) | `D:\QM\reports\smoke\QM5_1002\20260427_212954\summary.json` |
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
- 2026-04-27: Davey ships ten walk-forward parameter blocks in App B (one per ~6-month
  window). For V5 reuse, the cleanest baseline is the FINAL walk-forward block (Nb=14,
  NATR=93, ATRmult=2.55, TRmult=0.71, Stoplo=425); the EasyLanguage `vars:` defaults are
  legacy Ch 18 walk-through values and NOT the optimized final parameters.
- 2026-04-27: Davey's quantified performance figures are Monte Carlo outputs (Ch 19) and
  diversification-table entries (Ch 15), not raw backtest stats. Reviewers should not
  synthesize a single PF or win-rate from these — wait for V5's own P2 Baseline Screening.
- 2026-04-27: Author makes an explicit consistency callout — Ch 15 R/D=2.2 vs. Ch 19
  R/D=2.0 — recorded both verbatim. May reflect refinement runs or different sample sizes.
- 2026-04-27: The `@EC` futures vs. EURUSD.DWX spot mapping is the single biggest
  open question for this card. Tick-equivalence (1 tick @EC ≈ 1 pip EURUSD spot) gets
  the magnitude right but the underlying price series will differ enough that
  walk-forward params must be re-derived at P3. Flag to CTO.
```
