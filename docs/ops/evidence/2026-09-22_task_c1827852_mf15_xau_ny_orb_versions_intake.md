# Evidence: MF15 FF XAU NY ORB Versions Intake

- **Task ID:** `c1827852-75e0-4d5d-a3b8-d57502a3adb4`
- **Agent:** gemini
- **Campaign:** OWNER-INTAKE-YOUTUBE-MQL5-FF-VARIANTS-20260922
- **Family ID:** MF15
- **Date:** 2026-09-22
- **Verdict:** `REVIEW` (Disposition: `source-clarification`; EA branch held; primary source HTTP 403 access block; gold ORB lineage linked to `QM5_10181` and `QM5_9357`)

## Context & Authority

Authority: `decisions/2026-09-22_owner_found_sources_factory_intake_variants.md`.
Task packet: `D:/QM/reports/research/factory_source_intake_20260922/packets/mf15.json`.

Required Action:
> "Read both existing permalinks, then compare to gold ORB lineage. No cross-product of thresholds or source versions."

## Analysis & Findings

1. **Primary Source Access & Access Policy:**
   - Attempted bounded reading of the two primary Forex Factory permalinks (`https://www.forexfactory.com/thread/post/15585263` and `https://www.forexfactory.com/thread/post/15609751`) via `read_url_content`.
   - Both URLs returned **HTTP 403 Forbidden** (Cloudflare bot management).
   - Per the binding access contract: "Access blocks are recorded, not bypassed. Stop on actual access block; no proxy/cookie/CAPTCHA bypass. Incomplete access requires a concrete clarification task, not invented source content."

2. **Existing Lineage & Control Audit:**
   - The search metadata in `discovery.json` (FF-07) indicates a New York opening range breakout system on XAUUSD utilizing ATR/body filters and staged exits, with snippets conflicting on range length and filter thresholds.
   - Evaluated `QM5_10181` (`tv-xau-ny-orb-retest`), which implements M5 NY ORB (09:30-09:45 ET), 1H EMA(50) directional bias, ATR range filter, strong-body breakout filter, retest entry, swing pivot stop, and 16:00 ET terminal exit.
   - Audited Q02 backtest results for `QM5_10181`: `FAIL` on `XAUUSD.DWX` (2026-07-05), `NDX.DWX`, `WS30.DWX`, and `GDAXI.DWX`.
   - Audited `QM5_9357` (`mql5-orb-break`): `FAIL` on `XAUUSD.DWX` (2026-07-28), `ZERO_TRADES` on `WS30.DWX`, `INVALID` on `NDX.DWX`.
   - Audited `QM5_10334` (`stockplay-orb`): `FAIL` across `SP500.DWX`, `WS30.DWX`, and `NDX.DWX`.
   - Retained `QM5_10181` and `QM5_9357` as `existing-linked` control evidence; no duplicate build or re-run warranted.

3. **Variant Dispositions:**
   - `GOLD_ORB_EARLIER_VERSION`: `source-gap` (Primary source blocked by HTTP 403; snippet describes XAUUSD NY ORB with ATR/body filter, structurally equivalent to failed `QM5_10181`; full rules unverified; EA branch held).
   - `GOLD_ORB_LATER_VERSION`: `source-gap` (Primary source blocked by HTTP 403; snippet indicates modified range length/thresholds of the same ORB family; parameter variation alone without new economic mechanism does not justify a new card; EA branch held).

4. **Deliverables:**
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf15/mf15_intake.json`
   - `D:/QM/reports/research/factory_source_intake_20260922/factory_outputs/mf15/mf15_intake.md`
