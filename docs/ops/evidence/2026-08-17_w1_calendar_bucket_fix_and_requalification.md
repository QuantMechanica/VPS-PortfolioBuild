# W1 calendar-bucket fix and requalification inventory

Date: 2026-08-17  
Router task: `82dd2e43-6483-40a2-9325-608ab94ed2f0`  
Branch: `agents/board-advisor`

## Fix

`QM_CalendarPeriodKey(PERIOD_W1)` no longer computes `day_of_year / 7`. That expression restarted its buckets on January 1 and left a one-day final bucket in non-leap years or a two-day final bucket in leap years.

The W1 key is now the `yyyymmdd` date of the real Monday anchoring the D1 timestamp’s Monday-Sunday week. The key remains an `int`, is stable inside a week, and advances strictly when the Monday changes, including across year boundaries. It remains derived from `iTime(symbol, PERIOD_D1, shift)`; no W1 or MN1 bar fetch was introduced. The MN1 `year * 100 + month` path is unchanged.

## Verification

`python -m pytest framework/scripts/tests/test_calendar_period_key.py -q`

Result: `4 passed`.

The fixture covers:

- the non-leap 2023-12-29 through 2024-01-02 boundary;
- the leap 2024-12-29 through 2025-01-02 boundary;
- full 2023 and 2024 sweeps proving internal buckets contain exactly seven consecutive days and bucket transitions are strictly increasing;
- static preservation of the D1 data source, the untouched MN1 formula, and absence of the old `day_of_year / 7` expression.

No EA was rebuilt, no backtest was run, no existing work item or verdict was rebound, and no live component was touched.

## Affected EA inventory

The 25-EA cohort is 24 direct `QM_CalendarPeriodKey(PERIOD_W1)` callers plus QM5_13000, which calls `QM_IsNewCalendarPeriod(PERIOD_W1)`. QM5_1224 is configurable but defaults to MN1 and is not part of the ticket’s 25-EA cohort.

Any new binary containing this framework change is behaviorally different. Existing verdicts remain historical evidence for the old binary only; they cannot be hash-rebound to a rebuilt binary. Nineteen EAs currently hold economic Q-only verdicts that must be re-earned if those EAs are rebuilt. Four have only administrative/defect verdicts; those records remain historical and do not authorize a rebuilt binary. Two have no verdict yet.

| EA | Current recorded Q-only verdict rows | Requalification consequence |
|---|---|---|
| QM5_10305_narang-xmom | Q02 RETIRE x10 | Administrative history only; no rebinding if resurrected. |
| QM5_12619_comm-reversal-4wk-xauusd | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_12896_xng-oct-turn-long | Q02 FAIL x1 | Re-earn Q02 after rebuild. |
| QM5_12918_jegadeesh-1w-reversal-fx | Q02 FAIL x3 / INFRA_FAIL x4 / PASS x4; Q04 INFRA_FAIL x2 / PASS x1 / PASS_LOWFREQ x1; Q05 PASS x2; Q06 FAIL x1 / INFRA_FAIL x1 / PASS x1; Q07 INFRA_FAIL x1 | Requalification must restart at Q02; all deeper verdicts are old-cadence evidence. |
| QM5_12965_wti-week-orb | Q02 FAIL x3 | Re-earn Q02 after rebuild. |
| QM5_13000_xng-rig-fri-fade | Q02 PASS x1; Q04 INFRA_FAIL x1 | Re-earn Q02 before a new Q04. |
| QM5_13007_eurnzd-tsmom-pb | Q02 PASS x2; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_13049_xti-1w-mom-vol | Q02 PASS x2; Q04 FAIL x2 | Re-earn Q02 and Q04 after rebuild. |
| QM5_13050_xti-1w-rev-vol | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_13055_xbr-1w-mom-vol | Q02 BLOCKED_STALE_BUILD_RESULT x1 / PASS x1 / RETIRE x1; Q04 FAIL x1 | Re-earn from Q02 if rebuilt; do not carry Q04 forward. |
| QM5_13056_xbr-1w-rev-vol | Q02 BLOCKED_STALE_BUILD_RESULT x1 / PASS x1 / RETIRE x1; Q04 FAIL x1 | Re-earn from Q02 if rebuilt; do not carry Q04 forward. |
| QM5_13101_xng-1w-mom-vol | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_13102_xng-1w-rev-vol | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_13109_xng-febjun-long | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_13205_xau-xag-qc | Q02 FAIL x3 | Re-earn Q02 after rebuild. |
| QM5_20011_xng-thu-tue | Q02 DRAFT_DEFECT x1 | Administrative defect history only; no rebinding. |
| QM5_20172_wti-fri-bear | Q02 BLOCKED_STALE_BUILD_RESULT x1 / DRAFT_DEFECT x1 | Administrative defect history only; no rebinding. |
| QM5_20182_wti-sum-bull | Q02 BLOCKED_FACTORY_OFF x1 / PASS x2; Q03 FAIL x2; Q04 FAIL x1 | Requalification must restart at Q02. |
| QM5_20185_wti-win-bearfade | Q02 PASS x2; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_20292_fx-carry-unwind | Q02 DRAFT_DEFECT x2 | Administrative defect history only; no rebinding. |
| QM5_21502_xau-weekly-tsmom | none | No verdict to rebind; first run must use a binary built after this fix and after code-review repair. |
| QM5_21504_xng-flowrev | Q02 INFRA_FAIL x1 / PASS x1; Q04 PASS_LOWFREQ x1; Q05 FAIL x1 | Requalification must restart at Q02. |
| QM5_21505_xag-weekly-lowvol-momentum | none | No verdict to rebind; first run must use a binary built after this fix and after code-review repair. |
| QM5_21520_xng-flow-mom | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |
| QM5_21521_wti-flow-switch | Q02 PASS x1; Q04 FAIL x1 | Re-earn Q02 and Q04 after rebuild. |

This ticket deliberately lands the primitive and tests only. Rebuild scheduling and requalification are separate deterministic router work.
