# Evidence: MF05 Stocks-in-Play and MePip Cash-Equity ORB Intake

- **Task ID:** `0331d6ec-0ee5-42d2-b660-be0819183683`
- **Agent:** gemini
- **Campaign:** OWNER-INTAKE-YOUTUBE-MQL5-FF-VARIANTS-20260922
- **Family ID:** MF05
- **Date:** 2026-09-22
- **Verdict:** `REVIEW` (Disposition: `source-clarification` / `data-gap`; EA branch held; single-stock venue gap; CFD lineage linked to `QM5_1255` & `QM5_10334`)

## Context & Authority

Authority: `decisions/2026-09-22_owner_found_sources_factory_intake_variants.md`.
Task packet: `D:/QM/reports/research/factory_source_intake_20260922/packets/mf05.json`.

Required Action:
> "Attach both sources to a stock-venue fidelity/data task; keep their rule versions separate."

## Analysis & Findings

1. **Existing Lineage Audit:**
   - Evaluated `QM5_10334` (`stockplay-orb`), an index-CFD proxy port of the single-stock "in-play" concept; failed economically in Q02 across `SP500.DWX`, `WS30.DWX`, and `NDX.DWX` due to poor volume proxy fidelity on index composites.
   - Evaluated `QM5_10335` (`nse-vol-orb`), a volume-filtered ORB; failed Q02 across `NDX.DWX`, `SP500.DWX`, and `WS30.DWX`.
   - Evaluated `QM5_1255` (`zarattini-qqq-orb`), which already captures the mechanical cash-session opening range breakout; successfully passed Q02 and Q03 on `NDX.DWX`, currently pending Q04 walk-forward (`1890918d-19c0-44a2-89f8-3ebf3c7d83b9`).

2. **Source Analysis & Venue Fidelity Gaps:**
   - **MQL5 Article 23226 (In-Play Stocks):** Single-stock relative volume selection requires point-in-time US equity feeds, corporate actions adjustments (splits/dividends), borrow locate availability, and real consolidated tape volume—none of which are provided on the active MT5 CFD infrastructure (Darwinex Zero, FTMO).
   - **Forex Factory MePip (Post 15187690):** Relies on Interactive Brokers (IBKR) direct market access on shares/QQQ and discretionary tape reading. Its mechanical breakout rule is already covered by `QM5_1255`.

3. **Variant Dispositions:**
   - `STOCKS_IN_PLAY_FAITHFULNESS`: `data-gap` / `existing-linked` (linked to failed `QM5_10334`). Single-stock data gap; EA branch held.
   - `MEPIP_NATIVE_VENUE_CONTRACT`: `existing-linked` (linked to active pipeline candidate `QM5_1255` in Q04). Native equity venue fidelity gap; duplicate build avoided.

4. **Deliverables:**
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf05/mf05_intake.json`
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf05/mf05_intake.md`
