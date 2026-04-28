# Strategy Card — Lien Double Bollinger Bands: Join a New Trend (trend-join breakout)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` (verbatim Lien Ch 9 § "Using Double Bollinger Bands to Join a New Trend").
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S02b
ea_id: TBD
slug: lien-dbb-trend-join
status: APPROVED
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28
g0_verdict: APPROVED
g0_reviewer: CEO (interim until Quality-Business hire)
g0_reviewed_at: 2026-04-28
g0_issue: QUA-398

strategy_type_flags:
  - bband-reclaim                             # vocabulary-gap PROPOSED — entry: close back across N·σ Bollinger band after K consecutive bars on the OUTER side. SHARED FLAG with sibling S02a; per-card disambiguation `precondition_mode = n-bars-opposite-1sigma` (this card) vs `outer-band-zone` (S02a). V4 had no equivalent SM_XXX EA. Flagged at § 16; batch-ratified at SRC04 closeout. See sibling card `lien-dbb-pick-tops_card.md` § 16 for canonical proposal.
  - atr-hard-stop                             # Lien: fixed 65-pip initial stop; V5 maps to ATR(14) × M-multiple sweep
  - symmetric-long-short                      # Lien explicitly mirrors long and short rules (PDF pp. 107-110)
  - friday-close-flatten                      # V5 default; trend-join hold typically 24 hours to ~6 trading days per Lien examples
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 9 'Technical Strategy: Trading with Double Bollinger Bands' — § 'Using Double Bollinger Bands to Join a New Trend' (PDF pp. 107-110) including 'Strategy Rules for Long Trade' and 'Strategy Rules for Short Trade'. Cross-reference: § 'Using Double Bollinger Bands to Determine Trend versus Range' (PDF p. 107) for regime-classification framing."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` lines 290-333 (Long + Short rule lists verbatim), lines 337-367 (USDJPY Long example + GBPUSD Short example with explicit pip arithmetic), lines 279-288 (trend-vs-range regime framing). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Sibling strategy to S02a `lien-dbb-pick-tops`. Same Double-Bollinger-Band construction (20-period 1st-σ + 2nd-σ bands), same NY-close 5pm fill, same partial-close-at-target-then-trail TM pattern — but FIRES IN THE OPPOSITE REGIME. Lien's regime classification (PDF p. 107): when price is between the two outer bands (1st-σ and 2nd-σ on the SAME side of mean) the pair is in TREND mode; when between the 1st-σ bands above and below mean the pair is in RANGE mode. S02a fires the RANGE-mode signal (mean-revert from outer-band zone back to inner-band); S02b fires the TREND-JOIN signal (close ACROSS 1st-σ band after 2 consecutive bars on the OPPOSITE side, signalling regime flip into a new trend).

Long entry: pair closes ABOVE 1st-σ band IF prior 2 candles were BELOW 1st-σ band → buy at 5 pm NY. Short mirror. Initial fixed 65-pip stop, partial close at +50 pips (move rest to BE), second target +195 pips. Note that S02b is **not risk-symmetric** — initial stop and target distances are FIXED PIPS, not multiples of risk; this is structurally different from S02a's 1R/2R partial-close pattern.

Lien's verbatim concept framing, PDF p. 107:

> "When the pair is trading between the two lower or upper Bollinger Bands, it is in trend, and when it is trading between the first standard deviation Bollinger Bands, it is in range, as shown in Figure 9.6. When the currency pair is in trend mode, it is best to look for opportunities to join the trend. When it is in the range zone, picking tops and bottoms is preferred."

PDF p. 107:

> "Another way to use the double Bollinger Bands is to join a new uptrend or downtrend using a daily chart."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 9 entire universe is forex spot pairs; examples: USDJPY, GBPUSD
timeframes:
  - D1                                        # Lien explicit: "Both of these strategies are for daily charts" (PDF p. 110)
  - H4                                        # H4 plausible D1-derivative (V5 internal P3 sweep variant); out-of-source extrapolation
