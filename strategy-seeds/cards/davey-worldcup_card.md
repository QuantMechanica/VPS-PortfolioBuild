# Strategy Card — Davey World Cup System (X-bar Close Breakout, RSI-filtered, Trend-Following)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC01/raw/ch3_worldcup_xbar_breakout.md` (verbatim Ch 3 prose specification + 3-year contest performance).
> Submitted for CEO review (Quality-Business not yet hired).

> ⚠ **Note to reviewers:** This is the strategy Davey personally traded in the **World Cup Championship of Futures Trading®** in 2005, 2006, and 2007 (placing 2nd, 1st, 2nd with annual returns of **148%, 107%, 112%**). The contest performance is real and published. **However Davey himself, and his mentor Dr. Van Tharp, both warn that contest-grade position sizing is NOT a sustainable normal-account risk profile** — Davey accepted up to 75% max DD by design. V5 deployment must size positions for normal V5 risk modes, NOT for contest leverage. See § 9 Author Claims for verbatim warnings, § 12 hard_rules_at_risk for `risk_mode_dual` flag.

## Card Header

```yaml
strategy_id: SRC01_S05
ea_id: TBD
slug: davey-worldcup
status: APPROVED
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27
g0_verdict: APPROVED
g0_reviewer: CEO (interim until Quality-Business hire)
g0_reviewed_at: 2026-04-27
g0_issue: QUA-276

strategy_type_flags:
  - trend-following                           # 48-bar high close → BUY (trend continuation expected); explicit Davey framing: "It is just a simple trend-following approach"
  - breakout                                  # entry trigger is a fresh N-bar close-extreme
  - momentum                                  # 30-bar RSI momentum filter (long requires RSI>50, short requires RSI<50)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 3 'World Cup Championship of Futures Trading® Triumph', pp. 23-31 (verbatim strategy specification at p. 24; basket of 9 futures p. 24; capital and contract-size at p. 25; 2005-2007 contest results in Figures 3.1, 3.2, 3.4 at pp. 26, 28, 30; Davey's self-critique of selection process p. 25; Van Tharp warning on contest-grade sizing p. 31). Earlier glance at Chapter 2 p. 21 also provides context."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC01/raw/ch3_worldcup_xbar_breakout.md`. Source PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf`.

## 2. Concept

A **trend-following daily-bar breakout strategy** with an RSI momentum filter, traded on a basket of 9 diverse futures. BUY next bar after a fresh 48-bar high close when the 30-bar RSI confirms upward momentum (RSI > 50); SHORT after a fresh 48-bar low close with RSI < 50. Multiple stop layers: a $1,000 fixed dollar stop plus an ATR-multiple trailing stop (Y) plus an ATR-multiple profit target (Z). Plus inter-trade discipline: wait 5 bars after a loser, 20 bars after a winner. Daily bars; one contract per instrument; basket-of-9 deployment.

Davey's framing (Ch 3 p. 21): *"It is just a simple trend-following approach, and as long as some sustained trends develop, the system overall will make money."* The 48/30 bar parameters and RSI+50 threshold define the trigger; the multiple-stop architecture controls risk; the wait rules manage psychology and reduce whipsaw exposure.

**Distinct from S04 `davey-es-breakout`:** that strategy is COUNTERTREND on close-vs-N-day-extreme on ES daily; this strategy is TREND-FOLLOWING on a similar-shaped trigger but on a multi-instrument basket. Same trigger family (close = N-bar high/low) but **opposite trade direction**.

## 3. Markets & Timeframes

```yaml
markets:
  - currency_futures                          # Davey's basket: Japanese yen
  - equity_index_futures                      # Davey's basket: Nikkei Index
  - rate_futures                              # Davey's basket: 5/10-year Treasury notes
  - agriculture_futures                       # Davey's basket: Corn, Cotton, Sugar, Coffee
  - metal_futures                             # Davey's basket: Copper, Gold
timeframes:
  - daily bars                                # Davey, Ch 3 p. 24: "The system utilized daily bars for all trading signals"
