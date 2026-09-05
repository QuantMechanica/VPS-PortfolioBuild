# DSR V2 read-only frontier projection

RESULT: PASS (read-only projection). Decision **OWNER-DEC-DSR-V2-ACTIVATION-20260905** activates the corrected Q08 Deflated Sharpe Ratio V2 for NEW runs only. This document projects the current frontier under V2 without changing anything. **No stored verdict, work item, pool definition, contract, threshold, trade stream, freeze or pointer was modified; no database or `D:/QM/reports/work_items` write occurred.** The projection reads each existing `aggregate.json` through the read-only inspector `tools/strategy_farm/evidence_status.py` (env `QM_DSR_V2=1`, cwd `C:/QM/repo`), which emits `qm.evidence-status/v1` JSON to stdout and touches no state.

Snapshot: 2026-09-05T19:04:21.954880+00:00. Inputs enumerated from `docs/ops/evidence/2026-09-05_m04_dsr_wiring.md` (sections `current_q11_pass_pairs` and `latest_28_q08_pass_artifacts`) and the linked `docs/ops/evidence/2026-09-05_m04_dsr/snapshot_1818/recompute.json` (aggregate paths + SHA-256). V2 formula: Bailey & Lopez de Prado (2014), eq. 2; corrected calendar/cohort construction in `framework/scripts/q08_davey/dsr_v2.py`.

## Headline

Across **48 distinct Q08 aggregate artifacts** (the 31 current Q11 PASS pairs union the 28 latest Q08 PASS artifacts; the two scopes overlap by 11 shared artifacts, so **31 + 28 entries = 48 distinct**, never additive candidate-pool counts):

- **0 of 48 project a V2 PASS.** None can: no artifact carries a sealed, hash-bound, loser-inclusive selection cohort or a declared trial count via a `dsr_context`.
- **46 project `UNCORRECTED_SELECTION`** — a positive-Sharpe survivors-only estimate with no correction evidence. Under an *active* V2 run this classification blocks the aggregate as INVALID.
- **2 project `LOW_SAMPLE`** — fewer than 60 calendar days of returns; the existing LOW_SAMPLE allowance is retained (not a selection correction, not a PASS).
- **`dsr_context` present: 0 of 48.**

## Summary table (counts by V2 projected outcome)

| Scope | Rows | Legacy DSR | V2 projected | dsr_context present |
|---|---:|---|---|---:|
| Frontier — current Q11 PASS pairs | 31 | deferred=31 | UNCORRECTED_SELECTION=31 | 0 |
| Latest 28 Q08 PASS artifacts | 28 | deferred=26, insufficient days=2 | LOW_SAMPLE=2, UNCORRECTED_SELECTION=26 | 0 |
| Distinct (union) | 48 | deferred=46, insufficient days=2 | LOW_SAMPLE=2, UNCORRECTED_SELECTION=46 | 0 |

Additional inspector axes (distinct 48): technical_validity unavailable=25, valid=23; economic_result positive=48; evidence_binding current=23, missing=23, stale=2.

Legacy-outcome vocabulary: **deferred** = legacy DSR PASS deferred to a future cohort (positive Sharpe, `n_peers=0`, `standalone_pending_cohort`); **insufficient days** = legacy gate flagged `insufficient_daily_returns` (< 60 calendar days); **computed** = a real deflated DSR was calculated (none present).

## Plain-language reading

**What the counter currently rests on.** Every current Q11 PASS pair traces back through `promoted_from_work_item` to a Q08 sub-gate 8.2 that is a *deferred* DSR PASS: the first candidate for its (EA, symbol) had a positive Sharpe and no peer cohort, so the legacy gate recorded a trivial pass and postponed deflation "until >= 1 peer(s)." That is the same as saying **no multiple-testing correction has ever been applied** to any pair on the frontier. The two `insufficient days` artifacts never had enough daily returns to compute a Sharpe at all. Economically the streams are positive after recorded costs (positive=48), which is why they survived the other Q08 sub-gates — but positive-after-cost is not a selection-corrected edge.

