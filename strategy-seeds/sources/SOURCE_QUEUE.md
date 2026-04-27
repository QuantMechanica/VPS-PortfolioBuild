---
authored_by: Research Agent
authored_on: 2026-04-27
last_updated: 2026-04-27
parent_issue: QUA-191
status: proposed_for_owner_ceo_ratification
folder_root: G:\My Drive\QuantMechanica\Ebook\PDF resources\
file_count_total: 59
file_count_unique: 53
file_count_duplicates: 6
tier_schema:                                  # OWNER directive 2026-04-27 ~17:28 local — T1/T2/T3 sequential mandate
  T1: curated_local_pdfs                      # 57 PDFs, OWNER-supplied; processed first
  T2: named_public_containers                 # OWNER-named (Babypips, Forex Factory, MQL5, Grimes blog, etc.); processed after T1
  T3: open_internet_autonomous_discovery      # Research finds these itself; processed after T2; steady-state operating mode
v0_filter:
  - mechanical
  - no_ml
  - no_dwx_suffix
  - fits_magic_formula_registry
  - news_compliance_compatible
diversity_bias_rules:                         # per OWNER directive 17:28 — apply when picking next-up source
  - "3+ consecutive trend-following sources queued → next pick must be different class"
  - "3+ from same author → next pick must be different author"
  - "3+ from same source domain → next pick must be different domain"
---

# SOURCE_QUEUE.md — V5 Research source-prioritization queue

