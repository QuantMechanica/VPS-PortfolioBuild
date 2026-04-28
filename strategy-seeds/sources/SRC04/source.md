---
source_id: SRC04
tier: T1                                      # curated local PDF (OWNER-supplied)
parent_issue: QUA-333
status: scaffold_first_heartbeat
authored-by: Research Agent
last-updated: 2026-04-28
budget_tracking:
  heartbeats_used: 6                          # h1 scaffold + PDF text extract + per-chapter validation read; h2 first-pass extraction (S02a + S02b + S03 — 3 cards); h3 first-pass technical-block continuation (S05 + S07 — 2 cards); h4 technical-block continuation (S04 + S06 + S08 — 3 cards); h5 technical-block closeout + fundamental-block start (S09 + S11 DRAFT, S01 + S10 SKIP — 2 cards + 2 SKIPs); h6 fundamental-block CLOSEOUT (S12/S13/S14/S17 SKIP, S15/S16 KILL — 0 cards + 6 SKIPs/KILLs) + completion_report.md drafted + sub-issues opened.
  cards_drafted: 10                           # SRC04_S02a (lien-dbb-pick-tops), SRC04_S02b (lien-dbb-trend-join), SRC04_S03 (lien-fade-double-zeros), SRC04_S04 (lien-waiting-deal), SRC04_S05 (lien-inside-day-breakout), SRC04_S06 (lien-fader), SRC04_S07 (lien-20day-breakout), SRC04_S08 (lien-channels), SRC04_S09 (lien-perfect-order), SRC04_S11 (lien-carry-trade)
  cards_skipped: 6                            # S01 (Ch 8 SKIP_METHODOLOGY), S10 (Ch 17 SKIP_DISCRETIONARY), S12 (Ch 19 SKIP_DISCRETIONARY), S13 (Ch 21 SKIP_UNDERSPEC), S14 (Ch 22 SKIP_UNDERSPEC), S17 (Ch 25 SKIP_DISCRETIONARY)
  cards_killed_pre_p1: 2                      # S15 (Ch 23 Risk Reversals — darwinex_native_data_only BIND), S16 (Ch 24 Option Vols — darwinex_native_data_only BIND)
  cards_passed_g0: 0                          # awaiting CEO review batch on the 10 DRAFTs
extraction_pass_status: first_pass_complete   # All 17 surveyed slots have verdict: 10 DRAFT (S02a/S02b/S03/S04/S05/S06/S07/S08/S09/S11), 6 SKIP (S01/S10/S12/S13/S14/S17), 2 KILL (S15/S16). Yield ratio 10/17 = 59% draft (lower-third of § 6.5.4 forecast range 53-71%); 10/(10+8) = 59% pipeline-throughput including KILLs. completion_report.md drafted; sub-issues opened sequentially per DL-029.
completion_report: pending                    # authored after all SRC04_S* sub-issues close

---

# SRC04 — Kathy Lien, *Day Trading and Swing Trading the Currency Market* (3rd ed., 2015)

QUA-333 is the parent SRC issue per [DL-032](/QUA/issues/QUA-273) (CEO Autonomy Waiver v3 — autonomous source-queue ordering and per-batch source approval) and Process 13 (one-source-at-a-time, child sub-issue per strategy). Source rank: T1 Tier A, `proposed_order = 4` per [`SOURCE_QUEUE.md`](../SOURCE_QUEUE.md). Opened 2026-04-28 by CEO closeout on [QUA-298](/QUA/issues/QUA-298) (SRC03 Williams ratification).

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 9781119108412 (paperback) / 9781119220107 (ePDF) / 9781119220091 (ePub)."
    location: TBD                              # populated per-card with chapter + PDF page on extraction
    quality_tier: A                            # forex-industry insider; 15+ years FX experience (JPMorgan FX desk → FXCM/DailyFX → BK Asset Management); CNBC contributor; multi-book Wiley author; "queen of the macro forex trade" per industry framing
    role: primary
```

**Citation note.** The 3rd edition (2015) supersedes 2008 2nd edition and 2005 1st edition (originally titled *Day Trading the Currency Market*). All three editions exist; verbatim quotes cite the 3rd ed. specifically because that is the supplied PDF. Lien is one of the most widely-cited forex practitioners and a JPMorgan/BK Asset Management strategist — Tier A by the SRC quality rubric (peer-known practitioner with industry track record). Per-card citations cite chapter numbers + PDF page numbers (printed-book pagination starts at Roman numeral preface, then Arabic page 1 at Chapter 1).

## 2. Source-text status

```yaml
source_text_path: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Day Trading and Swing Trading t - Kathy Lien.pdf"
file_size_bytes: 4932950                       # 4.9 MB
file_modified: 2024-07-17                      # per ls -la mtime
text_extraction_method: poppler `pdftotext -layout`
status: on_disk_text_extracted
```

`pdftotext -layout` returned 693KB / 10962 lines of clean text. PDF is a 3rd-edition Wiley publication with embedded text layer (no OCR needed). Page-formatting artifacts (headers, footers, page numbers in mid-paragraph) are present but extraction-tolerable.

Raw text excerpts archived under `raw/` (all created at h1 scaffold for citation reuse during card drafting):

- `raw/full_text.txt` — full PDF text dump (693 KB; 10,962 lines; 33 chapters + index)
- `raw/toc_and_ch1-2.txt` — TOC + Ch 1 (FX intro) + Ch 2 (FX historical events) — context only
- `raw/ch07_trade_parameters.txt` — Ch 7 trade-environment-classification framework + risk management (filter context, NO Strategy Card per § 6.5 below)
- `raw/ch08-12_technical.txt` — Ch 8 multi-time-frame methodology + Ch 9 Double Bollinger Bands (TWO STRATEGIES per Lien's own subsections — Pick Tops/Bottoms + Trend-Joining) + Ch 10 Fading Double Zeros + Ch 11 Waiting for the Real Deal + Ch 12 Inside Days Breakout
- `raw/ch13-16_technical.txt` — Ch 13 Fader (ADX<20 false-BO fade) + Ch 14 20-Day Breakout + Ch 15 Channels + Ch 16 Perfect Order (MA-stack)
- `raw/ch17-20_fundamental.txt` — Ch 17 Pairing Strong-with-Weak + Ch 18 Leveraged Carry Trade (mechanical-mappable) + Ch 19 Macro-Event-Driven + Ch 20 QE-Impact (informational)
- `raw/ch21-24_fundamental.txt` — Ch 21 Commodity-Prices-Leading-Indicator (borderline) + Ch 22 Bond-Spreads-Leading-Indicator (borderline) + Ch 23 Risk Reversals (option data) + Ch 24 Option Volatilities (option data)
- `raw/ch25_intervention.txt` — Ch 25 Intervention (discretionary, irregular event-driven)
- `raw/ch26-33_currency_profiles.txt` — Ch 26 currency-profiles overview + Ch 27-33 per-currency profiles (EUR, GBP, CHF, JPY, AUD, NZD, CAD)

## 3. Why Lien #4 (per QUA-333)

Per QUA-333 description and `SOURCE_QUEUE.md` § "Why this ordering":

> **Lien, *Day Trading and Swing Trading the Currency Market*** — forex-specific, clear entry/exit rules. V5 backtests forex symbols, so direct fit.

Three role-specific reasons reinforce the slot:

1. **Class diversity vs SRC01 + SRC02 + SRC03.** SRC01 Davey was process-textbook (4/5 mean-reversion-flagged); SRC02 Chan was statistical-arbitrage / cointegration / factor-models on equities (8/8 multi-symbol or stat-rigor demos); SRC03 Williams was futures/single-symbol price-action breakout + day-trade timing (14 cards: vol-expansion-breakout, gap-fade, rejection-bar, calendar-bias, failed-breakout-fade families). Lien brings **forex-specialist patterns**: multi-time-frame technical setups, currency-correlation-driven trades, carry-trade fundamentals, IR-spread / bond-yield differentials, intervention-driven trades, double-Bollinger and channel-breakout systems calibrated for FX session dynamics (NY/London/Tokyo overlaps). Net-new strategy class to V5 corpus. No 3+ consecutive same-class trigger fires on the SOURCE_QUEUE diversity-bias rule.
2. **V5-architecture compatibility profile — highest yet.** V5 backtests and live-trades forex symbols on Darwinex (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, etc.). Lien's deployment universe is the **closest match yet of any source**. Predict 100% architecture-clean rate (matching SRC03's 100%, exceeding SRC02's 50%). Currency-pair semantics, pip-based stops, swap/carry mechanics — all natively supported by V5.
3. **Daily / 4-hour / 1-hour bar timeframes = M15+ V5 fit.** Lien's strategies are stated on daily and intraday bars; her style is "day trading and swing trading" — short-term, but not scalping. No HFT, no sub-minute execution. News-compliance compatible with caveats: Macro Event Driven (Ch 19) and Intervention (Ch 25) may be news-driven and require P8 News Impact pause-window discipline — flagged at extraction.

## 4. Expected strategy count

Lien is **chapter-per-strategy** by design. Chapters 8-16 (9 technical strategies) + Chapters 17-19, 21-25 (8 fundamental strategies) + Ch 20 (QE context) + Ch 26-33 (currency profiles, context only). Per **DL-033 Rule 1** (every distinct mechanical strategy that passes V5 hard rules gets a card; pipeline G0 → P10 is the filter, not Research's prior beliefs), Research extracts cards for each named strategy chapter.

```yaml
expected_strategy_count: 12-17                # 17 named strategy chapters (Ch 8-16 + Ch 17-19 + Ch 21-25); some may fold or escalate (e.g., Ch 19 macro-event-driven and Ch 25 intervention are likely qualitative/discretionary, not mechanical-cardable)
expected_chapter_count: 17                    # strategy-bearing chapters only (Ch 8-16 technical + Ch 17-19, 21-25 fundamental)
strategy_locations:                            # validated at survey-pass; finalized at extraction
  - "Ch 8 (PDF p. 91+) — Multiple Time Frame Analysis"
  - "Ch 9 (PDF p. 101+) — Trading with Double Bollinger Bands"
  - "Ch 10 (PDF p. 111+) — Fading the Double Zeros"
  - "Ch 11 (PDF p. 117+) — Waiting for the Deal"
  - "Ch 12 (PDF p. 123+) — Inside Days Breakout Play"
  - "Ch 13 (PDF p. 129+) — Fader"
  - "Ch 14 (PDF p. 135+) — 20-Day Breakout Trade"
  - "Ch 15 (PDF p. 139+) — Channels"
  - "Ch 16 (PDF p. 143+) — Perfect Order"
  - "Ch 17 (PDF p. 149+) — Pairing Strong with Weak"
  - "Ch 18 (PDF p. 153+) — The Leveraged Carry Trade"
  - "Ch 19 (PDF p. 161+) — Macro Event Driven Trade"
  - "Ch 21 (PDF p. 177+) — Commodity Prices as a Leading Indicator"
  - "Ch 22 (PDF p. 181+) — Using Bond Spreads as a Leading Indicator for FX"
  - "Ch 23 (PDF p. 187+) — Risk Reversals"
  - "Ch 24 (PDF p. 191+) — Using Option Volatilities to Time Market Movements"
  - "Ch 25 (PDF p. 195+) — Intervention"

