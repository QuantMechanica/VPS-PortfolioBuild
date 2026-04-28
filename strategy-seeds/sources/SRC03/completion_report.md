---
source_id: SRC03
parent_issue: QUA-298
authored_by: Research Agent
authored_on: 2026-04-28
status: drafted_pending_ceo_review
budget_summary:
  heartbeats_used: 6                          # h1 scaffold + survey; h2 S01/S02/S07; h3 S04/S05/S06; h4 S08/S09/S10; h5 S03/S11/S12/S14/S15 + S13 escalation; h6 sub-issues + completion_report
  cards_drafted: 14                           # S01-S12 + S14 + S15 (S13 ESCALATED as TM-module spec, NOT card)
  cards_passed_g0: 0                          # all DRAFT; awaiting CEO + Quality-Business review
  cards_killed_pre_p1: 0
  yield_ratio_cards_per_heartbeat: 2.33       # 14 / 6 — well above SRC02's 1.0 benchmark; Williams' rule-tightness drives high yield
  vs_src02_yield: 2.33 / 1.0 = 2.3× SRC02     # primarily Williams stacks ~15 patterns at rule-level density vs Chan's ~8 at chapter-level density
  extraction_rate: 14/15                      # 93% (vs SRC02's 8/13 = 62%, vs SRC01's 5/?)
---

# SRC03 Completion Report — Williams, *Long-Term Secrets to Short-Term Trading*

This report closes out SRC03 per `processes/13-strategy-research.md` § "Per-step responsibilities" Step 5 and § "Exits" (parent close → completion_report.md). All strategy-rich sections of the source PDF (pp. 1-46 text-clean range) have been surveyed; **14 Strategy Cards drafted** under V5 schema; **1 candidate ESCALATED** as TM-module specification rather than standalone card (S13 3-Bar Trailing Stop — exit-only mechanism per V5 template § 12 `trade_entry` requirement).

**SRC03 status from Research's side: extraction complete.** Awaiting CEO action on:
1. The 14 DRAFT cards (G0 review per DL-030 Class 2 Review-only execution policy) — sub-issues opened as [QUA-314](/QUA/issues/QUA-314) (`todo`) through [QUA-327](/QUA/issues/QUA-327) (`blocked`)
2. The 4 batched controlled-vocabulary additions per `strategy_type_flags.md` addition-process
3. The 1 calendar-cycle vocabulary refinement question (option a generalize vs option b siblings)
4. The S13 ESCALATE_NO_CARD ratification request
5. SRC04 dispatch per DL-032 Autonomy Waiver v3 (next source in `SOURCE_QUEUE.md`: Lien, *Day Trading and Swing Trading the Currency Market*, `proposed_order = 4`)

## 1. Source identity (recap)

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: PDF pp. 1-46 (text-clean range; pp. 47+ are OCR-degraded image-scanned content per source.md § 2)
    quality_tier: A
    role: primary
```

Source-text on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf` (1.8 MB; `pdftotext -layout` extraction-method verified working on PDF pp. 1-46). Citation note flagged in source.md § 1: the supplied PDF is structurally a Williams Inner Circle Workshop companion volume mirroring the *Long-Term Secrets* book content. No SRC03 candidate is blocked by the OCR-degraded section.

## 2. Strategy harvest

Fourteen Strategy Cards drafted; full set summarized in the table below. All fourteen carry `status: DRAFT` and are awaiting CEO + Quality-Business G0 review.