session_window: NY close (5 pm New York time)  # Lien: "buy at close of candle or 5pm NY Time" (PDF p. 107, rule 3)
primary_target_symbols:
  - "USDJPY.DWX (Lien example: PDF pp. 109-110 USDJPY Long Trade @ 119.97, target +195 pips at 121.92)"
  - "GBPUSD.DWX (Lien example: PDF p. 110 GBPUSD Short Trade @ 1.5263, target -195 pips at 1.5068)"
  - "EURUSD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX (multi-major generalization implicit in Lien's chapter framing)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF pp. 107-108 rule lists.

```text
PARAMETERS:
- BB_PERIOD          = 20         // Lien: "the 20-period moving average" (Ch 9 PDF p. 101)
- BB_INNER_SIGMA     = 1.0        // Lien: "the 20-period, one-standard deviation" (Ch 9 PDF p. 102)
- BB_OUTER_SIGMA     = 2.0        // Lien: "the two standard deviation bands" (Ch 9 PDF p. 101)
- BAR                = D1         // Lien: "Both of these strategies are for daily charts"
- ENTRY_TIME         = "17:00 NY" // Lien: "5pm NY Time" (PDF p. 107)
- LOOKBACK_BARS      = 2          // Lien: "the last two candles were below the first standard deviation Bollinger Band" (PDF p. 107, long rule 2)
                                  //   For short mirror: "the last two candles were above the first standard deviation Bollinger Band"
- INIT_STOP_PIPS     = 65         // Lien: "Initial stop at +65 pips" (PDF p. 107, long rule 4; PDF p. 108, short rule 4 — symmetric)
- TP1_PIPS           = 50         // Lien: "Close half of position at +50 pips" (PDF p. 107, long rule 5)
- TP2_PIPS           = 195        // Lien: "Close remainder of position at +195 pips" (PDF p. 107, long rule 6)

EACH-BAR (evaluated at NY close):
- mid          = SMA(close, BB_PERIOD)
- inner_upper  = mid + BB_INNER_SIGMA * stdev(close, BB_PERIOD)
- inner_lower  = mid - BB_INNER_SIGMA * stdev(close, BB_PERIOD)

LONG ENTRY (close back across inner_lower band after K-bar dwell below):
- precondition: close[t-k] < inner_lower[t-k] for ALL k in 1..LOOKBACK_BARS
                                                                      // Lien: "Check to see if the last two candles were below the first standard deviation Bollinger Band"
- trigger:      close[t] > inner_lower[t]                              // Lien: "Look for the currency pair to close above the first standard deviation Bollinger Band"
- if both: BUY at close of bar (NY 5pm)                                // Lien: "buy at close of candle or 5pm NY Time"
- initial stop: entry - INIT_STOP_PIPS_at_entry                        // Lien: "Initial stop at +65 pips"

SHORT ENTRY (mirror):
- precondition: close[t-k] > inner_upper[t-k] for ALL k in 1..LOOKBACK_BARS
- trigger:      close[t] < inner_upper[t]
- if both: SELL at close of bar (NY 5pm)
- initial stop: entry + INIT_STOP_PIPS_at_entry
```

## 5. Exit Rules

Lien's exit rule list (PDF p. 107 long rules 5-6, PDF p. 108 short rules 5-6):

> "5. Close half of position at +50 pips; move stop on rest to initial entry price (breakeven).
>  6. Close remainder of position at +195 pips."

Pseudocode:

```text
PARAMETERS:
- TP1_PIPS           = 50         // Lien: "Close half of position at +50 pips"
- TP2_PIPS           = 195        // Lien: "Close remainder of position at +195 pips"
- TRAIL_AFTER_TP1    = "BE"       // Lien: "move stop on rest to initial entry price (breakeven)" — fixed BE move at TP1

EACH-BAR (in position):
- HARD STOP — fires at INIT_STOP_PIPS distance from entry (rule 4)
- TP1 (close half): if abs(price - entry) >= TP1_PIPS:
    CLOSE_HALF
    move_remaining_stop to BE (entry price)
- TP2 (close remaining): if abs(price - entry) >= TP2_PIPS:
    CLOSE_ALL

FRIDAY CLOSE: V5 default applies. Lien examples: USDJPY Long takes 6 trading days to hit TP2;
GBPUSD Short hits both targets same day. Hold range 1-6 sessions; weekend hold occasional;
default-flatten preserves edge. No waiver requested.
```