**What changes for NEW runs.** With V2 active (`QM_DSR_V2=1` inherited by the Q08 child process and a `dsr_context` forwarded in the work-item payload), the deferred/trivial branch no longer yields a silent PASS. A run that reaches sub-gate 8.2 without a sealed loser-inclusive cohort is classified `UNCORRECTED_SELECTION` and the aggregate is rendered INVALID rather than passed. The strict threshold `p < 0.05` and the existing LOW_SAMPLE allowance are unchanged. Missing context can never become a trivial PASS — the failure is fail-closed.

**What a legitimate V2 PASS requires.** A producer must seal, and the payload must hash-bind, a `dsr_context` (`qm.dsr-selection-context/v1`) that supplies: a complete search history (`qm.dsr-search-history/v1`, `complete=true`, candidate-configuration trial IDs, `annual_measurements_are_trials=false`) and a loser-inclusive research cohort (`qm.dsr-research-cohort/v1`, `complete=true`, `losers_included=true`) whose per-trial daily series hashes and dispersion match the evaluated candidate byte-for-byte. For a DL-089 v3 selection the sealed trial declaration must match the adopted rule hash and the **declared trial count of 154 pattern trials plus the predeclared numeric trials**, with `selection_trial_ids` of exactly that count; annual measurement cells do not multiply the count. Until a governed producer emits that receipt, the honest projection for all existing frontier artifacts is `UNCORRECTED_SELECTION`.

**No verdict was changed.** This is a projection only. The 48 artifacts retain their stored Q08 verdicts and the 31 pairs retain their Q11 PASS. Activation applies to NEW runs; existing verdicts are untouched by decision and by this document.

## Per-entry — frontier (current Q11 PASS pairs, 31)

