# E1-B2 native data completion — REVIEW

Task `07add720-26c2-4e30-9c29-e2c801681df9`. Code `93198a4d2d2efe9922141b3114a9acc5cb72d4dc` on `agents/codex-news-e1b2-20260905`; based on the reviewed E1-A builder commit. Ten native exports are on disk and hash-verified. Candidate verification remains **FAIL / NOT PUBLISHABLE**. No production calendar, Common mirror, bundle, dxz23 registry, detector enforcement or news hold was changed.

| Native export | Rows | SHA256 |
|---|---:|---|
| T_EXPORT_USD_HIGH_2026H1_NATIVE.csv | 256 | `fdf66947d3e96315066742d096f5f56ddf22238d829a718362cf69cd15f085c2` |
| T_EXPORT_EUR_HIGH_2026H1_NATIVE.csv | 75 | `a85f188e46e85814bfc134147940011bd3fd8ad67a4167a37942cf12886394d6` |
| T_EXPORT_GBP_HIGH_2026H1_NATIVE.csv | 38 | `37b945c429ebd1bf8050487f0f5262eab39c8eba8df892573a427059e204659d` |
| T_EXPORT_JPY_HIGH_2026H1_NATIVE.csv | 30 | `0fcc2ee25ac1b0813ced4d0a8799efac3f499a0e302c2d8063ef80e58d5c052b` |
| T_EXPORT_AUD_HIGH_2026H1_NATIVE.csv | 4 | `e4947aa1e22391e7fd3bfc633aea90c9938597aec4b8cd4326d8947031161061` |
| T_EXPORT_CAD_HIGH_2026H1_NATIVE.csv | 5 | `f08c81110a41a5fdf1a2c29593e7929127463de315f56f56e17363580857bdae` |
| T_EXPORT_USD_ALL_CORE_PPI_2018_2025_NATIVE.csv | 94 | `a18a444683e52b113d509e34fa501e42060109830395349ac547e74c31a37869` |
| T_EXPORT_USD_ALL_EMPIRE_STATE_2018_2025_NATIVE.csv | 96 | `5bf93456ebc9b9d04dd39eadf549fba1b33e2f70dc805f5945cf7414fbe5d315` |
| T_EXPORT_USD_ALL_BUILDING_PERMITS_2018_2025_NATIVE.csv | 93 | `d2f1695b38034fbc8446b5c3215ffe406cd129608d402e73232acf5e38aa6d78` |
| T_EXPORT_USD_ALL_TRADE_BALANCE_2018_2025_NATIVE.csv | 95 | `24d6d748a703c911225b0ad477284f6ce66bc2390af62613fd808233b6df3b62` |

The exporter uses the canonical bootstrap's StartUp configuration pattern and process-observation helpers through a wrapper restricted to `D:/QM/mt5/T_Export`. The current canonical bootstrap classifies T_Export as unknown, so its lane/factory launch guard was preserved. The new wrapper validates the exact export path, unique task config and fresh process identity, compiles a read-only script, launches hidden with Experts/AllowLiveTrading/AllowDllImport disabled, and closes only the owned export process. Existing output names are refused. No T1–T10 process was interrupted and no T_Live process was signalled.

Currency-wide annual USD queries returned 5401. Event-specific annual queries produced the catalog files. The native Empire State catalog name is `NY Fed Empire State Manufacturing Index`, event ID 840230001. The single-export preset required numeric datetime epochs; diagnostic receipts preserve the refused/empty attempts. A MetaTrader update replaced one launcher process; a separate cleanup receipt binds its exact executable, unique StartUp config, creation time and completed script marker. Final wrapper handling covers that handoff. Final exporter compile: **0 errors, 0 warnings**; the compiled source/ex5 hashes and process cleanup are in `export_receipt.json`. Tests: **22 passed** (repair/detector/export validation and handoff identity).

The candidate is `D:\QM\reports\news_calendar\repair_e1a\20260905T102700Z_e1b2_candidates`, manifest SHA256 `a3feb12a0065cc5b7d9a19ca2c4f539bdc840a4d2e9b9adc0eaac2b849e309b3`. Both files retain their exact 20/9-column schemas and all source rows. Native-confirmed matches take precedence. **2,294** remaining unambiguous one-minute SECONDARY differences were aligned to PRIMARY and explicitly logged `COMMON_MINUTE_PRIMARY_FALLBACK_UNVERIFIED`. This is consistency, not independent timestamp proof. Ambiguous matches remain unresolved. No impacts were promoted; catalog medium/low rows cannot generate HIGH backfills.

Fresh query timestamps are excluded from candidate truth until their own three distinct, consistent official anchors establish their UTC encoding. Ten new exports currently lack that proof. This avoids inheriting UTC from the old full-range export: its separate 2025 query was previously measured +3 hours. MQL5 documents calendar timestamps in [trade-server time](https://www.mql5.com/en/docs/calendar/calendarvaluehistorybyevent). Export presence therefore does not establish correct UTC blackouts.

| Gate | Result |
|---|---|
| 6.1_anchor_shares | FAIL |
| 6.2_coverage | FAIL |
| 6.3_cross_file_identity | PASS |
| 6.4_nonusd_completeness | PASS |
| 6.5_tick_footprints | FAIL |
| 6.6_no_row_loss | PASS |
| 6.7_detector_clean | FAIL |
| 6.8_schema | PASS |

`verification.json` records exact failed groups; `e2_e4_gap_inventory.csv` retains the EUR/JPY/AUD/CAD and other unresolved class/month gaps, and `nonusd_offset_decisions.json` retains offset evidence. H1 structural exports are present; official H1 anchors, unverified native time encodings and existing tick-footprint gaps still prevent publication. Production input hashes before/after match. Candidate files and the complete row audit remain under D:, bound by `result.json`'s artifact inventory. Leave REVIEW; no reseal or release is authorized by this FAIL result.
