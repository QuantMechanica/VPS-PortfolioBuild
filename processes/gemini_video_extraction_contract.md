# Gemini Video Extraction Contract

**Phase:** Plan / Pre-Gemini design (Task #6 of Dropbox strategy-research initiative)
**Authored:** 2026-05-23
**Status:** DRAFT — first iteration. Iterate after Wave 1 of real Gemini batches.

This document defines exactly what Claude asks Gemini to do per trading-course video, what Gemini returns, and how that return becomes a V5 Strategy Card. The contract exists because the canonical Strategy Card schema is detailed (`strategy-seeds/cards/_TEMPLATE.md`) — unstructured Gemini output cannot be card-converted without machine-tractable fields, and unstructured prompts produce shallow extractions.

## 1. Purpose

Per the `[Dropbox strategy research 2026-05-23]` initiative, ~2,687 course videos in `Finanzen/Forex/` need triage. Gemini is the designated video-analysis worker (router capability: `research, strategy, source_discovery`; max parallel 2). Claude stays the project lead and Strategy Card author — Gemini extracts structured rules, Claude synthesises the card.

## 2. When NOT to invoke

Skip Gemini entirely and do not enqueue a task when:

- **Reservoir gate is closed.** If `farmctl` reports ready-Card reservoir ≥ 5, do not enqueue new Gemini work. The pipeline must drain to ≤ 4 ready cards before another wave starts.
- **Video is in a TIER-4 SKIP folder** (per `docs/research/dropbox/finanzen_forex_course_index.md`). POW BANKER family, ZELDA, ORACLE, Theorem, Darwin Evolution, AnEasierWayToTrade, Ratford, broken duplicates.
- **Folder is a known duplicate** of one already analysed (Quantreo ×3, Photon ×2, MQL5 Beginner ×2, London-NY-Tokyo ×2, 1-Minute-Master ×2, Forex&Gold ×2). Pick one canonical release per cluster.
- **Folder already has transcripts** (`.vtt`/`.srt`). Claude reads the transcript directly — Gemini call is wasted budget. Applies to: 12 folders identified in the course index.
- **Folder appears explicitly ML-centric.** Names like "AI Algorithmic Trading", "GenAI Usage", "Python for finance/ML" — title implies V5-incompatible content. Mine for ideas only, not for code-as-is, and pre-screen with the prompt note "do not extract any ML-dependent rule chain".
- **Video runtime < 90 seconds.** Likely an intro or teaser; no rule content possible.

## 3. Pre-flight (one-time per course folder)

Before enqueueing per-video tasks for a course folder:

1. **Allocate a `source_id`** for the course. Convention: `SRC-<short-slug>-<YYYYMMDD>`, where short-slug is a kebab-case abbreviation of the course title. Example: `SRC-andrea-unger-bundle-20260523`. Store under `strategy-seeds/sources/<source_id>/source.md`.
2. **Create the source folder** with a minimal `source.md` capturing: course folder path, author (best-guess), video count, language, expected wave assignment (per course index), TIER assignment (1/2/3).
3. **Cross-grep existing code** for concepts the course is likely to teach (ICT/SMC/Asian Range/Donchian/MA/RSI/SilverBullet etc.) against `Ftmo/week1-2/`, `FTMO March 2026/EAs/`, `Trustful Trading/YoutubeCodeFIles/`, and the existing `strategy-seeds/cards/`. List the matches. Each match becomes a "port-or-skip" candidate the per-video Gemini call should be informed about.

## 4. Per-video task specification

One agent_router task per video.

```bash
python tools/strategy_farm/agent_router.py enqueue research_strategy \
  --priority 50 \
  --skills "video-analysis,strategy-extraction" \
  --payload-json '{
    "kind": "dropbox-video-extraction",
    "source_id": "SRC-andrea-unger-bundle-20260523",
    "course_folder": "Andrea.Unger.Bundle.5.Courses.02.19",
    "video_relative_path": "Course 1/01 - Intro.mp4",
    "video_absolute_path": "C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\Andrea.Unger.Bundle.5.Courses.02.19\\Course 1\\01 - Intro.mp4",
    "tier": 1,
    "language_hint": "en",
    "duration_sec": 1834,
    "existing_code_matches": ["Ftmo/week2/AsianRangeUltimate.mq5"],
    "contract_version": "v1-2026-05-23"
  }'
```

Routing will land it on Gemini (only agent with `source_discovery` capability and `research+strategy` overlap, given codex/claude are not configured for source-discovery work).

## 5. Gemini prompt template (literal text the agent receives)

```
You are extracting mechanical trading-strategy rules from a trading-course video for QuantMechanica V5, a deterministic MT5 expert-advisor pipeline. V5 has Hard Rules: NO machine learning in EAs (no neural nets, no ONNX inference, no online learning, no parameters that re-fit on running PnL); 1-position-per-magic-number; deterministic logic; grid trading allowed only if bounded with a defined non-runaway position-size formula.

Video metadata (from task payload):
- Source ID: {source_id}
- Course folder: {course_folder}
- Video path: {video_relative_path}
- Duration: {duration_sec} seconds
- Language hint: {language_hint}
- Existing code concepts already in our codebase that this video might cover: {existing_code_matches}

YOUR JOB

Watch the video. Extract every distinct MECHANIZABLE TRADING STRATEGY taught. Most videos will teach 0 strategies (intro/theory/setup/motivational/Q&A) or 1 (focused tutorial). A few teach 2-3. Do not invent strategies the video does not actually teach.

For each strategy, produce one block of structured YAML matching the schema below. Capture verbatim author quotes with timestamps — do NOT paraphrase performance numbers.

OUTPUT FORMAT — single fenced ```yaml block, no prose around it.

```yaml
video:
  source_id: "{source_id}"
  course_folder: "{course_folder}"
  video_relative_path: "{video_relative_path}"
  duration_sec: {duration_sec}
  language_detected: "<en | de | es | …>"
  asset_kind: "<lecture | live-trade | software-walkthrough | interview | hype | other>"

extraction:
  has_strategies: <true | false>
  rationale_if_none: "<one sentence if has_strategies=false; else empty>"
  strategies:
    - slug_candidate: "<lowercase kebab-case ≤ 16 chars, e.g. unger-3sd-break>"
      one_line: "<single sentence describing the edge>"

      source_segment: "<HH:MM:SS-HH:MM:SS>"     # span in the video where the strategy is taught

      markets:                                  # which the author recommends
        - forex
        # - indices | commodities | crypto
      timeframes:
        - H1
        # - M1 | M5 | M15 | M30 | H4 | D1 | W1
      author_target_symbols:                    # specific symbols the author mentions
        - EURUSD

      entry_rules: |
        # pseudocode, one bullet per condition. Use indicator names exactly as in the video.
        - if RSI(14) closes < 30
        - and price > SMA(200) on closed bar
        - then BUY at next bar open

      exit_rules: |
        - TP at +2R from entry
        - SL handled by entry stop
        - trailing stop after +1R: ATR(14)*1.5

      sl_tp: "<one-liner SL+TP formula, e.g. SL=2*ATR(14); TP=3*ATR(14)>"

      no_trade_filters: |
        # author-specified filters; framework defaults (news pause, Friday close) inherited automatically
        - skip first hour after market open
        - skip during NFP day

      trade_management: |
        - move SL to BE at +1R
        - close 50% at +2R
        - no pyramiding

      parameters_to_sweep:
        - { name: rsi_period, default: 14, sweep: [9, 12, 14, 18, 21] }
        - { name: atr_mult, default: 1.5, sweep: [1.0, 1.5, 2.0] }

      author_claims_verbatim:                   # VERBATIM. No paraphrasing of numbers.
        - { text: "I've personally been using this since 2007.", timestamp: "00:24:15" }
        - { text: "Profit factor 1.8 on EURUSD H1 over the last decade.", timestamp: "00:28:42" }

      evidence_kind: "<backtest-curve | spoken-claim | live-screenshot | trade-record | none>"
      reproducibility_risk: "<low | medium | high>"
      reproducibility_notes: "<what's missing or fragile, e.g. 'ATR period not stated', 'indicator settings only on chart screenshot'>"

      strategy_type_flags:                      # from controlled vocabulary; PICK ALL THAT APPLY:
        # martingale, grid, scalping, breakout, trend-following, mean-reversion,
        # momentum, carry, seasonality, news-pause, time-of-day, fade, hedge, pairs,
        # arbitrage, channel, pullback, structure-break, liquidity-sweep
        - breakout

      # SELF-CHECK against V5 G0 criteria (qb_reputable_source_criteria.md v 2026-05-23)
      r1_pass: true                             # source_id is assignable (always true at extraction)
      r2_pass: <true | false>                   # entry+exit rules mechanizable (gaps OK; pure discretion = false)
      r3_pass: <true | false>                   # ≥1 DWX symbol testable (forex, indices, gold, oil — port allowed)
      r4_pass: <true | false>                   # no ML; no runaway martingale; deterministic; 1-pos-per-magic compatible
      r4_concern: "<empty if r4_pass=true; else the specific Hard-Rule clash>"

      # framework module mapping (best guess; CTO refines at APPROVED stage)
      modules_used:
        no_trade: <true | false>
        trade_entry: true                       # always true for any executable strategy
        trade_management: <true | false>
        trade_close: <true | false>

      # any hard-rule risk worth flagging early (multi)
      hard_rules_at_risk:
        # - friday_close                        # holds across Fri 21:00 broker time
        # - ml_forbidden                        # uses any ML-trained component
        # - one_position_per_magic_symbol       # pyramiding implied
        # - grid_1pct_cap                       # grid/martingale without bounded sizing
        # - scalping_p5b_latency                # scalper-tight TP needs VPS latency calibration
        # - news_pause_default                  # author claims edge during news windows
        # - darwinex_native_data_only           # references non-broker data feed

      duplicate_likelihood: "<low | medium | high>"
      duplicate_notes: "<which existing concept this resembles, if any — referenced from existing_code_matches>"
```

QUALITY BAR

A strategy is only worth including if ALL of the following hold:
  - Entry trigger is rule-based (no "feel for the market")
  - Exit trigger is rule-based (SL/TP/timestop — at minimum SL must be specified)
  - At least one symbol/timeframe is named
  - At least one verbatim author claim with timestamp is captured

If the strategy is described only at a conceptual level ("buy at support, sell at resistance" with no operationalization), set has_strategies=false and explain in rationale_if_none.

EDGE CASES

- Video teaches multiple strategies → one block per strategy, all under `strategies:`.
- Video is purely theory / motivational / Q&A / personal-story → has_strategies=false.
- Video shows backtest results only, no rules → has_strategies=false; mention what was promised in rationale_if_none.
- Author claims ML or AI is required → still extract the strategy if you can describe the rule chain, but mark r4_pass=false and r4_concern accordingly; downstream may still mine the non-ML logic.
- Author uses runaway martingale (doubles indefinitely) → r4_pass=false; mark hard_rules_at_risk with grid_1pct_cap; brief description so we know to skip.
- Author uses bounded grid (capped open positions, fixed sizing per level) → r4_pass=true; flag grid_1pct_cap so CTO documents the cap.

DO NOT

- Do not invent rules to fill gaps. If a parameter is not stated, omit it or note it under reproducibility_notes.
- Do not include backtest performance claims you did not hear or see in the video.
- Do not include strategies from videos that just LIST strategies without teaching the rules.
- Do not output prose around the YAML block. Just the fenced YAML.

REPLY FORMAT

Single fenced ```yaml block. No commentary. If the video cannot be read (corrupted, encrypted, language not understood), reply with a YAML block where has_strategies=false and rationale_if_none explains the failure mode.
```

## 6. R1–R4 self-check (Gemini's job)

Per `processes/qb_reputable_source_criteria.md` (revision 2026-05-23):

- **R1 (single source per card, type open):** always PASS at extraction because the `source_id` is allocated upstream.
- **R2 (implementable mechanically, gaps OK):** PASS if entry AND exit are rule-based. FAIL only if purely discretionary.
- **R3 (testable on ≥ 1 DWX instrument, porting allowed):** PASS if any forex pair, index CFD, gold, oil — or anything portable to those.
- **R4 (no ML, 1-pos-per-magic, deterministic, grid OK if bounded):** binding Hard Rule 14. FAIL on neural nets, online learning, ONNX inference, parameters that re-fit on running PnL, runaway martingale, undeclared multi-position-per-magic.

A strategy with `r4_pass=false` may still be included in the YAML — Claude decides downstream whether to discard or to mine a non-ML subset.

## 7. Post-processing by Claude (consuming Gemini output)

Per video-task return, Claude:

1. **Validates the YAML.** If malformed, mark the agent_task FAILED, attach the raw return, do not retry without inspecting why.
2. **Per strategy block** (in the order Gemini returned them):
   - If `r2_pass=false` OR `r4_pass=false` with no salvageable non-ML subset → DROP (note in source's `dropped.md` for audit).
   - If `duplicate_likelihood=high` → check the named existing concept; if confirmed duplicate, log as `port-or-skip` candidate; do not create a new card.
   - If `duplicate_likelihood=medium|low` → CREATE a Strategy Card at `strategy-seeds/cards/<slug>_card.md` using `_TEMPLATE.md`. Map Gemini fields into card sections:
     - `source_id` → `source_citations[0].citation` + `source_citations[0].location` = `source_segment`
     - `markets`, `timeframes`, `author_target_symbols` → § 3
     - `entry_rules` → § 4
     - `exit_rules` + `sl_tp` → § 5
     - `no_trade_filters` → § 6
     - `trade_management` → § 7
     - `parameters_to_sweep` → § 8
     - `author_claims_verbatim` → § 9 (each one as a separate quoted line)
     - `strategy_type_flags` → frontmatter
     - `modules_used` + `hard_rules_at_risk` → § 12
     - `reproducibility_notes` → appended to § 11 as "Reproducibility gap noted in Gemini extraction: …"
3. **Status:** new card lands in `DRAFT`. Claude reviews and bumps to `IN_REVIEW` only after a quick sanity read. CEO (OWNER + Claude proxy) then bumps to `APPROVED` if R1-R4 all pass.
4. **Reservoir gate check after each new card** — if reservoir reaches 5, halt Gemini wave, drain pipeline, resume.

## 8. Failure modes & handling

| Symptom | Likely cause | Handling |
|---|---|---|
| Gemini returns no YAML or non-fenced prose | Prompt drift or model refused | Mark task FAILED, attach raw, escalate to OWNER if pattern repeats |
| YAML valid but `has_strategies=false` for >50% of a course | Course is theory-heavy or Gemini bored | Spot-check 2 videos manually; if Gemini correct, lower the course's tier in the index |
| YAML produced but all strategies marked `r2_pass=false` | Course is purely discretionary (e.g. price-action with no rules) | Stop the wave for that course; record in source's `dropped.md` |
| Same strategy returned across 5+ videos in one course | Author repeats teaching | OK — pick the most complete extraction, merge `author_claims_verbatim` from the others |
| `r4_pass=false` flagged ML but rules describe non-ML logic | Author teaches both | Salvage the non-ML rules into a card; note the ML layer was stripped |
| Duplicate of existing Strategy Card | Port-or-skip needed | DO NOT create a new card. Add a note to the existing card's § 12 referencing the new source as supplementary citation. |

## 9. Routing & throttle

- **Routing:** `agent_router.py route-many` will assign `research_strategy` tasks with `kind: dropbox-video-extraction` to Gemini (only agent with `source_discovery`).
- **Parallelism:** Gemini's `max_parallel=2` per the agent registry. Wave dispatch respects this; do not flood with 50 enqueues at once.
- **Reservoir gate:** ≥5 ready cards = stop new waves. Per OWNER's mining policy `qb_reputable_source_criteria.md § Mining policy 2026-05-15`: extract up to 5 cards per session, then mark source `cards_ready`, drain pipeline, resume after all 5 reach pipeline-end.
- **Wave-1 anchor list** (per `docs/research/dropbox/finanzen_forex_course_index.md`): start with EA-FTMO Trading Course (55 vids, has code), Andrea Unger Bundle (161 vids, mechanical), Quantreo Alpha Quant (42 vids, mechanical). NOT all at once — pick one course, work through to 5 cards, drain, repeat.

## 10. Iteration policy

This contract is `v1-2026-05-23`. Bump the version field in the task payload (`contract_version`) each time the schema changes — Gemini's prompt template must change in lockstep. Wave-1 will reveal where the schema is too tight (Gemini omits a needed field) or too loose (returns noise the post-processor can't use). Revise after Wave 1 with concrete examples of what worked / didn't.

## 11. References

- `strategy-seeds/cards/_TEMPLATE.md` — canonical Strategy Card schema
- `strategy-seeds/cards/singh-eng-bk-tea_card.md` — concrete example of a well-formed card (reference for level of detail)
- `processes/qb_reputable_source_criteria.md` — R1-R4 (revision 2026-05-23)
- `processes/13-strategy-research.md` — overall research workflow (per QUA-236)
- `docs/research/dropbox/finanzen_forex_course_index.md` — TIER assignments + wave order
- `tools/strategy_farm/agent_router.py` — task routing (`enqueue research_strategy`, capabilities, registry)
- `CLAUDE.md` — V5 Hard Rules (no ML in EAs, RISK_FIXED for backtest / RISK_PERCENT for live, no public VPS exposure)

## 12. OWNER-resolved policies (2026-05-23)

The original five open questions resolved as follows:

1. **Source-folder naming.** `strategy-seeds/sources/SRC-<short-slug>-<YYYYMMDD>/source.md`. Self-describing, date-versioned, alphabetically sortable. Differs from the legacy `SRC<NN>` numeric convention in processes/13-strategy-research.md — the new naming wins for Dropbox-mined sources; existing numeric SRCs (e.g. SRC06 Singh) keep their names. No renumbering campaign.
2. **TIER-3 mining policy.** Skip TIER-3 (the 26 generic YouTube courses + 5 "02.19" vintage packs) until TIER-1 and TIER-2 are fully exhausted. Do not enqueue TIER-3 tasks while any TIER-1/2 course remains with unmined videos.
3. **Hinterleitner videos.** Deferred. Re-open only if `Finanzen/Forex` ends up containing identifiable Hinterleitner course material that Task #2 catalogue did not surface under his name (e.g. videos hosted under a different folder title). If Wave-1 reveals such videos, raise the MomentumTrailer reimplementation question with OWNER then.
4. **Per-source Gemini budget cap.** **Max 50 videos per course per day**, ~8 h wall-clock at 2 parallel Gemini extractions × ~10 min each. Caps individual-course concentration without freezing the queue: Andrea Unger (161 videos) ≈ 3 days end-to-end, EA-FTMO (55) ≈ 1 day, Quantreo (42) < 1 day.
5. **"Course exhausted" signal.** **Complete coverage** — every video of a course goes through Gemini once before the source flips to `status: done`. No early-exit heuristic on consecutive `has_strategies=false`. Avoids false-negatives from author-style "theory first, then strategy" sequencing. Combined with the reservoir gate + OWNER mining policy (5 cards then drain), a 161-video course spans many drain cycles spread across days, but every video gets seen.

## 13. Wave-1 queue (concrete starting point)

Anchor course for Wave-1: **`EA - FTMO - Trading Course`** (55 videos, 4.9 GB). Rationale: TIER-1, smallest video count among the top anchors (8h fits inside one budget-cap day), and the course ships with 15 .mq5 sources + 1 .ex5 already on disk — so even partial Gemini extractions can be reconciled against compiled code. Best controlled environment to validate the contract before scaling to Andrea Unger.

Pre-flight steps for Wave-1 (not yet executed; require explicit OWNER kick-off):

1. Allocate `source_id`: `SRC-ea-ftmo-trading-course-20260523`.
2. Create `strategy-seeds/sources/SRC-ea-ftmo-trading-course-20260523/source.md` with course metadata + cross-grep against existing FTMO_*_Portfolio EAs (lots of overlap likely with `FTMO March 2026/EAs/`).
3. Enqueue first batch of ≤ 5 video-tasks via `agent_router.py enqueue research_strategy`.
4. Monitor returns, validate YAML, synthesise cards.
5. At reservoir = 5, halt, drain pipeline, resume next batch.

Wave-2 anchor (after EA-FTMO complete): **Andrea Unger Bundle** (161 videos, 5.4 GB) — highest-signal vendor in the archive.
