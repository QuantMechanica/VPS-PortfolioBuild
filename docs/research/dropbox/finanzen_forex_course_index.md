# Finanzen/Forex Course Index — OWNER's Dropbox

**Phase:** Explore Step 3 (Task #2 of Dropbox strategy-research initiative)
**Snapshot date:** 2026-05-23
**Scope:** 107 course folders under `C:\Users\Administrator\Dropbox\Finanzen\Forex\`. Pure inventory — no video content analysis (that's a per-Gemini-batch task).

## Headline numbers

| Metric | Count |
|---|---:|
| Course folders | **107** |
| Total videos | **2,687** |
| Total transcripts (`.vtt`/`.srt`) | 672 |
| Total PDFs | 268 |
| Total MQ source (`.mq5`/`.mq4`/`.mqh`) | 96 |
| Total compiled (`.ex5`/`.ex4`) | 13 |
| Total `.set` files | 44 |
| Total Jupyter notebooks | ~219 |
| Total Python scripts | ~4,890 |
| Folders with **transcripts** | **12** (cheap signal — read direct, no Gemini cost) |
| Folders with **code** | **15** (mechanizable shortcut) |
| Folders with PDFs (≥ 1) | 29 |
| Folders with **zero videos** (likely scams or text-only) | 14 |

**Implication:** for ~95 folders Gemini video analysis is the only path. For 12 folders we have direct transcript text. For 15 folders code is on disk.

---

## Tiering rubric

- **TIER-1 ANCHOR** — reputable author + mechanical strategy + code or transcripts present → first Gemini batches
- **TIER-2 HIGH** — recognised source + relevant topic (ICT / MQL5 / FTMO) → after TIER-1
- **TIER-3 CONDITIONAL** — anonymous YouTube content, untested claims → mine selectively if reservoir gate allows
- **TIER-4 SKIP** — commercial blackboxes, scam EAs, broken duplicates → never mine

---

## TIER-1 ANCHOR (must mine — 8 folders)

| # | Folder | Vids | Size | Transcripts | Code (MQ/EX) | Why TIER-1 |
|---|---|---:|---:|---:|---|---|
| 1 | `Andrea.Unger.Bundle.5.Courses.02.19` | 161 | 5.4 GB | 0 | 0 | **Andrea Unger = 4× World Cup of Trading Championship winner**, fully-mechanical systems author. 161 videos + 12 PDFs + 57 docs = the single highest-signal vendor in the archive |
| 2 | `EA - FTMO - Trading Course` | 55 | 4.9 GB | 0 | **15 .mq5 + 1 .ex5 + 4 PDFs** | Course explicitly targets FTMO compliance + provides 15 working EAs as exercises |
| 3 | `Quantreo.Alpha.Quant.Program.02.19` | 42 | 7.0 GB | 0 | 0 | **Quantreo (Lucas Inglese)** = respected quant-finance educator (Quantreo.com). Mechanical, math-driven curriculum |
| 4 | `Quantreo-Alpha-Quant-Program-Donwload` | 42 | 6.0 GB | 0 | 0 | Same content, different release. Reconcile vs row 3 before deciding which to mine |
| 5 | `11 - Algorithmic Trading In MQL5 Automate Free Up Your Time` | 92 | 4.0 GB | **92** | 4 .mq5 | 92 transcripts = read directly, no Gemini cost. Practical MQL5 |
| 6 | `4 - Forex Algorithmic Trading For Beginners 30 Robots Monthly` | 38 | 1.3 GB | **38** | **60 .mq5** | "30 Robots Monthly" + 60 .mq5 sources = highest code-density course in archive. Plus 38 transcripts |
| 7 | `Algorithmic Trading Robots Without Programming (17 Hrs) MT5` | 55 | 2.7 GB | **94** | 0 | 17h course on MT5 Wizard EA builds — useful for non-code strategy specs |
| 8 | `15 - Algorithmic-Trading-Robots-Without-Programming 15 8` | 62 | 3.2 GB | 0 | 0 | Likely Joe Lammers' MT5 wizard series — pair with #7 for full curriculum |

---

## TIER-2 HIGH (mine after TIER-1 — ICT cluster, MQL5 PROJECTS, recognised educators)

### ICT-related (cross-reference with Task #4 ICT-Database before mining!)

| Folder | Vids | Size | Notes |
|---|---:|---:|---|
| `Proven ICT Forex Trading Strategy Make Consistent Profits` | 62 | 2.1 GB | Generic "Proven ICT" YouTube series |
| `Zeussy MMXM Course` | 53 | 9.0 GB | MMXM = Market Maker XM model, ICT-adjacent |
| `Simplified ICT Forex Scalping Trading Strategy using OTE!` | 50 | 2.1 GB | Optimal Trade Entry (62-79% Fib retracement) |
| `The Complete FOREX Trading Secrets of BIG BANKS Course 2023` | 22 | 1.4 GB | + 5 PDFs + 7 docs |
| `Ultimate ICT Day Trading Forex Technique Make 3R per Trade!` | 21 | 1.5 GB | |
| `Daye's Quarterly Theory Mentorship` | 21 | 1.9 GB | Daye's quarterly-theory model |
| `The MMXM Trader Course` | 22 | 1.0 GB | |
| `The MMXM Traders 2nd Course` | 7 | 2.2 GB | Sequel to above |
| `Winning ICT Forex Day Trading Strategy Easy 7R Setups` | 13 | 0.3 GB | |
| `Advanced ICT Order Block Forex Trading Strategy High-Gain!` | 13 | 0.4 GB | |
| `Exclusive ICT Forex Trading Strategy Course Breaker Block!` | 12 | 0.5 GB | |
| `1-minute Scalping Trading Strategy ICT Session Liquidity` | 6 | 0.4 GB | |

**Total ICT cluster: 312 videos / 22 GB**. Many concepts overlap with `Ftmo/week1-2` existing code and ICT-Database PDFs (Task #4). Before queueing these to Gemini: grep existing code for the named concepts — what's already implemented becomes a port task instead of fresh research.

### MQL5 PROJECTS series (likely same producer — code-focused)

| Folder | Vids | Size |
|---|---:|---:|
| `MQL5 PROJECTS Code a Master Candlestick breakout strategy` | 19 | 1.9 GB |
| `MQL5 ADVANCED Code a Currency Strength Filter for EAs` | 19 | 1.8 GB |
| `MQL5 PROJECTS Code a Fair Value GapImbalance Strategy` | 18 | 1.5 GB |
| `12 - MQL5 PROJECTS Code the Harriet Momentum Hedging strategy` | 17 | 1.5 GB |
| `MQL5 PROJECTS Code the Black Swan Trading Strategy in MQL5` | 15 | 1.3 GB |
| `MQL5 ADVANCED Code an HMA Trend Following Strategy` | 14 | 1.6 GB |
| `MQL5 PROJECT Code An AntiPersistence Mean Reversion System` | 12 | 1.0 GB |
| `MQL5 PROJECTS Code a Carry TradeRoll Over Strategy in MQL5` | 11 | 0.9 GB |
| `1 - MQL5 PROJECTS Code the White Fairy Pyramiding strategy` | 7 | 0.8 GB |
| `1 - Grid - MQL5 PROJECTS Code the White Fairy Pyramiding strategy` | 5 | 0.5 GB |
| `MQL5 ADVANCED Coding for Fundamental Analysis` | 3 | 0.3 GB |

**Total MQL5 PROJECTS: 140 videos / 13 GB**. Each course = one strategy walked through in code. Direct Strategy Card material if course delivers on title. SKIP: "Pyramiding" + "Grid Pyramiding" (martingale-family, likely violate V5 risk rules).

### MQL5 Beginner / Advanced (foundation)

| Folder | Vids | Size | Note |
|---|---:|---:|---|
| `7 - MQL5 Beginner Algorithmic trading with MQL5 New 2021` | 36 | 3.4 GB | |
| `MQL5 Beginner Algorithmic trading with MQL5 New 2021` | 35 | 4.1 GB | Likely duplicate of row above — reconcile |
| `2 - Mql5 Advanced Creating Algorithmic Trading Robots With Mql5` | 27 | 3.3 GB | **+27 transcripts** |
| `Mql5 Complete Algorithmic Trading Course for Synthetic` | 7 | 0.7 GB | |
| `6 - Mql5 Complete Algorithmic Trading Course for Synthetic` | 1 | 0.06 GB | Stub — incomplete download? |

### Photon Trading (large vendor, 2 releases)

| Folder | Vids | Size |
|---|---:|---:|
| `Photon.Trading.FX.2023.02.19` | 47 | **45.5 GB** (HD?) |
| `PhotonTradingFX.The.Photon.Course.02.19` | 47 | 7.4 GB |

Same 47 videos, different folder sizes (likely SD vs HD release). Photon is a popular ICT-derivative retail course. Reconcile which one to mine.

### Other recognised vendors

| Folder | Vids | Size | Note |
|---|---:|---:|---|
| `Bernd Skorupinski` | 106 | 17.7 GB | German trader / educator, retail-Forex |
| `WB Trading` | 78 | 13.1 GB | YouTube channel, "WB Trading" brand |
| `Phantom Course 09-2023 Update` | 77 | 9.1 GB | Phantom Forex / Phantom Trading |
| `Six Figure Capital - Forex Course` | 38 | 12.3 GB | Retail Forex brand |
| `WondaFX` | 31 | 4.8 GB | Funded-trader content |
| `URBAN FOREX - MASTERING PRICE ACTION 1.0` | 45 | 3.5 GB | Classic price-action |
| `URBAN FOREX - MASTERING PRICE ACTION 2.0` | 32 | 1.7 GB | Sequel, **+32 docs** |
| `Fenix Pinheiro Trading - Funded Trader 1 Million` | 33 | 2.7 GB | Prop-firm trader |
| `Wyckoff Video Course` | 3 | 4.3 GB | Wyckoff method (small video count, big files = lectures) |
| `Trading to Win - Bookmap Masterclass` | 5 | **16.7 GB** | Bookmap order-flow tool — useful concepts, not directly portable |
| `Dodgy's Dungeon - Ultimate Trading Course` | 22 | 10.9 GB | |
| `ADZ Trading Academy - Sniperadz` | 6 | 10.7 GB | Big folder, few vids = HD lectures |
| `1.Minute.Master.The.Perfect.Execution.1.Minute.Strategy.DOWNLOAD.LINKS` | 15 | 6.8 GB | |
| `1.Minute.Master.The.Perfect.Execution.1.Minute.Strategy.02.19` | 9 | 1.2 GB | Possibly partial release of above |

### Python algo trading (lower V5 priority — MT5 is MQL5, but mineable for strategy ideas)

| Folder | Vids | Size | Note |
|---|---:|---:|---|
| `14 - Python for Financial Analysis and Algorithmic Trading` | 111 | 6.4 GB | + 105 .ipynb |
| `5 - Algorithmic Trading Quantitative Analysis Using Python` | 108 | 8.8 GB | **+216 transcripts** |
| `Algorithmic Trading with Python Complete Course` | 102 | 5.6 GB | + 69 .ipynb + 14 .py |
| `The Ultimate Forex Algorithmic Trading Course Build 5 Bots` | 73 | 1.6 GB | **+73 transcripts**, **+4830 .py** (likely lib/dep tree) |
| `Algorithmic Trading Strategies In Python` | 67 | 3.9 GB | + 21 .ipynb |
| `Algorithmic Forex Trading with MT5 Python API` | 56 | 5.4 GB | MT5↔Python bridge |
| `Exploring Algorithmic Trading and Generative AI Usage` | 63 | 4.7 GB | **GenAI angle — possibly violates V5 no-ML rule** |
| `13 - Python for finance/ML/algorithmic trading` | 29 | 0.8 GB | **+29 transcripts**, ML angle |
| `Practical Python for Algorithmic Trading` | 27 | 0.3 GB | **+27 transcripts** |
| `AI Algorithmic Trading Remove Emotion Automate w Python` | 27 | 4.8 GB | **AI/automation angle** |
| `Algorithmic trading for dummies` | 35 | 4.2 GB | **+34 transcripts** |
| `3 - Algorithmic Trading Course London New York Tokyo System` | 10 | 0.8 GB | **+17 transcripts** |
| `x3 - Algorithmic Trading Course London New York Tokyo System` | 7 | 0.5 GB | x-prefix usually = "remove/dupe" — likely cull |

Python clusters that explicitly mention ML / AI / GenAI flag for the V5 no-ML hard rule. Mine for strategy IDEAS only, never for code-as-is.

---

## TIER-3 CONDITIONAL (generic YouTube — mine selectively, low expectation)

| Folder | Vids | Size |
|---|---:|---:|
| `The Complete FOREX Trading Course` | 39 | 1.2 GB |
| `Simple Strategy for trading US100 Index` | 23 | 2.4 GB |
| `Ultimate Chart Pattern Trading Strategy for Easy Gains 2024` | 22 | 5.6 GB |
| `Forex Training for Beginners with Proven Profit Strategy` | 14 | 0.9 GB |
| `Forex Trading with Technical Indicators and Forex Robots EA` | 13 | 0.6 GB |
| `Simple Swing Trading Strategy for Working Professionals` | 13 | 1.2 GB |
| `Beginner-Friendly Forex Trading Strategy for all pairs` | 10 | 1.3 GB |
| `Powerful Forex Day Trading Strategy 90 Winrate` | 9 | 0.3 GB |
| `PROFITABLE Forex and Gold Day Trading Strategy` | 9 | 0.6 GB |
| `16 - PROFITABLE Forex and Gold Day Trading Strategy` | 9 | 1.7 GB |
| `16 - SimpleAlgorithmicTradingCrashCourse 4 5 1` | 8 | 0.4 GB |
| `Unbeatable Forex Scalping Strategy` | 8 | 0.4 GB |
| `Bullet Proof Forex Scalping Strategy` | 8 | 0.4 GB |
| `A Framework to find and trade A+ setups on Forex Major` | 8 | 0.9 GB |
| `Forex Break and Retest Strategy with Price Action and Trend` | 4 | 1.5 GB |
| `Powerful Forex Scalping Trading Strategy Works Every Time` | 1 | 0.04 GB |
| `001_Cracking Prop Trading Challenges` | 3 | 0.2 GB |
| `TyroneTradesFX - Tyrone Course` | 2 | 0.5 GB |
| `The Ultimate Swing Trading Strategy for Forex Trading` | 7 | 0.3 GB |
| `ABC's of algorithm principles` | 15 | 1.0 GB |
| `ss94n.L.MQL5.B.a.8Currency.H.R.MT.5` | 20 | 0.4 GB | + 8 PDFs + 14 .mq5 |

The folder naming convention "ss94n.L.MQL5.B.a.8Currency.H.R.MT.5" suggests a multi-currency hedging-or-portfolio EA course (8Currency / H.R. = hedge/risk?) — has 14 .mq5 source. Worth a code-first inventory pass.

### Old "02.19" packs (Feb-2019 vintage — established names)

| Folder | Vids | Size | Author/topic |
|---|---:|---:|---|
| `Evolved.Traders.My.Trading.Strategy.02.19` | 12 | 1.2 GB | |
| `Forex.Rebellion.Trading.System.02.19` | 11 | 0.5 GB | **+4 .ex4 compiled MT4 EAs** |
| `Abyss.The.Trader.Trading.Course.02.19` | 4 | 0.7 GB | |
| `13.MARKET.MOVES.FORMULA.02.19` | 4 | 3.7 GB | |
| `Desire.To.Trade.The.Secretariat.Trend.Trading.Strategy.Masterclass` | 5 | 2.1 GB | "Secretariat" trend system |

---

## TIER-4 SKIP (commercial blackbox / scam / broken duplicates — 14 folders)

| Folder | Vids | Reason to skip |
|---|---:|---|
| `MT5 EA ZELDA mq5` | 0 | 1 .mq5 source from "ZELDA" — typical retail-scam EA |
| `ORACLE EA V3.0 2023` | 0 | 1 .ex5 only, no source — opaque commercial EA |
| `POW BANKER MT5 8.16` | 0 | Same family — retail scam EA, ~v8.x |
| `POW BANKER V8.12 EA MT5 UNLIMITED` | 0 | Same family, "UNLIMITED" = cracked |
| `POW BANKER EA v8.16` | 0 | Same family |
| `POW banker Red Alert by @gediyafx (1)` | 0 | Same family — 28 .ex5 across 1 vendor = pure spam |
| `Theorem EA V5` | 0 | 4 .ex5 — opaque |
| `Darwin Evolution MT5 EA` | 0 | Empty / placeholder |
| `AnEasierWayToTrade Semi-EA  MT5` | 0 | Manual EA wrapper, not mechanical |
| `Ratford S. Algorithmic Trading Strategies. The Most Profitable...2022` | 0 | 1 PDF only, clickbait title |
| `Trader Dante Swing Trading Forex and Financial Futures 02 19` | 0 | 0 videos, 0.5 GB ghost — broken download |
| `Quantreo Alpha Quant Program 02 19` | 0 | 10 GB folder but 0 videos — broken duplicate of working Quantreo entry |
| `Quantreo-Alpha-Quant-Program-Don…` | 0 | Truncated folder name = stub |
| `Trading Busters - London Strategy.zip` | 2 | Single ZIP file at top level — not unpacked; revisit only if needed |

**Skip rationale:** zero mechanizable source code we can read + no transcripts + zero or stub videos = no extraction path. POW BANKER family alone is 4 entries with 0 video content — these are the same EA repacked, retail-scam tier.

---

## SPECIAL: text-only intake folders

| Folder | Vids | PDFs | Docs | Note |
|---|---:|---:|---:|---|
| `Alessio Aloisi - Trading - Forex komplette Sammlung für Einsteiger (ungekürzt)` | 0 | 0 | 2 | "Complete German Forex collection for beginners (uncut)" — 340 MB but only 2 docs counted, likely PDF mis-tagged |
| `###  Forex to read` | 0 | **166** | 8 | **166 PDFs in a single "to read" bin** — large untriaged reading pile, deserves a dedicated inventory task |

The `### Forex to read` folder is its own world — 166 PDFs is the same order of magnitude as the entire ICT-Database (54). Schedule a separate sub-task to triage this.

---

## Cross-source duplicates and ambiguities to resolve

- **Three Quantreo entries:** `Quantreo.Alpha.Quant.Program.02.19` (42 vids 7 GB), `Quantreo-Alpha-Quant-Program-Donwload` (42 vids 6 GB), `Quantreo Alpha Quant Program 02 19` (0 vids 10 GB) + truncated stub. Identify which release is canonical.
- **Two Photon Trading entries:** 47 vids each, 45.5 GB vs 7.4 GB → likely HD vs SD; mine smaller version unless quality matters.
- **Two MQL5 Beginner New 2021 entries:** 36 vids vs 35 vids — likely re-download.
- **Two London/NY/Tokyo entries:** with and without `x3-` prefix — `x3-` prefix usually marks "remove me".
- **Two 1-Minute-Master entries:** `02.19` (9 vids 1.2 GB) vs `DOWNLOAD.LINKS` (15 vids 6.8 GB).
- **Two Forex&Gold Day Trading entries:** identical wording with/without "16 -" prefix.

Resolve in Task #5 (priority tiering) — wasted Gemini budget if same video analysed twice.

---

## Recommended Gemini-batch sequencing (input to Task #5 + Task #6)

**Wave 1 (TIER-1 anchors):** Andrea Unger Bundle (highest-signal vendor) → EA-FTMO Trading Course (has code) → Quantreo Alpha Quant (mechanical-quant) → MQL5 PROJECTS top-vid count (Master Candlestick, Currency Strength, FVG/Imbalance).
**Wave 2 (transcripts-first):** the 12 folders with `.vtt`/`.srt` — read those transcripts directly without Gemini, cheap signal, fast Strategy Cards.
**Wave 3 (ICT cluster):** AFTER cross-grepping existing code — only mine concepts not already in `Ftmo/week1-2` or `FTMO March 2026/EAs`.
**Wave 4 (TIER-2 vendors):** Bernd Skorupinski, Phantom, Photon, Zeussy, WB Trading.
**Wave 5 (TIER-3 selectively):** only after reservoir empties below cap.
**Never:** TIER-4 (POW BANKER, ZELDA, ORACLE, Theorem, Darwin Evolution, Ratford, broken Quantreo dupes).

Reservoir gate (≥ 5 ready Strategy Cards) caps the rate — Gemini queue must respect this.

---

## Side note: raw CSV

Cached at `docs/research/dropbox/.finanzen_forex_raw.csv` (dot-prefixed to keep out of routine glob hits). Re-runnable PowerShell pipeline that produced it is embedded in the corresponding Bash/PowerShell command history.
