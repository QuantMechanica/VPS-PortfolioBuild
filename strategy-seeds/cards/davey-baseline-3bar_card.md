# Strategy Card — Davey Baseline 3-Bar Mean-Reversion (App A Strategy 1)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC01/raw/appA_baseline_and_monkey_variants.md` § "Strategy 1" + Chapter 12 ("Limited Testing") § "Monkey See, Monkey Do" pp. 109-110.
> Submitted for CEO review (Quality-Business not yet hired).

## Card Header

```yaml
strategy_id: SRC01_S03
ea_id: TBD
slug: davey-baseline-3bar
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:
  - mean-reversion                            # 3-bar consecutive-direction trigger fires the OPPOSITE-side trade (buy after 3 down closes; short after 3 up closes)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: "Appendix A 'Monkey Trading Example, TradeStation Easy Language Code', Strategy 1 'Baseline Strategy (No Randomness)', pp. 247-249 (verbatim EasyLanguage code) + Chapter 12 'Limited Testing', § 'Monkey See, Monkey Do', pp. 109-110 (use as monkey-test baseline; not a personally-traded strategy)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC01/raw/appA_baseline_and_monkey_variants.md` (this file extracted by Research, distinct from the foreign-process file at `appA_monkey_baseline.md` which contains an INCORRECT reading of the entry direction). Source PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf`.

## 2. Concept

A **3-bar mean-reversion strategy** that buys after three consecutive down closes (`close < close[1] < close[2]`) and sells short after three consecutive up closes. The only protective exit is a stop-loss equal to the smaller of `ssl1 * BigPointValue * ATR(14)` and a fixed-dollar cap (`ssl = $2,000` per contract). There is no profit target and no time exit; an open position closes when the stop is hit, OR when the opposite-direction trigger fires (which would reverse the position via the next market order).

Davey's own framing (Ch 12 p. 109):

> "With any strategy I create, the strategy's performance better be significantly improved over what any monkey could do by just throwing darts. If it is not, then I have no desire to trade such a strategy."

This strategy IS the "baseline" against which Davey runs his monkey-tests in App A — Strategies 2/3/4 are random variants designed to test whether Strategy 1's performance is statistically distinguishable from random. **Davey does not present Strategy 1 as a personally-traded strategy** — it's a methodology demonstration. Per OWNER Rule 1 ([CEO comment 85b9ec8e](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470)) Research nonetheless extracts it as a card; the V5 pipeline gates G0/P2 will rule on whether it has a real edge worth keeping.

## 3. Markets & Timeframes

```yaml
markets:
  - NOT_SPECIFIED                             # Davey App A code is instrument-agnostic (uses BigPointValue which adapts to whatever futures contract the chart is set to)
                                              # V5 deployment: pick one or more Darwinex futures-equivalents at CTO sanity-check
                                              # Candidates: ES (US500.DWX), NQ (NAS100.DWX), 6E (EURUSD.DWX), CL (USOIL.DWX), GC (GOLD.DWX)
timeframes:
  - NOT_SPECIFIED                             # Davey App A code does not commit to a bar size
                                              # Walk-forward windows of ~12 months suggest D1 or H4
                                              # V5 P3 sweep should test multiple bar sizes
primary_target_symbols:
  - "NOT_SPECIFIED in source — Davey uses Strategy 1 as a generic mechanical baseline in Ch 12; V5 deployment picks instruments at CTO sanity-check."