| Slot | Sub-issue | Card slug | Source location | Strategy character | Author-claim type | Primary `hard_rules_at_risk` |
|---|---|---|---|---|---|---|
| S01 | [QUA-314](/QUA/issues/QUA-314) (`todo`) | `williams-vol-bo` | PDF p. 25 + Bonds/T-Bonds context pp. 37, 43 | Volatility Breakout: stop-buy at next-day open + N% × prior-day range; default N=100, Bonds=30, T-Bonds-best-day=7 | Verbatim rule only; no per-strategy backtest published | `dwx_suffix_discipline`, `enhancement_doctrine` (N_PCT) |
| S02 | [QUA-315](/QUA/issues/QUA-315) (`blocked`) | `williams-monday-oops` | PDF pp. 35-36, 39-40 | Monday OOPS!: Friday-not-outside + Mon-open-below-Fri-TRUE-LOW → stop-buy at Friday's low; sub-rule B = Thurs/Fri-prior + last-2-days low | Bonds-Monday-buys composite (RELATED-BUT-DISTINCT trigger): $79,200 / 69% accuracy / 0.81 RR (PDF p. 31) | `dwx_suffix_discipline`, `kill_switch_coverage` (gap-fade fails on COVID/Lehman Mondays) |
| S03 | [QUA-316](/QUA/issues/QUA-316) (`blocked`) | `williams-hidden-oops` | PDF pp. 36, 40 | Hidden OOPS!: projected H/L formula `(H+L+C)/3 × 2`; multi-sub-rule structure (S&P A-D, Bonds A-C) | Verbatim rule only; no backtest | `enhancement_doctrine` (sub-rule selection) |
| S04 | [QUA-317](/QUA/issues/QUA-317) (`blocked`) | `williams-tdw-bias` | PDF pp. 32-33, 37-38 | TDW: open-buy on positive-bias weekdays + first-profitable-open exit | Bonds Mon 79% / Tue 76% / Fri 73% wins (1990-1999); Gold-filter boost to 84% / 82% / 81% | `news_pause_default` (FOMC Wed clustering may explain part of edge) |
| S05 | [QUA-318](/QUA/issues/QUA-318) (`blocked`) | `williams-tdom-bias` | PDF pp. 33, 37-38, 42-45 | TDOM: open-buy on positive-bias TDOMs; consolidates dozens of best-day-of-year tabulations as parameter-set | S&P TDOM 22 = 90% wins / $398 avg trade; T-Bonds best-day-by-month tables | `enhancement_doctrine` (parameter-set choice) |
| S06 | [QUA-319](/QUA/issues/QUA-319) (`blocked`) | `williams-holiday-trd` | PDF pp. 33-34, 41-42 | National Holiday Trades: 8 federal holidays × specific buy/sell open/close rules; Bonds and S&P maps disagree on direction (risk-on/risk-off-flip) | **Bonds 1978-1999: 84% wins, $52,200 net, $1,978 max DD, 4.31 PF, 1,048% ROA** — Williams: "among the best I have ever seen". S&P 1982-1999: 63% wins, $108,675 net, 2.66 PF | `dwx_suffix_discipline`, `enhancement_doctrine` |
| S07 | [QUA-320](/QUA/issues/QUA-320) (`blocked`) | `williams-smash-day` | PDF p. 19 | Smash Day: HH+HL+higher-C with close substantially below open → stop-buy at smash-bar's high; symmetric short verbatim | Verbatim rule only; no backtest | `enhancement_doctrine` (BODY_REJECTION_PCT — "substantially" qualitative) |
| S08 | [QUA-321](/QUA/issues/QUA-321) (`blocked`) | `williams-fakeout-day` | PDF p. 19 | Fake Out Day: HH+HL+lower-close-vs-prior → stop-buy at PRIOR bar's high | Verbatim rule only | (none load-bearing) |
| S09 | [QUA-322](/QUA/issues/QUA-322) (`blocked`) | `williams-naked-close` | PDF pp. 19-20 | Naked Close: close-outside-prior-bar → stop-buy at SAME bar's high. Joe-Stowell-attributed term | Verbatim rule only | `kill_switch_coverage` + P5c crisis-slice (event-driven cluster days) |
| S10 | [QUA-323](/QUA/issues/QUA-323) (`blocked`) | `williams-spec-trap` | PDF p. 20 | Specialist Trap: trend → 6-20 day box → wide-range breakout day → FADE at breakout-bar's opposite true extreme. Multi-bar pattern (~30 bars precondition) | Verbatim rule only; Williams' own candor "It may go on, or it may not" | `kill_switch_coverage` + P5c crisis-slice, `enhancement_doctrine` (THREE qualitative gaps: trend/box/breakout) |
| S11 | [QUA-324](/QUA/issues/QUA-324) (`blocked`) | `williams-8wk-box` | PDF pp. 23-25 | 8-Week Box Congestion Breakout: 8-week sideways → GO-WITH-breakout in pre-box-trend direction. Multi-attempt KEEP_SWINGING rule | Verbatim rule + Williams' informal 1/3-failure-rate guess (NOT a tested backtest number) | `friday_close` (multi-week hold), `kill_switch_coverage` (KEEP_SWINGING streak DD) |
| S12 | [QUA-325](/QUA/issues/QUA-325) (`blocked`) | `williams-18bar-ma` | PDF p. 17 + 14-symbol backtest pp. 17-18 | 18-Bar Two-Bar MA: two consecutive bars on same MA-side, no inside days, enter at 2-bar window's extreme. Symmetric long/short | **14 symbols POSITIVE-EXPECTANCY** over 10-year window (Copper 29.2k / SFranc 48.9k / BPound 132.9k / Corn 35.8k / Gold 83.4k / JYen 147.5k / Coffee 188.0k / HOil 30.2k / Beans 87.9k / Euro 30.5k / Sugar 96.0k / Wheat 41.5k / DMark 79.1k / TBonds 44.8k). **Broadest source-published validation in SRC03.** | `enhancement_doctrine` (MA_PERIOD = 18 acknowledged-arbitrary by Williams) |
| S14 | [QUA-326](/QUA/issues/QUA-326) (`blocked`) | `williams-cdc-pattern` | PDF pp. 35-36, 40 | CDC: 2-3 consecutive down closes + range-shrinking + 30-day-trend filter + optional Gold filter; entry at open + (H-C) | Verbatim rule only; Bonds aggregate 1990-1999 ($72,550 / 87% wins) covers ALL Bonds rules combined, not per-strategy | `enhancement_doctrine` (N_DOWN_CLOSES 2 vs 3) |
| S15 | [QUA-327](/QUA/issues/QUA-327) (`blocked`) | `williams-gap-dn-buy` | PDF p. 36 | Gap-Down-Close buy: today's high < yesterday's low (full gap) + open-rebound (sub-rule A) OR Gold-trend filter (sub-rule B) | Verbatim rule only | `kill_switch_coverage` + P5c crisis-slice (event-driven gap-down trends fail recovery thesis) |

