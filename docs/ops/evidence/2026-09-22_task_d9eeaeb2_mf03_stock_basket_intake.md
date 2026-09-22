# Evidence: MF03 Stock Baskets & Supply-Chain Lead/Lag Intake

- **Task ID:** `d9eeaeb2-8052-4a77-ad3b-74be66b5523e`
- **Agent:** gemini
- **Campaign:** OWNER-INTAKE-YOUTUBE-MQL5-FF-VARIANTS-20260922
- **Family ID:** MF03
- **Enqueued Child Task:** `1878c6df-fb9d-4748-85fd-38cb4f3ffa89`
- **Date:** 2026-09-22
- **Verdict:** `REVIEW` (Disposition: `data-gap` / `source-clarification`; EA branch held; data-contract clarification child task enqueued)

## Context & Authority

Authority: `decisions/2026-09-22_owner_found_sources_factory_intake_variants.md`.
Task packet: `D:/QM/reports/research/factory_source_intake_20260922/packets/mf03.json`.

Required Action:
> "Queue source/data-contract clarification only. Link extensive cointegration lineage; no automatic FX proxy or broad pair search."

## Analysis & Findings

1. **Cointegration Lineage Audit:**
   - Previous factory EAs attempting cointegration (`QM5_1156`, `QM5_9184`, `QM5_10309`, `QM5_12532`, `QM5_12003`) repeatedly demonstrated that substituting arbitrary FX pairs for fundamentally cointegrated economic assets leads to out-of-sample breakdown (failing Q04/Q05).
   - Foreign exchange co-movements reflect macro sovereign policies rather than corporate economic linkages.

2. **Source Scope (MQL5 Articles 19052, 18702, 19428, 19626, 21811):**
   - Focuses on supply-chain customer-supplier relationships and equity cointegration.
   - Requires single-stock equity data feeds, corporate action adjustments, borrow availability for short legs, and point-in-time relationship tracking.
   - Current MT5 broker venues (DWX, FTMO) do not support the required single-stock equity data or execution environment.

3. **Execution & Deliverables:**
   - Enqueued data-contract clarification task `1878c6df-fb9d-4748-85fd-38cb4f3ffa89` to investigate single-stock venue and data feeds.
   - Held EA branch; rejected automatic FX proxying per strict instruction.
   - Durable intake reports written to:
     - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf03/mf03_intake.md`
     - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf03/mf03_intake.json`