| EA / symbol | Q08 work-item | Legacy DSR | V2 projected | stat_suff | tech | econ | binding | dsr_context | aggregate.json |
|---|---|---|---|---|---|---|---|:---:|---|
| QM5_10145 / XAUUSD.DWX | 48778bc7 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\48778bc7-e7e0-499a-8266-4c0c1c50e8a5\QM5_10145\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10403 / XAUUSD.DWX | 7fd4caf6 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\7fd4caf6-b599-4833-a431-a132a404b60b\QM5_10403\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10513 / XAUUSD.DWX | da5dc579 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\da5dc579-3d0a-4591-80e8-dc64eb52d81e\QM5_10513\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10700 / XAUUSD.DWX | ce371d25 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\ce371d25-12b0-44b8-9d55-0854c9adcdd8\QM5_10700\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10706 / GBPUSD.DWX | a2e1aba6 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\a2e1aba6-45ea-4dcf-af98-1f679ebeb64f\QM5_10706\Q08\GBPUSD_DWX\aggregate.json` |
| QM5_10911 / GDAXI.DWX | 55256268 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\55256268-50f8-4d94-8d9a-83652c64b013\QM5_10911\Q08\GDAXI_DWX\aggregate.json` |
| QM5_11294 / XAUUSD.DWX | d0f55c10 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\d0f55c10-bcaf-414d-ba04-5e1307e5a061\QM5_11294\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_11421 / EURUSD.DWX | c93263aa | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | stale | no | `D:\QM\reports\work_items\c93263aa-a707-45ea-a915-204ec59df077\QM5_11421\Q08\EURUSD_DWX\aggregate.json` |
| QM5_11422 / USDCAD.DWX | d3907c1a | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\d3907c1a-dc69-4498-be2f-80b064a2c02f\QM5_11422\Q08\USDCAD_DWX\aggregate.json` |
| QM5_11660 / NDX.DWX | 0fd00da5 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\0fd00da5-b4c2-4aa2-a5d2-99fe5b62be9c\QM5_11660\Q08\NDX_DWX\aggregate.json` |
| QM5_11708 / EURUSD.DWX | 861577c0 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\861577c0-2a5b-42a2-9a6a-2ea9cfb9caf5\QM5_11708\Q08\EURUSD_DWX\aggregate.json` |
| QM5_11881 / GBPUSD.DWX | 964600f4 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\964600f4-b743-4b94-8693-6a1abbe5e5f1\QM5_11881\Q08\GBPUSD_DWX\aggregate.json` |
| QM5_11910 / NZDUSD.DWX | e0237a77 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\e0237a77-9017-4b56-aef3-1be924c2c8cc\QM5_11910\Q08\NZDUSD_DWX\aggregate.json` |
| QM5_12710 / XTIUSD.DWX | bfda1943 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\bfda1943-a80e-42de-a872-d26029e3e428\QM5_12710\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_12849 / XTIUSD.DWX | a30d8bcd | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\a30d8bcd-a7c3-4ad4-a061-09e1fe789a35\QM5_12849\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_12855 / XTIUSD.DWX | 7f0a919d | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\7f0a919d-35de-45ce-8ca9-a9dd993520b5\QM5_12855\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_13013 / NDX.DWX | 6fdfbae6 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\6fdfbae6-98a3-4839-9663-01d4dfb7199e\QM5_13013\Q08\NDX_DWX\aggregate.json` |
| QM5_13054 / XTIUSD.DWX | 42f1dc63 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\42f1dc63-2629-47ce-819f-49c1c3a02745\QM5_13054\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_13213 / USDJPY.DWX | 048643ac | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\048643ac-a569-45f6-9d5d-c559c5a9c060\QM5_13213\Q08\USDJPY_DWX\aggregate.json` |
| QM5_1537 / XAGUSD.DWX | 262514ac | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\262514ac-c3c6-4834-9e17-02a42c8878b7\QM5_1537\Q08\XAGUSD_DWX\aggregate.json` |
| QM5_20048 / XTIUSD.DWX | a43559cd | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\a43559cd-b084-4c0e-8bc3-2c7b6fc1a5ea\QM5_20048\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_20086 / EURUSD.DWX | 20431af7 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\20431af7-c535-46fa-b13e-641d402cb69b\QM5_20086\Q08\EURUSD_DWX\aggregate.json` |
| QM5_20086 / NDX.DWX | a9cccf5c | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\a9cccf5c-d8dd-4456-bf58-5e8831698cec\QM5_20086\Q08\NDX_DWX\aggregate.json` |
| QM5_20266 / XTIUSD.DWX | 87731bac | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\87731bac-29cc-4846-ac26-b348b13af59b\QM5_20266\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_21501 / USDJPY.DWX | 65e42be0 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\65e42be0-2f98-4c5a-b77f-54f892b36345\QM5_21501\Q08\USDJPY_DWX\aggregate.json` |
| QM5_21502 / XAUUSD.DWX | 0dbc6aab | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\0dbc6aab-8e71-4841-a46b-5c7a50de22e2\QM5_21502\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_21505 / XAGUSD.DWX | 9c51f7eb | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\9c51f7eb-d3a2-435c-a50d-66ade0356f5c\QM5_21505\Q08\XAGUSD_DWX\aggregate.json` |
| QM5_21507 / XAUUSD.DWX | 837ea578 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\837ea578-a2d9-4c7f-9294-7d7cf406ca9b\QM5_21507\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_41219 / XAUUSD.DWX | 800fd4f1 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\800fd4f1-9b4c-4cb7-a5fb-9d392f02b7c1\QM5_41219\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_41221 / EURUSD.DWX | fbc72af5 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\fbc72af5-6917-49fe-b597-3c24e72be490\QM5_41221\Q08\EURUSD_DWX\aggregate.json` |
| QM5_9641 / WS30.DWX | fe2c88a9 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\fe2c88a9-b0eb-424c-b5e2-f39d314071ab\QM5_9641\Q08\WS30_DWX\aggregate.json` |

