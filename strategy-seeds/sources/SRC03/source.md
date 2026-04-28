---
source_id: SRC03
tier: T1                                      # curated local PDF (OWNER-supplied)
parent_issue: QUA-298
status: scaffolded_pending_extraction
authored-by: Research Agent
last-updated: 2026-04-28
budget_tracking:
  heartbeats_used: 3                          # h1 scaffold + survey-pass; h2 first-pass S01+S02+S07; h3 second-pass calendar-bias S04+S05+S06
  cards_drafted: 6                            # S01, S02, S04, S05, S06, S07 drafted to DRAFT; sub-issues created when first/second-pass cards stabilize
  cards_passed_g0: 0
  cards_killed_pre_p1: 0
extraction_pass_status: second_pass_partial   # 15 candidates identified from text pp. 1-46; 6/15 cards drafted (S01, S02, S04, S05, S06, S07); 9 candidates remain (S03 Hidden OOPS!, S08-S15 reversal/composite/variant family)
completion_report: pending                    # authored after all SRC03_S* sub-issues close

---

# SRC03 — Larry R. Williams, *Long-Term Secrets to Short-Term Trading*

QUA-298 is the parent SRC issue per [DL-032](/QUA/issues/QUA-273) (CEO Autonomy Waiver v3 — autonomous source-queue ordering and per-batch source approval) and Process 13 (one-source-at-a-time, child sub-issue per strategy). Source rank: T1 Tier A, `proposed_order = 3` per [`SOURCE_QUEUE.md`](../SOURCE_QUEUE.md). Opened 2026-04-28 in parallel with SRC02 (Chan, [QUA-275](/QUA/issues/QUA-275)) closeout per OWNER speed-up directive in [QUA-297](/QUA/issues/QUA-297).

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: TBD                              # populated per-card with section + PDF page on extraction
    quality_tier: A                            # peer-known practitioner; 1987 World Cup Championship of Futures Trading winner ($10K → $1.1M in 12 months); 35+ years industry experience; widely-cited author of multiple short-term trading books
    role: primary
```

**Citation note.** The PDF supplied at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf` is structurally a Williams **Inner Circle Workshop** companion volume that mirrors the *Long-Term Secrets* book content (TDW, TDOM, OOPS!, Volatility Breakouts, holiday biases, money-management formula). The verbatim author claims will reflect what is in this PDF; per-card citations cite section-headings + PDF page numbers (printed-book page numbers are inconsistent due to mixed workshop / book content). Where the source self-references published works ("My 1974 book *Sure Thing Commodity Trading*" — workshop p. 9; "as discussed earlier in this presentation" — p. 21), Research preserves Williams' framing without paraphrase.

## 2. Source-text status

```yaml
source_text_path: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Long-Term Secrets to Short-Term - Larry R. Williams.pdf"
file_size_bytes: 1861402                       # 1.8 MB
file_modified: 2024-07-17                      # per ls -la mtime
text_extraction_method: poppler `pdftotext -layout` (verified text-clean on PDF pp. 1-46; pp. 47+ are OCR-degraded image-scanned content)
status: on_disk_partial_text
```

**Extraction limitation flagged.** `pdftotext -layout` returns text-clean output for PDF pages 1-46 (workshop sections 1-8 + Inside-Circle Short-Term Trading approach + Bonds/S&P TDW/TDOM/Holiday/OOPS rules). Pages 47+ are image-scanned with garbled OCR (handwritten chart annotations, illegible). The strategy-rich short-term-mechanical content is fully captured in the text-clean range; deeper-page content (chart examples, additional commodity-specific tables) is not. **No SRC03 candidate is blocked by this**; the rules and entry/exit signals for all 15 candidates below are extractable from pp. 1-46.

If the OCR-degraded section turns out to contain a distinct mechanical strategy at extraction time, Research will document the extraction barrier on the relevant card and either (a) re-OCR with `pdftotext -raw` + `tesseract` fallback, or (b) escalate to CEO with a SKIP / partial-extract verdict.

Raw text excerpts archived under `raw/`:

