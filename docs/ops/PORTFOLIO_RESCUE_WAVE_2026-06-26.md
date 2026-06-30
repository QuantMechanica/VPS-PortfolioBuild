# Portfolio Rescue Wave — failed-gate EA triage (2026-06-26)

Owner prompt: "Was ist mit all den EAs, die vorher irgendwo gestorben sind bei einem Gate?"

## Executive result

The rescue path is real, but it is not a bulk-admit path. Current actionable result:

- Q08 `FAIL_SOFT` distinct streamable pairs: **7**
- Fresh Q09 rescue pass after canonical XNG redump: **6**
- Fresh Q09 rescue reject: **1** (`11124:SP500`, redundant to `11132:SP500`)
- Fresh Q09 `NEED_MORE_DATA`: **0** after redumping `12567:XNGUSD` over 2017-2025
- Current certified book: **6 Q12_REVIEW_READY sleeves**

Fresh evidence root:
`D:\QM\reports\portfolio\rescue_q09_20260626T1338Z\summary.json`

Canonical XNG redump + admission evidence:
- Redump: `D:\QM\reports\portfolio\canonical_restore_12567_XNG\QM5_12567\20260626_133519\summary.json`
- Q09: `D:\QM\reports\portfolio\canonical_q09_12567_20260626\QM5_12567\Q09_PORTFOLIO\XNGUSD_DWX\aggregate.json`

## Fresh Q09 rescue verdicts

| Candidate | Verdict | Why | Trades | Corr basis | Max corr | Marginal DD effect |
|---|---|---:|---:|---|---:|---:|
| `10440:NDX.DWX` | PASS_PORTFOLIO | admitted | 441 | monthly | +0.0586 | 1.7835% -> 1.5320% |
| `10513:XAUUSD.DWX` | PASS_PORTFOLIO | admitted | 22 | monthly | +0.0586 | 2.6449% -> 1.5320% |
| `10692:NDX.DWX` | PASS_PORTFOLIO | admitted | 443 | monthly | -0.0205 | 1.8514% -> 1.5320% |
| `10940:XAUUSD.DWX` | PASS_PORTFOLIO | admitted | 35 | monthly | +0.0889 | 1.9746% -> 1.5320% |
| `11124:SP500.DWX` | FAIL_PORTFOLIO | correlation_above_max_corr | 33 | monthly | +0.5693 | 1.5320% -> 2.1163% |
| `11132:SP500.DWX` | PASS_PORTFOLIO | admitted | 43 | monthly | +0.0889 | 2.0055% -> 1.5320% |
| `12567:XNGUSD.DWX` | PASS_PORTFOLIO | admitted after canonical 2017-2025 redump | 20 | monthly | +0.1694 | 1.5320% -> 0.7680% |

DB materialization check: no `PASS_PORTFOLIO` row is missing from `portfolio_candidates`.
The Q12 book is correctly materialized and deduped. The old `12567:XNGUSD` `NEED_MORE_DATA`
row is retained for audit; a new `PASS_PORTFOLIO` Q09 work_item
`q09-rescue-12567-xng-619205deb800` backs the Q12-ready candidate.

## Exploratory robust-pool book

After fixing the report capital base to the canonical tester default (`initial_deposit=100000`),
the exploratory `q08_fail_soft_robust_pool` report selects:

`10440:NDX`, `10692:NDX`, `10940:XAU`, `11132:SP500`, `12567:XNG`

KPIs from `D:\QM\reports\portfolio\portfolio_latest.json` after redump:

- MaxDD **1.0816%**
- Sharpe **2.1356**
- total net-of-cost profit **8242.11**
- OOS cap met: **true**
- deployment eligible: **false** by design

This now agrees with the certified Q12 admission direction: `12567:XNGUSD` is portfolio-valuable
and now clears the 20-trade Q09 floor after the canonical stream was extended through 2025.

## Current Q12-ready deploy-review draft

`D:\QM\strategy_farm\artifacts\portfolio\portfolio_manifest_tlive_DRAFT.json` now contains
6 sleeves:

`10440:NDX`, `10513:XAU`, `10692:NDX`, `10940:XAU`, `11132:SP500`, `12567:XNG`

KPIs:

- Observed MaxDD **0.7680%**
- MC-p95 MaxDD **1.3741%**
- Sharpe **2.0585**
- total net-of-cost profit **7478.15**
- status **DRAFT_FOR_OWNER_APPROVAL**
- cap met **true** under the 6% DD cap

## Next executable buckets

1. **XNG deploy-review follow-up**
   - Target: `12567:XNGUSD`
   - Status: Q09 `PASS_PORTFOLIO`, Q12-ready, included in the 6-sleeve draft.
   - Action: OWNER/Claude review the updated T_Live draft and standard deploy-verification packet.

2. **Infra resurrection, not portfolio admission**
   - Large recurring cohorts include `ONINIT_FAILED;INCOMPLETE_RUNS`, `NO_HISTORY;INCOMPLETE_RUNS`,
     `REPORT_FORMAT_DRIFT`, `setfile_missing`, `ex5_missing`, and `METATESTER_HUNG`.
   - These must be rebuilt/requeued before any portfolio judgment. They are not failed edges yet.

3. **Basket harness fix**
   - `basket_manifest_logical_q02` appears in the failure inventory and matches the known issue:
     basket strategies are being judged per-leg instead of by combined basket PnL.
   - High ROI because FX/commodity market-neutral sleeves are exactly the portfolio gap.

4. **Do not rescue hard edge failures**
   - Q08 `FAIL_HARD` and Q04 folds with persistent `pf_net=0`/zero-trade folds are not
     portfolio candidates without a separate strategy fix.

## Code/report hygiene fixed in this wave

- `portfolio_periodic_report.py` now defaults to the canonical tester capital instead of stale
  `$10k`.
- `portfolio_admission.py` and `portfolio_q08_contribution.py` now use the same canonical default,
  so new Q09 artifacts report DD on the same scale as the deploy manifest.
- Portfolio tests: **49 passed**.