Note: Lien's TM is **fixed-pip** (50 / 195), NOT R-multiple as in S02a (1R / 2R). The 65-pip initial stop is asymmetric vs the 50/195-pip targets — TP1=0.77R partial close, TP2=3.0R remainder. P3 sweep axis tests both fixed-pip and R-multiple variants.

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (Lien rules describe single-position-at-a-time)
- gridding: NOT allowed
- regime gate (Lien Ch 9 § "Trend versus Range" PDF p. 107):
  S02b is the TREND-JOIN card; sibling S02a is the RANGE-MR card. The two cards are co-regime
  mutually exclusive at the SAME bar. Card-level filter: skip entries when the SAME-bar
  precondition for S02a would also fire (i.e., when prior bar was in the outer-band zone — i.e.
  between inner-σ and outer-σ on the SAME side as the K-bar dwell). Otherwise both cards could
  fire in the same direction on the same bar with conflicting risk/target structures.
- Lien Ch 7 ADX-trend filter (optional sweep axis): trade only when ADX(14) > 25 (trend regime),
  per Lien's regime-classification system. Off by default; on as a P3 axis variant.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- position size: V5 RISK_PERCENT / RISK_FIXED standard; Lien describes a "two-lot" trade in examples (PDF pp. 109-110)
- TP1 (50% close at +50 pips + BE move): hard rule
- TP2 (close remainder at +195 pips): fixed-pip target
- Friday Close: forced flat per V5 default (no waiver)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: bb_period
  default: 20
  sweep_range: [10, 14, 20, 26, 34]
- name: bb_inner_sigma
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25, 1.5]
- name: bb_outer_sigma                        # not load-bearing for entry but used in S02a co-regime suppression
  default: 2.0
  sweep_range: [1.75, 2.0, 2.25, 2.5]
- name: lookback_bars
  default: 2                                  # Lien: "the last two candles were below the first standard deviation Bollinger Band"
  sweep_range: [1, 2, 3, 4, 5]
- name: init_stop_pips
  default: 65                                 # Lien: "Initial stop at +65 pips"
  sweep_range: [30, 45, 50, 65, 80, 100]
- name: tp1_pips
  default: 50                                 # Lien: "Close half of position at +50 pips"
  sweep_range: [25, 35, 50, 65, 80]
- name: tp2_pips
  default: 195                                # Lien: "Close remainder of position at +195 pips"
  sweep_range: [100, 150, 195, 250, 300]
- name: target_mode
  default: fixed_pips                         # Lien primary (50 + 195 fixed)
  sweep_range: [fixed_pips, r_multiple_1_3, r_multiple_2_4, r_multiple_atr_scaled]
                                              # Tests whether fixed-pip targets are essential or
                                              # better expressed in R-multiple / ATR-scaled form
                                              # for cross-symbol generalization
```

P3.5 (CSR) axis: re-run on Darwinex FX cohort (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`) plus key crosses. **Note**: Lien's fixed-pip targets (65/50/195) are calibrated for major FX (~10000-pip USDJPY range, ~1.5-2.0 EURUSD-class moves on D1); cross-pair generalization tests whether fixed-pip is robust or whether ATR-scaled targets are necessary.

## 9. Author Claims (verbatim, with quote marks)

Trend-join framing, PDF p. 107:

> "Another way to use the double Bollinger Bands is to join a new uptrend or downtrend using a daily chart."

Long rule list, PDF p. 107:

> "Strategy Rules for Long Trade
> 1. Look for the currency pair to close above the first standard deviation Bollinger Band.
> 2. Check to see if the last two candles were below the first standard deviation Bollinger Band.
> 3. If so, buy at close of candle or 5pm NY Time.
> 4. Initial stop at +65 pips.
> 5. Close half of position at +50 pips; move stop on rest to initial entry price (breakeven).
> 6. Close remainder of position at +195 pips."

Short rule list, PDF p. 108:

> "Strategy Rules for Short Trade
> 1. Look for the currency pair to close below the first standard deviation Bollinger Band.
> 2. Check to see if the last two candles were above the first standard deviation Bollinger Band.
> 3. If so, sell at close of candle or 5pm NY Time.
> 4. Initial stop at +65 pips.
> 5. Close half of position at +50 pips; move stop on rest to initial entry price (breakeven).
> 6. Close remainder of position at +195 pips."