- `raw/toc_pp1-14.txt` — Inner Circle Workshop sections 1-8 (WVI, COT, DMI/ADX, Pinch/Paunch, Sentiment, Seasonal, Open Interest, Spreads)
- `raw/probe_pp15-30.txt` — Williams Entry Techniques, 18-Bar MA, Pro-Go, Failure Day Family (Fakeout / Smash / Naked Close / Specialist Trap), 8-Week Box, Volatility Breakout, Stochastic, Money Management
- `raw/probe_pp30-60.txt` — Inside Circle Short-Term Trading Approach: Bonds TDW/TDOM/Holidays/Power-of-Gold; Bonds Specific Patterns (Consecutive Down Closes, Gap Down, Friday Set-Up Trades for Monday, Hidden OOPS!); S&P 500 Trading Rules (Monday OOPS!, Hidden OOPS!, Consecutive Down Closes, Monday-Only Trades, Short-Term Sell Patterns); S&P Holiday Trades; Best/Worst Buy and Sell Days of the Year
- `raw/full_text.txt` — full PDF text dump (113 KB; effectively pp. 1-46 content; pp. 47+ empty / garbled)

## 3. Why Williams #3 (per QUA-298)

Per QUA-298 description and `SOURCE_QUEUE.md` § "Why this ordering":

> Williams, *Long-Term Secrets to Short-Term Trading* — Tier A, well-known practitioner with classic mechanical strategies (Volatility Breakout, OOPS pattern, etc.).

Three role-specific reasons reinforce the slot:

1. **Class diversity vs SRC01 + SRC02.** SRC01 Davey was process-textbook (4/5 mean-reversion-flagged). SRC02 Chan covered statistical-arbitrage / cointegration / factor-models (8/8 multi-symbol or stat-rigor demos). Williams brings **classic single-symbol price-action breakout + day-trade timing**: volatility breakouts, calendar-day biases (TDW/TDOM/holidays), and short-term reversal patterns (OOPS! / Smash / Specialist Trap). This is a third distinct strategy-class lineage. No 3+ consecutive same-class trigger fires on the SOURCE_QUEUE diversity-bias rule.
2. **V5-architecture compatibility profile.** Unlike SRC02 Chan (where 4/8 cards were V5-architecture-incompatible due to multi-stock universe requirements), Williams' strategies are predominantly **single-symbol** — futures contracts on US Bonds and S&P 500 (mappable to `US500.DWX` and bond-equivalent CFDs), and per the source's own framing: "The astute trader will focus on seasonal indications and look for confirmation from trend indications" applies on any liquid futures or spot symbol. Expected G0 architecture-fit yield is HIGH compared to SRC02.
3. **Daily-bar timeframe = M15+ V5 fit.** Williams' rules are stated on daily bars; rules reference "open" / "close" / "yesterday's high" / "Friday's range" — all available on M15+ in the V5 framework. No HFT, no scalping (the closest is M5-bar Volatility Breakout which Williams does not advocate; his framing is daily). News-compliance compatible (mechanical breakout / day-trade rules with no economic-event dependency).

## 4. Expected strategy count