**Total: 14 cards, 14 distinct mechanical structures.** Yield is Williams-typical — rule-tight short-term-trading textbook with ~15 patterns stacked across workshop + Bonds + S&P sections.

### S13 ESCALATION (NO CARD)

S13 `williams-3bar-exit` (3-Bar Trailing Stop, PDF p. 21) is Williams' "Amazing 3 Bar Entry/Exit Technique" — an exit/trailing-stop mechanism, not an entry trigger. Per V5 Strategy Card template § 12 (`trade_entry` module is required), an exit-only mechanism does not qualify as a standalone Strategy Card.

S13 is already documented as the DEFAULT trail mechanism in 7 of the 14 SRC03 cards (S01, S07, S08, S09, S10, S11, S12).

**Recommendation:** ESCALATE_NO_CARD — elevate to a TM-module specification (e.g., `framework/V5_TM_MODULES.md` or per-card § 5 reference). NOT a separate Strategy Card.

CEO ratification options:
- (a) Accept ESCALATE_NO_CARD — document as TM-module spec
- (b) Override — draft S13 with exit-only Strategy Card structure (would require `trade_entry: not_applicable` extension to template § 12)

### Strategy-type-flag distribution (across the 14 drafted cards)

| Flag | S01 | S02 | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S10 | S11 | S12 | S14 | S15 | Count |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| atr-hard-stop | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | | ✓ | ✓ | 12 |
| symmetric-long-short | ✓ | ✓ | | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | | 9 |
| friday-close-flatten | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 14 |
| long-only | | | ✓ | ✓ | ✓ | | | | | | | | ✓ | ✓ | 5 |
| trend-filter-ma | | | | | | | | | | ✓ | | ✓ | ✓ | ✓ | 4 |
| signal-reversal-exit | | | | ✓ | ✓ | ✓ | | | | | | | | | 3 |
| intraday-day-of-month | | | ✓ | ✓ | ✓ | ✓ | | | | | | | | | 4 |
| narrow-range-breakout | | | | | | | | | | | ✓ | | | | 1 |
| n-period-max-continuation | | | | | | | | | | | | ✓ | | | 1 |
| n-period-min-reversion | | | | | | | | | | | | | ✓ | ✓ | 2 |
| atr-trailing-stop | | | | | | | | | | | ✓ | | | | 1 |
| **proposed:** vol-expansion-breakout | ✓ | | | | | | | | | | | | ✓ | ✓ | 3 |
| **proposed:** gap-fade-stop-entry | | ✓ | ✓ | | | | | | | | | | | | 2 |
| **proposed:** rejection-bar-stop-entry | | | | | | | ✓ | ✓ | ✓ | | | | | | 3 |
| **proposed:** failed-breakout-fade | | | | | | | | | | ✓ | | | | | 1 |
| **proposed:** intraday-day-of-week | | | | ✓ | | | | | | | | | | | 1 |
| **proposed:** holiday-anchored-bias | | | | | | ✓ | | | | | | | | | 1 |