OWNER directive on [QUA-191](/QUA/issues/QUA-191) (2026-04-27 ~17:30 local) supersedes the prior single-source SRC01 (Chan, *Algorithmic Trading*) and the prior public-blog pivot (Adam Grimes archive). OWNER has uploaded **59 PDFs** to `G:\My Drive\QuantMechanica\Ebook\PDF resources\`. This file is Research's tiered survey of those 59 files with a proposed extraction order. **It is a proposal — OWNER + CEO ratify the order before SRC01 is opened on a specific source.**

The OWNER constraint is binding:

> *"Each one of them could be 1 research job, don't start too many jobs on research in parallel!"*

→ Research processes ONE source at a time per [QUA-236](/QUA/issues/QUA-236). The 59 PDFs do NOT become 59 parent issues today. CEO opens **one** SRC issue at a time per the ratified order; subsequent SRC issues are opened only after the current SRC's strategies have completed their lifecycle.

## Tier definitions (per `strategy-seeds/cards/_TEMPLATE.md` § 1)

- **A** — peer-reviewed / well-known primary work by a verifiable author.
- **B** — credible practitioner with clear authorship (self-published, blog-aggregated, but reputationally identifiable).
- **C** — uncertain authorship, generic title, or author marked "Unbekannt" / "Owner" / "Telekom" / similar generic. Most `pdfcoffee.com` re-hosts.
- **D** — skip entirely (low-signal duplicates, non-strategy content, beginner-only intro with no extractable mechanical strategies).

## V5 boundary flags

- **`ML_HEAVY`** — dominant content is machine-learning. V5 hard rule `EA_ML_FORBIDDEN`. Book may still yield non-ML strategies; flag indicates extra filter needed.
- **`HFT_NOT_APPLICABLE`** — content is high-frequency-trading. V5 stack (MT5 + DXZ live-only) can't run HFT. Slippage / market-microstructure insights still extractable for [QUA-228](/QUA/issues/QUA-228) calibration JSON.
- **`SCALPING`** — V5 allows but requires P5b VPS-realistic latency stress.
- **`SMC_GANN_ELLIOTT`** — Smart-Money-Concept / Gann / Elliott. V5 has no explicit ban but the V5 hard rule "strategy concept is mechanical (no discretionary judgment)" binds; many of these are pattern-fitting heavy and will likely fail G0 mechanical-only review.
- **`SKIP_DUPLICATE`** — duplicate of another file in this folder; canonical copy noted in row.
- **`SKIP_LOW_SIGNAL`** — Research's discretion: no extractable mechanical strategies expected.

## Strategy-richness estimate (qualitative)

Based on filename + author reputation + file size + Research's prior knowledge of the work. Validated only on actual extraction.

- **HIGH** — well-structured book by a known author with multiple discrete mechanical strategies expected.
- **MED** — practitioner book with at least one full strategy, possibly several.
- **LOW** — beginner intro, generic content, or single niche strategy.
- **SKIP** — flagged as duplicate or low-signal.

---

# T1 — Curated local PDFs (OWNER-supplied)

All rows in the three tables below (Tier A / Tier B / Tier C) are **T1** sources from `G:\My Drive\QuantMechanica\Ebook\PDF resources\`. Per the OWNER 17:28 directive, **T1 is processed first; no T2 / T3 work begins until T1 is drained or partially-exhausted with explicit CEO + OWNER ratification of pivoting.** The proposed_order column applies within T1 only; T2 and T3 have their own ordering once they activate.

## Tier A — peer-reviewed / known-author primary works (proposed_order 1–13)

| # | filename | author | quality_tier | strategy_richness | v5_flags | proposed_order |
|---|---|---|---|---|---|---|
| 1 | `Building Winning Algorithmic Tr - Kevin J. Davey.pdf` | Kevin J. Davey | A | HIGH | — | 1 |
| 2 | `Quantitative Trading_ How to Bu - Ernest P. Chan.pdf` | Ernest P. Chan | A | HIGH | — | 2 |
| 3 | `Long-Term Secrets to Short-Term - Larry R. Williams.pdf` | Larry R. Williams | A | HIGH | — | 3 |
| 4 | `Day Trading and Swing Trading t - Kathy Lien.pdf` | Kathy Lien | A | HIGH | — | 4 |
| 5 | `Algorithmic Trading_ Winning St - Ernie Chan.pdf` | Ernest P. Chan | A | HIGH | — | 5 |
| 6 | `How to Day Trade for a Living - Andrew Aziz.pdf` | Andrew Aziz | A | MED | SCALPING (some setups) | 6 |
| 7 | `Trading Price Action Trading Ra - Al Brooks.pdf` | Al Brooks | A | HIGH | risk_g0_discretionary (most setups need crisp mechanical translation; very large book) | 7 |
| 8 | `The Forex Trading Course_ A Sel - ABE Cofnas.pdf` | Abe Cofnas | A | MED | — | 8 |
| 9 | `An Introduction to Algorithmic - Edward A. Leshik.pdf` | Edward A. Leshik (& Lawrence Cralle) | A | LOW | (academic; strategy density modest) | 9 |
| 10 | `Getting Started With Forex Trad - Alexey Krishtop.pdf` | Alexey Krishtop | A | MED | (large; mixed mechanical / context) | 10 |
| 11 | `High-Frequency Trading_ A Pract - Irene Aldridge.pdf` | Irene Aldridge | A | LOW for V5 strategies | HFT_NOT_APPLICABLE (extract slippage / latency insights for QUA-228 only) | 11 |
| 12 | `Hands-On Machine Learning for A - Stefan Jansen.pdf` | Stefan Jansen | A | LOW for V5 strategies | ML_HEAVY (extract non-ML feature-engineering / regime ideas only) | 12 |
| 13 | `Machine Trading_ Deploying Comp - Ernest P. Chan.pdf` | Ernest P. Chan | A | LOW for V5 strategies | ML_HEAVY (most chapters ML; extract non-ML mechanical bits only) | 13 |

## Tier B — credible practitioner with clear authorship (proposed_order 14–32)

| # | filename | author | quality_tier | strategy_richness | v5_flags | proposed_order |
|---|---|---|---|---|---|---|
| 14 | `Day Trading with the Anti-Clima - Galen Woods.pdf` | Galen Woods | B | MED | (single specific mechanical setup; clean) | 14 |
| 15 | `Become a Price Action Master in - Galen Woods.pdf` | Galen Woods | B | MED | — | 15 |
| 16 | `Mechanical Day Trading Strategi - James Muranno.pdf` | James Muranno | B | MED | (title declares mechanical) | 16 |
| 17 | `17 Proven Currency Trading Stra - Mario Singh.pdf` | Mario Singh | B | HIGH | (explicitly multi-strategy list) | 17 |
| 18 | `20 Forex Trading Strategies - Thomas Carter.pdf` | Thomas Carter | B | MED | (small file size: density check at extraction) | 18 |
| 19 | `Back to Basics_ An Introduction - Kris Longmore.pdf` | Kris Longmore (Robot Wealth) | B | MED | — | 19 |
| 20 | `Beat the Odds in Forex Trading_ - Igor Toshchakov.pdf` | Igor Toshchakov | B | MED | — | 20 |
| 21 | `FOREX TRADING the Basics Explai - Jim Brown.pdf` | Jim Brown | B | MED | — | 21 |
| 22 | `10 Keys to successful Forex Tra - Jared F. Martinez.pdf` | Jared F. Martinez | B | MED | — | 22 |
| 23 | `Markttechnische Handelssysteme - Jonathan Hofmann.pdf` | Jonathan Hofmann | B | MED | (German; mechanical-systems focus) | 23 |
| 24 | `Algorithmic Trading Strategies_ - Scotty Ratford.pdf` | Scotty Ratford | B | MED | — | 24 |
| 25 | `Algorithmic Trading Systems and - Viktoria Dolzhenko.pdf` | Viktoria Dolzhenko | B | MED | — | 25 |
| 26 | `Python Trader_ Code Your Way to - Hayden van Der Post.pdf` | Hayden van Der Post | B | LOW | (large file; mostly programming exposition; some strategies) | 26 |
| 27 | `Expert Advisor Programming for - Andrew R. Young.pdf` | Andrew R. Young | B | reference-only | (MT4 EA-coding manual, not a strategy book; keep as engineering reference for Development) | 27 |
| 28 | `Forex Trading_ Beginners' Guide - David Reese.pdf` | David Reese | B | LOW | (beginner intro) | 28 |
| 29 | `Smart Money Strategy_ Your Ulti - Luke Smith.pdf` | Luke Smith | B | MED | SMC_GANN_ELLIOTT (SMC mechanical translation required) | 29 |
| 30 | `How To Indentify High-Profit El - Walker, Myles Wilson.pdf` | Myles Wilson Walker | B | MED | SMC_GANN_ELLIOTT (Elliott; mechanical translation risk) | 30 |
| 31 | `Elliott Wave_ Fibonacci High Pr - Jarrod Sanders.pdf` | Jarrod Sanders | B | MED | SMC_GANN_ELLIOTT (Elliott + Fib; mechanical translation risk) | 31 |
| 32 | `Trade Like Pro. The Ultimate Tr - Jode Lebin.pdf` | Jode Lebin | B | LOW | (author less verifiable; tier B by default, may demote to C at extraction) | 32 |

