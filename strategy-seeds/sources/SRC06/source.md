---
source_id: SRC06
tier: T1                                      # curated local PDF (OWNER-supplied)
parent_issue: QUA-1058                        # OWNER 2026-05-09 directive: extract 10-15 new cards using Anthropic headroom while Codex throttled to 5/14
status: extraction_pass_complete              # 14 cards drafted from 17 numbered strategies (3 skipped per documented hard-rule rationale)
authored-by: Research Agent
last-updated: 2026-05-09
budget_tracking:
  heartbeats_used: 1                          # h1: full extraction in single Anthropic-Opus heartbeat per OWNER QUA-1058
  cards_drafted: 14                           # S01-S04 + S07-S13 (S13 single card, two-part variants) + S15-S17
  cards_passed_g0: 0                          # awaits QB R1-R4 + CEO G0 verdict
  cards_killed_pre_p1: 0
  cards_skipped_with_rationale: 3             # S05 Gawk the Talk + S06 Balk the Talk + S14 Siamese Twins — see § 6
extraction_pass_status: extraction_pass_complete   # 14/17 strategies extracted; 3 SKIP'd per documented hard-rule rationale.
proposed_order: 17                            # T1 Tier B per `SOURCE_QUEUE.md`. OWNER 2026-05-09 prioritized for 10-15-card target due to multi-strategy declared content.

---

# SRC06 — Mario Singh, *17 Proven Currency Trading Strategies: How to Profit in the Forex Market*

QUA-1058 is the parent extraction issue per OWNER 2026-05-09 directive (Codex throttled until 5/14, use Anthropic Subscription headroom for 10-15 card G0 expansion). Source rank: T1 Tier B, `proposed_order = 17` per [`SOURCE_QUEUE.md`](../SOURCE_QUEUE.md). OWNER prioritized this source over strict proposed_order because:

1. **Single-source 10-15-card guarantee** — author declares "17 Proven" in title, with 17 numbered strategies across 5 dedicated chapters (Ch 6-10).
2. **Forex-pure focus** — all 17 strategies trade forex spot pairs (no equities, no futures) which V5 backtests cleanly.
3. **Diversity-bias check passes** — SRC05 Chan AT was algorithmic-trading methodology + multi-asset; SRC06 Singh is forex-specialist single-asset. No 3-consecutive same-class violation.
4. **Tier B adequately reputable** — Mario Singh is verifiable practitioner: founder/CEO of Fullerton Markets, regularly featured on CNBC (Squawk Box, Capital Connection, Worldwide Exchange), Wiley-published (ISBN 978-1-118-38551-7). Author was mentored by Kathy Lien (SRC04) per Acknowledgments + Preface, providing direct lineage to SRC04 vocabulary.

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7 (Cloth) / 978-1-118-38553-1 (ePDF) / 978-1-118-38554-8 (Mobi) / 978-1-118-38552-4 (ePub)."
    location: TBD                              # populated per-card with chapter + section + PDF page on extraction
    quality_tier: B                            # verifiable practitioner; Wiley-published; CNBC-featured; founder of FX1 Academy / Fullerton Markets; mentored by Kathy Lien (SRC04 author)
    role: primary