notes: |
  Lien's style: chapter-per-strategy with a clear setup → entry → stop → target framing in technical chapters (Ch 8-16). Fundamental chapters (Ch 17-19, 21-25) lean more on macro thesis + qualitative trade-construction; some may be too discretionary to operationalize as mechanical cards.

  Likely-mechanical-cardable (high G0 prediction): Ch 9 Double Bollinger Bands, Ch 12 Inside Days Breakout, Ch 13 Fader, Ch 14 20-Day Breakout, Ch 15 Channels, Ch 16 Perfect Order, Ch 18 Leveraged Carry Trade, Ch 22 Bond Spreads as FX Leading Indicator, Ch 21 Commodity Prices as FX Leading Indicator.

  Likely-discretionary-or-escalate (G0 risk): Ch 8 Multi-Time-Frame (methodology, may not be standalone strategy), Ch 19 Macro Event Driven (news-discretionary), Ch 23 Risk Reversals (options-data, not on Darwinex feed), Ch 24 Option Volatilities (options-data, not on Darwinex feed), Ch 25 Intervention (rare, discretionary).

  Ch 7 "Trade Parameters for Various Market Conditions" may contain regime-classification rules that become a Filter / regime-detector module rather than a Strategy Card.

  `darwinex_native_data_only` Hard Rule will likely BIND on Ch 23 and Ch 24 (FX options data is not in Darwinex CFD feeds). Pre-emptive flagging at extraction; CEO will decide PASS_G0_with_flag vs KILLED_PRE_P1.

  Rule 1 binds: every distinct mechanical strategy that passes V5 hard rules gets a card. Pipeline gates do the filtering. Research extracts; CEO + Quality-Business + CTO ratify per process 13.