## Tier C — uncertain authorship / generic / re-hosts (proposed_order 33–53)

| # | filename | author | quality_tier | strategy_richness | v5_flags | proposed_order |
|---|---|---|---|---|---|---|
| 33 | `The Market Maker's Matrix - Evan J Christopher.pdf` | Evan J Christopher | C | LOW | SMC_GANN_ELLIOTT-adjacent (market-maker thesis) | 33 |
| 34 | `Mastering the Smart Money Conce - David E. Morrison.pdf` | David E. Morrison | C | LOW | SMC_GANN_ELLIOTT | 34 |
| 35 | `Sure-Fire Hedging Strategy - Owner.pdf` | Unknown ("Owner") | C | LOW | (well-known retail martingale-grid; high G0 fail risk; keep for risk-survey only) | 35 |
| 36 | `ICT INNOVATION_ Use of Microsof - Carlos Cuellar.pdf` | Carlos Cuellar | C | LOW | SMC_GANN_ELLIOTT (ICT) | 36 |
| 37 | `TRADING HUB 3.0_ Beat the Retai - Ayoub Ajroub.pdf` | Ayoub Ajroub | C | LOW | SMC_GANN_ELLIOTT-adjacent | 37 |
| 38 | `W.D. Gann Implicit Rules of Tre - Khit Wong.pdf` | Khit Wong | C | LOW | SMC_GANN_ELLIOTT (Gann) | 38 |
| 39 | `KOBASFX STRATEGY - OLAKEMI.pdf` | OLAKEMI ("Kobasfx") | C | LOW | (niche retail signal-service writeup) | 39 |
| 40 | `Forex - Devisenhandel.pdf` | Unknown (German "FX trading") | C | LOW | — | 40 |
| 41 | `Forex _ The Ultimate Guide To P - Discover Everything You Need to.pdf` | Unknown ("Discover Everything…") | C | LOW | — | 41 |
| 42 | `Automation of Trading Machine f - How to Develop Trading Models.pdf` | Unknown | C | LOW | — | 42 |
| 43 | `Trading Forex -- Ebook, Trading - Unbekannt.pdf` | Unknown | C | LOW | — | 43 |
| 44 | `E-book Smart Money SMC - Unbekannt.pdf` | Unknown | C | LOW | SMC_GANN_ELLIOTT | 44 |
| 45 | `Inner Circle Workshop Trading M - Unbekannt.pdf` | Unknown (ICT context) | C | LOW | SMC_GANN_ELLIOTT (ICT) | 45 |
| 46 | `Trading Secrets of the Inner Ci - Unbekannt.pdf` | Unknown (ICT context) | C | LOW | SMC_GANN_ELLIOTT (ICT) | 46 |
| 47 | `Unlocking Success in ICT 2022 M - Lumitraders.pdf` | Lumitraders (group/forum) | C | LOW | SMC_GANN_ELLIOTT (ICT) | 47 |
| 48 | `SIMPLE STRATEGY________________ - Telekom.pdf` | Unknown ("Telekom" metadata) | C | LOW | — | 48 |
| 49 | `Smart Money Concept Scalping_ S - Dominick M.pdf` | Dominick M. | C | LOW | SMC_GANN_ELLIOTT + SCALPING | 49 |
| 50 | `pdfcoffee.com forex-momentum-st - UMTB.pdf` | Unknown ("UMTB"; pdfcoffee re-host) | C | LOW | — | 50 |
| 51 | `pdfcoffee.com forex-price-actio - Unbekannt.pdf` | Unknown (pdfcoffee re-host) | C | LOW | — | 51 |
| 52 | `pdfcoffee.com forex-scalping-st - Unbekannt.pdf` | Unknown (pdfcoffee re-host) | C | LOW | SCALPING | 52 |
| 53 | `pdfcoffee.com golden-strategy-f - Unbekannt.pdf` | Unknown (pdfcoffee re-host) | C | LOW | — | 53 |