### Direction-class diversity (cross-source)

V5 corpus across SRC01 + SRC02 + SRC03 now spans:

| Class | SRC01 (Davey) | SRC02 (Chan) | SRC03 (Williams) | Total |
|---|---|---|---|---|
| Trend-following / momentum / breakout | 1 (worldcup) | 0 | 3 (S01 vol-bo, S11 8wk-box, S12 18bar-ma) | 4 |
| Mean-reversion (single-bar) | 4 (Davey RSI/Bollinger family) | 1 (S02 chan-bollinger-es) | 4 (S07 Smash, S08 Fakeout, S09 Naked Close, S14 CDC) | 9 |
| Calendar-bias | 0 | 0 | 3 (S04 TDW, S05 TDOM, S06 Holiday) | 3 |
| Gap-fade reversal | 0 | 0 | 3 (S02 Monday OOPS!, S03 Hidden OOPS!, S15 Gap-Down) | 3 |
| Failed-breakout fade | 0 | 0 | 1 (S10 Spec Trap) | 1 |
| Cointegration / pair-trade | 0 | 1 (S01 chan-pairs-stat-arb) | 0 | 1 |
| Cross-sectional / multi-stock | 0 | 4 (S03/S04/S05/S06 chan multi-stock) | 0 | 4 |
| Annual calendar trade | 0 | 2 (S07/S08 chan seasonals) | 0 | 2 |
| **TOTAL** | 5 | 8 | 14 | 27 |

**SRC03 broadens V5's direction-class coverage significantly:** introduces 4 new direction-classes (calendar-bias, gap-fade-reversal, failed-breakout-fade, single-symbol breakout). Combined with SRC01+SRC02, V5 corpus now has 8 direction-classes, well-diversified.

**Diversity-bias check (per SOURCE_QUEUE):** No 3+ consecutive same-class trigger fires. Williams brings net-new strategy classes; SRC04 (Lien) is acceptable next per `SOURCE_QUEUE.md` `proposed_order = 4`.

### V5-architecture-fit profile

A useful angle for CEO + CTO ratification of the SRC03 set:

| Architecture-fit | Cards | Recommended G0 path |
|---|---|---|
| **Clean (single-symbol Darwinex CFD or spot FX)** | S01 vol-bo, S02 monday-oops, S03 hidden-oops, S04 tdw, S05 tdom, S06 holiday, S07 smash, S08 fakeout, S09 naked-close, S10 spec-trap, S11 8wk-box, S12 18bar-ma, S14 cdc, S15 gap-dn-buy | **ALL 14 CARDS — single-symbol architecture-clean.** Standard advance through P-pipeline; primary risks per individual card. |
| Architecture-incompatible | (none) | n/a |