Williams is **strategy-rich and rules-tight** by design — unlike Davey (process textbook) or Chan (methodology + small set of named demos), Williams stacks ~15 distinct mechanical patterns across the workshop and short-term-trading approach. Per **DL-033 Rule 1** (every distinct mechanical strategy that passes V5 hard rules gets a card; pipeline G0 → P10 is the filter, not Research's prior beliefs), Research extracts cards for each.

```yaml
expected_strategy_count: 10-15                # high yield expected; survey-pass identified 15 candidates (§ 6)
expected_chapter_count: 8                     # workshop sections 1-8 + Short-Term Trading Approach (Bonds + S&P 500) + Money Management
strategy_locations:                            # validated at survey-pass; finalized at extraction
  - "PDF p. 25 — Volatility Breakout (open + 100% prior day range, 'when market is primed')"
  - "PDF p. 25 + multi-section context — Williams' single-symbol calling card; rules reside in 'Entry Techniques' section"
  - "PDF pp. 35-36, 39-40 — Monday OOPS! (Friday up-close → Monday opens below Friday TRUE LOW → buy at Friday low on stop)"
  - "PDF pp. 36, 40 — Hidden OOPS! (projected high/low formula = (H+L+C)/3 *2 − H = projected low; − L = projected high)"
  - "PDF pp. 32-33, 37-38 — TDW (Trade Day of Week) bias for Bonds and S&P (Mon/Tue best, Wed/Thu worst on Bonds)"
  - "PDF pp. 33, 37-38 — TDOM (Trade Day of Month) bias for Bonds and S&P (specific days with 60-90% win rates)"
  - "PDF pp. 33-34, 41-42 — National Holiday Trades (8 holidays, specific buy/sell open/close on N-th TD before/after)"
  - "PDF p. 19 — Smash Day pattern (higher H/L/C BUT close substantially below open → buy on takeout)"
  - "PDF p. 19 — Fake Out Day (higher H, higher L, lower C → buy at prior day's high)"
  - "PDF p. 20 — Naked Close Days (close below prior day's low → buy at high of that day)"
  - "PDF p. 20 — Specialist Trap (uptrend → 6-20 day box → big breakout day → SELL at true low of breakout day; reversed for buy)"
  - "PDF pp. 24-25 — 8-Week Box Congestion Breakout (8-week sideways range → buy/sell on breakout in direction of major trend coming in)"
  - "PDF p. 17 — 18-Bar Two-Bar MA Entry (two consecutive lows above 18-bar MA, no inside days, enter at highest high)"
  - "PDF p. 21 — 3-Bar Trailing Stop / Exit (after run-away move starts: lowest true low of 3 non-inside-day window, exit at penetration)"
  - "PDF pp. 35-36, 40 — Consecutive Down Closes pattern (2-3 down closes + range-shrinking filter + Gold filter; buy at open + (H-C))"
  - "PDF p. 36 — Gap-Down-Close pattern (today H < yesterday L + Gold filter; buy at open + (H-C))"

notes: |
  Williams' style: dense-rule short-term-trading approach with optional fundamental "set-up" filters (WVI / COT / Sentiment / Seasonal). The setup tools (workshop §§ 1-8, PDF pp. 1-14) are FILTERS, not entry strategies — they qualify the market regime but do not trigger trades on their own. Per DL-033 Rule 1, FILTERS are documented per-card under § 6 (Filters / No-Trade module) but do NOT each become a separate Strategy Card.

  The DOZENS of "best buy/sell days of the year" and "TDW + TDOM combinations" tabulated in pp. 38-46 represent SAME mechanical class with different parameter values. They consolidate into ONE TDOM-bias Strategy Card with the specific days as parameters_to_test, not 200+ cards.

  Some entry patterns are tightly variant (Monday OOPS! vs Hidden OOPS! vs Friday Set-Up rules A-E). Research's extraction-time decision per pattern: distinct mechanical entry → distinct card; minor parameter variant → same card with parameter sweep. Default classification listed in § 6 may be revised at extraction.

  Rule 1 binds: every distinct mechanical strategy that passes V5 hard rules gets a card. Pipeline gates do the filtering. Research extracts; CEO + Quality-Business + CTO ratify per process 13.
```

## 5. v0 filter rules applied to this source

Inherited from QUA-298 acceptance criteria + DL-029 strategy-research workflow + the v5_flags conventions in `SOURCE_QUEUE.md`:

- **Mechanical only** — Williams' rules are hard-coded entry conditions (TRUE LOW, projected high/low formulas, day-of-week numeric biases, N-bar MA crossings). All mechanical and EasyLanguage-implementable per the source's own backtest-output dumps (PDF pp. 31, 37, 41, 44 show printed PerfReport-style stats from a TradeStation-class testing engine).
- **No Machine Learning** — Williams predates and explicitly avoids ML; no neural-net / gradient-boost / random-forest construction in the source. `EA_ML_FORBIDDEN` does NOT bind.
- **`.DWX` suffix discipline** — Williams' universe is US Bonds futures + S&P 500 futures + individual commodities (Gold, Wheat, Cotton, Copper, etc.) + currency futures. V5 deployment maps to Darwinex spot FX / indices / metals (`EURUSD.DWX`, `GOLD.DWX`, `US500.DWX`). Single-symbol = clean architecture-fit (unlike SRC02 Chan multi-stock cards). Cards from this source raise `dwx_suffix_discipline` in `hard_rules_at_risk` only if the strategy is bond-specific in a way that doesn't translate to indices/FX (TDW/TDOM patterns may be S&P-specific; TBD at extraction).
- **`darwinex_native_data_only` Hard Rule** — Williams' filters reference Gold-vs-Bonds correlation + COT data. **COT data is NOT in Darwinex-native feeds** — flag `darwinex_native_data_only` for any card that requires COT-Index filtering. Gold-as-filter for Bonds-trading is solvable (Darwinex has GOLD.DWX). Per-card flagging at extraction.
- **Magic-formula registry compatible** — Williams' strategies are all single-position-at-a-time at the symbol level. Compatible with `one_position_per_magic_symbol`.
- **News-compliance compatible** — TDW/TDOM/Holiday biases are **calendar-driven**, not news-driven. P8 News Impact handles standard high-impact-news pauses. The Holiday strategy may need explicit definition of "holiday windows" — TBD at extraction.
- **Friday Close compatibility** — Williams' rules typically exit on first profitable open + bail-out stop (max ~5-day hold). Most cards Friday-close-compatible. The Holiday cards may straddle weekends (entry "TD before holiday", exit days later) — `friday_close` flag at extraction per holiday.
- **`scalping_p5b_latency`** — None of the 15 candidates are scalping-class (all daily-bar or open-of-day execution). Flag does not bind.

## 6. Sub-issue queue (per QUA-298 process-13 setup)

Per QUA-298 acceptance: "Each candidate that survives V5 v0_filter becomes a SRC03_S* child card and is opened with CEO G0 review." Slot table populated as cards are drafted. Slug pattern: `williams-<topic>` per QUA-298. Filenames follow `_TEMPLATE.md` (`<slug>_card.md`).

| Slot | Strategy slug | Card path | Sub-issue | Status | Source location | Notes |
|---|---|---|---|---|---|---|
| S01 | `williams-vol-bo` | `strategy-seeds/cards/williams-vol-bo_card.md` | TBD | DRAFT (2026-04-28) | PDF p. 25 + chapter-context | Volatility Breakout: open + N% × prior-day range (default N=100, Bonds=30, T-Bonds-best-day=7). Single-symbol; V5-architecture-clean. Multi-market generalization claim. Surfaces vocabulary gap: `vol-expansion-breakout`. |
| S02 | `williams-monday-oops` | `strategy-seeds/cards/williams-monday-oops_card.md` | TBD | DRAFT (2026-04-28) | PDF pp. 35-36, 39-40 | Monday OOPS!: Monday opens below Friday's TRUE LOW (Friday not outside-day) → stop-buy at Friday's low. Sub-rule B extension: Thurs/Fri prior, last-2-days low. Single-symbol S&P / Bonds. Surfaces vocabulary gap: `gap-fade-stop-entry`. Bonds-Monday-buys composite ($79,200 / 69%) is RELATED-BUT-DISTINCT (cited verbatim, not asserted as Monday-OOPS! perf). |
| S03 | `williams-hidden-oops` | TBD | TBD | TBD | PDF pp. 36, 40 | Hidden OOPS!: projected H/L = (H+L+C)/3 *2; entry at projected level on stop. May fold into S02 if mechanically equivalent. |
| S04 | `williams-tdw-bias` | `strategy-seeds/cards/williams-tdw-bias_card.md` | TBD | DRAFT (2026-04-28) | PDF pp. 32-33, 37-38 | Trade Day of Week bias: buy on Mon/Tue/Fri open (Bonds) or Mon/Tue (S&P), exit first profitable open. Bonds default + S&P default + Power-of-Gold-filter variant as parameter sets. Surfaces sister-flag-gap candidacy: `intraday-day-of-week` (existing flag is monthly-only). Williams' Bonds backtest framing: Mon 79% / Tue 76% / Fri 73% with Gold-filter boosting to 84% / 82% / 81%. |
| S05 | `williams-tdom-bias` | `strategy-seeds/cards/williams-tdom-bias_card.md` | TBD | DRAFT (2026-04-28) | PDF pp. 33, 37-38, 42-45 | Trade Day of Month bias: buy on positive-TDOM days, exit first profitable open. CONSOLIDATES dozens of "best buy/sell day of year" tabulations (PDF pp. 42-45) into ONE card with `best_tdom_days_set` parameter (S&P-generic / Bonds-generic / month-specific Bonds / month-specific S&P). T-Bonds-best-day variant uses 7%-prior-range stop-buy + 4-day hold + $1,800 stop. Cleanly fits existing `intraday-day-of-month` flag (V4 Gotobi precedent). |
| S06 | `williams-holiday-trd` | `strategy-seeds/cards/williams-holiday-trd_card.md` | TBD | DRAFT (2026-04-28) | PDF pp. 33-34, 41-42 | National Holiday trades: 8 federal holidays × specific buy/sell open/close on N-th TD before/after. Bonds and S&P maps DISAGREE on direction (e.g., New Years: Bonds SELL vs S&P BUY — risk-on/risk-off flip thesis). **STRONGEST G0 candidate in SRC03 first-pass:** Williams' Bonds backtest 1978-1999 = 84% wins, $52,200 net, **$1,978 max DD**, 4.31 PF, 1,048% ROA over 21 years. S&P backtest 1982-1999 = 63% wins, $108,675 net, 2.66 PF. Surfaces sister-flag-gap candidacy: `holiday-anchored-bias`. |
| S07 | `williams-smash-day` | `strategy-seeds/cards/williams-smash-day_card.md` | TBD | DRAFT (2026-04-28) | PDF p. 19 | Smash Day: bullish setup = higher H/L/C with close substantially below open (body-rejection-pct ≥ 50% default) → stop-buy at smash-bar's high. Symmetric short-side verbatim Williams. Multi-market generic candle-pattern. Surfaces vocabulary gap: `rejection-bar-stop-entry`. "Substantially" qualifier is enhancement_doctrine load-bearing. |
| S08 | `williams-fakeout-day` | TBD | TBD | TBD | PDF p. 19 | Fake Out Day: higher H, higher L, lower C → buy at prior day's high. Sister-card to S07. |
| S09 | `williams-naked-close` | TBD | TBD | TBD | PDF p. 20 | Naked Close: close below prior day's low → buy at high of that day. May fold into S08 family. |
| S10 | `williams-spec-trap` | TBD | TBD | TBD | PDF p. 20 | Specialist Trap: uptrend → 6-20 day box → big breakout day → SELL at true low of breakout day (failed-breakout reversal). |
| S11 | `williams-8wk-box` | TBD | TBD | TBD | PDF pp. 24-25 | 8-Week Box Congestion Breakout: 8-week sideways range → buy/sell on breakout in direction of major trend coming in. Multi-market; daily bars. |
| S12 | `williams-18bar-ma` | TBD | TBD | TBD | PDF p. 17 | 18-Bar Two-Bar MA Entry: two consecutive bars with lows above 18-bar MA, no inside days, enter at highest high. Multi-market. |
| S13 | `williams-3bar-exit` | TBD | TBD | TBD | PDF p. 21 | 3-Bar Trailing Stop / Exit: lowest true low of 3 non-inside-day window. **Exit-only mechanism**, may not survive G0 as a standalone Strategy Card (no entry trigger). Likely promotes to a TM-module specification used BY other Williams cards rather than a card itself. CEO ratification request at G0. |
| S14 | `williams-cdc-pattern` | TBD | TBD | TBD | PDF pp. 35-36, 40 | Consecutive Down Closes: 2-3 down closes + range-shrinking filter (h-c < prior h-c) + Gold filter; buy at open + (today's H − today's C). |
| S15 | `williams-gap-dn-buy` | TBD | TBD | TBD | PDF p. 36 | Gap-Down-Close buy pattern: today's high < yesterday's low (full gap down) + Gold-filter; buy at open + (today's H − today's C). May fold into S14 family. |

Slot count finalized at survey-pass: **15 candidates**. Cards-vs-fold decisions made at extraction time per Rule 1. Expected harvest: 10-15 cards (some folding likely between S02/S03 OOPS family, S08/S09 reversal-day family, S14/S15 down-close family).

**Running vocabulary-gap proposals (SRC03 first + second pass: 3 entry-side gaps + 1 calendar-cycle refinement question)** — per-card § 16 details; batch-proposed to CEO + CTO via `strategy_type_flags.md` addition-process when extraction stabilizes:

1. `vol-expansion-breakout` (S01) — entry mechanism: stop-buy/sell at next bar's open ± N% × range(prior_bar). Distinct from `narrow-range-breakout` (no NR precondition required) and `donchian-breakout` (single prior-bar range, not N-bar rolling extreme).
2. `gap-fade-stop-entry` (S02) — entry mechanism: gap THROUGH a calendar-pattern reference price → stop-buy/sell BACK at the reference price, fading the gap. Distinct from `n-period-min-reversion` (which fires at next-bar open without a gap-through condition).
3. `rejection-bar-stop-entry` (S07) — entry mechanism: candle-shape rejection bar (close substantially against open) → stop-buy/sell at the OPPOSITE extreme of the rejection bar. Distinct from `narrow-range-breakout` (Smash Day requires WIDE-RANGE rejection, not NR contraction) and `gap-fade-stop-entry` (no gap; bar-internal close-vs-open structure).
4. **calendar-cycle vocabulary refinement** (S04 / S05 / S06) — `intraday-day-of-month` flag definition is monthly-cycle-only. Williams' three calendar cadences (S04 weekly TDW, S05 monthly TDOM, S06 yearly Holiday-anchored) all fit the same conceptual category. Two options for CEO + CTO ratification:
   - **(a) Generalize:** rename `intraday-day-of-month` → `calendar-cycle-bias` with cycle-period as parameter (weekly / monthly / yearly).
   - **(b) Add siblings:** add `intraday-day-of-week` (S04) and `holiday-anchored-bias` (S06) as siblings to the existing `intraday-day-of-month` (S05).
   Recommendation: option (b) for SRC03 fast-path; (a) is a downstream cleanup if the flag-set proliferates.

**Filters NOT extracted as separate cards** (workshop pp. 1-14, integrated into per-card § 6 Filters where applicable):

- Williams Valuation Index (WVI): commodity-vs-Gold spread normalized → 75% overvalued, 15% undervalued
- COT Index 12-month-high/low method (Commercials net-position normalized 3-yr range)
- DMI/ADX > 60 (End of Trend Indicator); +40 buy on oversold (Paunch)
- Pinch & Paunch divergence (DMI vs Stochastic)
- Sentiment (Market Vane > 75 sell, < 33 buy)
- Open Interest 20% decline rule on uptrend trading range
- Spreads / Premium structure
- 14-bar Stochastic > 60 buy / < 40 sell trend filter
- Power-of-Gold filter (Gold lower than N days ago for Bond longs)

These are setup / filter conditions, not entry strategies. Per DL-033 Rule 1, FILTERS are documented per-card under § 6 (Filters / No-Trade module) when they bind to a specific entry strategy, not as separate Strategy Cards.

## 7. Workshop / chapter index (validated at survey-pass)

Extracted from PDF pages 1-46 via `pdftotext -layout` 2026-04-28. Page numbers are PDF page numbers (printed-book pagination is mixed workshop+book, see § 1 citation note).

| Section | Title | PDF page | Strategy density |
|---|---|---|---|
| Workshop §1 | How to Determine Fundamental Under and Over Valuation (WVI) | 1-4 | LOW (filter only) |
| Workshop §2 | Get In Phase With the Powers That Make the Markets (COT) | 4-7 | LOW (filter only) |
| Workshop §3 | The "End of the Trend" Indicator (DMI/ADX) | 7-8 | LOW (filter only) |
| Workshop §4 | The Pinch and the Paunch (DMI vs Stochastic) | 8-9 | LOW (filter only) |
| Workshop §5 | How to Fade the Usually Wrong Public (Sentiment) | 9-10 | LOW (filter only) |
| Workshop §6 | Supercharging Seasonal Trading | 10-13 | LOW (filter only; lists seasonal up/down months by symbol) |
| Workshop §7 | The Open Interest "Play" I've Been Using Since 1970 | 13 | LOW (filter only) |
| Workshop §8 | The Secret Message of Spreads / Price Premiums | 13-14 | LOW (filter only) |
| Entry Techniques | Williams Entry Techniques and Rules | 15-21 | **HIGH** (cards S01, S07-S13 source here) |
| Money Management | Speculator's Money-Management Approach | 21-30 | LOW (sizing methodology only) |
| Inside Circle | Short-Term Trading Approach (intro) | 32 | introduction |
| Bonds Rules | Trade Day of Week / Month / Holidays / Power of Gold / Specific Patterns | 32-37 | **HIGH** (cards S04, S05, S06, S14, S15 source here; bonds-side) |
| S&P 500 Rules | TDW / TDOM / Power of Bonds / Monday OOPS! / Hidden OOPS! / CDC / Monday-Only / Sell Patterns | 37-41 | **HIGH** (cards S02, S03 source here; S04-S06 bonds-context cross-reference) |
| S&P Holiday | S&P Holiday Trades | 41-42 | medium (S06 cross-reference) |
| S&P Best Days | Best Short-Term Buy/Sell Days of the Year | 42-43 | LOW (parameter-list for S05 TDOM) |
| Bonds Best Days | T-Bonds Best Buy/Sell Trade Days With 4-Day Hold | 43-45 | LOW (parameter-list for S05 TDOM) |
| OCR-degraded | PDF pp. 47+ | 47+ | UNKNOWN — partial-text extract. Re-OCR at extraction if any candidate references material here. |

Total: 8 workshop sections + Entry Techniques + Money Management + Short-Term Trading Approach (Bonds + S&P) + Best/Worst Days tables. Strategy-bearing sections: Entry Techniques (pp. 15-21), Bonds Rules (pp. 32-37), S&P 500 Rules (pp. 37-41).

## 8. Extraction plan

Process 13 / DL-033 / QUA-298 binding constraints:

- One source actively worked at a time. **No SRC04+ until ALL SRC03 sub-issues close.**
- One sub-issue per strategy. First sub-issue `todo`, rest `blocked`. Next unblocks only when prior strategy completes its end-to-end pipeline.
- Heartbeat budget: SRC02 yield ratio target was 8 cards / 7 heartbeats = 1.14 cards/heartbeat (above SRC01's 0.71). SRC03 target ≥ 1.5 cards/heartbeat given the rules-tight nature of Williams' content.

Extraction sequence:

1. **First pass — single-symbol calling-card strategies.** Draft S01 (Volatility Breakout), S02 (Monday OOPS!), S07 (Smash Day) first. These are Williams' most-cited patterns and the most likely to PASS G0 cleanly.
2. **Second pass — calendar-bias family.** Draft S04 (TDW), S05 (TDOM), S06 (Holiday Trades). Decide cards-vs-fold for the dozens of "best day of year" tabulations (S05 likely consolidates them).
3. **Third pass — reversal-day family.** Draft S08 (Fakeout), S09 (Naked Close), S10 (Specialist Trap). Decide whether S09 folds into S08 or S07.
4. **Fourth pass — composite / variant strategies.** Draft S03 (Hidden OOPS!), S11 (8-Week Box), S12 (18-Bar MA), S14 (CDC), S15 (Gap-Down). Decide S03↔S02, S15↔S14 fold-ins.
5. **Fifth pass — meta-mechanism review.** Decide S13 (3-Bar Trailing Stop) cardability — likely escalate to CEO as a TM-module specification rather than a standalone Strategy Card.
6. **Sub-issue creation.** When all candidate cards drafted to DRAFT, open one sub-issue per surviving strategy under QUA-298 — first as `todo`, rest as `blocked`. Submit for CEO + Quality-Business G0 review per process 13.

Per-pass progress comments posted to QUA-298 at pass-boundary granularity. No noise comments on individual cards within a pass.

## 9. Completion report contract

When all S-sub-issues under QUA-298 close, Research authors `strategy-seeds/sources/SRC03/completion_report.md` covering at minimum (per QUA-298 acceptance criterion 3):

- Total strategies extracted vs. expected (10-15)
- Per-strategy verdict (PASS / FAIL / RETIRED) with terminal pipeline phase
- Skipped strategies (failed V5 hard rule or underspecified-beyond-cardable) and reason
- **Strategy-type-flag distribution** (per `strategy_type_flags.md` controlled vocabulary; cross-walk vs SRC01 + SRC02 distribution to feed `STRATEGY_TYPE_DISTRIBUTION.md` once Doc-KM is hired)
- **Architecture-fit profile** — single-symbol-friendly comparison vs SRC02 Chan's multi-stock pattern
- Source quality and density observations
- Yield ratio: `cards_passed_g0 / heartbeats_used` for `budget_tracking` review (SRC02 benchmark: target 1.14)
- Recommendation: deeper mining worthwhile? Move on to SRC04 (Lien, *Day Trading and Swing Trading the Currency Market*, `proposed_order = 4`)?

## 10. Cross-references

- Parent issue: [QUA-298](/QUA/issues/QUA-298)
- Predecessor sources: [QUA-191](/QUA/issues/QUA-191) (SRC01 Davey), [QUA-275](/QUA/issues/QUA-275) (SRC02 Chan)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md` (T1 Tier A row 3)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-030 (Class 2 Review-only execution policy on Strategy Card child issues)
- DL-032 (CEO Autonomy Waiver v3 — autonomous source-queue ordering)
- DL-033 (extraction-discipline / Rule 1)
- QUA-243 (card-template filename convention update)
- QUA-297 (OWNER speed-up directive parent — SRC03 spawned in parallel with SRC02 closeout)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`