## Tier D / SKIP_DUPLICATE — confirmed duplicates (no proposed_order)

| filename | duplicate_of (canonical) | size_bytes | v5_flags |
|---|---|---|---|
| `Beat the Odds in Forex Trading_ - Unknown Author.pdf` | `Beat the Odds in Forex Trading_ - Igor Toshchakov.pdf` (canonical, row 20) | 7,822,701 vs 7,822,360 (near-identical) | SKIP_DUPLICATE |
| `Elliott Wave - Fibonacci High P - Jarrod Sanders.pdf` | `Elliott Wave_ Fibonacci High Pr - Jarrod Sanders.pdf` (canonical, row 31) | 5,319,618 vs 5,311,713 | SKIP_DUPLICATE |
| `W. D. Gann Implicit Rules of Tr - Khit Wong.pdf` | `W.D. Gann Implicit Rules of Tre - Khit Wong.pdf` (canonical, row 38) | 309,182 vs 305,038 | SKIP_DUPLICATE |
| `intro-to-algo-trading-ebook com - Kris Longmore.pdf` | `Back to Basics_ An Introduction - Kris Longmore.pdf` (canonical, row 19) | 1,357,599 (matches pdfcoffee re-host below) | SKIP_DUPLICATE |
| `intro-to-algo-trading-ebook_com - Kris Longmore.pdf` | `Back to Basics_ An Introduction - Kris Longmore.pdf` (canonical, row 19) | 1,393,353 (matches canonical 1,393,367) | SKIP_DUPLICATE |
| `pdfcoffee.com intro-to-algo-tra - Kris Longmore.pdf` | `Back to Basics_ An Introduction - Kris Longmore.pdf` (canonical, row 19) | 1,357,599 (pdfcoffee re-host) | SKIP_DUPLICATE |