```

## 4. Entry Rules

```text
PARAMETERS (Davey's final-walk-forward-window default; per-period values in § 8 below):
- ssl1     = 0.75    // ATR multiplier for stop-loss in dollar terms (BigPointValue adapts to instrument)
- ssl      = 2000    // dollar-cap on the stop loss (per contract)
- ATR_period = 14    // hard-coded
- nContracts = 1     // input; default 1 contract

ENTRY RULE — LONG (mean-reversion after 3-bar down sequence):
- if close < close[1] AND close[1] < close[2]:
  → buy ncontracts contracts next bar at market

ENTRY RULE — SHORT (mean-reversion after 3-bar up sequence):
- if close > close[1] AND close > close[2]:
  → sellshort ncontracts contracts next bar at market

ACTIVATION GATE:
- date >= 2007-03-16   (Davey's original test-window start; drop for V5 deployment)
```

**Important:** the entry rules fire on EVERY bar where the 3-bar sequence is satisfied, regardless of whether a position is currently open. EasyLanguage market orders next-bar will reverse an existing position when the opposite-side trigger fires. There is no `marketposition = 0` guard (unlike Strategy 3 which adds one). So a long position can be flipped to short on a 3-up-close trigger; same for short→long.

## 5. Exit Rules

```text
STOP LOSS:
- setstoploss(minlist(ssl1 * BigPointValue * avgtruerange(14), ssl))
  // stop in USD per contract = MIN of:
  //   ssl1 (0.5-1.25 across walk-forward) * BigPointValue * ATR(14)
  //   ssl = $2,000 cap
  // SetStopContract: stop applies per contract.

POSITION REVERSAL via entry trigger:
- When 3-bar opposite-direction sequence fires while in a position, the next-bar market order
  REVERSES the position (no separate "close position" rule). E.g., long position + 3 up closes
  = next bar sells short, closing the long and opening a short in one trade-event.

NO PROFIT TARGET in source.
NO TIME-BASED EXIT in source.
NO SESSION-CLOSE EXIT in source.
```

## 6. Filters (No-Trade module)

```text
- Date guard: do nothing for bars dated before 2007-03-16 (Davey's original activation date).
  // Drop for V5 deployment.

- NO time-of-day filter in source.
- NO news filter in source (V5 framework default applies).
- NO volatility-floor filter in source.
- NO higher-timeframe-trend filter in source.

- Framework defaults (V5):
  - QM_NewsFilter — V5 default ON. Strategy makes no exception.
  - Friday Close — strategy can hold positions across Friday 21:00 broker time. See § 12.
  - Kill-switch — V5 default; not affected.
```

## 7. Trade Management Rules

```text
- One open position at a time, but the position can flip on opposite-side triggers (no flat-only guard).
- No move-to-break-even rule in source.
- No partial close in source.
- No trailing stop in source.
- Pyramiding: NOT used (single-contract per-trigger; V5 one_position_per_magic_symbol disallows in any case).
- Gridding:   NOT used.
```

## 8. Parameters To Test (P3 Sweep)

Davey's appendix ships **seven walk-forward parameter blocks** (one per ~12-month window from 2007-03-16 to 2014-03-08). Each block sets only `ssl1`. Reproduced verbatim in raw evidence file.

```yaml
- name: ssl1                                  # ATR multiplier for stop-loss
  default: 0.75                               # Davey's most-used value across the 7 walk-forward windows (4 of 7 windows)
  fallback_default: 1.0                       # EasyLanguage `var:` default (effectively 1 ATR)
  sweep_range: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]  # union of values Davey used (0.5, 0.75, 1.25) + endpoints
- name: ssl                                   # fixed dollar-cap on stop
  default: 2000                               # EasyLanguage var: default; never overridden in walk-forward
  sweep_range: [1000, 2000, 3000, 5000]       # cap should scale with instrument volatility
- name: ATR_period                            # currently hard-coded 14; expose for sweeping
  default: 14
  sweep_range: [10, 14, 20, 30]
- name: bar_size                              # NOT specified in source; sweep candidate
  default: D1                                 # default guess based on walk-forward window cadence
  sweep_range: [H1, H4, D1, W1]
- name: instrument                            # NOT specified in source
  default: TBD                                # CEO + CTO pick first instrument(s) at G0 intake
  candidates: [US500.DWX, NAS100.DWX, EURUSD.DWX, GBPUSD.DWX, USOIL.DWX, GOLD.DWX, GER40.DWX]
```

V5 deployment will need to pick a specific instrument before any P-stage testing. Recommend running the P2 Baseline Screening on a 2-4 instrument basket (e.g., `US500.DWX`, `EURUSD.DWX`, `GOLD.DWX`) so the strategy's edge — if any — is tested against multiple regime types.

## 9. Author Claims (verbatim, with quote marks)

Davey makes **NO quantified performance claims for Strategy 1 in App A** — the appendix is pure code. Strategy 1 appears in the main text only as the methodology-demonstration baseline against which the monkey tests run. Verbatim from Ch 12 p. 109:

```text
"With any strategy I create, the strategy's performance better be significantly improved over
what any monkey could do by just throwing darts. If it is not, then I have no desire to trade
such a strategy. I use three different monkey tests and two different time frames for testing.
Passing all of the tests gives me confidence I have something better than random." (Ch 12, p. 109)

"Typically, a good strategy will beat the monkey 9 times out of 10 in net profit and in maximum
drawdown. For my 8,000 monkey trials, that means approximately 7,200 must have net profit worse
than my results, and the same number of runs with higher maximum drawdown than my walk-forward
results. If I don't reach these goals, I really have to wonder if my entry is truly better than
random." (Ch 12, p. 109)
```

**Crucial scope note:** Davey provides no PF, no DD, no win rate, no annualized return for Strategy 1. He does not present it as a personally-traded strategy. He uses it as a structural example of a strategy-shaped object that monkey-tests can be run against. **Reviewers should treat this card's eventual P2 Baseline Screening output as the FIRST quantified performance evidence for this strategy** — there is no author-claim baseline to anchor expectations against.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Davey provides no PF
expected_dd_pct: TBD                          # Davey provides no DD
expected_trade_frequency: TBD                 # Davey provides no trade count
risk_class: medium                            # operator's read; 3-bar trigger should fire reasonably often (~10-30% of bars on noisy markets); low position duration
gridding: false
scalping: false                               # bar_size unspecified; not high-frequency-by-design
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — entry rule is a simple price-vs-prior-close inequality; stop is ATR-based + dollar-cap; no discretion.
- [x] No Machine Learning required.
- [x] Gridding: N/A.
- [x] Scalping: N/A (bar size unspecified; if D1, definitely not scalping; if H1 or H4, also not scalping).
- [ ] Friday Close compatibility — see § 12. **Likely to bind:** strategy has no time exit, so positions can hold across Friday 21:00 broker time. V5 deployment must add an explicit Friday-Close handler (or accept a deviation, which CEO + CTO must approve).
- [x] Source citation precise (book + ISBN + appendix + Strategy 1 + page numbers + chapter cross-reference with page numbers).
- [x] No near-duplicate of existing approved card. Distinct from S01 Euro Night and S02 Euro Day on instrument, bar size, entry trigger, exit logic.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: false                                # source has NO no-trade conditions; framework defaults (kill-switch, news, friday-close) supplied externally
    notes: "Strategy 1 has no entry filters of its own. V5 framework defaults must cover news and Friday Close; see hard_rules_at_risk."
  trade_entry:
    used: true
    notes: "3-bar consecutive-close-direction mean-reversion trigger; market order at next bar; no other gates. Existing positions can be flipped by opposite-side triggers."
  trade_management:
    used: true
    notes: "ATR-multiple OR fixed-dollar stop, whichever is tighter (per contract). NO trailing, NO partial close, NO BE-move. Position-protective via SetStopContract."
  trade_close:
    used: false                                # no separate exit-signal logic; close is governed by stop OR position-flip-via-trigger only
    notes: "Strategy has no explicit close logic beyond the stop. Position flips via entry trigger are NOT a 'close' in the framework sense — they're new entries that incidentally close the prior position."
```

```yaml
hard_rules_at_risk:
  - friday_close                               # strategy has NO time-based exit; positions held across Friday 21:00 broker time unless externally forced flat. V5 framework Friday-Close handler MUST be applied.
  - dwx_suffix_discipline                      # source is instrument-agnostic; Darwinex symbol (with .DWX suffix) chosen at CTO sanity-check.
  - darwinex_native_data_only                  # walk-forward parameter values from Davey's instrument (unspecified) won't transfer 1-for-1; full re-optimization on chosen Darwinex instrument required.
  - one_position_per_magic_symbol              # the position-flip-via-trigger pattern is not pyramiding (max one position at any time); V5 hard rule should not bind. But the entry-flip mechanic should be explicit in the EA.
  - kill_switch_coverage                       # no native time exit makes kill-switch coverage ESPECIALLY important — a runaway position has no implicit time-out.
at_risk_explanation: |
  - friday_close: this is the most important hard-rule risk for this card. Davey's source has
    no time-based exit at all — positions persist until the stop is hit or until the opposite-side
    trigger reverses them. On Friday evening, an open position will hold across the V5 21:00 broker
    force-flat. V5 deployment MUST add an explicit Friday-Close exit. Recommend forcing flat at
    Friday 21:00 (V5 framework default behavior) — no special handling beyond what the framework
    already provides.

  - dwx_suffix_discipline / darwinex_native_data_only: Davey's source is instrument-agnostic. CTO
    picks instrument(s) at G0 intake (recommend a small 2-4 instrument basket spanning equity-index,
    FX-major, commodity for regime diversity). All Davey-derived parameter values (`ssl1` 0.5-1.25)
    are stripped at P3; full re-optimization on chosen Darwinex instrument(s).

  - one_position_per_magic_symbol: the position-flip-via-trigger pattern means the strategy
    naturally holds at most one position at any time, which COMPLIES with the V5 hard rule. But the
    EA must explicitly close the existing position before opening the new one (rather than relying
    on TradeStation's market-order-flip behavior which is a TradeStation-specific shortcut not
    available identically in MT5).

  - kill_switch_coverage: with no native time exit, an open position with a stop that never gets
    hit could persist indefinitely. V5 kill-switch is the only backstop for runaway positions on
    this strategy. Pipeline-Operator should specifically validate kill-switch coverage at P9b
    Operational Readiness for this card.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                                # only framework defaults (Friday-Close, news, kill-switch)
  entry: TBD                                   # 3-bar consecutive-close-direction trigger; fire on every qualifying bar
  management: TBD                              # ATR-multiple OR $2k cap, whichever tighter; per contract
  close: TBD                                   # framework Friday-Close handler; position-flip via opposite-side trigger
estimated_complexity: small                    # ~30 lines of EasyLanguage; trivial port to MQL5
estimated_test_runtime: TBD                    # depends on chosen instrument(s) and bar size
data_requirements: standard
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | TBD | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | DRAFT | this card |
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
- 2026-04-27: Davey provides no quantified performance claims for Strategy 1. The card has no
  author-claim baseline — V5's P2 Baseline Screening will produce the first numbers we use.
  This is unusual for a Strategy Card and reviewers should expect a "weaker prior" than for
  S01 Euro Night and S02 Euro Day (both of which have Ch 19 Monte Carlo claims).
- 2026-04-27: Strategy 1 has NO time-based exit. V5 framework Friday-Close handler is the
  single most important framework integration for this card. Pipeline-Operator: validate
  Friday-Close coverage at P9b Operational Readiness.
- 2026-04-27: Strategy 1 is instrument-agnostic in source. Davey doesn't tell us which futures
  contract he ran the monkey tests on. V5 deployment must pick 2-4 instruments to test edge
  across regime types (equity-index, FX-major, commodity).
- 2026-04-27: Davey calls this strategy "the baseline" in his Ch 12 monkey-test demonstration —
  he does NOT present it as a personally-traded strategy. Per OWNER Rule 1, Research extracts
  it anyway; the pipeline gates rule on whether it has edge worth keeping. If P2 Baseline
  Screening kills it on the "no edge" basis, that's the correct Rule-1-compliant outcome.
- 2026-04-27: A foreign-process file at `appA_monkey_baseline.md` (in this same SRC01/raw/
  directory) reads Strategy 1's entry as "consecutive-direction momentum entry" — that is
  WRONG. The 3-bar consecutive-direction trigger fires the OPPOSITE-side trade (mean-reversion).
  My raw evidence file at `appA_baseline_and_monkey_variants.md` documents the correct reading
  with code-by-code parsing. Flagged for CEO awareness in QUA-191 thread.
```
