# Evidence: Kevin Davey Index Rule Contract Intake

- **Task ID:** `002c4ec3-9081-4cb8-a3a5-c966398a977d`
- **Agent:** gemini
- **Campaign:** OWNER-INTAKE-YOUTUBE-MQL5-FF-VARIANTS-20260922
- **Family ID:** KEVIN_DAVEY_SOURCE
- **Enqueued Child Task:** `3b755d40-747a-4058-9818-294bfdff273d`
- **Linked Book Source:** `63f7babe-045d-534b-ad66-ba4e69881764` (`book:davey-building-winning-algorithmic-trading-systems`)
- **Date:** 2026-09-22
- **Verdict:** `REVIEW` (Disposition: `source-gap`; EA branch held; bounded book research child task enqueued)

## Context & Authority

Authority: `decisions/2026-09-22_owner_found_sources_factory_intake_variants.md`.
Task packet: `D:/QM/reports/research/factory_source_intake_20260922/packets/kevin_davey_source.json`.

Required Action:
> "Create one bounded source task linked to existing Davey book-source 63f7babe-045d-534b-ad66-ba4e69881764 (pending). Select at most one ES/NQ rule from a specific official video or book section, record exact URL/section/date and actual transcript/page receipt, and extract entry, exit, stop, session, timeframe, sizing, costs and tested periods. Compare with existing 1004 and 11454; latter is FX-only in its SPEC. If no complete rule is available, return named missing fields and hold the EA branch. Do not invent Donchian/ADX rules from the June synthesis."

## Analysis & Findings

1. **Existing Implementations:**
   - `QM5_1004` (`davey-es-breakout`): Uses a 20-bar Donchian channel breakout on H1 ES with ATR(14)*2.0 SL and opposite-breakout exit.
   - `QM5_11454` (`davey-session-open-bracket-breakout`): Implements an 08:00 UTC London opening bracket for FX majors, with Section 3 of `SPEC.md` explicitly stating "Explicitly NOT for: Index .DWX symbols".

2. **Source Status:**
   - The public links (`kjtradingsystems.com/videos-and-tools.html`, YouTube channel) provide high-level methodology and workshop promotion, lacking complete, unambiguous index mechanical specifications.
   - Named missing fields:
     1. Entry trigger formula
     2. Stop loss calculation
     3. Exit mechanism
     4. Trading session hours (RTH vs ETH)
     5. Timeframe / bar frequency
     6. Sizing and transaction costs
     7. In-sample / out-of-sample testing range

3. **Execution & Deliverables:**
   - Enqueued bounded source research task `3b755d40-747a-4058-9818-294bfdff273d` linked to pending book source `63f7babe-045d-534b-ad66-ba4e69881764`.
   - Held EA branch from speculative card creation to avoid unverified synthetic indicators.
   - Durable intake reports written to:
     - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/kevin_davey_source/kevin_davey_source_intake.md`
     - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/kevin_davey_source/kevin_davey_source_intake.json`
