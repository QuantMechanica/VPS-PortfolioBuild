# Strategy Card — Singh Commodity Correlation (D1, two-part: oil↔CADJPY + USDX↔XAUUSD)

## Card Header

```yaml
strategy_id: SRC06_S13
ea_id: TBD
slug: singh-cmd-corr
status: APPROVED
created: 2026-05-09
created_by: Research
last_updated: 2026-05-09

# Dual-gate verdict (sourced from QUA-1059 thread, run 9713f33a, 2026-05-09;
# canonical QB record at processes/strategy_cards/g1_approved_2026-05-09.md sec 4)
g0_issue: QUA-1059
g0_reviewed_at: 2026-05-09
g0_reviewer: "CEO (per QUA-1110 directive; QUA-1059 disposition 2026-05-09T11:21:53Z accepting QB G1 batch + treating QUA-1059 thread as g0 source-of-truth)"
g0_verdict: APPROVED
g1_issue: QUA-1059
g1_reviewed_at: 2026-05-09
g1_reviewer: "Quality-Business (R1-R4 reputable-source check, batch-wide PASS for SRC06)"
g1_verdict: APPROVED
g1_verdict_record: "processes/strategy_cards/g1_approved_2026-05-09.md (sec 4)"

strategy_type_flags: [position-trade, intermarket-correlation, breakout]
```
## Verdict Trail (QUA-1059)