Worked example, PDF pp. 109-110 (USDJPY Long):

> "USDJPY closed above the first standard deviation Bollinger Band on May 18. We check to see if the last two candles were below the band and the rules are satisfied, allowing us to initiate a long trade at 119.97. The stop is placed 65 pips below at 119.32. The target for the first half of the position is 50 pips, or 120.47, and the target for the second half is 195 pips, or 121.92. The first profit target is reached 24 hours later (which is generally the case). When that happens, the stop is raised to 119.97, which is the initial entry or breakeven price. The trade is left on and the second profit target of +195 pips is reached six trading days after the trade was first initiated."

Worked example, PDF p. 110 (GBPUSD Short):

> "GBPUSD close below the first standard deviation Bollinger Band on March 4, so we check to see if the last two candles were above the band and the rules are satisfied, allowing us to initiate a short trade at 5pm when the currency pair is trading at 1.5263. The stop is placed 65 pips above at 1.5328. The target for the first half of the position is 50 pips, or 1.5213, and the target for the second half is 195 pips, or 1.5068. The trade floats for 24 hours, then GBPUSD drops sharply, hitting our first and second profit target on the very same day."

Strategy boundary statement, PDF p. 110:

> "We encourage you to lay the Bollinger Bands on your charts and look for more examples of these strategies in action. There are many ways to use the double Bollinger Bands for forex trading. Both of these strategies are for daily charts, but different strategies and rules can be used for intraday trading using the bands."

**Lien provides NO numeric performance claim** (no win-rate, profit-factor, max-drawdown, or annualized-return figure) for this strategy on its own — only the worked-example pip P&L on individual trades cited above (USDJPY: 50/195 pips on 6-day hold; GBPUSD: 50/195 pips on same-day hit). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; trend-join with TP1=0.77R partial + TP2=3.0R fat-tail typically 1.1-1.5 PF range when win rate is moderate; D1 trend-join is V4-archive-aligned in PF profile
expected_dd_pct: 20                           # rough estimate; D1 single-symbol trend-join strategies typically 15-25% DD in V4 archive
expected_trade_frequency: 15-30/year/symbol   # rough estimate; trend-onset signals are rarer than range-MR signals; Lien's 2-bar dwell precondition is restrictive
risk_class: medium                            # daily-bar single-symbol trend-join; not scalping, not gridding
gridding: false
scalping: false                               # D1 bars; not scalping
ml_required: false                            # threshold + pip arithmetic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (Bollinger-band crossing + 2-bar dwell precondition; deterministic NY-close fill)
- [x] No Machine Learning required
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (D1 bars)
- [x] Friday Close compatibility: typical hold 1-6 sessions; V5 default Friday-close applies cleanly. No waiver required.
- [x] Source citation is precise enough to reproduce (PDF pp. 107-108 rule lists + pp. 109-110 worked examples + p. 107 regime framing; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: sibling SRC04_S02a `lien-dbb-pick-tops` uses same indicator but OPPOSITE regime — co-regime-fire suppression at § 6 prevents conflict. SRC02 chan-bollinger-es uses ±2σ M5 ES futures — different mechanic and timeframe)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); regime gate at S02a co-regime-fire suppression; optional ADX>25 trend-regime filter (Lien Ch 7) as P3 sweep axis"
  trade_entry:
    used: true
    notes: "close back across inner-σ Bollinger band after K consecutive bars on opposite side; NY-close (5pm) fill; long/short symmetric"
  trade_management:
    used: true
    notes: "TP1 = +50 pips partial close + move-rest-to-BE; TP2 = +195 pips fixed-pip target (P3 sweep axis tests R-multiple and ATR-scaled variants)"
  trade_close:
    used: true
    notes: "exit on TP2 hit OR initial 65-pip stop OR BE-after-TP1"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # NOT load-bearing — typical 1-6 session hold; default V5 Friday-close applies cleanly. Listed for CTO completeness.
  - enhancement_doctrine                      # load-bearing on FIXED-PIP target structure (50/195); Lien's verbatim values are calibrated for major FX, but cross-pair generalization (CSR P3.5) may require ATR-scaled targets. P3 sweep `target_mode` axis tests this. Any post-PASS retune of pip values is enhancement_doctrine.
  - news_pause_default                        # standard V5 P8 news-blackout applies; Lien does not address news explicitly for this strategy.