## Per-entry — latest 28 Q08 PASS artifacts (28)

| EA / symbol | Q08 work-item | Legacy DSR | V2 projected | stat_suff | tech | econ | binding | dsr_context | aggregate.json |
|---|---|---|---|---|---|---|---|:---:|---|
| QM5_10145 / XAUUSD.DWX | 48778bc7 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\48778bc7-e7e0-499a-8266-4c0c1c50e8a5\QM5_10145\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10146 / AUDUSD.DWX | de21a2ad | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\de21a2ad-e30b-445f-bcc5-2ad649180eed\QM5_10146\Q08\AUDUSD_DWX\aggregate.json` |
| QM5_10148 / EURNZD.DWX | 1da1645c | insufficient days | LOW_SAMPLE | low_sample | valid | positive | current | no | `D:\QM\reports\work_items\1da1645c-7c69-43d9-8617-f55040122bdc\QM5_10148\Q08\EURNZD_DWX\aggregate.json` |
| QM5_10183 / XAUUSD.DWX | 4032f22e | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\4032f22e-47d1-4bfc-b974-0d22bfb7841e\QM5_10183\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10513 / XAUUSD.DWX | da5dc579 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\da5dc579-3d0a-4591-80e8-dc64eb52d81e\QM5_10513\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10571 / XAUUSD.DWX | fab8ff14 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\fab8ff14-e0ba-4824-b3cd-488c3dd744af\QM5_10571\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10700 / XAUUSD.DWX | ce371d25 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\ce371d25-12b0-44b8-9d55-0854c9adcdd8\QM5_10700\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_10706 / GBPUSD.DWX | 7855588a | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | stale | no | `D:\QM\reports\work_items\7855588a-9ff8-4896-8d8d-16e1fdc25f72\QM5_10706\Q08\GBPUSD_DWX\aggregate.json` |
| QM5_10706 / GBPUSD.DWX | a2e1aba6 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\a2e1aba6-45ea-4dcf-af98-1f679ebeb64f\QM5_10706\Q08\GBPUSD_DWX\aggregate.json` |
| QM5_11421 / EURUSD.DWX | c93263aa | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | stale | no | `D:\QM\reports\work_items\c93263aa-a707-45ea-a915-204ec59df077\QM5_11421\Q08\EURUSD_DWX\aggregate.json` |
| QM5_11422 / USDCAD.DWX | 2bd0f95c | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\2bd0f95c-6c62-4a53-92cf-04f0d39fbb48\QM5_11422\Q08\USDCAD_DWX\aggregate.json` |
| QM5_11881 / SP500.DWX | c8f6d637 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\c8f6d637-2d70-45ae-8178-e8363ccfd319\QM5_11881\Q08\SP500_DWX\aggregate.json` |
| QM5_12623 / XAUUSD.DWX | 5fd45ac3 | insufficient days | LOW_SAMPLE | low_sample | unavailable | positive | missing | no | `D:\QM\reports\work_items\5fd45ac3-4743-4671-85dd-e24903064919\QM5_12623\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_12823 / USDJPY.DWX | 5ec0f0a6 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\5ec0f0a6-d51e-4081-9fe0-a1ad78ebb615\QM5_12823\Q08\USDJPY_DWX\aggregate.json` |
| QM5_12847 / NDX.DWX | 00363e8b | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\00363e8b-653c-497a-bd73-7b899d192821\QM5_12847\Q08\NDX_DWX\aggregate.json` |
| QM5_12925 / WS30.DWX | 4dc0cee3 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\4dc0cee3-a46c-45a8-b01d-90a3430511f9\QM5_12925\Q08\WS30_DWX\aggregate.json` |
| QM5_13013 / NDX.DWX | 6fdfbae6 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\6fdfbae6-98a3-4839-9663-01d4dfb7199e\QM5_13013\Q08\NDX_DWX\aggregate.json` |
| QM5_13054 / XTIUSD.DWX | 21dd6839 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\21dd6839-4d77-4228-b5ba-5dd86aeb0cdb\QM5_13054\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_13213 / USDJPY.DWX | 048643ac | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\048643ac-a569-45f6-9d5d-c559c5a9c060\QM5_13213\Q08\USDJPY_DWX\aggregate.json` |
| QM5_1537 / XAGUSD.DWX | f62fe6b3 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\f62fe6b3-f734-466e-95dd-d7ca76294729\QM5_1537\Q08\XAGUSD_DWX\aggregate.json` |
| QM5_20048 / XTIUSD.DWX | 3ee5c53c | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\3ee5c53c-6fe5-4776-9baf-a3ec9600e626\QM5_20048\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_20048 / XTIUSD.DWX | a43559cd | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\a43559cd-b084-4c0e-8bc3-2c7b6fc1a5ea\QM5_20048\Q08\XTIUSD_DWX\aggregate.json` |
| QM5_20188 / USDJPY.DWX | 596f5dac | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\596f5dac-0c93-4a3b-9cbc-784c27627d94\QM5_20188\Q08\USDJPY_DWX\aggregate.json` |
| QM5_21501 / USDJPY.DWX | 65e42be0 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | unavailable | positive | missing | no | `D:\QM\reports\work_items\65e42be0-2f98-4c5a-b77f-54f892b36345\QM5_21501\Q08\USDJPY_DWX\aggregate.json` |
| QM5_21505 / XAGUSD.DWX | 15c1ec7b | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\15c1ec7b-5821-4944-81a7-86d23754565d\QM5_21505\Q08\XAGUSD_DWX\aggregate.json` |
| QM5_41161 / GBPUSD.DWX | 577031e5 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\577031e5-f7ce-41b2-aed6-ae75d7197873\QM5_41161\Q08\GBPUSD_DWX\aggregate.json` |
| QM5_41219 / XAUUSD.DWX | 800fd4f1 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\800fd4f1-9b4c-4cb7-a5fb-9d392f02b7c1\QM5_41219\Q08\XAUUSD_DWX\aggregate.json` |
| QM5_41221 / EURUSD.DWX | fbc72af5 | deferred | UNCORRECTED_SELECTION | uncorrected_selection | valid | positive | current | no | `D:\QM\reports\work_items\fbc72af5-6917-49fe-b597-3c24e72be490\QM5_41221\Q08\EURUSD_DWX\aggregate.json` |