QB G0 advisory + R1-R4 verdict rendered in QUA-1059 thread (run 9713f33a, 2026-05-09; QB comment 2026-05-09T11:02:19Z).
CEO G0 ratification recorded in QUA-1059 disposition (2026-05-09T11:21:53Z) and reaffirmed by QUA-1110 (this commit's authority).
Canonical QB record on origin/main: `processes/strategy_cards/g1_approved_2026-05-09.md` (sec 4), commit `07c2d2f9`.

### Source-level R1-R4 (batch-wide, applies to all 14 SRC06 cards)

- **R1 author identifiable**: PASS - Mario Singh, named author, Wiley-published (Wiley Trading series, ISBN 978-1-118-38551-7), CNBC-featured (Squawk Box / Capital Connection / Worldwide Exchange), founder FX1 Academy and Fullerton Markets.
- **R2 source verifiable**: PASS - ISBN confirmed; PDF on OWNER Google Drive (text-clean via pdftotext, 26.5 MB, 9187 lines); per-card page numbers cited verbatim from source.
- **R3 mechanical clarity**: PASS - each card has explicit Long/Short Trade Setup extracted verbatim from book's structured chapters; SL/TP/entry all rule-specified.
- **R4 no paywall bypass**: PASS - OWNER-supplied commercial PDF; no piracy.

Source verdict: **REPUTABLE** (T1 Tier B per `processes/qb_reputable_source_criteria.md`).
Author-claim band: **author-claimed**.

### Per-card verdict (verbatim QB excerpt from QUA-1059)

> **singh-cmd-corr (SRC06_S13 - D1, oil-CADJPY + USDX-XAUUSD intermarket correlation)**
> 
> APPROVED
> Edge mechanism: intermarket leading-indicator correlation - oil S/R breaks trigger CADJPY trades; USDX S/R breaks trigger XAUUSD trades; both correlations are practitioner-documented and include World Gold Council citation in source
> Portfolio fit: FIRST intermarket-correlation archetype in pipeline; XAUUSD commodity exposure adds diversity to forex-heavy portfolio; CADJPY adds minor-pair coverage
> Author claim: single-trade R-multiple illustrations; intermarket correlation thesis is non-statistical but institutionally verifiable
> 
> **P0 dependency flagged (not G0 blocker):** WTI.cash.DWX and USDX.f (or composite proxy) availability on Darwinex MT5 must be verified by Pipeline-Operator / CTO before P0 compilation. Instrument-availability check is a P0 concern, not an edge question.

### Flags carried forward

- P0 instrument-availability check (CTO/Pipeline-Operator): WTI.cash.DWX + USDX.f (or composite proxy) must be confirmed on Darwinex MT5 before P0 compilation. Not a G0 blocker.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 9 'Strategies for Position Traders' — Strategy 13: Commodity Correlation. Part 1 (oil → CAD/JPY) PDF pp. 199-204; Part 2 (Dollar Index → XAU/USD) PDF pp. 204-210; Strategy Roundup PDF pp. 209-210."
    quality_tier: B
    role: primary
```

## 2. Concept

Position-trader intermarket-correlation strategy with two variants under the same Strategy 13 banner: trades on a forex/commodity pair are TRIGGERED by S/R breaks on a DIFFERENT correlated leading-instrument's chart. Part 1 uses oil-price S/R breaks to trigger CAD/JPY trades (Canada is a top-10 oil exporter, Japan is a net oil importer; oil prices act as a leading indicator for CAD/JPY). Part 2 uses Dollar Index (USDX) S/R breaks to trigger XAU/USD (gold) trades, exploiting the well-known inverse correlation between USD and gold. The book quotes World Gold Council: "While holding all else equal, gold tends to rise when the US dollar falls" (PDF p. 205).

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                       # CAD/JPY (Part 1)
  - commodities                                 # XAU/USD (Part 2; spot gold)
timeframes:
  - D1
primary_target_symbols:
  - CADJPY                                      # Part 1 trade instrument
  - XAUUSD                                      # Part 2 trade instrument
leading_indicator_instruments:                  # NOT trade instruments, only used for signal generation
  - WTI.cash.DWX or WTI.b                       # Part 1: oil price
  - USDX.f or composite proxy                   # Part 2: Dollar Index
```

## 4. Entry Rules

```text
PART 1 — oil-CADJPY:

LONG CADJPY:
- on closed D1 bar of OIL chart
- identify resistance R_oil on oil's D1 chart (e.g., HighestHigh of last 30 bars + 2 prior touches)
- if oil's just-closed D1 Close > R_oil
- then on the OPENING of the next D1 candle, BUY CADJPY at market
- SL = Entry - 2 × ATR(14) of CADJPY at entry bar         # author specifies "twice the ATR of the previous candle"
- TP = Entry + 3 × (Entry - SL)                            # R:R 1:3 (author-fixed)

SHORT CADJPY:
- on closed D1 bar of OIL chart
- identify support S_oil
- if oil's just-closed D1 Close < S_oil
- then on the OPENING of next D1 candle, SELL CADJPY at market
- SL = Entry + 2 × ATR(14) of CADJPY
- TP = Entry - 3 × (Entry - SL)

PART 2 — USDX-XAUUSD (INVERSE):

LONG XAUUSD:
- on closed D1 bar of USDX chart
- identify support S_dxy
- if USDX just-closed D1 Close < S_dxy
- then on the OPENING of next D1 candle, BUY XAUUSD at market
- SL = Entry - 2 × ATR(14) of XAUUSD at entry bar
- TP = Entry + 3 × (Entry - SL)                            # R:R 1:3

SHORT XAUUSD:
- on closed D1 bar of USDX chart
- identify resistance R_dxy
- if USDX just-closed D1 Close > R_dxy
- then on the OPENING of next D1 candle, SELL XAUUSD at market
- SL = Entry + 2 × ATR(14) of XAUUSD
- TP = Entry - 3 × (Entry - SL)
```

## 5. Exit Rules

```text
- Single TP at R:R 1:3 (no multi-target structure for this strategy)
- SL handled by entry stop
- Friday Close enforced (V5 default; D1 trades may hold 1-4 weeks; forced Fri 21:00 close cuts winners)
```

## 6. Filters (No-Trade)

```text
- skip if leading-indicator's S/R was last established < 10 bars ago (immature)
- skip if D1 ATR(14) of trade instrument is below 30-day-average ATR by 30%+ (low-vol regime)
- skip if CADJPY (Part 1) or XAUUSD (Part 2) spread is > 2× normal (broker-side issue)
- skip during major central-bank announcements affecting USD or JPY (V5 default)
- Part 1: skip if oil chart shows recent extreme volatility (e.g., > 5% daily range last bar — geopolitical event risk)
- Part 2: skip if USDX < 75 or > 110 (extreme regime; correlation may break down)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol (trade instrument is CADJPY or XAUUSD, NOT the leading indicator)
- no partial close (single 1:3 target)
- no pyramiding, no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: leading_indicator_lookback_bars
  default: 30
  sweep_range: [20, 30, 50, 70, 100]
- name: leading_min_touches
  default: 2
  sweep_range: [2, 3]
- name: atr_period
  default: 14
  sweep_range: [10, 14, 18, 21]
- name: sl_atr_mult
  default: 2.0
  sweep_range: [1.0, 1.5, 2.0, 2.5, 3.0]
- name: tp_rr
  default: 3.0
  sweep_range: [2.0, 2.5, 3.0, 4.0, 5.0]
- name: variant
  default: "both"
  sweep_range: ["part1_oil_cadjpy", "part2_usdx_xauusd", "both"]
```

## 9. Author Claims (verbatim)

```text
PART 1 — oil-CADJPY:

"The risk for this trade is 154 pips, and the reward is 462 pips if the profit target is hit. The risk to reward ratio would be 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 202 — illustrative single-trade long example, CADJPY D1)

"The risk for this trade is 154 pips, and the reward is 462 pips if the profit target is hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 204 — illustrative single-trade short example, CADJPY D1)

"This strategy is especially suited to traders who would like to trade oil but prefer not to experience the volatility associated with it." (PDF p. 209)

PART 2 — USDX-XAUUSD:

"For much of 2011 and 2012, the correlation coefficient for gold and the dollar index was between -0.6 and -0.8. This means that if the dollar index was up, there was a 60% to 80% probability that gold prices would come down. In contrast, if the dollar index was down, there was a 60% to 80% probability that gold prices would go up." (PDF p. 204)

"The risk for this trade is 2,664 pips, and the reward is 7,992 pips if the profit target is hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 207 — illustrative single-trade long example, XAUUSD D1)

"The risk for this trade is 8,044 pips, and the reward is 24,132 pips if the profit target is hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 208 — illustrative single-trade short example, XAUUSD D1)

"While holding all else equal, gold tends to rise when the US dollar falls." (PDF p. 205, citing World Gold Council)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                               # 1:3 RR with sub-50% win rate
expected_dd_pct: TBD                           # 10-20%; correlation breakdown is the catastrophic loss path
expected_trade_frequency: 10-30/year per variant  # D1 leading-indicator S/R breaks ~1-3/month per leading instrument
risk_class: medium-high                        # XAU pip-value variation + oil geopolitical shocks
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (S/R as N-bar lookback + 2-touch confirmation; ATR-based SL is rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatibility: D1 trades; forced Fri close exits some winners early but strategy is still viable
- [x] Source citation precise: PDF pp. 199-210
- [x] No near-duplicate (Chan AT chan-at-vx-es-roll-mom is futures roll-yield, not leading-indicator-correlation; SRC04 has no XAU strategy)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "S/R maturity + ATR floor + spread guard + central-bank event blackout + variant-specific extreme-regime filters"
  trade_entry:
    used: true
    notes: "leading-indicator S/R close-break triggers next-day market entry on TRADE instrument"
  trade_management:
    used: false
    notes: "single 1:3 target; no BE move, no partial close, no trailing"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline
  - darwinex_native_data_only
at_risk_explanation: |
  dwx_suffix_discipline: leading-indicator instruments are oil (Part 1) and USDX (Part 2).
  Darwinex symbol availability check required at P1 build:
    - Oil: WTI.cash.DWX, WTI.b, or BRENT.cash equivalent — likely available
    - USDX: USDX.f or DX.f — broker-dependent, may not be in Darwinex universe
  If USDX is not natively available, Part 2 falls back to either
   (a) computing a USDX proxy from the 6 component pairs (EUR, JPY, GBP, CAD, SEK, CHF
       weighted per author p. 205) — fully mechanical synthesis, OR
   (b) being SKIP'd until OWNER ratifies non-Darwinex USDX feed integration.

  darwinex_native_data_only: same as above; the synthesized USDX proxy is Darwinex-native if
  computed from broker-fed component pairs. Pure external USDX feed would violate the rule.
  G0 review must verify symbol availability on Darwinex symbol list before P1 build.
```