at_risk_explanation: |
  friday_close — Daily-bar strategy with typical 1-6 session hold; weekend-gap risk
  rarely binds. Default V5 Friday-close applies cleanly. No waiver requested.

  enhancement_doctrine — Lien's verbatim 50/195 fixed-pip target structure is
  calibrated for major-FX volatility scale. The 195-pip second target is reached on a
  6-day hold in the USDJPY worked example — well within the 1-9 day window typical
  for D1 trend-join strategies. Cross-pair generalization (especially to CHF crosses
  and NZD pairs) may require ATR-scaled targets, which is the P3 `target_mode` axis.
  Once a live target structure is fixed, any subsequent retune is enhancement_doctrine.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Lien
  Ch 9 does not address news explicitly for this strategy; standard framework gating
  handles it.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + S02a co-regime-fire suppression
  entry: TBD                                  # BB(20, 1) + close-cross-back-across with K-bar dwell precondition; NY 5pm fill; ~80-150 LOC in MQL5
  management: TBD                             # 50% partial close at +50 pips + move-rest-to-BE; +195-pip fixed target
  close: TBD                                  # standard SL/TP plus optional R-multiple / ATR-scaled target variants
estimated_complexity: small                   # straightforward BB indicator + close-back-across trigger + standard partial/fixed-pip TM
estimated_test_runtime: 2-4h                  # P3 sweep ≈ 5×4×4×5×6×5×5×4 ≈ 24,000 cells; D1 bars; 10+ years; FX cohort — moderate
data_requirements: standard                   # D1 OHLC on Darwinex .DWX FX symbols; no external feeds
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | APPROVED (CEO interim, QUA-398) | this card |
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
- 2026-04-28: SRC04_S02b shares the proposed `bband-reclaim` flag with S02a. The flag covers
  BOTH the range-MR variant (S02a — outer-band-zone precondition) and the trend-join variant
  (S02b — N-bars-opposite-1σ precondition) via Card-level `precondition_mode` parameter.
  Canonical proposal is in `lien-dbb-pick-tops_card.md` § 16; this card incorporates by
  reference. Batch-ratify at SRC04 closeout per process 13 § Exits + DL-033 Rule 1.

- 2026-04-28: TM structure DIFFERS between S02a and S02b despite same indicator + same trigger
  bar. S02a uses 1R partial + 2R remainder (R-multiple, asymmetric stops 50 long / 30 short);
  S02b uses fixed-pip 50/195 partial-and-second-target with symmetric 65-pip stop. Lien's own
  rule lists are explicit on this — the difference is intentional, not a transcription error.
  P3 sweep `target_mode` axis tests whether the fixed-pip TM is robust across FX cohort or
  whether ATR-scaled R-multiple variants generalize better.

- 2026-04-28: The 195-pip second target with 65-pip initial stop is a 3.0R risk-reward profile —
  fat-tail dependent. The USDJPY worked example takes 6 trading days to hit TP2, suggesting
  realistic hold horizon is 1-9 days. P5/P5c stress on multi-day hold periods + P9b Friday-
  close edge case for the 6-day-hold scenario where TP2 may straddle a weekend.

- 2026-04-28: Co-regime-fire conflict with S02a — both cards COULD fire on the SAME bar in the
  SAME direction if the dwell window for S02a (outer-band zone) overlaps with the K-bar dwell
  for S02b (N consecutive bars below 1st-σ). § 6 documents the conflict-resolver: skip S02b
  when S02a would also fire on the same bar (S02a takes priority because its precondition is
  more restrictive — outer-band-zone is a STRICT subset of N-bars-below-1σ). CTO sanity-check
  at G0 + IMPL.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, daily bars, no
  multi-leg / multi-stock / cointegration architecture concerns. Cleanest architecture-fit so
  far in SRC04 family alongside S02a. Expected G0 yield CLEAN.
```