Total duplicates: **6** files → 53 unique sources from 59 on-disk files.

---

## Why this ordering

**Top 5 (Tier A core):** Picks the same first five Board Advisor recommended in the wake comment, with the rationale that:

1. **Davey** — practitioner-focused, mechanical strategies, well-structured workbook. Best validator of the depth-first workflow without ML / HFT complications. Davey explicitly walks the reader through strategy generation, optimization, and Monte-Carlo robustness — directly aligned with V5's pipeline (P0 → P5).
2. **Chan, *Quantitative Trading*** — clean structure, statistically-rigorous, mean-reversion + momentum classics. Strong V5 fit.
3. **Williams, *Long-Term Secrets to Short-Term Trading*** — classic mechanical strategies (e.g., the Volatility Breakout). Runs cleanly on M15+ which V5 supports.
4. **Lien, *Day Trading and Swing Trading the Currency Market*** — forex-specific, clear entry/exit rules. V5 backtests forex symbols, so direct fit.
5. **Chan, *Algorithmic Trading*** — the originally-planned SRC01. Deferred from #1 because Davey is more procedurally aligned with the V5 build pipeline; Chan AT is still A-tier and processed early.

**Tier A 6–13:** Aziz, Brooks, Cofnas, Leshik, Krishtop, Aldridge, Jansen, Chan-Machine. Aldridge and the two ML books pushed to the end of Tier A because they bind on V5 hard rules (HFT and ML respectively); Research extracts the salvageable non-flagged content.

**Tier B 14–32:** Galen Woods first (most mechanically-precise of the practitioner authors, smallest discretionary surface). Multi-strategy list books (Singh, Carter) come early because high strategy density per page. Programming-reference books (Young, Van Der Post) come later — they yield engineering insight more than trading strategies. SMC / Elliott practitioners (Smith, Walker, Sanders) at the end of Tier B because of the SMC_GANN_ELLIOTT flag risk.

**Tier C 33–53:** Author-credible-ish SMC books first (Christopher, Morrison), then the well-known-but-author-anonymous "Sure-Fire Hedging" (because the V5 risk team will want a verbatim writeup of how that retail martingale-grid strategy is sold, even if every strategy in it fails G0). Then ICT-cluster (Cuellar, Ajroub, Wong, anonymous ICT books) — high SMC_GANN_ELLIOTT mechanical-translation risk, all flagged. The pdfcoffee re-hosts come last because authorship is least verifiable; Research will spot-check them and may move some to Tier D / `SKIP_LOW_SIGNAL` upon opening.

**Demotion-on-extraction policy:** Any source whose first chapter reveals zero extractable mechanical strategies after a good-faith read may be demoted to `SKIP_LOW_SIGNAL` and skipped. Research notes the demotion in `strategy-seeds/sources/SRC{n}/source.md` so the audit trail is preserved; CEO confirms the skip.

## Recommendation for SRC01 dispatch

If the OWNER + CEO ratify this order, **SRC01 = Davey, *Building Winning Algorithmic Trading Systems*** (file: `Building Winning Algorithmic Tr - Kevin J. Davey.pdf`). CEO opens a new SRC01 issue, links this file as the source, and Research begins extraction in the next heartbeat.