```

**Author lineage to SRC04.** Singh's Acknowledgments (PDF p. xix) names Kathy Lien (SRC04 author) and Ed Ponsi as his "forex mentors." Two of Singh's strategies are direct vocabulary inheritors: pendulum-style range trading and trend-following ADX exits both appear in Lien's *Day Trading and Swing Trading the Currency Market*. Per Process 13 § Strategy lineage: lineage-by-mentorship is NOT same-source; cards with similar mechanical structure to SRC04 cards must be evaluated individually for distinctness. None of the 17 Singh strategies has a 1-to-1 SRC04 duplicate (Lien's 11 cards are all distinct from Singh's 17).

## 2. Source-text status

```yaml
source_text_path: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\17 Proven Currency Trading Stra - Mario Singh.pdf"
file_size_bytes: 27775290                      # 26.5 MB
file_modified: 2024-07-17
text_extraction_method: poppler `pdftotext -layout` (verified text-clean across 9187 lines; book is text-rendered, not image-scanned)
status: on_disk_text_clean
```

Raw text excerpt archived under `raw/full_text.txt` (full PDF text dump, 9187 lines, 419357 bytes).

## 3. Strategy survey & extraction map

Singh's book Part Two (Chapters 6-10) presents 17 numbered strategies in dedicated chapters by trader-profile. Each strategy is structured uniformly: Time Frame / Indicators / Currency Pairs / Strategy Concept / Long Trade Setup / Short Trade Setup / Strategy Roundup. This uniformity makes per-strategy mechanical extraction unusually clean.

```yaml
expected_strategy_count: 17                    # author-declared in title + TOC
extracted_card_count: 14                       # 17 numbered minus 3 SKIP per hard-rule rationale (§ 6)
strategy_locations:
  - "PDF p. 111-117 — Strategy 1: Rapid-Fire (Ch 6, Scalpers; M1 EURUSD, Parabolic SAR + SMA 60). STRATEGY S01."
  - "PDF p. 118-124 — Strategy 2: Piranha (Ch 6, Scalpers; M5 GBPUSD, Bollinger Bands 12/2 range mean-reversion). STRATEGY S02."
  - "PDF p. 125-131 — Strategy 3: Fade the Break (Ch 7, Day Traders; M15/M30 false-break-candle reversal at S/R). STRATEGY S03."
  - "PDF p. 131-137 — Strategy 4: Trade the Break (Ch 7, Day Traders; M15/M30 breakout-candle continuation at S/R, SL at 60% range mark). STRATEGY S04."
  - "PDF p. 142-147 — Strategy 5: Gawk the Talk (Ch 7, Day Traders; news-trade Rule-of-20 actual-vs-forecast >+20% deviation). SKIP — see § 6 rationale."
  - "PDF p. 148-153 — Strategy 6: Balk the Talk (Ch 7, Day Traders; news-trade Rule-of-20 actual-vs-forecast <-20% deviation). SKIP — see § 6 rationale."
  - "PDF p. 155-163 — Strategy 7: Trend Rider (Ch 8, Swing; H1/H4 EMA12-cross-EMA36 + ADX(14)>40-then-back-below exit). STRATEGY S07."
  - "PDF p. 163-169 — Strategy 8: Trend Bouncer (Ch 8, Swing; H1/H4 BB(12,2) pullback to MA12 + BB(12,4) SL, three RR targets). STRATEGY S08."
  - "PDF p. 169-177 — Strategy 9: Fifth Element (Ch 8, Swing; H1/H4 MT4 MACD-histogram switch then 5th-bar entry). STRATEGY S09."
  - "PDF p. 177-184 — Strategy 10: Power Ranger (Ch 8, Swing; H1/H4 stochastic 10/3/3 oversold/overbought + range). STRATEGY S10."
  - "PDF p. 185-190 — Strategy 11: The Pendulum (Ch 8, Swing; H1/H4 range bounce — enter at 10% off support/resistance). STRATEGY S11."
  - "PDF p. 192-199 — Strategy 12: Swap and Fly (Ch 9, Position; D1/W1 three-soldiers/three-crows + carry-positive pair, BE-after-1R). STRATEGY S12."
  - "PDF p. 199-204 — Strategy 13 Part 1: Commodity Correlation oil-CADJPY (Ch 9, Position; D1 oil-S/R-break triggers CADJPY trade, ATR×2 SL, 1:3 RR). STRATEGY S13a."
  - "PDF p. 204-210 — Strategy 13 Part 2: Commodity Correlation USDX-XAUUSD (Ch 9, Position; D1 Dollar-Index-S/R-break triggers gold trade, ATR×2 SL, 1:3 RR). STRATEGY S13b."
  - "PDF p. 210-216 — Strategy 14: Siamese Twins (Ch 9, Position; D1 China-news-release triggers AUDUSD trade). SKIP — see § 6 rationale."
  - "PDF p. 217-223 — Strategy 15: Guppy Burst (Ch 10, Mechanical; M5 GBPJPY 3hr-NY-close-to-Asia-open range bracket). STRATEGY S15."
  - "PDF p. 223-228 — Strategy 16: English Breakfast Tea (Ch 10, Mechanical; M15 GBPUSD 04:15→08:15 London-direction compare, reverse-trade at 08:30 London). STRATEGY S16."
  - "PDF p. 228-233 — Strategy 17: Good Morning Asia (Ch 10, Mechanical; D1 USDJPY follow-prev-day's-bull-or-bear-direction). STRATEGY S17."

notes: |
  Singh's 17 strategies span all five trader-profile categories (scalper / day / swing /
  position / mechanical). This breadth makes SRC06 the highest-yield single-source extraction
  in the V5 queue to date (matches SRC03 Williams 17 cards under williams-* slug family). All
  strategies are clean rule-tight mechanical except S05/S06/S14 which require external
  fundamental-news data (forecast-vs-actual deviation, central-bank PMI/CPI/GDP releases) that
  is NOT in the Darwinex-native price feed.

  **Author claims throughout the book are illustrative single-trade R-multiple computations**
  (e.g., "1:5.4 risk to reward, 16.2% return on a 3% risk"). The book does NOT contain
  multi-year backtest results, win-rate statistics, equity curves, or annualized returns.
  Singh writes: *"trading is simple but it's not easy. It's simple because there are only a
  few rules to follow"* (PDF p. 235, Ch 11). Per V5 BASIS rule, every per-strategy author claim
  is preserved verbatim as a single-trade illustration; no annualized aggregate is fabricated
  by Research.