## Method & integrity

- Inspector invoked once per `aggregate.json`: `python tools/strategy_farm/evidence_status.py --aggregate <abs path>` (cwd `C:/QM/repo`, subprocess env `QM_DSR_V2=1`). The tool reads the aggregate and reports the stored sub-gate 8.2 through the V2 vocabulary; it performs no writes. The env flag is set for parity with the activation path — the inspector's projection is identical with or without it, because it reads the stored gate rather than re-running a backtest.
- Legacy outcome and `dsr_context` presence were additionally read directly from each `aggregate.json` (`utf-8-sig`); every one of the 48 distinct artifacts exists on disk and none contains a `dsr_context` key or a `QM_DSR_V2` engine stamp.
- Tool errors: **0**.
- Note on two `insufficient days` artifacts (`QM5_10148/EURNZD.DWX`, `QM5_12623/XAUUSD.DWX`): the inspector projects `LOW_SAMPLE` (their stored detail is `insufficient_daily_returns:got=29/55:need>=60`). The M04 before/after table listed these two under `UNCORRECTED_SELECTION`; both readings agree neither is a V2 PASS — the difference is only whether the low-day condition or the missing-cohort condition is named first.

Per-entry machine-readable records: `docs/ops/evidence/2026-09-05_dsr_v2_projection.json`.