The previously-blocked SRC01 (Ernest Chan, *Algorithmic Trading*) is mooted: that book is now on disk (file row 5 above) and will be processed in turn at proposed_order 5.

## Acceptance criteria for ratification

- [ ] OWNER reviews ordering and either ratifies or returns proposed reorderings (especially top-5).
- [ ] CEO ratifies the queue and opens SRC01 against the first ratified source.
- [ ] [QUA-191](/QUA/issues/QUA-191) closed as superseded by this queue (the original Chan-first SRC01 is replaced by the queue-first model).
- [ ] All future SRC issues created one-at-a-time; only one SRC active in `in_progress` at any time per the OWNER constraint.
- [ ] This file (`SOURCE_QUEUE.md`) is treated as the canonical research roadmap; updated when sources are completed (`status` column added) or when extraction reveals a tier-change is warranted.

## Out-of-folder sources (informational, T1-scope only)

The earlier wake context mentioned firecrawl + paper-context-resolver for follow-up reading on cited sub-references inside the books. Those skills remain available but are NOT part of T1. If a Tier A book cites a paper that materially refines a strategy (e.g., Chan citing a Lo-MacKinlay paper), Research may pull that supplemental paper at extraction time and cite it as `role: supplement` per `_TEMPLATE.md` § 1. The T1 queue itself stays bounded to the 53 unique on-disk PDFs above.

---

# T2 — Named public containers (OWNER-named at 2026-04-27 ~17:25)

T2 sources are **public-internet containers** (forums, blog archives, article aggregators, paper repositories). Per the OWNER 17:25 source-class taxonomy directive, the granularity differs from T1:

> **A book is a source, a forum is a CONTAINER of sources.** Each high-quality thread / post / paper inside the container becomes its own SRC sub-issue, NOT one container = one source.

**T2 dispatch begins only after T1 is drained or partially-exhausted with CEO + OWNER ratification of pivoting.** When T2 dispatch opens, Research first runs a survey-pass over each container (sampling N threads / posts / papers, tagging each by quality tier A/B/C and v5_flags), then proposes a per-thread / per-post extraction order for CEO + OWNER ratification — same shape as the T1 queue above.

## T2 container manifest (proposed_order TBD; per-container survey-pass at T2 dispatch)