```

## 5. v0 filter rules applied to this source

Inherited from QUA-333 acceptance criteria + DL-029 strategy-research workflow + the v5_flags conventions in `SOURCE_QUEUE.md`:

- **Mechanical only** — Lien's technical-chapter rules (Ch 9-16) have explicit setup → entry → stop → target structure. Fundamental chapters (Ch 17-25) range from mechanical (e.g., Ch 18 carry-trade IR-differential ranking) to qualitative (Ch 19 macro-event, Ch 25 intervention). Per-chapter mechanical-vs-discretionary verdict at extraction.
- **No Machine Learning** — Lien predates and avoids ML; no neural-net / gradient-boost / random-forest construction in the source. `EA_ML_FORBIDDEN` does NOT bind.
- **`.DWX` suffix discipline** — Lien's universe is **forex spot pairs** (G10 majors + crosses). V5 deployment is direct: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, plus crosses. **Cleanest architecture-fit of any SRC so far.**
- **`darwinex_native_data_only` Hard Rule** — Likely BINDS on:
  - Ch 22 Bond Spreads — requires US Treasury yields + foreign-government bond yields. **NOT in Darwinex CFD feeds** unless proxied via bond futures CFDs. Per-card flagging.
  - Ch 23 Risk Reversals — requires FX options skew data. **NOT in Darwinex feeds.** Likely KILL_PRE_P1 unless Lien's rule reduces to spot-only proxy.
  - Ch 24 Option Volatilities — same as Ch 23.
  - Ch 21 Commodity Prices — Darwinex has GOLD.DWX, OIL.DWX, copper-equivalent. Workable.
  - Ch 18 Leveraged Carry Trade — requires interbank IR data; central-bank rate calendar is public, but live-IR-differential feed may need a proxy. Per-card review.
- **Magic-formula registry compatible** — Lien's strategies are all single-position-at-a-time at the symbol level. Compatible with `one_position_per_magic_symbol`.
- **News-compliance compatible** — Most technical strategies (Ch 9-16) are price-pattern-driven; standard P8 News Impact pause-window covers them. Macro-event (Ch 19) and Intervention (Ch 25) are news-DRIVEN — incompatible with default P8 unless a "fade-after-news" module is layered. Per-card flagging.
- **Friday Close compatibility** — Lien's swing-trade examples can hold multi-day; Friday-close waiver candidacy at P3 (precedent: SRC02 chan-pairs, SRC03 williams-8wk-box). Most day-trade examples Friday-close-compatible.
- **`scalping_p5b_latency`** — None of the chapters target sub-1-minute execution. Flag does not bind.

## 6. Sub-issue queue (per QUA-333 process-13 setup)

Per QUA-333 acceptance: "Each candidate that survives V5 v0_filter becomes a SRC04_S* child card." Slot table populated as cards are drafted. Slug pattern: `lien-<topic>` (mirrors `williams-<topic>` SRC03 pattern; CEO TBD-confirm at first-card G0). Filenames follow `_TEMPLATE.md` (`<slug>_card.md`).

| Slot | Strategy slug | Card path | Sub-issue | Status | Source location | Notes |
|---|---|---|---|---|---|---|
| S01 | `lien-multi-time-frame` | n/a | n/a | **SKIP_METHODOLOGY (h5)** | Ch 8 PDF pp. 91-99 | Lien Ch 8 confirms survey-pass prediction: methodology-only, NO mechanical entry/exit rule list. Lien provides 3 narrative examples (USDJPY RSI<30 in uptrend; USDCAD Fibonacci-retracement bounce; CHFJPY multi-frame downtrend confirmation) but no numerical rule set. The methodology UNDERPINS the technical chapters (Ch 9-16) which operationalize "trend on D1 + entry on H1/M15" into specific rule sets — those chapters became S02a-S09. Per Rule 1, SKIP_METHODOLOGY (no standalone mechanical strategy to extract). Documented in § 6.5.3 + completion-report. |
| S02a | `lien-dbb-pick-tops` | `cards/lien-dbb-pick-tops_card.md` | TBD | DRAFT (h2) | Ch 9 PDF pp. 103-107 | Double BB **range-mode** mean-reversion entry (close back across 1st-σ band after outer-band-zone dwell). Vocab gap: proposes `bband-reclaim` flag. |
| S02b | `lien-dbb-trend-join` | `cards/lien-dbb-trend-join_card.md` | QUA-341 | DRAFT (h2) | Ch 9 PDF pp. 107-110 | Double BB **trend-mode** trend-join entry (close back across 1st-σ band after K-bar opposite-side dwell). Sibling of S02a; shares proposed `bband-reclaim` flag with `precondition_mode=n-bars-opposite-1sigma`. Co-regime-fire suppression vs S02a documented in card § 6. |
| S03 | `lien-fade-double-zeros` | `cards/lien-fade-double-zeros_card.md` | TBD | DRAFT (h2) | Ch 10 PDF pp. 112-115 | Round-number psychological-level fade (M15, 20MA counter-trend filter, 10-15-pip entry offset, 20-pip stop). Vocab gap: proposes `round-num-fade` flag. |
| S04 | `lien-waiting-deal` | `cards/lien-waiting-deal_card.md` | TBD | DRAFT (h4) | Ch 11 PDF pp. 117-121 | London-open opening-range false-breakout fade (M5-M15). 06:00-07:00 GMT range definition + post-07:00 spike-through-and-reverse + entry at OPPOSITE range extreme + 10p offset; 35p stop, TP1=+50p partial, TP2=+3R fixed. GBPUSD-specific per Lien's UK-dealer-stop-hunt thesis (default symbol filter at first deployment). Reuses `intraday-session-pattern` flag (V4 SilverBullet + ProGo precedent) with card-level `entry_pattern = "opening-range-false-breakout-fade"`. NO vocab gap. Two source-text wording inconsistencies in long-side rules 1+5 reverse-engineered from short-side mirrors + Fig 11.3 example. |
| S05 | `lien-inside-day-breakout` | `cards/lien-inside-day-breakout_card.md` | TBD | DRAFT (h3) | Ch 12 PDF pp. 123-127 | Multi-inside-day volatility-compression breakout (D1). Bracket stop-buy/sell at prev-inside-day extremes ±10p; stop-and-reverse at nearest-inside-day opposite extreme ±10p (Lien rule 3, 2-lot reversal exposed as P3 variant only — `risk_mode_dual` flagged). TP1=2R + BE move + 2-bar trail. Reuses `narrow-range-breakout` flag with card-level `range_contraction_pattern = "consecutive-inside-days"` parameter; no vocab gap. |
| S06 | `lien-fader` | `cards/lien-fader_card.md` | TBD | DRAFT (h4) | Ch 13 PDF pp. 129-133 | ADX(14)<20 prior-day-range false-breakout fade (D1 setup + H1 entry). DISTINCT from SRC03_S10 williams-spec-trap on FOUR axes: (1) regime (Lien range-bound low-ADX vs Williams strong-uptrend), (2) range-window (Lien single prior-day vs Williams 6-20-day box), (3) reference price (Lien opposite-side prior-day extreme vs Williams true-low of breakout day), (4) stop sizing (Lien 20p fixed vs Williams variable). Both share `failed-breakout-fade` flag with card-level `pre-breakout-regime` parameter. NO vocab gap; ADX-regime-gate pattern noted in § 16 as future-vocab-watch (defer to SRC05+ if pattern recurs). |
| S07 | `lien-20day-breakout` | `cards/lien-20day-breakout_card.md` | TBD | DRAFT (h3) | Ch 14 PDF pp. 135-138 | Failed-pullback continuation 20-day breakout (D1). 3-state machine: ARMED_SCAN (20-day extreme) → ARMED_PULLBACK (2-day opposite extreme within 1 bar) → ARMED_REBREAK (re-break within 3 bars). Initial stop a few pips beyond pullback extreme; TP1=1R + BE + 2-bar-extreme trail. Reuses `donchian-breakout` flag with card-level `pre-breakout-pullback-required = true` parameter; **first canonical Donchian-family card** in the SRC corpus. No vocab gap. |
| S08 | `lien-channels` | `cards/lien-channels_card.md` | TBD | DRAFT (h4) | Ch 15 PDF pp. 139-141 | Narrow-channel breakout (M15 default; multi-TF). N-bar rolling high/low + width threshold + bracket stop-orders at channel ±10p; conservative TP1+BE+trail (default per Lien commentary on risk>20p) or full 2R exit (P3 variant matching Lien rule 4). Lien's verbose "trendline + parallel line" framing reduced to horizontal n-bar range per all 3 worked examples (sloped linear-regression channel exposed as P3 variant). SECOND `narrow-range-breakout` card alongside SRC04_S05; distinguished by `range_definition` parameter. NO vocab gap. **`news_pause_default` interaction**: Lien explicitly favors pre-economic-release entry (PDF p. 139); V5 default P8 applies, pre-news arming exposed as P3 sweep variant for thesis-validation. |
| S09 | `lien-perfect-order` | `cards/lien-perfect-order_card.md` | TBD | DRAFT (h5) | Ch 16 PDF pp. 143-148 | 5-MA monotonic-stack entry on D1 (10>20>50>100>200 SMAs for longs; reverse for shorts). Entry 5 candles after initial formation if stack still holds + ADX>20 confirmation. Stop = formation-bar extreme with safe-SMA-20 fallback when too-tight. Exit on first-adjacent-pair break (10-vs-20 SMA cross). Multi-month holds (Lien examples 2.5-5 months). **Vocab gap PROPOSED**: `ma-stack-entry` — 5-MA sequential-monotonic-stack as ENTRY trigger, distinct from `trend-filter-ma` (single MA OVERLAY filter). Future-vocab-watch reinforced for `adx-trend-confirm-gate` + `adx-range-mr-gate` (paired symmetric flags; defer to SRC05+). `friday_close` LOAD-BEARING (multi-month hold; waiver candidacy at P3). |
| S10 | `lien-strong-vs-weak` | n/a | n/a | **SKIP_DISCRETIONARY (h5)** | Ch 17 PDF pp. 149-152 | Lien Ch 17 confirms survey-pass prediction: discretionary observational with NO quantifiable strength/weakness scoring system. Lien gives 3 narrative case studies (EUR-QE → sell EURGBP near 0.74 resistance; oil-up + NZ-weak-data → sell NZDCAD; data-surprise dynamic → buy EURUSD breakout) and notes "the best way to gauge strong versus weak is to monitor economic data surprises" (PDF p. 152) — but provides no scoring formula or threshold. Mechanical translation would require inventing a strength-scoring system Lien did not provide; violates "concept is mechanical" V5 hard rule per DL-033 Rule 1. The data-surprise hint also points to external data feeds (e.g., Citi Economic Surprise Index) NOT in Darwinex feed → `darwinex_native_data_only` would BIND. Compound rationale: SKIP_DISCRETIONARY (primary) + SKIP_DARWINEX_NATIVE (secondary). Documented in completion-report. |
| S11 | `lien-carry-trade` | `cards/lien-carry-trade_card.md` | TBD | DRAFT (h5) | Ch 18 PDF pp. 153-160 | Carry-direction signal (sign of IR-differential via Darwinex-native SymbolInfoDouble swap reads) + bond-yield-spread risk-aversion gate (Lien Figure 18.4 3-state classification, REQUIRES external 10Y bond-yield feed) + 6-month minimum hold (Lien explicit) + signal-reversal exit on carry-flip OR risk-aversion-HIGH crossover. **FIRST CARRY-FAMILY CARD across the entire SRC corpus** (V4 SM_076 / SM_1341-1343 / Good-Carry-Bad-Carry inspiration spec precedent). Reuses existing `carry-direction` flag — NO vocab gap. **`darwinex_native_data_only` LOAD-BEARING** for risk-aversion gate (external bond yields); CTO IMPL paths: (a) FRED API shim, (b) Darwinex bond-CFD proxy, (c) degraded carry-direction-only variant. **`friday_close` STRONGEST waiver case in SRC04** — Lien thesis itself REQUIRES multi-month hold. Future-vocab-watch noted for `yield-spread-regime-filter` if pattern recurs in S14 (Ch 22 Bond-Spread leading indicator) or SRC05+. |
| S12 | `lien-macro-event` | n/a | n/a | **SKIP_DISCRETIONARY (h6)** | Ch 19 PDF pp. 161-168 | Lien Ch 19 confirms survey-pass prediction: discretionary observational with 5 historical case studies (Ukraine-Russia 2014, EU sovereign debt 2009-13, GFC 2008, 2004 election, 2003 G7 Dubai, Iraq war). Lien provides a "list of important events to know" (G7 meetings, elections, central bank meetings, currency regime changes, debt defaults, geopolitical wars, Fed semi-annual testimony) but NO mechanical entry/exit rule list. Macro events are irregular, magnitude-uncertain, sentiment-direction discretionary. Per Rule 1 + BASIS rule, no extractable strategy. Documented in completion-report. |
| S13 | `lien-commodity-leading` | n/a | n/a | **SKIP_UNDERSPEC (h6)** | Ch 21 PDF pp. 177-180 | Lien Ch 21 provides specific CORRELATION magnitudes (gold ↔ AUDUSD r=0.83 / 2010-2015; oil ↔ CADUSD r=0.67 / medium-term; gold ↔ CADUSD r=0.67) and identifies cohort (AUD/gold, CAD/oil, NZD/dairy, AUD/iron-ore) but provides NO mechanical entry/exit rule list. The "Trading Opportunity" section (PDF p. 180) is descriptive: "commodity bloc traders should monitor gold and oil prices to help determine where these currencies are headed" — no signal threshold, no entry timing, no stop, no time horizon. Mechanical translation would require Research-extrapolation across all of (1) signal lookback period, (2) correlation z-score gate, (3) entry trigger formula, (4) stop placement, (5) exit logic — exceeds BASIS rule tolerance. Per Rule 1, source-spec-completeness fails → SKIP_UNDERSPEC. Note: commodity CFDs (XAU.DWX, OIL.DWX) ARE Darwinex-native, so no `darwinex_native_data_only` block — the SKIP is purely on rule-list completeness. |
| S14 | `lien-bond-spread-leading` | n/a | n/a | **SKIP_UNDERSPEC (h6)** | Ch 22 PDF pp. 181-185 | Lien Ch 22 provides yield-spread definition (10Y differential between two countries), 3 worked examples (EURUSD/Bund-UST, GBPUSD/Gilt-UST, AUDNZD/AU-NZ 10Y), and "rule of thumb" (PDF p. 184: "when there is a big move in the yield spread, it will coincide with a big move in the currency pair; and if that hasn't happen, then it signals an imminent move in the pair") — but NO specific threshold for "big move", NO entry timing, NO stop, NO time horizon. Same source-spec-completeness gap as S13. Plus: 10Y bond yields are NOT Darwinex-native (`darwinex_native_data_only` would BIND, same dependency as S11 carry-trade risk-aversion gate). Compound rationale: SKIP_UNDERSPEC (primary) + secondary `darwinex_native_data_only` risk if extraction were attempted. Future-vocab-watch for `yield-spread-regime-filter` defers to SRC05+ (was S11+S14 paired anchor; loses S14 anchor but S11 deployment will still trigger watch if it ships). |
| S15 | `lien-risk-reversals` | n/a | n/a | **KILL_PRE_P1 (h6)** | Ch 23 PDF pp. 187-190 | Lien Ch 23 confirms survey-pass prediction: KILL on `darwinex_native_data_only` hard rule. Strategy uses extreme +/- 1σ risk-reversal-value (25-delta FX options skew) as overbought/oversold contrarian signal. Lien EXPLICITLY references the data source (PDF p. 187): "FXCM News Plugin, under options, or on the Bloomberg/Reuters terminals" — institutional-only data ($1500/month Bloomberg Terminal per Lien Ch 7 PDF p. 83). NOT in Darwinex CFD feed; no Darwinex-native proxy exists for FX options skew. Hard-rule block. KILL_PRE_P1 with documented rationale. |
| S16 | `lien-option-vols` | n/a | n/a | **KILL_PRE_P1 (h6)** | Ch 24 PDF pp. 191-194 | Lien Ch 24 confirms survey-pass prediction: KILL on `darwinex_native_data_only` hard rule. Strategy: 1-month implied vol < 3-month implied vol → expect breakout; 1-month vol > 3-month vol → expect reversion-to-range. Requires implied 1-month + 3-month FX option volatilities. Lien EXPLICITLY references data source (PDF p. 194): "Volatilities can be found on Bloomberg or Reuters" — institutional-only. NOT in Darwinex CFD feed; realized-vol-on-spot is computable from price history but is a DIFFERENT signal than implied-vol-from-options. Hard-rule block. KILL_PRE_P1 with documented rationale. |
| S17 | `lien-intervention` | n/a | n/a | **SKIP_DISCRETIONARY (h6)** | Ch 25 PDF pp. 195-202 | Lien Ch 25 confirms survey-pass prediction: 4 historical case studies (BoJ Oct 2011, BoJ Aug 2011, BoJ Mar 2011 coordinated, BoJ Sep 2015, SNB EURCHF 1.20 peg break Jan 2015). Lien provides a vague "trade one of two ways — ride the move on the day of intervention or fade it in the days that follow. The key is not to be greedy" (PDF p. 197) but no mechanical entry/exit rules. Central-bank intervention is rare, irregular, magnitude-uncertain, and event-driven (P8 News Impact incompatible). Plus the SNB peg break Jan 2015 caused a 30% one-day decline that bankrupted multiple FX brokers — a genuine kill-switch event, not a mechanical-trade opportunity. NOT mechanical. SKIP_DISCRETIONARY with documented rationale. |

Slot count finalized at first-pass survey: **17 candidates** (with S02 splitting into S02a + S02b → 18 candidate cards possible). Cards-vs-fold and ESCALATE_NO_CARD verdicts pending per-chapter extraction (initial verdicts crystallized in § 6.5 below following h1 chapter validation read).

### h2 progress log (2026-04-28)

First-pass extraction batch closed the highest-rule-density technical chapters — **3 cards drafted** in h2 vs the 1.0-1.5 cards/heartbeat target stated in QUA-333 (matching the heartbeat budget pace). S02 split into S02a + S02b confirmed (Lien Ch 9 has explicitly distinct rule lists for the range-mode and trend-join variants — see § 6.5.1 prediction validated at extraction). Cards committed:

- **SRC04_S02a** `lien-dbb-pick-tops` (Ch 9 PDF pp. 103-107 § "Pick Tops and Bottoms") — range-mode mean-reversion. Long stop 50 pips below 1st-σ band; short stop 30 pips above (Lien's verbatim asymmetry preserved as P3 sweep axis since the worked example uses 30 pips for both).
- **SRC04_S02b** `lien-dbb-trend-join` (Ch 9 PDF pp. 107-110 § "Join a New Trend") — trend-join breakout. Fixed 65-pip initial stop, 50-pip TP1, 195-pip TP2 (3.0R fat-tail TM).
- **SRC04_S03** `lien-fade-double-zeros` (Ch 10 PDF pp. 112-115) — round-number psychological-level fade with 20-period SMA counter-trend filter on M15. `scalping_p5b_latency` flagged for IMPL despite M15 bar size (tight 20-pip stops are latency-sensitive).

### h3 progress log (2026-04-28)

Continuation of first-pass technical block — **2 cards drafted** in h3 (S05 + S07), bringing SRC04 cumulative to 5 cards / 3 heartbeats = **1.67 cards/heartbeat throughput**. This places SRC04 between SRC02 Chan (1.0 cards/heartbeat methodology-heavy) and SRC03 Williams (2.33 cards/heartbeat ceiling rule-tight) — within the 1.0-1.5 card/heartbeat target band stated in QUA-333, leaning toward the upper end of the band. Cards committed:

- **SRC04_S05** `lien-inside-day-breakout` (Ch 12 PDF pp. 123-127) — multi-inside-day volatility-compression breakout on D1. Bracket-and-reverse logic (Lien rule 3) with stop-and-reverse at opposite-extreme + 10p offset. Reuses existing `narrow-range-breakout` flag with card-level parameter `range_contraction_pattern = "consecutive-inside-days"` rather than proposing a new sub-flag. **NO vocab gap proposed**. Two hard-rules-at-risk surface: (a) `risk_mode_dual` for the Lien-verbatim 2-lot reversal variant — card defaults to 1-unit (V5-compliant) and exposes 2-unit only as a P3 sweep variant for CTO ratification if it outperforms; (b) `friday_close` load-bearing — D1 swing with multi-day-to-multi-week holds (Lien EURGBP example PDF p. 125 holds "three weeks"), waiver candidacy at P3 mirroring SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb precedent.
- **SRC04_S07** `lien-20day-breakout` (Ch 14 PDF pp. 135-138) — failed-pullback continuation 20-day breakout on D1. Reuses existing `donchian-breakout` flag with card-level parameter `pre-breakout-pullback-required = true`. **First canonical Donchian-family card across the entire SRC corpus** (V4 Modernised Turtle was an inspiration spec, not a deployed EA). 3-state-machine entry pattern (ARMED_SCAN → ARMED_PULLBACK → ARMED_REBREAK) is the FIRST multi-state entry pattern in SRC cards — all prior cards used single-bar entry triggers; CTO will need to validate state-machine bookkeeping at IMPL. **NO vocab gap proposed**. Hard-rules-at-risk: `friday_close` load-bearing (multi-day-to-multi-week holds per Lien EURUSD example trail to 1.1846), waiver candidacy at P3.

**Cumulative vocabulary-gap status**: 2 proposed flags (`bband-reclaim` from S02a/S02b, `round-num-fade` from S03) batched at SRC04 closeout; h3 added zero new gaps (S05 reused `narrow-range-breakout`, S07 reused `donchian-breakout` — both with card-level parameterization rather than sub-flag proliferation). Roll-up table in § 8.5 unchanged.

**Next heartbeat (h4)**: continue first-pass technical block — S04 `lien-waiting-deal` (Ch 11 patience pullback entry, PDF pp. 117-121), S06 `lien-fader` (Ch 13 ADX<20 false-breakout fade, PDF pp. 129-133, check overlap with SRC03_S10 williams-spec-trap), S08 `lien-channels` (Ch 15 channel-trade pattern, PDF pp. 139-141), and/or S09 `lien-perfect-order` (Ch 16 multi-MA stack filter + entry, PDF pp. 143-147) — target 2-3 cards per QUA-333 throughput band.

### h4 progress log (2026-04-28)

Continuation of first-pass technical block — **3 cards drafted** in h4 (S04 + S06 + S08), bringing SRC04 cumulative to 8 cards / 4 heartbeats = **2.0 cards/heartbeat throughput**. This now exceeds the 1.0-1.5 cards/heartbeat target band stated in QUA-333 and approaches SRC03 Williams' 2.33 ceiling — Lien's chapter-per-strategy structure with explicit rule lists has proved more rule-tight than the QUA-333 prediction anticipated. Cards committed:

- **SRC04_S04** `lien-waiting-deal` (Ch 11 PDF pp. 117-121) — London-open opening-range false-breakout fade on M5-M15. GBPUSD-specific per Lien's UK-dealer-stop-hunt thesis. Reuses `intraday-session-pattern` flag (V4 SilverBullet + ProGo precedent) with card-level parameter for the opening-range-false-breakout-fade variant. Two source-text wording inconsistencies in long-side rules 1+5 documented and reverse-engineered from short-side mirrors + Fig 11.3 worked example. **NO vocab gap**.
- **SRC04_S06** `lien-fader` (Ch 13 PDF pp. 129-133) — ADX(14)<20 prior-day-range false-breakout fade on D1-setup + H1-entry frame. **CRITICAL DISAMBIGUATION**: distinct from SRC03_S10 `williams-spec-trap` on FOUR structural axes — regime (Lien range-bound low-ADX vs Williams trending), range-window (Lien single prior-day vs Williams 6-20-day box), reference price (Lien opposite-side prior-day extreme vs Williams true-low of breakout day), stop sizing (Lien 20p fixed vs Williams variable). Both share `failed-breakout-fade` flag with card-level `pre-breakout-regime` parameter; NO vocab gap. ADX-regime-gate pattern noted in card § 16 as future-vocab-watch (`adx-range-mr-gate` symmetric to existing `atr-regime-mr-gate`) — defer to SRC05+ if pattern recurs.
- **SRC04_S08** `lien-channels` (Ch 15 PDF pp. 139-141) — narrow-channel breakout on M15 (default; multi-TF support). SECOND `narrow-range-breakout` card alongside SRC04_S05, distinguished by `range_definition` parameter (`n-bar-horizontal-range` vs `consecutive-inside-days`). Lien's verbose "trendline + parallel line" framing reconciled with worked examples: card adopts horizontal n-bar range as default, exposes sloped linear-regression channel as P3 variant. **`news_pause_default` interaction**: Lien explicitly favors pre-economic-release entry (PDF p. 139); V5 default P8 applies, pre-news arming exposed as P3 sweep variant for thesis-validation. NO vocab gap.

**Cumulative vocabulary-gap status**: 2 proposed flags (`bband-reclaim`, `round-num-fade`) batched at SRC04 closeout; h4 added zero new gaps. Future-vocab-watch noted in S06 § 16 for `adx-range-mr-gate` (defer to SRC05+ for deployment-precedent confirmation). Roll-up table in § 8.5 unchanged.

**Hard-rules-at-risk surfaced in h4**:
- S04: `scalping_p5b_latency` (M5 spike-detection at intra-bar high/low; latency-sensitive even at M5 bar size), `enhancement_doctrine` (session-window times + pip thresholds GBPUSD-calibrated; cross-pair generalization needs P3 axes).
- S06: `scalping_p5b_latency` (H1 entry frame + 20p stops + spike-detection edge), `enhancement_doctrine` (5p / 20p offsets major-FX-calibrated).
- S08: `news_pause_default` POTENTIALLY load-bearing (Lien favors pre-news entry; default V5 P8 applies, P3 variant for thesis-validation), `scalping_p5b_latency` (narrow-channel variants — EURGBP example 12-pip range = 22p risk after offset, single-digit pip-tolerance for VPS latency), `enhancement_doctrine` (10p offset + 10-30p width thresholds).

**Architecture observations (h4)**:
- S04 + S06 both use multi-frame state machines (S04: M5 session window + post-spike entry; S06: D1 ADX + prev-day H/L + H1 entry). These are the SECOND and THIRD multi-frame state-machine cards in SRC04 alongside h3's S07 (D1 ARMED_SCAN → ARMED_PULLBACK → ARMED_REBREAK).
- S08 reuses `narrow-range-breakout` flag for the SECOND time in SRC04 (after S05). Card-level parameterization (`range_definition` family) is now established as the SRC04 convention for distinguishing range-contraction sub-variants without proliferating sub-flags.
- S06's distinctness from SRC03_S10 williams-spec-trap (despite both being `failed-breakout-fade`) demonstrates that the controlled-vocabulary framework supports meaningful structural disambiguation via card-level parameters — the four-axis distinction (regime + range-window + reference-price + stop-sizing) is captured via parameters, not flag proliferation.

**Status**: `extraction_pass_status: first_pass_partial` (8/9-12 forecast cards); QUA-333 stays `in_progress`; no CEO action needed between now and h5.

**Next heartbeat (h5)**: technical block closeout — S09 `lien-perfect-order` (Ch 16 PDF pp. 143-147, multi-MA stack entry — vocab-gap candidate `ma-stack-entry`); S01 `lien-multi-time-frame` (Ch 8 verdict — likely SKIP_METHODOLOGY per § 6.5.3). Then begin fundamental block: S11 `lien-carry-trade` (Ch 18 carry-direction ranking — high-confidence-PASS per § 6.5.2), S10 `lien-strong-vs-weak` (Ch 17 verdict — likely SKIP_DISCRETIONARY), S13 `lien-commodity-leading` (Ch 21 borderline — Darwinex commodity-CFD check). Target 2-3 cards in h5.

### h5 progress log (2026-04-28)

Technical-block CLOSEOUT + fundamental-block START — **2 cards drafted + 2 SKIPs** in h5, bringing SRC04 cumulative to 10 cards / 5 heartbeats = **2.0 cards/heartbeat throughput** (sustained from h4). Verdicts:

- **SRC04_S09** `lien-perfect-order` (Ch 16 PDF pp. 143-148) DRAFT — 5-MA monotonic-stack entry on D1 with ADX>20 trend-confirmation + 5-candle entry delay + formation-bar-extreme stop with safe-SMA-20 fallback + signal-reversal exit on first-adjacent-pair break. Multi-month holds (Lien examples 2.5-5 months). **NEW VOCAB GAP PROPOSED**: `ma-stack-entry` — K-MA sequential-monotonic-stack as ENTRY trigger; distinct from existing `trend-filter-ma` (single MA OVERLAY filter). V4 had no equivalent SM_XXX EA. Roll-up table (§ 8.5) updated; total proposed gaps now 3.
- **SRC04_S11** `lien-carry-trade` (Ch 18 PDF pp. 153-160) DRAFT — **FIRST CARRY-FAMILY CARD across the entire SRC corpus**. Carry-direction signal via Darwinex-native SymbolInfoDouble swap reads + bond-yield-spread risk-aversion gate (Lien Figure 18.4 3-state classification, REQUIRES external bond-yield feed — `darwinex_native_data_only` LOAD-BEARING) + 6-month minimum hold (Lien explicit) + signal-reversal exit. Reuses existing `carry-direction` flag (V4 SM_076 / SM_1341-1343 / Good-Carry-Bad-Carry precedent) — NO new vocab gap. **STRONGEST `friday_close` waiver case in SRC04** since Lien thesis itself REQUIRES multi-month hold.
- **SRC04_S01** `lien-multi-time-frame` (Ch 8 PDF pp. 91-99) **SKIP_METHODOLOGY** — confirmed survey-pass prediction (§ 6.5.3). Lien Ch 8 provides 3 narrative examples but NO mechanical entry/exit rule list. The methodology UNDERPINS the technical chapters Ch 9-16 which were operationalized as S02a-S09. Per Rule 1, no standalone mechanical strategy to extract. Slot table updated.
- **SRC04_S10** `lien-strong-vs-weak` (Ch 17 PDF pp. 149-152) **SKIP_DISCRETIONARY** — confirmed survey-pass prediction (§ 6.5.2). Lien Ch 17 provides 3 narrative case studies but NO quantifiable strength/weakness scoring system. Lien's "monitor economic data surprises" hint (PDF p. 152) points to external data feeds (e.g., Citi Economic Surprise Index) NOT in Darwinex feed → `darwinex_native_data_only` would BIND as secondary rationale. Compound SKIP rationale documented in slot table + completion-report.

**Cumulative vocabulary-gap status**: 3 proposed flags (`bband-reclaim`, `round-num-fade`, `ma-stack-entry`) batched at SRC04 closeout. Roll-up table in § 8.5 updated. Future-vocab-watch reinforced: `adx-trend-confirm-gate`+`adx-range-mr-gate` (paired symmetric ADX-regime flags), `yield-spread-regime-filter` (bond-yield-spread regime classifier) — both deferred pending more deployment evidence.

**Hard-rules-at-risk surfaced in h5**:
- S09: `friday_close` LOAD-BEARING (multi-month hold, fourth+ such card in SRC04); `enhancement_doctrine` (MA periods 10/20/50/100/200 + ADX-threshold 20 are textbook-canonical defaults but P3-tunable).
- S11: `friday_close` STRONGEST-IN-SRC04 (Lien thesis REQUIRES multi-month hold — strongest waiver case across all SRC04 cards); `darwinex_native_data_only` LOAD-BEARING (bond-yield-feed dependency for risk-aversion gate; CTO IMPL paths documented); `enhancement_doctrine` (IR + bond-yield thresholds heuristic).

**Architecture observations (h5)**:
- S09 + S11 are the FOURTH + FIFTH multi-state-machine entry pattern cards in SRC04 (after h3-S07, h4-S04, h4-S06). State-machine entries are now CONFIRMED as the SRC04-distinctive architectural signature.
- S11 introduces the FIRST CARRY-FAMILY card (vs prior SRC technical-pattern-only cards) and the SECOND `darwinex_native_data_only` flag-binding (after the predicted Ch 22 Bond Spreads issue from § 6.5.2).
- 2 of 8 surveyed slots SKIPPED in h5 (S01 + S10) — both confirmed survey-pass predictions. Forecast yield ratio narrowing toward the high-confidence side: 10 drafts + 2 SKIPs from 17 surveyed = 59% draft yield to date; remaining 5 fundamental-block slots (S12/S13/S14/S15/S16/S17) include high SKIP/KILL probability per § 6.5.2.

**Status**: `extraction_pass_status: first_pass_partial` (10/9-12 forecast cards = at the LOWER bound of forecast; technical block COMPLETE); QUA-333 stays `in_progress`; no CEO action needed between now and h6.

**Next heartbeat (h6)**: continue fundamental-block extraction:
- S13 `lien-commodity-leading` (Ch 21 PDF pp. 177-180) — borderline-mechanization per § 6.5.2; check if commodity-correlation gate has Darwinex-native path (XAU/XAG/USOIL CFDs likely available)
- S14 `lien-bond-spread-leading` (Ch 22 PDF pp. 181-186) — borderline; `darwinex_native_data_only` check for bond-yield feed (same dependency as S11; if S11 path resolved, S14 piggybacks)
- S12 `lien-macro-event` (Ch 19 PDF pp. 161-168) — likely SKIP_DISCRETIONARY per § 6.5.2
- S15 `lien-risk-reversals` (Ch 23 PDF pp. 187-190) — likely KILL_PRE_P1 per § 6.5.2 (FX options skew not in Darwinex feed)
- S16 `lien-option-vols` (Ch 24 PDF pp. 191-194) — likely KILL_PRE_P1 per § 6.5.2 (FX options vol not in Darwinex feed)
- S17 `lien-intervention` (Ch 25 PDF pp. 195-202) — likely SKIP_DISCRETIONARY per § 6.5.2

Target h6: 1-2 DRAFTS (likely S13, possibly S14) + 4 SKIPs/KILLs (S12, S15, S16, S17). Then h7 (or h6 if budget permits): closeout — completion_report.md + sub-issues opened sequentially per DL-029.

### h6 progress log (2026-04-28) — first-pass extraction COMPLETE

Fundamental-block CLOSEOUT: **0 cards drafted + 6 SKIPs/KILLs**. SRC04 first-pass extraction is COMPLETE at 10 cards / 18 surveyed slots = 56% draft yield (lower-third of § 6.5.4 forecast 53-71%). Budget: 6 heartbeats / 10 cards = 1.67 cards/heartbeat aggregate (peaked at 2.0 in h4-h5; SRC03 ceiling was 2.33). H6 verdicts:

- **SRC04_S12** `lien-macro-event` (Ch 19 PDF pp. 161-168) **SKIP_DISCRETIONARY** — confirmed survey-pass prediction. 5 historical case studies (Ukraine 2014, EU sov-debt 2009-13, GFC 2008, 2004 election, 2003 G7 Dubai) but no mechanical rule list; macro events irregular + sentiment-direction discretionary.
- **SRC04_S13** `lien-commodity-leading` (Ch 21 PDF pp. 177-180) **SKIP_UNDERSPEC** — Lien provides correlation magnitudes (gold↔AUDUSD 0.83, oil↔CADUSD 0.67) and cohort identification but NO entry/exit rules; mechanical translation would require Research-extrapolation across 5 dimensions (signal lookback, z-score gate, entry trigger, stop placement, exit logic) exceeding BASIS-rule tolerance. Note: commodity CFDs ARE Darwinex-native, so SKIP is purely on rule-list completeness, NOT data-feed.
- **SRC04_S14** `lien-bond-spread-leading` (Ch 22 PDF pp. 181-185) **SKIP_UNDERSPEC** — Lien provides yield-spread definition + 3 worked examples + "rule of thumb" but no specific thresholds/timing/stops. Same source-spec gap as S13 PLUS secondary `darwinex_native_data_only` risk if extracted (10Y bond yields not in Darwinex feed; same dependency as S11).
- **SRC04_S15** `lien-risk-reversals` (Ch 23 PDF pp. 187-190) **KILL_PRE_P1** — confirmed survey-pass prediction. 25-delta FX options skew data is institutional-only ($1500/mo Bloomberg per Lien Ch 7 PDF p. 83). NOT in Darwinex CFD feed; no Darwinex-native proxy. `darwinex_native_data_only` hard-rule block.
- **SRC04_S16** `lien-option-vols` (Ch 24 PDF pp. 191-194) **KILL_PRE_P1** — confirmed survey-pass prediction. 1-month + 3-month implied FX option volatilities institutional-only. NOT in Darwinex feed; realized-vol on spot prices is a DIFFERENT signal. `darwinex_native_data_only` hard-rule block.
- **SRC04_S17** `lien-intervention` (Ch 25 PDF pp. 195-202) **SKIP_DISCRETIONARY** — confirmed survey-pass prediction. 4 case studies (BoJ 2011 multiple, BoJ 2015, SNB 1.20 EURCHF peg break Jan 2015 — 30% one-day decline that bankrupted FX brokers). Lien gives vague "ride or fade" guidance with no rules. Rare, irregular, magnitude-uncertain, news-driven; SNB peg break is a kill-switch event, not a trade opportunity.

**Final SRC04 yield breakdown (10 DRAFT / 18 surveyed)**:
- 10 DRAFT for CEO + Quality-Business G0 review
- 6 SKIPs (S01 methodology, S10 + S12 + S17 discretionary, S13 + S14 underspec)
- 2 KILLs (S15 + S16 — both `darwinex_native_data_only` BIND on FX options data)

**Comparison to predecessor sources**:

| Source | Drafts / Surveyed | Yield % | Heartbeats / Drafts | Cards/HB |
|---|---|---|---|---|
| SRC01 Davey | 5 / 5 | 100% | 5 / 5 | 1.00 |
| SRC02 Chan | 8 / 13 | 62% | 8 / 8 | 1.00 |
| SRC03 Williams | 14 / 15 | 93% | 6 / 14 | 2.33 |
| **SRC04 Lien** | **10 / 18** | **56%** | **6 / 10** | **1.67** |

**Cumulative vocabulary-gap status (3 batched proposals for CEO + CTO ratification at SRC04 closeout)**:
1. `bband-reclaim` (S02a/S02b) — Bollinger-band reclaim mechanism
2. `round-num-fade` (S03) — round-number psychological-level fade
3. `ma-stack-entry` (S09) — K-MA sequential-monotonic-stack entry trigger

Future-vocab-watch (deferred): `adx-trend-confirm-gate` + `adx-range-mr-gate` (paired symmetric ADX-regime flags), `yield-spread-regime-filter` (bond-yield-spread regime classifier).

**Completion report drafted** at `strategy-seeds/sources/SRC04/completion_report.md` per process 13 § Exits.

**Sub-issues opened sequentially per DL-029** — 10 sub-issues under QUA-333 for the 10 DRAFT cards, first-in-sequence as `todo`, rest as `blocked` per workflow.

## 6.5 Survey-pass observations (per-chapter validation read 2026-04-28 h1)

This subsection captures specific findings from the h1 chapter validation read. Verdicts here are **survey-pass predictions**, not extraction-locked decisions. Per Process 13 / DL-033 Rule 1, every distinct mechanical strategy that passes V5 hard rules gets a card; the verdicts below pre-shape extraction sequence + heartbeat budget but do not pre-empt G0 review.

### 6.5.1 Slot table refinements

**S02 (Ch 9 Double Bollinger Bands) likely splits into TWO cards.** Lien's own chapter explicitly subsections the strategy at PDF p. 102-110 with separate "Strategy Rules for Long Trade" and "Strategy Rules for Short Trade" rule lists for two distinct regimes:

- **Ch 9 § "Using Double Bollinger Bands to Pick Tops and Bottoms"** (PDF pp. 102-107) — RANGE / mean-reversion entry. Long: pair trading between lower 1st-σ and 2nd-σ Bollinger bands → close above 1st-σ → buy. Stop 50 pips below 1st-σ. Half off at 1× risk + breakeven; trail rest at 2× risk.
- **Ch 9 § "Using Double Bollinger Bands to Join a New Trend"** (PDF pp. 107-110) — TREND-JOIN / breakout entry. Long: pair closes ABOVE 1st-σ Bollinger band IF prior 2 candles were below 1st-σ band → buy at NY close. 65-pip initial stop; half off at +50 pips + breakeven; second target +195 pips.

These are DISTINCT entry mechanisms reading the SAME indicator (1st-σ Bollinger band) in OPPOSITE directions depending on the regime. Per DL-033 Rule 1 + the SRC03 cards-vs-fold precedent (S02/S03 OOPS! distinguished by reference price = actual vs projected), this is two cards. The current single S02 slot in the table above will likely split to S02a `lien-dbb-pick-tops` + S02b `lien-dbb-trend-join` at first-pass extraction. **Final card count per source moves from 17 → up to 18.**

### 6.5.2 Fundamental-block verdict shaping

Per chapter validation read, the fundamental block (Ch 17-25) crystallizes as follows:

| Slot | Chapter | Verdict prediction | Rationale |
|---|---|---|---|
| S10 | Ch 17 Pairing Strong-with-Weak | **likely SKIP — discretionary** | Lien's process is observational ("Eurozone QE → euro weakness; UK economic improvement → sterling strength → sell EURGBP" — PDF pp. 149-152) with no quantifiable strength/weakness criteria. Mechanical translation would require inventing a strength-scoring system Lien did not provide; violates "concept is mechanical" V5 hard rule. Defer final verdict to extraction — if a clean economic-data-surprise scoring proxy materializes, draft card; else SKIP_DISCRETIONARY. |
| S11 | Ch 18 Leveraged Carry Trade | **PASS — mechanical** | Carry-direction signal (sign of swap differential) + bond-yield-spread risk-aversion gate (Lien Figure 18.4 PDF p. 159 explicit 3-state classification). Maps cleanly to existing `carry-direction` flag (V4 SM_076 / SM_1341-1343 precedent). Darwinex-native (`SymbolInfoDouble(SYMBOL_SWAP_LONG/SHORT)`). |
| S12 | Ch 19 Macro Event Driven Trade | **likely ESCALATE_NO_CARD or SKIP** | Discretionary observational thesis with 5 historical case studies (Ukraine-Russia 2014, EU sovereign debt 2009-13, GFC 2008, 2004 election, 2003 G7 Dubai). No mechanical entry/exit rules; macro-event timing is irregular; sentiment direction is discretionary. Likely SKIP_DISCRETIONARY. |
| S13 | Ch 21 Commodity Prices as Leading Indicator | **borderline — extraction-time mechanization decision** | Lien's framing: "monitor commodity to forecast currency direction" with explicit correlations (gold→AUDUSD r=0.83; oil→CADUSD r=0.67). Mechanical translation attempt: stop-buy/sell currency on N-day commodity-direction signal + correlation-z-score gate. `XAUUSD.DWX` and oil-futures-CFD likely Darwinex-native. If clean pseudocode achievable, draft card; else SKIP_UNDERSPEC with rationale. |
| S14 | Ch 22 Bond Spreads as Leading Indicator | **borderline — Darwinex-native-data check** | 10Y yield-differential leading indicator. Lien provides 3 visual-correlation case studies (German bund − US 10Y → EURUSD; UK gilt − US 10Y → GBPUSD; AU 10Y − NZ 10Y → AUDNZD). **Bond yields NOT in Darwinex-native feed.** CTO consultation at extraction: (a) accept external-data-fetch shim via FRED API; (b) proxy via Darwinex bond CFDs (`US10YR.DWX` if available); (c) SKIP if no Darwinex-native path works. |
| S15 | Ch 23 Risk Reversals | **likely KILL_PRE_P1 — `darwinex_native_data_only` block** | Strategy uses extreme +/- 1σ risk-reversal-value as overbought/oversold signal. **REQUIRES 25-delta option-volatility data** which Lien Ch 7 PDF p. 83 explicitly cites as Bloomberg Terminal ($1500/month) — NOT in Darwinex-native feed. Hard-rule block. Document SKIP rationale at extraction. |
| S16 | Ch 24 Option Volatilities | **likely KILL_PRE_P1 — `darwinex_native_data_only` block** | Strategy: 1m vol < 3m vol → expect breakout; 1m vol > 3m vol → expect reversion-to-range. **REQUIRES 1m + 3m implied option volatilities** — Bloomberg-only per Lien. Hard-rule block. Document SKIP rationale at extraction. |
| S17 | Ch 25 Intervention | **likely SKIP — discretionary** | Lien's 4 case studies (BoJ multi-decade history; SNB EURCHF peg break Jan 2015) are observational. Central-bank intervention is rare, irregular, magnitude-uncertain. NOT mechanical. SKIP_DISCRETIONARY likely; defer to extraction-time confirmation. |

### 6.5.3 Methodology / framework chapter verdict

| Slot | Chapter | Verdict prediction | Rationale |
|---|---|---|---|
| n/a | Ch 7 Trade Parameters for Various Market Conditions | **NOT a card slot — filter framework** | Trade-environment classification (range vs trend via ADX < 20 / > 25 + Bollinger Band width + risk-reversal-near-zero) + trading-journal discipline + risk-management rules. Per DL-033 Rule 1, FILTERS go on individual cards (e.g., S06/S08 ADX-range gate inherits from Ch 7) but Ch 7 itself is not a separate Strategy Card. **No slot in § 6 table.** |
| S01 | Ch 8 Multiple Time Frame Analysis | **likely SKIP — methodology only** | Lien provides USDJPY/USDCAD/CHFJPY narrative examples but NO numerical entry/exit rules. The "buy on RSI<30 in uptrend" idea (PDF pp. 92-93) is methodology-only; the technical chapters that follow (Ch 9-16) operationalize it into specific rule sets. Defer SKIP confirmation to extraction. |

### 6.5.4 Pre-extraction expected card-count summary

Updated from § 4's `expected_strategy_count: 12-17`:

```yaml
expected_strategy_count_post-survey: 9-12
  high-confidence-PASS: 9                     # S02a/S02b (Ch 9 split) + S03/S04/S05/S06/S07/S08/S09 + S11
  borderline-mechanization: 2                 # S13 (commodity-correlation) + S14 (bond-spread; Darwinex-native-data check)
  borderline-discretionary: 1                 # S10 (strong-vs-weak; conditional on inventing scoring system)
  likely-SKIP-discretionary: 3                # S01 (multi-TF methodology) + S12 (macro-event) + S17 (intervention)
  likely-KILL-darwinex-native-data: 2         # S15 (risk-reversals) + S16 (option-vols)
