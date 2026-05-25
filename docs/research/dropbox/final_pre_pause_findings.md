# Final Pre-Pause Findings — Dropbox Strategy Research

**Phase:** Close-out (Task #11 of Dropbox strategy-research initiative)
**Date:** 2026-05-23
**Status:** Initiative paused pending better local-video AI

OWNER paused the Dropbox-video mining initiative on 2026-05-23 after the Wave-A1 Batch-01 sandbox-hallucination crisis (see `strategy-seeds/sources/SRC-ea-ftmo-trading-course-20260523/source.md` § 7b). Before the pause, two final targeted explorations were run on artefacts that were assessable WITHOUT watching videos. Documented here so the work isn't lost when the initiative resumes.

## Finding 1 — `ss94n.L.MQL5.B.a.8Currency.H.R.MT.5` is NOT what the folder name suggests

**The catalog (`docs/research/dropbox/finanzen_forex_course_index.md`) flagged this folder as "TIER-3 with code: 14 .mq5 + 8 PDFs — Multi-Currency-Hedge-EA-Kurs."** Reality is much smaller:

- Course title (per PDF metadata): **"Learn MQL5 - Build an 8-Currency Hedging Robot (MetaTrader 5)"** — published Nov 2024
- **Only 1 real trading strategy: "Anna v1.00"** — a single-symbol SMA(10)×SMA(40) crossover EA with 30-pip hard stop + 30-pip trailing stop, 1 lot fixed, hedging-account order-centric trade management
- 14 .mq5 files breakdown: 3 actual EAs (Anna Complete + Anna Incomplete student-exercise + BlackAlgoBasicTemplate skeleton) + 12 educational practice scripts (OnStart() only, not EAs)
- 8 PDFs are foundational reference (OHLC basics, SMA theory, MT5 navigation, FX terminology, MQL5 docs guide, error handling) — NOT advanced strategy material
- "8-Currency Hedging" in the title is **pedagogical aspiration**: students are expected to copy Anna manually to trade 8 pairs. No 8-currency portfolio EA ships.

**V5 mining decision:** 1 candidate Strategy Card max (`anna-sma-cross`). V5-compliant (no martingale, 1-pos-per-magic, deterministic, no ML). Beginner-tier educational EA. Low priority vs the larger-signal sources in TIER-1 / TIER-2.

**Strategy summary (already extractable, no video needed):**

```yaml
slug_candidate: anna-sma-cross
concept: "SMA(10) crossing SMA(40) bottom-up → LONG; top-down → SHORT"
markets: forex
timeframes: any (no hardcoded period)
sl: 30 pips hard stop
tp: reverse-cross OR 30-pip trailing stop (no fixed TP)
position_sizing: 1 lot fixed
hedge_account: required (uses order-centric CTrade)
v5_compliance: R1-R4 PASS (single source, mechanical, DWX-portable, no ML)
expected_card_count: 1
```

The course's pedagogical bonus material (BlackAlgoBasicTemplate as a re-usable skeleton) is NOT separate-card material — it's the same Anna strategy without the parameters filled in.

## Finding 2 — EA-FTMO Trading Course PDFs cannot substitute for the videos

**4 PDFs in the course folder, none usable as a strategy-rule source:**

| PDF | Size | Status | Strategy content? |
|---|---|---|---|
| `Get Started with the FTMO Robot.pdf` (folder copy 1) | 25 MB | **Image-only Canva presentation, 36 pages, no text layer** | UNVERIFIABLE without OCR |
| `Get Started with the FTMO Robot.pdf` (folder copy 2, different MD5) | 25 MB | Same author (Petko Aleksandrov), 36 pages, slightly different file titled "Copy of Get Started with Expert Advisors" | UNVERIFIABLE without OCR |
| `scale-up-money-management.pdf` | 14 KB | **1-page diagram** showing R:R 1:3 / 1:2 / 1:2.5 scaling | Money mgmt only, no setup rules |
| `Time-to-practice.pdf` | 12.5 KB | **1-page exercise worksheet** of the same R:R diagram | Money mgmt only, no setup rules |

**Author attribution discovered (2026-05-23):** Petko Aleksandrov (Canva metadata) — a known MQL5 EA course creator. Both 25 MB PDFs created 2023-08-22. This contradicts the earlier "anonymous instructor" attribution in `SRC-ea-ftmo-trading-course-20260523/source.md` § 1 — author is identified but the PDFs themselves remain rule-empty (image-only marketing decks, not technical specs).

**Critical implication for the pause decision:** even with a working Gemini sandbox + paid API, the EA-FTMO course rules can ONLY be extracted from the 55 video lectures. The 7 FSB Pro-generated `.mq5` source files in the course folder (Envelopes + MACD + Spread Level + Chande Momentum stack) are auto-generated and don't document the human-language rules a Strategy Card needs. The image-PDFs may contain text rules but require OCR (Tesseract not installed on the VPS).

**OCR path NOT pursued** because:
1. Inconsistent with OWNER's whole-initiative pause
2. Even if OCR runs, it doesn't solve the visual-chart-element problem (the same reason Whisper-only was rejected)
3. Only saves 4 PDFs, marginal scope

## Finding 3 — Cleanup state

All 6 Wave-A1 task IDs now in terminal FAILED state in `agent_tasks`:

| Task | Final State | Note |
|---|---|---|
| `47059b7b` Setup 1 | FAILED | RECYCLE-loop final-cancelled |
| `84931317` Setup 2 | FAILED | RECYCLE cancelled before v2 hallucination |
| `6672fa16` Setup 3 | FAILED | Was APPROVED; card deleted, state corrected |
| `9abf0338` Setup 4 | FAILED | Was APPROVED; card deleted, state corrected |
| `aac25e1f` Setup 5 | FAILED | Cancelled before processing |
| `f5043456` Verify | FAILED | Sandbox-verify test; quota-walled, no artifact |

All 6 hallucinated card files deleted from `D:\QM\strategy_farm\artifacts\cards_review\`. Pipeline is clean of Dropbox-initiative noise.

## Resume conditions for the initiative

Three things must be true to restart:

1. **A multimodal video AI** that handles audio + visual on local files without per-MP4 quota limits — plausible candidates: Gemini 3.x Flash with bigger free quotas, Claude with video support, open-source video-LLMs.
2. **A verifiable source-anchoring contract** — Gemini-CLI's silent-hallucination failure mode must be ruled out. Either the tool must error visibly when it can't read input, or the contract must force evidence-of-read in the output schema (e.g. "quote 1 verbatim sentence from minute 03:15").
3. **OWNER green light** — the initiative is OWNER's call, not Claude's. Resume requires explicit instruction.

When (1) + (2) hold, restart with: `SRC-ea-ftmo-trading-course-20260523` re-enqueue (smallest TIER-1, code-on-disk for cross-validation, same Wave-A1 video list).

## Where this work sits in the larger initiative

Initiative inventory still solid:

- ✅ `docs/research/dropbox/existing_ea_inventory.md` — 6 cluster sweeps over 99 .mq5 / 17 .mqh / 222+ .set
- ✅ `docs/research/dropbox/textual_research_inventory.md` — 54 ICT-Database PDFs tiered, Hinterleitner notes read
- ✅ `docs/research/dropbox/finanzen_forex_course_index.md` — 107 course folders with TIER 1-4 assignment
- ✅ `processes/gemini_video_extraction_contract.md` (v1.1) — contract for future video-AI worker, even if Gemini-CLI proved unsuitable
- ✅ `docs/research/dropbox/gemini_wave_playbook.md` — wave-order plan still valid; just needs new video-AI backend
- ✅ THIS DOCUMENT — final pre-pause findings

The initiative is paused, not abandoned. All artefacts remain on `agents/board-advisor` branch for resume.

**Task #7** (`### Forex to read` 166 PDFs) deleted per OWNER 2026-05-23 ("die kannst du generell ignorieren").