| # | container | URL | source_class | survey_method | quality_skew | v5_flags | preliminary_priority |
|---|---|---|---|---|---|---|---|
| T2-01 | MQL5 articles | https://www.mql5.com/en/articles | Class 2 (peer-curated articles) | `firecrawl-search` filter `site:mql5.com/en/articles` by category ("Trading Systems", "Expert Advisors", "Statistics and analysis") | mostly B-tier; some MetaQuotes / known-author = A-tier; signal-to-noise highest of T2 | — | high (best signal density of T2) |
| T2-02 | Adam Grimes blog | https://www.adamhgrimes.com/ | Class 2 (single-author practitioner blog) | `WebFetch` per post; `firecrawl-scrape` once skill loads. **Survey-pass already partial** — see `strategy-seeds/sources/_t2_pending/grimes-blog/source.md` | mostly A/B-tier (verifiable practitioner; published author of *The Art and Science of Technical Analysis*, Wiley 2012) | — | high (pre-surveyed; first card already drafted at `strategy-seeds/cards/grimes-pullback_card.md` as T2_PENDING) |
| T2-03 | John Ehlers / MESA Software papers | https://www.mesasoftware.com/papers/ | Class 3 (academic/practitioner papers) | `paper-context-resolver` + `WebFetch` for individual papers | A-tier signal-processing-rooted strategies | — | high |
| T2-04 | Robot Wealth blog (Kris Longmore) | https://robotwealth.com/blog/ | Class 2 (practitioner blog) | `firecrawl-search` per post. Note: Longmore's *Back to Basics* PDF is at T1 row 19; the blog has more recent content | A/B-tier; engineering-rigorous | overlap_with_T1_row19 (Longmore PDF) | high |
| T2-05 | Ernest Chan blog | https://epchan.blogspot.com/ | Class 2 (single-author practitioner blog) | `firecrawl-search` per post | A-tier | overlap_with_T1_rows_2,5,13 (Chan PDFs) | medium (overlaps heavily with three T1 Chan books) |
| T2-06 | arXiv q-fin | https://arxiv.org/list/q-fin/recent | Class 3 (peer-reviewed-ish papers) | `paper-context-resolver` per paper; pre-filter for "trading", "strategy", "backtest" keywords | A-tier; peer-reviewed-ish; free | — | medium |
| T2-07 | SSRN finance | https://www.ssrn.com/index.cfm/en/fmrc/ | Class 3 (free preprints) | `paper-context-resolver` per paper | A/B-tier; often more practical than arXiv | — | medium |
| T2-08 | Forex Factory — Trading Systems subforum | https://www.forexfactory.com/forum/71-trading-systems | Class 2 (forum threads) | `firecrawl-search` site-restricted; filter by replies > 500 + activity / view-count threshold | wildly variable; legendary threads = A-tier; most C/D-tier; specific watchlist: "London Breakout", "4-Hour MACD", "Holy Grail", "Big Dog", Ronald Raygun, KOBASFX (overlaps T1 row 39) | — | medium (high noise; needs disciplined survey-pass) |
| T2-09 | Babypips forum | https://forums.babypips.com/ | Class 2 (forum threads) + Class 1 sub-area (School of Pipeline at https://www.babypips.com/learn) | `firecrawl-search site:forums.babypips.com "trading system" OR "strategy"` + author filter / view-count threshold; School of Pipeline treated as a small Class 1 book for survey purposes | educational, beginner-heavy; most threads C-tier; small set of long-running mechanical-strategy threads B-tier | — | low-medium (high noise; School of Pipeline only first-pass interest) |

### T2 quality gate (additive to V5 v0_filter above)

- A/B/C/D tiering same as T1 Tier definitions
- No paywall bypass, no piracy, no scraping behind login (binding)
- Anonymous claims without verifiable backtest evidence → auto-C
- Discretionary judgment patterns → kill at G0
- Any martingale / grid → must show strict 1%-cap fallback or fail V5

### T2 acceptance criteria (when dispatch opens)

- [ ] Per-container survey-pass produces a candidate list of threads / posts / papers, each tagged with quality tier + v5_flags + estimated mechanical-strategy yield
- [ ] CEO + OWNER ratify the survey-pass results and approve which T2 candidates enter the active per-thread queue
- [ ] Same ONE-source-at-a-time rule binds: T2 doesn't relax it
- [ ] Diversity-bias rules (above frontmatter `diversity_bias_rules`) apply to T2 picks just as to T1

---

# T3 — Open-internet autonomous discovery (placeholder; activates after T2)

T3 is Research's **steady-state operating mode** per the OWNER 17:28 directive: actively search the public internet for additional mechanical-trading-strategy sources and add them to the queue. **T3 has no fixed end.** It runs continuously after T2 is processed (or T2 yields are exhausted earlier than T1, with CEO + OWNER ratification).

## T3 discovery methods