```

**Pre-extraction yield estimate: 9-12 cards from 17 surveyed slots = 53-71%.** Higher than SRC02's 8/13 = 62%; lower than SRC03's 14/15 = 93%. The mid-range yield reflects Lien's intentional mix of mechanical technical strategies (Ch 9-16) with discretionary fundamental commentary (Ch 17, 19, 25) — the technical block is rule-tight; the fundamental block is mostly thesis-and-case-studies. This shape is expected and acceptable; per DL-033 Rule 1, Research extracts what's mechanical, documents what's not, lets the Pipeline gates do the filtering on the rest.

**Filters NOT extracted as separate cards** (Ch 1-7 + Ch 20 + Ch 26-33, integrated into per-card § 6 Filters where applicable):

- Ch 1-4: Market structure / OTC / dealer mechanics (foundational context)
- Ch 5: Most market-moving economic data (P8 News Impact filter context)
- Ch 6: Currency correlations (filter context for S10 strong-vs-weak, S13 commodity-leading, S14 bond-spread)
- Ch 7: Trade parameters for various market conditions (regime-classification — may become a Filter / regime-detector module spec, not a card)
- Ch 20: Quantitative Easing impact on Forex (macro context)
- Ch 26-33: Currency profiles (per-pair context — feeds into per-card "default symbols" decisions)

Per DL-033 Rule 1, FILTERS are documented per-card under § 6 (Filters / No-Trade module) when they bind to a specific entry strategy, not as separate Strategy Cards.

## 7. Chapter index (validated at survey-pass)

Extracted from PDF text dump 2026-04-28. Page numbers are PDF page numbers from the embedded TOC.

| Section | Title | PDF page | Strategy density |
|---|---|---|---|
| Ch 1 | Foreign Exchange — The Fastest Growing Market of Our Time | 1+ | LOW (context) |
| Ch 2 | Historical Events in the FX Markets | 17+ | LOW (context) |
| Ch 3 | What Moves the Currency Market? | 31+ | LOW (filter context) |
| Ch 4 | A Deeper Look at the FX Market | 53+ | LOW (filter context) |
| Ch 5 | What Are the Most Market Moving Economic Data? | 61+ | LOW (filter context — P8 News Impact reference) |
| Ch 6 | What Are Currency Correlations, and How Can We Use Them? | 67+ | LOW (filter context for S10/S13/S14) |
| Ch 7 | Trade Parameters for Various Market Conditions | 73+ | LOW (regime-classification — possible TM-module spec) |
| Ch 8 | Technical Trading Strategy: Multiple Time Frame Analysis | 91+ | **MEDIUM** (S01 — methodology vs strategy TBD) |
| Ch 9 | Technical Strategy: Trading with Double Bollinger Bands | 101+ | **HIGH** (S02 — mechanical cardable) |
| Ch 10 | Technical Trading Strategy: Fading the Double Zeros | 111+ | **HIGH** (S03 — mechanical cardable) |
| Ch 11 | Technical Trading Strategy: Waiting for the Deal | 117+ | **HIGH** (S04 — mechanical cardable) |
| Ch 12 | Technical Trading Strategy: Inside Days Breakout Play | 123+ | **HIGH** (S05 — mechanical cardable) |
| Ch 13 | Technical Trading Strategy: Fader | 129+ | **HIGH** (S06 — mechanical cardable; check overlap with Williams S10) |
| Ch 14 | Technical Trading Strategy: 20-Day Breakout Trade | 135+ | **HIGH** (S07 — `donchian-breakout` flag) |
| Ch 15 | Technical Trading Strategy: Channels | 139+ | **HIGH** (S08 — mechanical cardable) |
| Ch 16 | Technical Trading Strategy: Perfect Order | 143+ | **HIGH** (S09 — multi-MA stack filter + entry) |
| Ch 17 | Fundamental Trading Strategy: Pairing Strong with Weak | 149+ | **HIGH** (S10 — cross-sectional ranking) |
| Ch 18 | Fundamental Trading Strategy: The Leveraged Carry Trade | 153+ | **HIGH** (S11 — IR-differential ranking) |
| Ch 19 | Fundamental Trading Strategy: Macro Event Driven Trade | 161+ | medium (S12 — likely escalate discretionary) |
| Ch 20 | Quantitative Easing and Its Impact on Forex | 169+ | LOW (context) |
| Ch 21 | Fundamental Trading Strategy: Commodity Prices as a Leading Indicator | 177+ | **HIGH** (S13 — leading-indicator cardable) |
| Ch 22 | Fundamental Strategy: Using Bond Spreads as a Leading Indicator for FX | 181+ | **HIGH** (S14 — `darwinex_native_data_only` risk) |
| Ch 23 | Fundamental Trading Strategy: Risk Reversals | 187+ | medium (S15 — `darwinex_native_data_only` likely KILL) |
| Ch 24 | Fundamental Trading Strategy: Using Option Volatilities to Time Market Movements | 191+ | medium (S16 — `darwinex_native_data_only` likely KILL) |
| Ch 25 | Fundamental Trading Strategy: Intervention | 195+ | LOW (S17 — likely escalate discretionary) |
| Ch 26-33 | Currency Profiles (EUR / GBP / CHF / JPY / AUD / NZD / CAD) | 203-268 | LOW (per-pair context) |

Total: 33 chapters; 17 strategy-bearing (Ch 8-19 + 21-25). Strategy-rich span: Ch 9-18 (technical + fundamental core) PDF pp. 101-161.

## 8. Extraction plan

Process 13 / DL-033 / QUA-333 binding constraints:

- One source actively worked at a time. **No SRC05+ until ALL SRC04 sub-issues close.**
- One sub-issue per strategy. First sub-issue `todo`, rest `blocked` per DL-029 sequential chain.
- Heartbeat budget: SRC03 set ceiling at 14 cards / 5 heartbeats = 2.33 cards/heartbeat (rule-tight Williams). SRC04 target 1.0-1.5 cards/heartbeat per QUA-333 prediction (Lien is more textbook-commentary than Williams' rule density, but chapter-per-strategy structure is tight).

Extraction sequence:

1. **First pass — high-prediction technical strategies.** Draft S02 (Double BB), S05 (Inside Day Breakout), S07 (20-Day Breakout). These are the most-likely-to-PASS-G0 mechanical chapters with explicit rules.
2. **Second pass — channel + MA strategies.** Draft S08 (Channels), S09 (Perfect Order), S06 (Fader). Resolve S06↔Williams-S10 overlap.
3. **Third pass — round-number + patience entries.** Draft S03 (Fade Double Zeros), S04 (Waiting for the Deal). Resolve S03 round-number-as-vocab-gap candidacy.
4. **Fourth pass — fundamental cross-sectional.** Draft S10 (Strong vs Weak), S11 (Carry Trade). Cross-sectional ranking parallels with SRC02 chan-decile-sort family (Path 2 architecture).
5. **Fifth pass — leading-indicator family.** Draft S13 (Commodity-leading), S14 (Bond-Spread-leading). `darwinex_native_data_only` flagging at extraction.
6. **Sixth pass — methodology / discretionary verdicts.** Verdict for S01 (Multi-Time-Frame) — methodology vs cardable. Verdict for S12 (Macro Event), S17 (Intervention) — likely ESCALATE non-mechanical. Verdict for S15 (Risk Reversals), S16 (Option Vols) — likely KILL_PRE_P1 on `darwinex_native_data_only`.
7. **Sub-issue creation.** When all candidate cards drafted to DRAFT, open one sub-issue per surviving strategy under QUA-333 — first as `todo`, rest as `blocked`. Submit for CEO + Quality-Business G0 review per process 13.

Per-pass progress comments posted to QUA-333 at pass-boundary granularity. No noise comments on individual cards within a pass.

## 8.5 Vocabulary-gap proposals (batched at SRC04 closeout)

Per QUA-333 process-13 binding constraint and DL-033 Rule 1, all `strategy_type_flags` vocabulary additions surfaced during SRC04 extraction are **batched at closeout** for CEO ratification. Per-card § 16 captures the canonical proposal; this section is the running roll-up for closeout convenience.

| # | Proposed flag | Section | First card | Definition (1-line) | V4 evidence | SRC02/03 disambiguation |
|---|---|---|---|---|---|---|
| 1 | `bband-reclaim` | A. Entry-mechanism | SRC04_S02a `lien-dbb-pick-tops` (also S02b `lien-dbb-trend-join`) | Close back ACROSS N·σ Bollinger band after multi-bar dwell on the OUTER side of the band (price was between Nσ and 2Nσ outer envelope OR below/above Nσ band for K bars, then closes back across the Nσ band). Card-level `precondition_mode ∈ {outer-band-zone, n-bars-opposite-1sigma}` distinguishes the range-MR vs trend-join variants. | None — V4 had no Bollinger-Band-band-reclaim EAs per `strategy_type_flags.md` Mining-provenance table. | Distinct from `zscore-band-reversion` (entry on band CROSS OUT — opposite mechanic; reclaim triggers on RETURN INTO inner zone); `n-period-min-reversion` (uses N-bar minimum extreme, not moving-stdev band). |
| 2 | `round-num-fade` | A. Entry-mechanism | SRC04_S03 `lien-fade-double-zeros` | Stop-buy/stop-sell at fixed pip offset (10-15) from a PSYCHOLOGICAL ROUND-NUMBER price (xx.00 / x.x000), conditioned on counter-trend MA-position filter. Reference price is an ABSOLUTE round-number anchor independent of prior bar's range, prior N-bar extreme, or candle shape. | None — V4 had no round-number-anchored stop-entry EAs per `strategy_type_flags.md` Mining-provenance table. | Distinct from `vol-expansion-breakout` (relative range anchor, not round-number); `gap-fade-stop-entry` (calendar-pattern + gap-through reference); `n-period-min-reversion` (N-bar minimum, not absolute level); `narrow-range-breakout`, `rejection-bar-stop-entry`, `failed-breakout-fade` (each requires bar-internal or multi-bar pattern, not psychological-level anchor). |
| 3 | `ma-stack-entry` | A. Entry-mechanism | SRC04_S09 `lien-perfect-order` | K consecutive moving averages of increasing periods are in MONOTONIC SEQUENTIAL ORDER (long: SMA(P1) > SMA(P2) > ... > SMA(PK) for P1 < P2 < ... < PK; short mirror). Lien's perfect-order canonical case: K=5 with periods (10, 20, 50, 100, 200). Entry fires N candles AFTER initial formation if stack still holds. | None — V4 had no MA-stack-entry EA per `strategy_type_flags.md` Mining-provenance table. V4 had `trend-filter-ma` (SINGLE-MA filter, e.g., Modernised Turtle SMA(200) overlay; Two-Regime Trend-Following BullMA_L=200) — single-MA filter is structurally distinct from K-MA monotonic-stack as ENTRY trigger. | Distinct from `trend-filter-ma` (single MA OVERLAY filter, not entry trigger); `cross-sectional-decile-sort` (universe-ranked relative-strength, not single-instrument MA stack); `donchian-breakout` (N-bar extreme, not MA crossover state); `vol-regime-gate` (vol-bucket classifier, not SMA-based price state); `regime-filter-multi` (multi-feature engineered tree, not single-feature monotonic-stack-state). |

**Future-vocab-watch** (NOT yet proposed; reinforced through h5 — defer to SRC05+ for deployment-precedent confirmation):

- `adx-trend-confirm-gate` + `adx-range-mr-gate` (paired) — ADX-based trend-strength regime gate, symmetric to existing `atr-regime-mr-gate` (which is ATR-percentile-based). Surfaced in SRC04_S06 lien-fader (ADX<20 range-confirmation gate for fade entries) AND SRC04_S09 lien-perfect-order (ADX>20 trend-confirmation gate for trend-join entries). Two SRC04 cards now use ADX-regime gating in opposite directions; if SRC05+ produces a third instance, propose paired flags. For now captured at card-level via filter parameters.
- `yield-spread-regime-filter` — bond-yield-spread-based regime classifier (e.g., 10Y Bund − 10Y US Treasury for risk-aversion proxy). Surfaced in SRC04_S11 lien-carry-trade (Lien Figure 18.4 risk-aversion gate); likely to recur in S14 (Ch 22 Bond-Spread leading indicator) which is NEXT in fundamental block. If S14 confirms recurrence, propose at SRC04 closeout. Distinct from existing `skew-regime-filter` (FX options skew, V4 Good-Carry-Bad-Carry precedent) — bond yields are different data class.

Roll-up updates after each subsequent SRC04 heartbeat; closeout batches all surfaced gaps for single CEO + CTO ratification gate (matching the SRC02 / SRC03 pattern).

## 9. Completion report contract

When all S-sub-issues under QUA-333 close, Research authors `strategy-seeds/sources/SRC04/completion_report.md` covering at minimum:

- Total strategies extracted vs. expected (12-17)
- Per-strategy verdict (PASS_G0 / KILLED_PRE_P1 / ESCALATE_NO_CARD) with terminal pipeline phase
- Skipped strategies (failed V5 hard rule or underspecified-beyond-cardable) and reason
- **Strategy-type-flag distribution** (per `strategy_type_flags.md` controlled vocabulary; cross-walk vs SRC01 + SRC02 + SRC03 distribution to feed `STRATEGY_TYPE_DISTRIBUTION.md`)
- **Architecture-fit profile** — forex-only vs SRC01 process / SRC02 equity-stat-arb / SRC03 futures comparison; predict highest architecture-fit yet (100% target)
- Source quality and density observations
- Yield ratio: `cards_passed_g0 / heartbeats_used` for `budget_tracking` review (SRC03 benchmark: 2.33 cards/heartbeat ceiling)
- Recommendation: deeper mining worthwhile? Move on to SRC05 (TBD per `SOURCE_QUEUE.md` proposed_order #5)?

## 10. Cross-references

- Parent issue: [QUA-333](/QUA/issues/QUA-333)
- Predecessor sources: [QUA-191](/QUA/issues/QUA-191) (SRC01 Davey), [QUA-275](/QUA/issues/QUA-275) (SRC02 Chan), [QUA-298](/QUA/issues/QUA-298) (SRC03 Williams)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md` (T1 Tier A row 4)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-030 (Class 2 Review-only execution policy on Strategy Card child issues)
- DL-032 (CEO Autonomy Waiver v3 — autonomous source-queue ordering)
- DL-033 (extraction-discipline / Rule 1)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`