**SRC03 yields 14/14 = 100% architecture-clean cards.** Best architecture-fit profile of any source so far (vs SRC02's 4/8 = 50% architecture-clean rate; SRC02 had 4 cards architecturally incompatible with the Darwinex single-symbol stack). Confirms SRC03 source.md § 3 prediction that Williams' single-symbol focus produces a higher G0 yield than SRC02 Chan multi-stock.

## 3. SKIPs (sections classified as no-card per Rule 1)

**No SKIPs in SRC03.** All 15 surveyed candidates either:
- Drafted as Strategy Cards (14 cards)
- Escalated as TM-module spec (S13 — exit-only mechanism)

This is the highest extraction rate in the source-queue so far (SRC01: 5/?; SRC02: 8/13 = 62%; SRC03: 14/15 = 93%). Williams' textbook is genuinely strategy-rich with no methodology-only or hard-rule-failing sections in the text-clean range.

**Workshop §§ 1-8 (PDF pp. 1-14)** — fundamental setup tools (WVI, COT, DMI/ADX, Pinch/Paunch, Sentiment, Seasonal, OI, Spreads) — were consciously NOT extracted as Strategy Cards per source.md § 6. These are FILTER conditions, not entry triggers; integrated into per-card § 6 Filters where they bind to a specific entry. Per DL-033 Rule 1, FILTERS are documented per-card, not as separate cards.

## 4. Methodology cross-walk — Williams vs SRC01 Davey + SRC02 Chan

Three sources surveyed; methodology comparison:

| Aspect | SRC01 Davey | SRC02 Chan | SRC03 Williams |
|---|---|---|---|
| Source character | Process textbook | Methodology + small set of named demos | Strategy textbook + setup tools |
| Strategy density | ~5 cards over ~14 chapters | ~8 cards over 8 chapters | ~14 cards over ~46 PDF pages (rule-tight) |
| Backtest discipline | Per-strategy backtests with walk-forward | Per-strategy MATLAB code references; Sharpe pre/post-cost | Aggregate backtests (Bonds 21-year backtest; 14-symbol cross-validation); per-strategy verbatim rules without per-strategy backtests on most |
| Author candor on failure modes | Davey Ch 13 walk-forward FAILURE example (-$9,938 cumulative OOS) | Chan deliberate-failure examples × 3 (Bollinger ES, KhandaniLo open-bar, PCA factor) | Williams "It may go on, or it may not" (S10) + "accuracy is low and it is replete with whipsaws" (S12) — candid acknowledgment but no published per-strategy failure example |
| V5-architecture concerns | Low (most Davey cards single-symbol) | High (4/8 multi-stock incompatible) | Low (14/14 architecture-clean) |

**Cross-source methodology delta for V5 P-pipeline:**

- SRC01 Davey contributed walk-forward + Monte Carlo + live-trading-validation methodology (now folded into V5 P4/P6/P10 standards)
- SRC02 Chan contributed transaction-cost stress-testing (P9b Operational Readiness load-bearing) + survivorship-bias quantification (P3.5 CSR principle) + cointegration-vs-correlation disambiguation (CTO sanity-check at P3)
- **SRC03 Williams contributes:** (a) `enhancement_doctrine` discipline by example (Williams' multiple cited values for N_PCT show how a single rule can have multiple "live" parameter values, requiring strict enhancement-vs-fresh-strategy gate); (b) cross-symbol POSITIVE-validation pattern (S12 14-symbol backtest as the model for any "this works on many markets" claim — pipeline P3.5 CSR); (c) calendar-bias as legitimate strategy class (SRC01/SRC02 had none)

## 5. Vocabulary additions surfaced (batch-proposed for CEO + CTO)

Per `strategy_type_flags.md` addition-process: **4 entry-side gaps + 1 calendar-cycle refinement question** surfaced from SRC03.

### A. Four new entry-side flag proposals

```yaml
- name: vol-expansion-breakout
  proposed_at_cards: [S01, S14, S15]
  definition: "Entry triggered by stop-buy/sell at next bar's open ± N% × range(prior_bar). The N% multiplier is the load-bearing parameter; entry fires on price extension beyond the prior bar's range scaled by N%."
  v4_evidence: "No V4 SM_XXX EA implements this exactly per `strategy_type_flags.md` Mining-provenance table."
  disambiguation_from:
    - "narrow-range-breakout (which requires explicit range-CONTRACTION precondition; vol-expansion-breakout has no NR precondition)"
    - "donchian-breakout (which uses N-bar rolling extreme; vol-expansion-breakout uses single prior-bar range scaled by N%)"

- name: gap-fade-stop-entry
  proposed_at_cards: [S02, S03]
  definition: "Entry triggered by gap THROUGH a calendar-pattern reference price (actual prior-bar extreme, or projected H/L formula); stop-buy/sell placed BACK at the reference price, fading the gap. Calendar-pattern conditional (typically Monday after Friday close)."
  v4_evidence: "No V4 SM_XXX EA per Mining-provenance table."
  disambiguation_from:
    - "n-period-min-reversion (fires at next-bar open without a gap-through condition; gap-fade-stop-entry REQUIRES the gap through the reference)"
    - "intraday-day-of-month (calendar-day-of-month bias as ENTRY trigger; gap-fade is calendar-FILTERED but the gap-through is the entry)"

- name: rejection-bar-stop-entry
  proposed_at_cards: [S07, S08, S09]
  definition: "Entry triggered by candle-shape rejection bar (close substantially against open OR close-outside-prior-bar OR close-direction-failure-vs-prior-close); stop-buy/sell at fixed reference extreme (same-bar or prior-bar). Wide-range bar requirement; not NR contraction."
  v4_evidence: "No V4 SM_XXX EA per Mining-provenance table."
  disambiguation_from:
    - "narrow-range-breakout (rejection-bar-stop-entry requires WIDE-RANGE rejection bar, not NR contraction)"
    - "gap-fade-stop-entry (rejection-bar requires bar-internal close-vs-X structure; gap-fade requires gap-through reference)"

- name: failed-breakout-fade
  proposed_at_cards: [S10]
  definition: "Entry triggered by range-breakout that FAILS (price reverses back through the range); contrarian fade entry at OPPOSITE extreme of the breakout bar. Multi-bar precondition (trend + box + breakout day)."
  v4_evidence: "No V4 SM_XXX EA per Mining-provenance table."
  disambiguation_from:
    - "narrow-range-breakout (which is GO-WITH-breakout, NOT fade)"
    - "gap-fade-stop-entry (failed-breakout-fade is range-bound, not gap-driven)"
```

### B. Calendar-cycle vocabulary refinement (NOT a flag addition; a flag-set-architecture question)

The existing `intraday-day-of-month` flag definition is **monthly-cycle-only by definition** (V4 example: SM_124 Gotobi = 5/10/15/20/25 dates). Williams' SRC03 family uses three calendar cadences:
- S04 weekly TDW (`intraday-day-of-week` candidate)
- S05 monthly TDOM (fits existing flag — V4 Gotobi precedent)
- S06 yearly Holiday-anchored (`holiday-anchored-bias` candidate)

**Two ratification options for CEO + CTO:**

- **(a) Generalize:** rename `intraday-day-of-month` → `calendar-cycle-bias` with cycle-period as parameter (weekly / monthly / yearly). Pro: single flag covers all three Williams cadences cleanly. Con: changes existing flag name; risks downstream label drift.
- **(b) Add siblings:** keep `intraday-day-of-month` as-is; add `intraday-day-of-week` (S04) and `holiday-anchored-bias` (S06) as siblings. Pro: no rename; additive; clearer per-card flag selection. Con: 3 flags where 1 generalized flag could cover.

**Research recommendation: option (b) for SRC03 fast-path.** Avoids breaking the V4 Gotobi precedent labeling; additive.

## 6. Yield ratio + budget review

```yaml
heartbeats_used: 6                     # h1 scaffold; h2-h5 cards; h6 closeout
cards_drafted: 14
cards_passed_g0: 0                      # awaiting CEO review
cards_killed_pre_p1: 0
yield_ratio: 14/6 = 2.33               # cards-per-heartbeat
benchmark_vs_src02: 2.33 / 1.0 = 2.3×    # SRC03 yield is 130% above SRC02
benchmark_vs_src01: 2.33 / 0.71 = 3.3×   # SRC03 yield is 230% above SRC01
extraction_rate: 14 / 15 = 93%          # vs SRC02 8/13 = 62%; vs SRC01 ~ ?/14 chapters
```

**Yield-ratio drivers (Williams-vs-Chan analysis):**

1. Williams' textbook is **rule-tight** — each pattern is stated in 1-3 sentences vs Chan's chapter-length methodology demos
2. SRC03 architecture-clean rate = 100% (no multi-stock decomposition required) — vs SRC02's 50% (4/8 multi-stock incompatible)
3. Williams' **15-pattern density** within ~46 text-clean PDF pages = high-density harvest
4. Cards-vs-fold decisions retained DISTINCT for ALL candidate-pair questions (per Rule 1) — no collapsing of similar patterns into single cards

**Counter-factors (where yield could have been higher):**

1. S13 escalation reduced cards from 15 → 14 (one structural ESCALATE)
2. PDF pp. 47+ OCR-degraded — could conceivably contain additional patterns (low probability per source.md § 2 risk assessment)

## 7. Recommendation: deeper mining + next source

### Deeper SRC03 mining

**Recommendation: NO further SRC03 work.** The text-clean range (PDF pp. 1-46) has been exhaustively surveyed; the remaining OCR-degraded pages are unlikely to contain additional distinct mechanical strategies (per Williams' textbook structure: pp. 1-46 is the rule content; pp. 47+ are chart examples + handwritten annotations).

If pipeline P2-P9 reveals that Williams' patterns generalize beyond the 14 drafted cards in unexpected directions (e.g., Williams cross-references the 1974 *Sure Thing Commodity Trading* book for seasonal trades on PDF p. 9), Research can re-open SRC03 for a follow-up pass at CEO discretion.

### Next source

**Recommendation: dispatch SRC04 against Lien, *Day Trading and Swing Trading the Currency Market*** (`SOURCE_QUEUE.md` `proposed_order = 4`, T1 Tier A).

Rationale:
1. **Diversity-bias check passes** — Lien is a forex-specialist textbook; Williams was futures-heavy, Chan was equity-heavy, Davey was process-heavy. Forex single-symbol strategies are net-new to V5 corpus.
2. **No 3+ consecutive same-class trigger fires** — SRC03 was reversal-heavy (8/14 cards rejection-fade); SRC04 will likely shift toward currency-specific patterns (carry, interest-rate-driven flows, session-overlap dynamics).
3. **`proposed_order = 4` per OWNER-ratified queue** — CEO autonomous ordering per DL-032; no override needed.

Per DL-029 sequential workflow, no SRC04 work begins until SRC03 sub-issues complete G0 review (or are explicitly unblocked by CEO).

## 8. Open CEO actions (closing checklist)

- [ ] **G0 review** of 14 SRC03 cards under [QUA-314](/QUA/issues/QUA-314) (`todo`) through [QUA-327](/QUA/issues/QUA-327) (`blocked`); first card unblocks the rest sequentially per DL-029
- [ ] **Vocabulary batch-proposal ratification** — 4 entry-side flag additions + 1 calendar-cycle refinement option (a vs b)
- [ ] **S13 ESCALATE_NO_CARD ratification** — accept as TM-module spec or override with custom exit-only card structure
- [ ] **SRC04 dispatch** — open Lien parent issue per `SOURCE_QUEUE.md` `proposed_order = 4` after SRC03 sub-issues progress
- [ ] **(optional) S11 KEEP_SWINGING multi-attempt** ratification — confirm re-entry-after-stop-out semantics qualify under standard one-position-per-direction (NOT gridding under `grid_1pct_cap`)

## 9. Cross-references

- Parent issue: [QUA-298](/QUA/issues/QUA-298)
- Sub-issues: [QUA-314](/QUA/issues/QUA-314) (S01 `todo`) through [QUA-327](/QUA/issues/QUA-327) (S15 `blocked`)
- Predecessor sources: [QUA-191](/QUA/issues/QUA-191) (SRC01 Davey), [QUA-275](/QUA/issues/QUA-275) (SRC02 Chan)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md` (T1 Tier A row 3)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-030 (Class 2 Review-only execution policy)
- DL-032 (CEO Autonomy Waiver v3 — autonomous source-queue ordering)
- DL-033 (extraction-discipline / Rule 1)
- QUA-243 (card-template filename convention update)
- QUA-297 (OWNER speed-up directive parent — SRC03 spawned in parallel with SRC02 closeout)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`

— Research, SRC03 closeout authored. Awaiting CEO actions per § 8 checklist.
