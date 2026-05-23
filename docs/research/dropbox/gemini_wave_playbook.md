# Gemini Wave Playbook — Dropbox Strategy Mining

**Phase:** Plan (Task #5 of Dropbox strategy-research initiative)
**Authored:** 2026-05-23
**Companion docs:** `processes/gemini_video_extraction_contract.md` (the contract), `docs/research/dropbox/finanzen_forex_course_index.md` (the inventory), `docs/research/dropbox/existing_ea_inventory.md` + `textual_research_inventory.md` (cross-reference targets).

This is the **executable order** in which Dropbox content gets mined. Each wave is a self-contained block: pre-flight checklist, concrete commands, stop conditions, switch trigger to the next wave. Designed so OWNER can give "start Wave-N" and Claude has zero ambiguity about what to do next.

## Pre-conditions (must hold before any wave starts)

```
1. Reservoir gate OPEN: ready-card count < 5
   Check: python tools/strategy_farm/farmctl.py status | grep ready_cards
   If ≥ 5 → STOP. Drain pipeline first.

2. Gemini agent enabled in registry:
   Check: python tools/strategy_farm/agent_router.py status | grep gemini
   Expect: enabled=true, max_parallel=2.

3. CLAUDE_DISABLED.flag NOT present (Claude must be available for synthesis):
   Check: ls D:\QM\strategy_farm\CLAUDE_DISABLED.flag (should error)

4. agent_tasks table reachable (sqlite up):
   Check: python tools/strategy_farm/agent_router.py list-tasks --agent gemini | head -5
```

If any pre-condition fails → stop wave dispatch, report to OWNER.

## Wave structure

| Block | Source class | Why this block now | Gemini cost |
|---|---|---|---|
| **A** | TIER-1 anchors (Gemini-required) | Highest signal, smallest first to validate contract | High |
| **B** | Transcript-first folders | Cheap — read transcripts directly, no Gemini | Zero |
| **C** | ICT cluster (after cross-grep) | High V5 fit but heavy dup risk with existing code | Medium |
| **D** | MQL5 PROJECTS series | Code-focused, one-strategy-per-course | Medium |
| **E** | TIER-2 vendors | Recognised but unverified educators | High |
| **F** | TIER-3 + `### Forex to read` (Task #7) | Only after A-E exhausted, with dedup | Low |

Block ordering is OWNER-set policy (2026-05-23): TIER-3 only after TIER-1+2 exhausted; complete coverage per course; max 50 videos/course/day.

---

## Block A — TIER-1 Anchors (Gemini-required)

### A1 — `EA - FTMO - Trading Course` (Wave-1 anchor)

**Why first:** Smallest TIER-1 (55 videos ≈ 1 budget-cap day), ships with 15 .mq5 + 1 .ex5 on disk so partial Gemini extractions can be reconciled against compiled code. Lowest blast radius for validating the contract.

**Pre-flight:**

```bash
# 1. Allocate source_id and create source folder
mkdir -p strategy-seeds/sources/SRC-ea-ftmo-trading-course-20260523
# Write source.md (template below)

# 2. Cross-grep against existing code (results land in source.md as "existing_code_matches")
grep -lri -e "SilverBullet\|FVG\|MMXM\|Judas\|NNFX\|ORB\|AsianRange" \
  "Ftmo/" "FTMO March 2026/EAs/" "Trustful Trading/" > /tmp/ea_ftmo_concept_hits.txt

# 3. Enumerate the 55 videos for batch enqueue
ls "C:\Users\Administrator\Dropbox\Finanzen\Forex\EA - FTMO - Trading Course\"*.mp4 \
  > /tmp/wave1_video_list.txt
```

**Source.md template** (`strategy-seeds/sources/SRC-ea-ftmo-trading-course-20260523/source.md`):

```yaml
source_id: SRC-ea-ftmo-trading-course-20260523
title: "EA - FTMO - Trading Course"
type: video_course
folder_abs: "C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\EA - FTMO - Trading Course"
video_count: 55
total_size_gb: 4.9
language: en   # confirm during Wave-1
has_transcripts: false
has_code: true
code_assets:
  - 15 .mq5 source files
  - 1 .ex5 compiled
  - 4 PDFs
tier: 1
wave_assignment: A1
status: active
mining_policy:
  budget_cap_per_day: 50
  reservoir_drain_required: true
  complete_coverage: true
existing_code_matches: []   # populate from cross-grep
created: 2026-05-23
```

**Enqueue first batch (5 videos to stay under reservoir limit on a first run):**

```bash
# Per-video enqueue — repeat for each path in /tmp/wave1_video_list.txt[0..4]
python tools/strategy_farm/agent_router.py enqueue research_strategy \
  --priority 30 \
  --skills "video-analysis,strategy-extraction" \
  --payload-json '{
    "kind": "dropbox-video-extraction",
    "source_id": "SRC-ea-ftmo-trading-course-20260523",
    "course_folder": "EA - FTMO - Trading Course",
    "video_relative_path": "<VIDEO_FILENAME.mp4>",
    "video_absolute_path": "C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\EA - FTMO - Trading Course\\<VIDEO_FILENAME.mp4>",
    "tier": 1,
    "language_hint": "en",
    "existing_code_matches": ["<from cross-grep>"],
    "contract_version": "v1-2026-05-23"
  }'
```

**Stop condition:** reservoir hits 5 ready cards → halt.

**Switch trigger to A2:** every one of the 55 videos has been routed once (complete coverage); source flipped `status: done` in `farm_state.sqlite`.

### A2 — `Andrea.Unger.Bundle.5.Courses.02.19` (Wave-2 anchor)

**Why second:** Highest-signal vendor in the archive (4× World Cup champion, mechanical systems). 161 videos = ~3.2 days at 50-vid/day cap. Run after A1 has validated the contract.

**Pre-flight:** identical pattern to A1, replace identifiers:
- `source_id: SRC-andrea-unger-bundle-20260523`
- Cross-grep targets: NNFX, breakout, channel, time-of-day, mean-reversion (Unger's typical edge families)

**Stop condition:** reservoir gate + 50-vid/day cap (Wave-2 spans ≥ 3 days).
**Switch trigger to A3:** complete coverage of 161 videos.

### A3 — `Quantreo.Alpha.Quant.Program.02.19` (Wave-3 anchor)

**Why third:** 42 videos / 7 GB, mechanical quant focus (Lucas Inglese, Quantreo.com). Smaller and more recent than Unger.

**Pre-flight CRITICAL:** Three Quantreo entries exist — pick canonical:
- `Quantreo.Alpha.Quant.Program.02.19` (42 vids 7 GB) ← use this
- `Quantreo-Alpha-Quant-Program-Donwload` (42 vids 6 GB) — same content, lower bitrate or missing assets. Compare md5 of first 3 videos to confirm; if same, SKIP this folder.
- `Quantreo Alpha Quant Program 02 19` (0 vids 10 GB) — broken stub, SKIP.
- `Quantreo-Alpha-Quant-Program-Don…` (0 vids 0 GB) — truncated stub, SKIP.

Set `source_id: SRC-quantreo-alpha-quant-20260523`; cross-grep targets: feature engineering, regime detection, walk-forward methodology (Quantreo's typical topics).

**Switch trigger to A4:** complete coverage of the chosen Quantreo release.

### A4 — `15 - Algorithmic-Trading-Robots-Without-Programming 15 8` (Wave-4 anchor)

**Why fourth:** 62 videos / 3.2 GB, MT5 wizard course — generates EAs without code, useful for cross-checking simple rule-strategies. Pair with B2 below (transcript-bearing companion course `Algorithmic Trading Robots Without Programming (17 Hrs)`).

**Source:** `SRC-no-prog-robots-15-20260523`. Cross-grep targets: wizard-based EA templates, simple indicator combinations.

**Switch trigger to B (transcript-first block):** complete coverage of A4.

---

## Block B — Transcript-First (zero Gemini cost — read directly)

**12 folders carry `.vtt`/`.srt`.** These are read by Claude (or a sub-Explore agent) directly from disk — no Gemini call, no token cost. Strategy Card synthesis is the same as for Gemini output: each strategy in the transcript becomes a card draft, then through review.

Recommended ingestion order (high-signal-per-byte first):

| # | Folder | Vids | Transcripts | Special |
|---|---|---:|---:|---|
| B1 | `11 - Algorithmic Trading In MQL5 Automate Free Up Your Time` | 92 | 92 | + 4 .mq5 |
| B2 | `Algorithmic Trading Robots Without Programming (17 Hrs) MT5` | 55 | 94 | 17h course |
| B3 | `4 - Forex Algorithmic Trading For Beginners 30 Robots Monthly` | 38 | 38 | + 60 .mq5 (highest code density in archive!) |
| B4 | `2 - Mql5 Advanced Creating Algorithmic Trading Robots With Mql5` | 27 | 27 | |
| B5 | `Algorithmic trading for dummies` | 35 | 34 | |
| B6 | `5 - Algorithmic Trading Quantitative Analysis Using Python` | 108 | 216 | 2 transcripts/vid = subtitles + speaker text |
| B7 | `The Ultimate Forex Algorithmic Trading Course Build 5 Bots` | 73 | 73 | + 4830 .py (dep tree, ignore) |
| B8 | `13 - Python for finance/ML/algorithmic trading` | 29 | 29 | flag ML content |
| B9 | `Practical Python for Algorithmic Trading` | 27 | 27 | |
| B10 | `3 - Algorithmic Trading Course London New York Tokyo System` | 10 | 17 | |
| B11 | `x3 - Algorithmic Trading Course London New York Tokyo System` | 7 | 17 | likely dup of B10 → skip after dedup check |
| B12 | `16 - SimpleAlgorithmicTradingCrashCourse 4 5 1` | 8 | 8 | |

**Per-folder workflow:**

```bash
# 1. Allocate SRC-<slug>-20260523, create source.md
# 2. Glob transcripts: ls <folder>/*.vtt <folder>/*.srt
# 3. For each transcript, spawn Explore agent (read-only) with the same
#    extraction contract as Gemini gets — but the input is transcript
#    text instead of video. Output schema is identical.
# 4. Claude synthesises Strategy Cards from the YAML returns.
# 5. Same reservoir gate (5 cards) and switch trigger (complete coverage).
```

**Switch trigger to C:** all 12 folders processed; total expected runtime negligible compared to video processing.

---

## Block C — ICT Cluster (AFTER cross-grep)

**12 ICT sub-courses, 312 videos / 22 GB.** Heavy duplication risk with `Ftmo/week1-2/` EAs, `FTMO March 2026/EAs/` portfolios, and the @TRSTNGLRD PDF archive already inventoried.

**Mandatory pre-flight before C1:**

```bash
# Concept-grep against existing code AND existing cards AND ICT-Database
for concept in "SilverBullet" "MMXM" "OTE" "Judas" "FVG" "OrderBlock" \
               "BreakerBlock" "LiquiditySweep" "AsianRange" "QuarterlyTheory" \
               "FibRetracement" "62-79"; do
  echo "=== $concept ==="
  grep -lri "$concept" framework/EAs/ Ftmo/ "FTMO March 2026/EAs/" \
    "Trustful Trading/" strategy-seeds/cards/ 2>/dev/null | sort -u
done > /tmp/ict_existing_concepts.txt
```

Outputs feed into each ICT course's `source.md` as `existing_code_matches:` so Gemini knows which concepts to flag as `duplicate_likelihood: high`.

**Order within Block C (largest first within the cluster):**

| # | Folder | Vids | Likely concept |
|---|---|---:|---|
| C1 | `Proven ICT Forex Trading Strategy Make Consistent Profits` | 62 | generic ICT setups |
| C2 | `Zeussy MMXM Course` | 53 | Market Maker XM model |
| C3 | `Simplified ICT Forex Scalping Trading Strategy using OTE!` | 50 | OTE 62-79% Fib |
| C4 | `The Complete FOREX Trading Secrets of BIG BANKS Course 2023` | 22 | + 5 PDFs |
| C5 | `Ultimate ICT Day Trading Forex Technique Make 3R per Trade!` | 21 | 3R day trades |
| C6 | `Daye's Quarterly Theory Mentorship` | 21 | Daye Quarterly Theory |
| C7 | `The MMXM Trader Course` | 22 | MMXM |
| C8 | `The MMXM Traders 2nd Course` | 7 | MMXM follow-up |
| C9 | `Winning ICT Forex Day Trading Strategy Easy 7R Setups` | 13 | 7R day trades |
| C10 | `Advanced ICT Order Block Forex Trading Strategy High-Gain!` | 13 | OB |
| C11 | `Exclusive ICT Forex Trading Strategy Course Breaker Block!` | 12 | Breaker Block |
| C12 | `1-minute Scalping Trading Strategy ICT Session Liquidity` | 6 | M1 ICT scalper |

**Switch trigger to D:** complete coverage of all 12.

---

## Block D — MQL5 PROJECTS Series

**11 sub-courses, 140 videos / 13 GB.** Each course = one strategy walked through in code. Direct Strategy Card material if course delivers on title.

Order (largest first; martingale-family last):

| # | Folder | Vids | Risk note |
|---|---|---:|---|
| D1 | `MQL5 PROJECTS Code a Master Candlestick breakout strategy` | 19 | |
| D2 | `MQL5 ADVANCED Code a Currency Strength Filter for EAs` | 19 | filter, not strategy |
| D3 | `MQL5 PROJECTS Code a Fair Value GapImbalance Strategy` | 18 | likely dup of FTMO EURUSD Portfolio |
| D4 | `12 - MQL5 PROJECTS Code the Harriet Momentum Hedging strategy` | 17 | hedging — flag for R4 review |
| D5 | `MQL5 PROJECTS Code the Black Swan Trading Strategy in MQL5` | 15 | |
| D6 | `MQL5 ADVANCED Code an HMA Trend Following Strategy` | 14 | |
| D7 | `MQL5 PROJECT Code An AntiPersistence Mean Reversion System` | 12 | |
| D8 | `MQL5 PROJECTS Code a Carry TradeRoll Over Strategy in MQL5` | 11 | carry — special-case rollover logic |
| D9 | `MQL5 ADVANCED Coding for Fundamental Analysis` | 3 | likely no executable strategy |
| D10 | `1 - MQL5 PROJECTS Code the White Fairy Pyramiding strategy` | 7 | **flag pyramiding for R4** |
| D11 | `1 - Grid - MQL5 PROJECTS Code the White Fairy Pyramiding strategy` | 5 | **flag grid+pyramiding for R4** |

D10 + D11 are flagged at enqueue time with `"pre_check": "verify R4 bounded-grid before card creation"` in the payload.

Plus 5 MQL5 Beginner/Advanced foundation courses (lower priority, run after D11):
- `7 - MQL5 Beginner Algorithmic trading with MQL5 New 2021` (36 vids) — likely dup
- `MQL5 Beginner Algorithmic trading with MQL5 New 2021` (35 vids) — reconcile with above
- `Mql5 Complete Algorithmic Trading Course for Synthetic` (7 vids)
- `6 - Mql5 Complete Algorithmic Trading Course for Synthetic` (1 vid stub)

**Switch trigger to E:** complete coverage of D1-D11 plus foundation courses.

---

## Block E — TIER-2 Recognised Vendors

After A+B+C+D drain. Order by video count × signal-per-video heuristic:

| # | Folder | Vids | Size | Type |
|---|---|---:|---:|---|
| E1 | `Bernd Skorupinski` | 106 | 17.7 GB | German retail-Forex educator |
| E2 | `WB Trading` | 78 | 13.1 GB | YouTube channel |
| E3 | `Phantom Course 09-2023 Update` | 77 | 9.1 GB | Phantom Forex brand |
| E4 | `Photon.Trading.FX.2023.02.19` OR `PhotonTradingFX.The.Photon.Course.02.19` | 47 | 7.4 or 45.5 GB | Pick smaller release |
| E5 | `Six Figure Capital - Forex Course` | 38 | 12.3 GB | |
| E6 | `Fenix Pinheiro Trading - Funded Trader 1 Million` | 33 | 2.7 GB | prop-firm trader |
| E7 | `WondaFX` | 31 | 4.8 GB | funded-trader content |
| E8 | `URBAN FOREX - MASTERING PRICE ACTION 1.0` | 45 | 3.5 GB | classic price-action |
| E9 | `URBAN FOREX - MASTERING PRICE ACTION 2.0` | 32 | 1.7 GB | sequel + 32 docs |
| E10 | `Dodgy's Dungeon - Ultimate Trading Course` | 22 | 10.9 GB | |
| E11 | `ADZ Trading Academy - Sniperadz` | 6 | 10.7 GB | HD lectures, few vids |
| E12 | `Wyckoff Video Course` | 3 | 4.3 GB | Wyckoff method |
| E13 | `Trading to Win - Bookmap Masterclass` | 5 | 16.7 GB | Bookmap order-flow tool |
| E14 | `1.Minute.Master.The.Perfect.Execution.1.Minute.Strategy.DOWNLOAD.LINKS` | 15 | 6.8 GB | |
| E15-17 | Other TIER-2 vintage packs (`Evolved Traders`, `Forex Rebellion`, `13 MARKET MOVES FORMULA`, etc.) | varies | | |

**Pre-flight CRITICAL for E4:** Two Photon Trading folders — same 47 videos, different sizes (7.4 GB vs 45.5 GB = SD vs HD). Compare md5 of first video; mine the smaller release unless quality matters for transcription.

**Switch trigger to F:** complete coverage of E1-E15+.

---

## Block F — TIER-3 + `### Forex to read` PDFs

**Only after A+B+C+D+E exhausted.** Per OWNER policy 2026-05-23.

- F1: TIER-3 (the 26 generic YouTube courses + 5 "02.19" vintage packs) — Claude judgment call on which are worth mining; many can be skipped outright after a 1-video sample.
- F2: Task #7 `### Forex to read` (166 PDFs) — dedicated PDF-triage workflow; expected to be 50%+ dups of cards already built from Blocks A-E.

Task #7 description already pre-built (`#7. EXPLORE '### Forex to read' PDFs (LAST — after Strategy Cards built for dedup)`).

---

## Operational notes

- **Per-wave drain expectation:** Wave A1 (EA-FTMO 55 vids) generates an unknown number of cards (0-30 likely; depends on instructional density). Each card spawns Q02 backtest → Q03 sweep → Q08 evidence. Drain time per 5-card batch = depends on backtest queue saturation.
- **OWNER-visible status anchor:** after each wave block, Claude posts a status report (cards created / dropped / duplicates / open blockers) and asks for next-block green light.
- **Duplicate avoidance:** every new card-creation step grep-checks `strategy-seeds/cards/` first. Dedup is enforced by Claude (not by Gemini); Gemini only flags `duplicate_likelihood`.
- **Reservoir override:** OWNER may explicitly set ready_cards limit higher than 5 for an experiment. The default 5 stays unless OWNER overrides.
- **Wall-clock estimate (rough, not a commitment):** A1 = 1 day. A2 = 3 days. A3 = 1 day. A4 = 1.5 days. B = < 1 day total. C = 6-7 days. D = 3-4 days. E = 8-12 days. F = uncertain. **End-to-end: ~25-30 days** of mining activity, far longer if drain cycles dominate.

---

## Status anchors

Each wave block writes a closing-status block into the source's `source.md` when `status: done`:

```yaml
wave_close:
  ended: 2026-MM-DD
  videos_processed: N
  cards_drafted: M
  cards_approved: K
  cards_dropped: D
  duplicates_skipped: U
  total_gemini_calls: G
  total_runtime_hours: H
```

These feed the next-source decision and the per-block retrospective Claude writes for OWNER before requesting Wave-N+1 kick-off.