```

## 4. V5 Hard Rules at risk (cross-card summary)

| ID | Strategy | Hard rules potentially at risk | Status |
|---|---|---|---|
| S01 | Rapid-Fire (M1 EURUSD) | scalping_p5b_latency, news_pause_default | extracted (flag set) |
| S02 | Piranha (M5 GBPUSD) | scalping_p5b_latency | extracted (flag set) |
| S03 | Fade the Break | (none beyond V5 framework defaults) | extracted |
| S04 | Trade the Break | (none beyond V5 framework defaults) | extracted |
| S05 | Gawk the Talk | news_pause_default + darwinex_native_data_only (forecast-vs-actual) | **SKIP** — § 6 |
| S06 | Balk the Talk | news_pause_default + darwinex_native_data_only (forecast-vs-actual) | **SKIP** — § 6 |
| S07 | Trend Rider | (none beyond V5 framework defaults) | extracted |
| S08 | Trend Bouncer | (none beyond V5 framework defaults) | extracted |
| S09 | Fifth Element | (none beyond V5 framework defaults) | extracted |
| S10 | Power Ranger | (none beyond V5 framework defaults; trend-line draw is mechanizable as recent-N-extrema) | extracted |
| S11 | Pendulum | (none beyond V5 framework defaults; range identification mechanizable as recent-N-window high/low) | extracted |
| S12 | Swap and Fly | friday_close (positions held 35-36 weeks crossing many Fri 21:00 closes); needs framework-default override + carry-trade documentation | extracted (flag set) |
| S13 | Commodity Correlation (Part 1 oil-CADJPY + Part 2 USDX-XAUUSD; folded as one card with two parameter-set variants) | dwx_suffix_discipline (WTI.cash.DWX + USDX.f availability check) + darwinex_native_data_only (Dollar-Index source for Part 2) | extracted (flag set) |
| S14 | Siamese Twins | news_pause_default + darwinex_native_data_only (China central-bank releases, PMI surprise) | **SKIP** — § 6 |
| S15 | Guppy Burst | (none beyond V5 framework defaults; M5 noise risk handled at P5b) | extracted |
| S16 | English Breakfast Tea | (none beyond V5 framework defaults; time-of-day binding is mechanical) | extracted |
| S17 | Good Morning Asia | (none beyond V5 framework defaults; daily-candle binding is mechanical) | extracted |

## 5. Why Mentor-Lineage to SRC04 Lien

Singh names Kathy Lien (SRC04 author) as one of his two forex mentors (Acknowledgments PDF p. xix; Preface PDF p. xiv: "My quest for mastery also led me to seek out two of the biggest names in the forex industry as my mentors: Kathy Lien and Ed Ponsi."). This means Singh's vocabulary inherits SRC04 conventions:

- "Day trader / Swing trader / Position trader" categorization — mirrors Lien's chapter structure
- ADX-based trend exits — both authors use ADX as exit-signal indicator (Lien uses 25/30 thresholds; Singh uses 40)
- Bollinger-Band pullbacks — both authors use BB MA-12 pullback as range/trend entry
- Carry-trade emphasis — Lien's *carry-trade* card (SRC04_S07 lien-carry-trade) is the conceptual ancestor of Singh's S12 Swap-and-Fly (different mechanical trigger but same swap-earning thesis)

Per V5 BASIS: each Singh card cites Singh as primary, optionally cites Lien as `role: supplement` where the lineage is direct (S07 Trend Rider, S12 Swap and Fly).

## 6. SKIP'd strategies — verbatim author rationale (S05, S06, S14)

Per V5 BASIS Rule 1 (every distinct mechanical strategy that passes V5 hard rules gets a card), Research SKIPs strategies that fail V5 hard rules at the source-survey stage and documents the rationale. Three strategies fail because they are **fundamental-news-driven** and require economic-calendar data (forecast vs actual deviation) that is NOT in the Darwinex-native price feed.

### S05 — Gawk the Talk (PDF p. 142-147)

> *"As discussed in the Rule of 20, trades are taken by comparing the forecasted figures with the actual figures. For this strategy, we go long on the affected currency when actual figures are greater than forecasted figures by a minimum factor of 20%."* (Singh 2013, p. 144 verbatim)

**V5 fail:** entry condition = `actual > forecast × 1.20` requires economic-calendar feed (forecast figures + post-release actual figures). Darwinex provides price data only. The forex price-feed alone cannot synthesize the entry signal. Combined with V5 framework default `news_pause_default` (pause trading during high-impact news windows), the strategy would be auto-paused at the moment its own entry signal fires.

**Re-entry path:** if OWNER + CEO accept a third-party news-calendar feed integration (e.g., Forex Factory CSV ingestion to a custom indicator), S05 can be revisited as a conditional card. Until that decision lands, S05 is `BLOCKED_NO_NATIVE_DATA + news_pause_default_conflict`.

### S06 — Balk the Talk (PDF p. 148-153)

> *"For this strategy, we go short on the affected currency when actual figures are lower than forecasted figures by a minimum factor of 20%."* (Singh 2013, p. 149 verbatim)

**V5 fail:** identical to S05, with sign reversed. Same `BLOCKED_NO_NATIVE_DATA + news_pause_default_conflict`. Re-entry path identical to S05.

### S14 — Siamese Twins (PDF p. 210-216)

> *"This strategy seeks to take advantage of the movement of the AUD/USD by taking cue from China's reported figures and monetary policies. […] We take a long position on AUD/USD immediately after China announces better-than-expected data. Similarly, we take a short position on AUD/USD immediately after China announces worse-than-expected data."* (Singh 2013, p. 211 verbatim)

**V5 fail:** entry condition = "China announces better/worse-than-expected data" requires China-specific economic-calendar feed (PBOC RRR cuts, HSBC PMI, GDP releases). Same `BLOCKED_NO_NATIVE_DATA + news_pause_default_conflict`. Re-entry path identical to S05.

## 7. Extraction methodology notes

- **Card filename slug convention:** `singh-<short-name>` per Process 13 + `_TEMPLATE.md` § filename convention. Slug ≤ 16 chars lowercase kebab-case.
- **Author claims preserved verbatim** with quotation marks per V5 BASIS rule. Single-trade illustrative R-multiples (e.g., "1:5.4 risk to reward, 16.2% return on a 3% risk") are quoted as the author wrote them, with explicit annotation that these are single-trade examples not aggregate annualized returns.
- **R1-R4 Reputable-Source attribution** per QB binding criteria (memory `project_qb_reputable_source_binding.md`):
  - R1 Author identifiable: Mario Singh, named author, Wiley-published, CNBC-featured, FX1 Academy founder
  - R2 Source verifiable: ISBN 978-1-118-38551-7 + PDF on Drive `G:\My Drive\QuantMechanica\Ebook\PDF resources\` + page numbers cited per card
  - R3 Mechanical clarity: per-card entry/exit pseudocode extracted verbatim from the book's "Long/Short Trade Setup" sections
  - R4 No paywall bypass / no piracy: PDF was OWNER-supplied to project Drive; not pirated; commercial book lawfully obtained
- **Hard-rule pre-flight:** Each card's § 11 (Strategy Allowability Check) pre-checked before submission. ML_FORBIDDEN: none of the 17 use ML; all pass. friday_close: S12 explicitly fails default and is documented as exception. scalping_p5b_latency: S01 + S02 flagged for P5b.

## 8. Acceptance for closeout

```yaml
- [x] 14 cards drafted (S01-S04, S07-S13, S15-S17; S13 folded as one card with Part 1 oil-CADJPY + Part 2 USDX-XAUUSD as parameter-set variants) per BASIS rule
- [x] 3 strategies SKIP'd with verbatim author quotes + V5 hard-rule rationale (§ 6)
- [x] R1-R4 source attribution per card (§ 7)
- [x] V5 hard-rules-at-risk documented per card (§ 4)
- [ ] QB G0 verdict pending (handed off via QUA-1058 closeout comment)
- [ ] CEO ratification of card batch pending
```

## 9. Lineage to source-queue + SRC chronology

- Source: `SOURCE_QUEUE.md` row 17, T1 Tier B
- Predecessor in queue: SRC05 Chan AT (closed `closeout_pass_v2_complete` 2026-05-08, 14 cards)
- Successor: TBD per CEO + OWNER ratification post-QUA-1058 closeout
- Diversity-bias check at pick: SRC05 was algorithmic-trading methodology; SRC06 is forex-specialist single-asset. Pass.
- Skipped queue rows 6-16 (Aziz, Brooks, Cofnas, Leshik, Krishtop, Aldridge, Jansen, Chan-Machine, Galen Woods × 2, Muranno) per OWNER QUA-1058 directive: pick the highest-card-yield single source for the Anthropic-headroom push. These rows remain in the queue for future SRC slots.