primary_target_symbols:
  # Davey's 9-instrument basket on CME / NYBOT / CBOT / TOCOM / SIMEX (varies by 2005-2007 era):
  - "Corn (@C, CBOT)"
  - "Cotton (@CT, NYBOT/ICE)"
  - "Copper (@HG, COMEX)"
  - "Gold (@GC, COMEX)"
  - "Sugar (@SB, NYBOT/ICE)"
  - "5-year Treasury Notes (@FV, CBOT) OR 10-year Treasury Notes (@TY, CBOT)"
  - "Coffee (@KC, NYBOT/ICE)"
  - "Japanese Yen (@JY, CME)"
  - "Nikkei Index (@NK, CME OR @SXF/@SSI on TSE/SIMEX)"
  # V5 Darwinex re-mapping at CTO sanity-check — candidate proxies:
  # corn/cotton/sugar/coffee: Darwinex commodity CFDs (limited coverage; some may not exist)
  # copper/gold: GOLD.DWX, COPPER.DWX (or USOIL.DWX equivalent for industrial metals)
  # JPY: USDJPY.DWX (spot)
  # Nikkei: JP225.DWX (CFD)
  # T-notes: USTNOTE.DWX or similar — Darwinex coverage TBD
v5_basket_recommendation: |
  Per Davey's self-critique (p. 25), DO NOT cherry-pick instruments by historical performance.
  CTO at G0 either (a) tests on all available Darwinex proxies for Davey's 9 instruments equally,
  or (b) selects a smaller basket using explicit correlation analysis (Davey's other self-critique).
  Whichever approach: document the selection logic in the card's § 13 Implementation Notes.
```

## 4. Entry Rules

```text
PARAMETERS (Davey-specified where given; TBD where not):
- X            = 48        // bar count for highest(close, X) / lowest(close, X) — trend trigger
- RSI_period   = 30        // RSI lookback
- RSI_threshold = 50       // RSI gate (long requires RSI>50, short requires RSI<50)

ENTRY RULE — LONG (48-bar high close + RSI uptrend):
- if close = highest(close, X) AND RSI(close, RSI_period) > RSI_threshold:
  → buy next bar at market (next bar's open per Davey's "Buy next bar")

ENTRY RULE — SHORT (48-bar low close + RSI downtrend):
- if close = lowest(close, X) AND RSI(close, RSI_period) < RSI_threshold:
  → sellshort next bar at market

INTER-TRADE WAIT RULES (Davey, Ch 3 p. 24):
- if last closed trade was a loser: wait at least 5 bars before next entry
- if last closed trade was a winner: wait at least 20 bars before next entry

ENTRY GATE: standard mechanical (one position at a time per instrument, framework Friday-Close /
news / kill-switch defaults apply).
```

## 5. Exit Rules

```text
STOP LOSS (multi-layer; tightest of the three applies at any moment):
- LAYER 1: Fixed dollar stop = $1,000 (per contract, per instrument)
- LAYER 2: Y * ATR(?, ?) ATR-multiple trailing stop  // Y not numerical-valued in source — TBD
- LAYER 3: Z * ATR(?, ?) ATR-multiple profit target  // Z not numerical-valued in source — TBD

PROFIT TARGET:
- Z * ATR(?, ?) above entry (long) / below entry (short).
- Davey describes this as a "stop" but it's a profit-side exit (target hit closes for profit).

NO TIME-BASED EXIT in source — strategy can hold positions indefinitely until one of the three
exit layers fires.

POSITION REVERSAL: not explicitly described in source. Davey treats each trade as independent
(closed by one of the exit layers, then waits 5 or 20 bars per the inter-trade rule).
```

## 6. Filters (No-Trade module)

```text
- 30-bar RSI direction gate (described in § 4 — part of entry condition, not a separate filter).
- Inter-trade wait rules (5 bars after loser, 20 bars after winner) — described in § 4.
- NO time-of-day filter (daily bars — one signal evaluation per day at close).
- NO news filter in source (V5 framework default applies).
- NO volatility-floor filter.

- Framework defaults (V5):
  - QM_NewsFilter — V5 default ON.
  - Friday Close — strategy holds positions across Friday 21:00 broker time potentially. See § 12.
  - Kill-switch — V5 default; not affected.
```

## 7. Trade Management Rules

```text
- One open position per instrument; no scaling, no pyramiding.
  // Davey: "Since my capital was limited, I could only trade one contract of each instrument."
  // Davey did add to a losing copper position in late 2005 in violation of his own rules (p. 27);
  //   he flags this as a mistake. V5 deployment must enforce no-pyramiding strictly.
- No move-to-break-even rule in source (the multi-layer stop architecture handles this implicitly).
- No partial close in source.
- The $1,000 fixed dollar stop is a HARD floor; the ATR trailing stop should override it once it
  is tighter than the fixed stop (i.e., as profit accumulates, the trailing stop ratchets up).
- Pyramiding: NOT used (V5 hard rule complies).
- Gridding:   NOT used.

POSITION SIZING (CRITICAL — see § 12 hard_rules_at_risk):
- Davey's contest deployment: 1 contract per instrument, $15,000 starting account, accepted up to
  75% max DD. Max DD across 3 contest years was 42% / 40% / 50%.
- V5 deployment: USE V5'S STANDARD risk-mode-percent OR risk-mode-fixed sizing. DO NOT replicate
  Davey's contest leverage — the contest's "75% max DD acceptable" framing was specific to the
  return-only contest objective, NOT a normal trading-account objective.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: X                                     # bar count for entry trigger highest/lowest(close, X)
  default: 48                                 # Davey-specified
  sweep_range: [20, 30, 48, 60, 80, 100]
- name: RSI_period
  default: 30                                 # Davey-specified
  sweep_range: [14, 20, 30, 50]
- name: RSI_threshold
  default: 50                                 # Davey-specified (the RSI midpoint)
  sweep_range: [40, 45, 50, 55, 60]
- name: fixed_dollar_stop                     # Davey-specified $1,000
  default: 1000                               # USD per contract
  sweep_range: [500, 1000, 1500, 2000]
  # NB: per-instrument scaling required at V5 P3 — $1,000 on Corn vs Gold has very different ATR significance
- name: Y_atr_trail                           # ATR multiplier for trailing stop — NOT numerical in source
  default: 3.0                                # sensible default; TBD per Davey
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: Z_atr_target                          # ATR multiplier for profit target — NOT numerical in source
  default: 5.0                                # sensible default; TBD per Davey
  sweep_range: [3.0, 4.0, 5.0, 7.0, 10.0]
- name: wait_after_loser                      # Davey-specified
  default: 5                                  # bars
  sweep_range: [0, 3, 5, 10]
- name: wait_after_winner                     # Davey-specified
  default: 20                                 # bars
  sweep_range: [10, 20, 30, 50]
- name: bar_size
  default: D1                                 # Davey-specified
  sweep_range: [H4, D1, W1]
```

**Key note:** the source provides the X, RSI_period, RSI_threshold, fixed_dollar_stop, and wait rules numerically. The Y and Z ATR multipliers are described structurally but NOT numerical-valued in Ch 3. P3 sweep should explore both: V5 may converge to different Y/Z than Davey did.

## 9. Author Claims (verbatim, with quote marks)

```text
Strategy specification (Ch 3, p. 24):
"I was ready for 2005 with the following system:

Entry
Buy next bar after 48 bar high close (vice versa for short), as long as the 30-bar RSI was
greater than 50 (less than 50 for short trades).

Exit
Calculate stop based on:
   Fixed dollar value ($1,000)
   Y * average true range from entry
   Z * average true range from entry (profit target)

Other Rules (based on my psychology, I felt I needed these)
   If last trade was a loser, wait 5 bars before entering next trade (minimizes whipsaws).
   If last trade was a winner, wait 20 bars before entering next trade (be patient after wins)."

Performance — World Cup Championship of Futures Trading® (Ch 3, pp. 26, 28, 30):

2005 Results (Figure 3.1, p. 26):
   Contest position    Second place
   Return              148%
   Max Drawdown         42%
   Return/Drawdown       3.5

2006 Results (Figure 3.2, p. 28):
   Contest position    First place
   Return              107%
   Max Drawdown         40%
   Return/Drawdown       2.7

2007 Results (Figure 3.4, p. 30):
   Contest position    Second place
   Return              112%
   Max Drawdown         50%
   Return/Drawdown       2.2

Davey's framing of the strategy (Ch 2, p. 21):
"Nothing earth shattering about this strategy's entries or exits--I am sure this approach
was been applied by many people before. It is just a simple trend-following approach, and
as long as some sustained trends develop, the system overall will make money."

Davey's risk-tolerance choice (Ch 3, p. 24):
"To achieve 100 percent return over the course of a year, I knew I had to accept a very large
maximum drawdown. I decided I would allow around 75 percent maximum drawdown, which would
be ridiculous for any normal trader's account. But, as I'll discuss in great detail later,
your goals and expectations should be based on the situation at hand. For a trading contest
where the only success criterion was return on account, allowing a large drawdown makes
sense. If, however, the contest were based on return and risk (say the winning contestant
would have the highest Calmar ratio), I would have approached the contest completely
differently."

Davey's self-critique of selection process (Ch 3, p. 25):
"Looking back on this, though, I realize I made two pretty big rookie mistakes. First, when
I tested my system, I tested over 20 to 25 different instruments. Then, upon seeing the
actual performance, I simply selected the best performers. In other words, I optimized
based on market! That is a big no-no for good strategy development. For my second mistake,
I did not run any detailed correlation studies when selecting the portfolio."

Van Tharp warning on contest-grade trading (Ch 3, p. 31, quoted by Davey):
"And although Kevin has been trading and learning for 15 years, most people [who] win in
trading contests are doing some very dangerous things with position sizing. So notice your
reactions. Are you impressed with the people [who] win competitions? Or is your gut reaction
to learn more about how to trade effectively in any market — and just stay in the game!"
```

**Crucial scope note:** Davey's contest performance (148% / 107% / 112%) is REAL and contemporaneous (verifiable on World Cup Championship records). But it was achieved with deliberately aggressive position sizing (75% max DD allowance) that does NOT translate to normal-account V5 deployment. V5's P2 Baseline Screening on a Davey-derived basket should NOT expect to reproduce contest-level returns; expect single-digit-to-low-double-digit annualized returns at V5 risk-mode-percent levels.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Davey reports return/drawdown not PF
expected_dd_pct: TBD                          # Davey's contest DDs (42-50%) are NOT representative for V5 sizing; V5 default sizing → expected DD likely 5-15% on a basket
expected_trade_frequency: TBD                 # depends on basket size and instrument volatility; daily bars on 9 instruments → ~50-150 trades/yr aggregate
risk_class: medium                            # at V5 standard sizing; high at Davey contest sizing
gridding: false
scalping: false                               # daily bars
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — entry rule (close-vs-N-bar-extreme + RSI gate) is fully mechanical; multi-layer stop is mechanical; wait rules are mechanical.
- [x] No Machine Learning required.
- [x] Gridding: N/A.
- [x] Scalping: N/A (daily bars).
- [ ] Friday Close compatibility — see § 12. Strategy has no time exit; positions can hold across Friday 21:00 broker time. V5 Friday-Close handler must cover.
- [x] Source citation precise (book + ISBN + chapter + page numbers + figure references).
- [x] No near-duplicate of existing approved card. Distinct from S01-S04 on instrument basket, trade direction (TREND-following vs S04's countertrend on similar trigger), filter (RSI gate + wait rules unique to this card).

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "30-bar RSI gate (long requires RSI>50, short requires RSI<50); 5-bar wait after loser, 20-bar wait after winner; framework defaults for news/Friday-close/kill-switch."
  trade_entry:
    used: true
    notes: "close = highest(close, 48) AND RSI(close, 30) > 50 → buy next bar at market (long). Mirror for short."
  trade_management:
    used: true
    notes: "Multi-layer stops: $1,000 fixed + Y*ATR trail + Z*ATR target. Tightest applies. NO BE-move (not specified in source). NO partial close. NO pyramiding (Davey explicitly violated this once and flags it as a mistake)."
  trade_close:
    used: false                                # closes governed by stop layers only; no separate exit-signal logic
    notes: "Standard framework Friday-Close handler is the only non-stop closure trigger."
```

```yaml
hard_rules_at_risk:
  - friday_close                               # NO time exit; positions hold across Friday 21:00 broker. V5 Friday-Close handler MUST be applied.
  - dwx_suffix_discipline                      # source uses CME / NYBOT / CBOT futures symbols (@C, @CT, @HG, @GC, @SB, @FV/@TY, @KC, @JY, @NK); Darwinex re-mapping required at CTO sanity-check.
  - darwinex_native_data_only                  # futures continuous price series differ from Darwinex CFD/spot proxies; full re-optimization at P3.
  - risk_mode_dual                             # **PRIMARY HARD-RULE RISK ON THIS CARD.** Davey's contest deployment used 1-contract-per-instrument with explicit 75%-max-DD acceptance. V5 deployment must use V5's standard risk-mode-percent or risk-mode-fixed sizing — NOT replicate contest leverage. This is the most important framework note for this card.
  - one_position_per_magic_symbol              # NO pyramiding. Davey's own self-critique flags one violation in late-2005 coffee; V5 must enforce strictly.
  - kill_switch_coverage                       # no native time exit makes kill-switch coverage especially important.
  - enhancement_doctrine                       # Y, Z ATR multipliers are TBD in source. P3 will derive them; post-PASS tuning of these triggers a _v<n> rebuild.
  - magic_schema                               # 9-instrument basket means 9 magic-IDs required; standard `ea_id*10000+symbol_slot` formula applies but Pipeline-Operator should pre-allocate slots.
at_risk_explanation: |
  - risk_mode_dual: this is the #1 hard-rule consideration. Davey's CONTEST deployment is NOT a
    blueprint for V5 NORMAL deployment. The 148% / 107% / 112% returns came with 42% / 40% / 50%
    max DDs respectively, all from 1-contract-per-instrument on a $15,000 account. At V5
    risk-mode-percent (typical 0.5-2% per trade), expected returns will be MUCH lower (single-
    digit to low-double-digit annualized) AND max DDs will be MUCH lower (5-15% on a basket).
    Reviewers must NOT compare V5 P2 baseline-screening output to Davey's contest numbers — the
    risk profiles are non-comparable. CEO + OWNER should set normal-account performance
    expectations BEFORE P2 runs, so the strategy isn't unfairly killed for "underperforming"
    a contest benchmark that V5 deliberately doesn't replicate.

  - friday_close: standard same-as-S03/S04 — strategy has no time exit; framework default
    Friday-Close handler is the mitigation.

  - dwx_suffix_discipline / darwinex_native_data_only: 9-instrument basket includes some
    instruments without clean Darwinex equivalents (corn / cotton / sugar / coffee / T-notes
    coverage on Darwinex is partial at best). CTO at G0 picks the BEST-REPRESENTED 4-6
    instruments rather than forcing all 9. Document selection logic explicitly per Davey's
    own self-critique (don't cherry-pick by past performance).

  - one_position_per_magic_symbol: Davey explicitly violated this (late-2005 coffee, p. 27)
    and calls it a mistake. V5 must enforce — no manual override.

  - kill_switch_coverage: same as S03/S04 — no native time-out for runaway positions.

  - enhancement_doctrine: Y and Z ATR multipliers are TBD in source. P3 will produce specific
    values. If those values prove unstable across walk-forward windows, _v<n> rebuild cadence
    increases.

  - magic_schema: 9 instruments × 1 EA = 9 magic-IDs at deployment time. Pipeline-Operator
    pre-allocates slots per CLAUDE.md formula at G0/P9b.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                                # RSI gate + wait rules + framework defaults
  entry: TBD                                   # close-vs-48-bar-extreme + 30-bar RSI gate
  management: TBD                              # 3-layer stop architecture: $1k fixed + Y*ATR trail + Z*ATR target
  close: TBD                                   # framework Friday-Close handler
estimated_complexity: medium                   # multi-layer stop + wait-state tracking + per-instrument config; ~50-80 lines MQL5
estimated_test_runtime: TBD                    # depends on basket size and Y/Z sweep ranges
data_requirements: standard                    # but multi-instrument; Darwinex coverage gaps may force basket reduction
basket_selection_at_g0:                        # CRITICAL — see § 9 Davey self-critique
  approach_a: "all-Darwinex-proxies-tested-equally; rank by P2 baseline metric uniformly"
  approach_b: "correlation-driven basket selection (max-N most-uncorrelated instruments from Davey's list)"
  forbidden: "cherry-pick top-3 historical performers from Davey's basket — Davey himself flags this as a mistake"
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
- 2026-04-27: This is the second card in the Davey set with QUANTIFIED HISTORICAL performance
  (S04 davey-es-breakout was the first). Davey's 2005-2007 World Cup numbers are real and
  publicly verifiable. But the 148%/107%/112% returns came with 42%/40%/50% DDs, achieved with
  contest-grade leverage that V5 deliberately does NOT replicate. P2 baseline-screening output
  on V5 risk-mode sizing should be calibrated to single-digit-to-low-double-digit annualized
  expectations, not to contest-level benchmarks.

- 2026-04-27: Davey's self-critique (p. 25) explicitly flags two errors: instrument-cherry-
  picking (tested 25, picked best 9) and lack of correlation-aware basket selection. V5 G0
  basket selection MUST avoid both. CTO at G0 documents the basket-selection logic explicitly.

- 2026-04-27: Strategy specification is mostly numerical (X=48, RSI_period=30, RSI_threshold=50,
  fixed_stop=$1000, wait=5/20). The Y and Z ATR multipliers are NOT numerical in source — P1 and
  P3 will derive them. Use the sweep ranges in § 8 as starting point.

- 2026-04-27: Davey explicitly violated his own no-pyramiding rule once (late-2005 coffee, p. 27)
  and reflects on it as a mistake ("will I ever learn?"). V5 deployment must enforce strictly via
  the framework's one_position_per_magic_symbol hard rule.

- 2026-04-27: Distinct from S04 davey-es-breakout — same trigger family (close = N-bar high/low)
  but OPPOSITE trade direction. S04 is countertrend on ES daily; S05 is trend-following on a
  9-instrument futures basket with RSI gate. Reviewers should consider whether running BOTH S04
  and S05 produces edge-vs-redundancy or constructive interference; this is a P9 portfolio-level
  question, not a G0/P2 question.
```
