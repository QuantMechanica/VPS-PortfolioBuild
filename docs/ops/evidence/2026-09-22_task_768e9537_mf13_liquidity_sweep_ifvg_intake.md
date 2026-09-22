# Evidence: MF13 FF Liquidity-Sweep IFVG Inversion Intake

- **Task ID:** `768e9537-00bb-4344-8c68-f8123f7bac60`
- **Agent:** gemini
- **Campaign:** OWNER-INTAKE-YOUTUBE-MQL5-FF-VARIANTS-20260922
- **Family ID:** MF13
- **Date:** 2026-09-22
- **Verdict:** `REVIEW` (Disposition: `existing-linked`; EA branch held; `QM5_10253` two-arm NO_MERIT evidence linked; unread source blocked by HTTP 403)

## Context & Authority

Authority: `decisions/2026-09-22_owner_found_sources_factory_intake_variants.md`.
Task packet: `D:/QM/reports/research/factory_source_intake_20260922/packets/mf13.json`.

Required Action:
> "Link10253 two-arm NO_MERIT evidence. Clarify only whether the FF source adds a material mechanism; do not rerun exact negative arms or declare the unread source refuted. Complete the bounded primary-source read and exact mechanical comparison; reuse already read/critic-reviewed sections. Produce a draft only if a distinct mechanically defensible rule exists; otherwise record specific missing rule/data fields and reference disposition. No broad search or renamed retry."

## Analysis & Findings

1. **Primary Source Access & Access Policy:**
   - Attempted bounded reading of the Forex Factory thread (`https://www.forexfactory.com/thread/1382877-liquidity-imbalance-and-inversions-simple-and-repeatable`) via `read_url_content`.
   - The request returned **HTTP 403 Forbidden** (Cloudflare bot protection).
   - Per the access contract: "Access blocks are recorded, not bypassed. Stop on actual access block; no proxy/cookie/CAPTCHA bypass. Unread sources are not declared refuted, but incomplete access requires a concrete clarification task, not invented source content."

2. **Existing Lineage & Two-Arm NO_MERIT Audit:**
   - Audited `QM5_10253_tv-ifvg-sweep`, which mechanizes liquidity sweep plus imbalance / fair value gap inversion with multi-timeframe EMA directional filters.
   - Evaluated candidate analysis `QM5_10253_TV_IFVG_SWEEP_TWO_ARM_FULL_DEV_001` (`C:/QM/repo/framework/EAs/QM5_10253_tv-ifvg-sweep/docs/candidate-analysis/tv_ifvg_sweep_two_arm_full_dev_result.json`):
     - `A_CARD_CENTER`: `NO_MERIT`
     - `B_SOURCE_FAITHFUL`: `NO_MERIT`
     - Fails observed trade count thresholds and the dynamic Bonferroni familywise profit factor floor.
   - Audited pipeline gate history: Q04 `FAIL` on `EURUSD.DWX` (2026-09-06), Q02 `INVALID` on `NDX.DWX`, Q02 `FAIL` on `XAUUSD.DWX` and `GBPUSD.DWX`.
   - Audited related sweep EA `QM5_9926_ff-riverband-sop-m5`: Q04 `FAIL` across `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, linked to active pipeline triage task `7158b874-786a-4047-b0b8-53e80e691d23`.

3. **Mechanical Comparison & Variant Disposition:**
   - While the unread Forex Factory thread is not declared refuted, the liquidity sweep + FVG inversion core mechanism is already rigorously tested in QuantMechanica and failed development across both arms.
   - Creating a new draft card without accessible primary source text would require inventing missing order management, stops, targets, and session cutoffs (~80% of logic), violating the prohibition against fabricated rules.
   - Variant `FF_IFVG_INVERSION_CORE`: `existing-linked` to `QM5_10253` (`NO_MERIT`).
   - EA branch held; no duplicate build or re-run.

4. **Deliverables:**
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf13/mf13_intake.json`
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf13/mf13_intake.md`