- **`firecrawl-search`** — search the web with specific queries, return ranked URLs (skill not yet loaded into Research's active session — needs ToolSearch `select:firecrawl-search` or skill-pin)
- **`firecrawl-scrape`** — pull article / page content for survey-pass evaluation (same skill-load note)
- **`paper-context-resolver`** — academic paper analysis when search hits arXiv / SSRN / journal sites (skill-load note)
- **`anthropics/skills/pdf` (`pdf--3924e73e8d`)** — for any free PDF found in the wild (already loaded)
- **`WebFetch` + `WebSearch`** — built-in deferred tools; sufficient for discovery in heartbeats where the firecrawl skills are not loaded

## T3 search-heuristic seed list (Research evolves these)

- `"mechanical trading strategy" site:arxiv.org OR site:ssrn.com`
- `"quantitative trading rules" backtest`
- `"trading system" "entry rules" "exit rules" -course -"buy now"` (filter out paid content)
- `"algorithmic strategy" forex OR indices OR "S&P"`
- `"trading bot" "open source" github` (open-source EA repos sometimes carry strategy reasoning in their READMEs)
- Archetype searches: `"momentum strategy" backtest`, `"mean reversion" "ATR"`, `"breakout system" hourly`, `"carry trade" mechanical`, `"seasonal pattern" forex`
- Author-snowballing: when a high-quality source cites another author, follow the citation

## T3 actively-seek list

- arXiv q-fin, SSRN finance, MESA Software (also in T2)
- QuantStart, Adam Grimes, Quantocracy, Alvarez Quant Trading, Build Alpha (known-quality practitioner blogs)
- University finance department working papers (Stanford GSB, NYU Stern, LSE Finance)
- Open-source EA / strategy GitHub repos (README + commit history)
- Federal Reserve / BIS working papers (macroeconomic / FX regime; useful for filter design)

## T3 deprioritize list (Research's judgment, not absolute bans)

- Reddit threads — high noise, mostly opinion. Exception: r/algotrading occasional high-quality posts with code.
- Stack Exchange (Quant.SE) — useful for specific technical questions, less for full strategies
- YouTube — only if the channel publishes structured strategy content (not "pump my newsletter" videos); transcript availability uneven
- Twitter / X — atomized, low-context. Skip unless a specific quant author writes thread-form analysis.

## T3 approval cadence

- Research submits batches of ~5–10 newly discovered candidates per heartbeat-budget cycle to keep approval overhead reasonable
- CEO + OWNER tier each batch (A/B/C/D) and approve which to add to the active queue
- Rejected candidates archived in `strategy-seeds/sources/REJECTED.md` with reason — so we don't re-discover the same junk (file authored at first rejection event)

## T3 boundaries (binding, same as T1/T2)

- ONE source actively worked at a time. T3 doesn't relax this.
- No paywall bypass. No piracy. No scraping behind login.
- V5 hard rules trump source signal.
- T6 OFF LIMITS — Research never touches live trading paths.
- Public-domain / open-license content preferred for archived-citation purposes; copyrighted content fine to read for extraction but Strategy Cards quote sparingly per fair-use norms.

---

# Per-source budget tracking (OWNER directive 17:28 acceptance criterion)

Each SRC source's lifecycle is tracked for "this source took N heartbeats to extract M cards" so CEO can adjust the quality bar over time. Convention:

- The source's `source.md` § header gains two fields populated as work progresses:
  ```yaml
  budget_tracking:
    heartbeats_used: 0                       # incremented at end of each heartbeat that touched this source
    cards_drafted: 0                         # incremented when a card lands at DRAFT
    cards_passed_g0: 0                       # incremented when CEO + Quality-Business ratify a card
    cards_killed_pre_p1: 0                   # incremented on G0 fail / skip-on-extraction
  ```
- Source-completion report (`completion_report.md`, per `processes/13-strategy-research.md`) summarizes the four counts above plus a yield ratio (`cards_passed_g0 / heartbeats_used`).
- CEO uses the running yield ratio across SRCs to pivot the queue (e.g., demote a source mid-extraction if yield is far below T1 average).

---

# Diversity tracker — `STRATEGY_TYPE_DISTRIBUTION.md`

Per OWNER 17:28 acceptance criterion: a tracker file `strategy-seeds/sources/STRATEGY_TYPE_DISTRIBUTION.md` records the strategy-type-flag distribution across the queue (using the controlled vocabulary in `strategy-seeds/strategy_type_flags.md`).

**Authorship:** Doc-KM (per the directive). Research updates the file as cards land DRAFT / PASS_G0 / KILLED. The directive notes "Doc-KM authors a small auto-updating template"; until Doc-KM is hired or assigned, the diversity-bias rules in this file's frontmatter (`diversity_bias_rules`) provide an interim manual check at next-source-pick time.
