# Evidence: MF10 ORB Retest / Rebreak & Fadhl Nasdaq Examples Intake

- **Task ID:** `65d07967-0bea-42eb-a39a-aac5862f01d0`
- **Agent:** gemini
- **Campaign:** OWNER-INTAKE-YOUTUBE-MQL5-FF-VARIANTS-20260922
- **Family ID:** MF10
- **Date:** 2026-09-22
- **Verdict:** `REVIEW` (Disposition: `source-clarification`; EA branch held; limit-retest control linked to `QM5_10659`)

## Context & Authority

Authority: `decisions/2026-09-22_owner_found_sources_factory_intake_variants.md`.
Task packet: `D:/QM/reports/research/factory_source_intake_20260922/packets/mf10.json`.

Required Action:
> "Finish source contract then register maximum two clearly labelled variants. FF bounded public read is authorized; the old offline-router deferral is not a blanket intake block."

## Analysis & Findings

1. **Existing Lineage Audit:**
   - Evaluated `QM5_10659` (`tv-orb-retest`), which already implements boundary limit retests on opening ranges.
   - Audited Q02 backtest results across 7 symbols (`NDX.DWX`, `SP500.DWX`, `WS30.DWX`, `GDAXI.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`); all resulted in `FAIL` due to adverse selection on limit retest fills.
   - Retained `QM5_10659` as `existing-linked` control evidence (`LIMIT_RETEST_CONTROL`); no duplicate build or re-run needed.

2. **Source Analysis (MQL5 Article 18486 & Forex Factory 1292277):**
   - MQL5 18486 specifies a closed-bar re-break confirmation (not touch limit), but omits order placement, execution handlers, and exit rules.
   - Fadhl's Forex Factory posts are discretionary chart annotations with macro context rather than an algorithmic trading system.
   - Per Acceptance Criteria #5, completing the missing ~70% trade lifecycle cannot be attributed to the external author.

3. **Variant Dispositions:**
   - `LIMIT_RETEST_CONTROL`: `existing-linked` to `QM5_10659` (`FAIL` in Q02).
   - `REBREAK_MECHANIZED`: `source-clarification` (EA branch held pending formal internal Edge Lab thesis specification).

4. **Deliverables:**
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf10/mf10_intake.json`
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf10/mf10_intake.md`
