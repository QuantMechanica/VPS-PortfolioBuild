# Sunday preflight — FTMO_DEMO_BOOK_V3_D2G6_20260918_REHEARSAL

Decision: **NO_GO**. Scope: `READ_ONLY_PRE_SUNDAY_REHEARSAL`.

| Area | Check | State | Evidence / reason |
|---|---|---|---|
| CODE_ARTIFACT | All included EAs compile with 0 errors / 0 warnings | **GREEN** | `C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\RECEIPT_alias_builds.md` |
| CODE_ARTIFACT | Exact installed EX5 binding | **GREEN** | `7/7 installed EX5 hashes match` |
| CODE_ARTIFACT | Exact installed setfile binding | **GREEN** | `7/7 setfile hashes match` |
| CODE_ARTIFACT | Magic registry clean | **GREEN** | `C:\QM\repo\framework\registry\magic_numbers.csv` |
| CODE_ARTIFACT | No unknown artifact drift | **GREEN** | `Genesis verification status PASS (0 drift rows)` |
| ACCOUNT_RISK | Account governor present and hash-bound | **GREEN** | `C:\QM\repo\framework\EAs\QM5_13206_ftmo-account-governor\QM5_13206_ftmo-account-governor.mq5` |
| ACCOUNT_RISK | Daily Loss anchor mode correct | **RED** | `configuration_status=MISSING_GOVERNED_INITIALIZER; anchor_mode=None` |
| ACCOUNT_RISK | Prague rollover helper and configuration present | **RED** | `C:\QM\repo\framework\include\QM\QM_FTMOGovernorPolicy.mqh` |
| ACCOUNT_RISK | Maximum Loss logic present | **GREEN** | `C:\QM\repo\framework\include\QM\QM_FTMOGovernorPolicy.mqh` |
| ACCOUNT_RISK | Combined open-risk calculation present | **GREEN** | `C:\QM\repo\framework\include\QM\QM_AccountRiskReservation.mqh` |
| ACCOUNT_RISK | Kill-Switch test evidence | **RED** | `docs/ops/evidence/2026-09-21_4fd8222f_ftmo_d2g6_kill_switch_anchor_diagnosis.md` |
| ACCOUNT_RISK | Book-generation identity | **RED** | `generation_id=FTMO_DEMO_BOOK_V3_D2G6_20260918_REHEARSAL; book_tag=None` |
| EXECUTION | Spread and commission assumptions realistic | **GREEN** | `docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/README.md` |
| EXECUTION | No known unrealistic fill dependency | **RED** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` |
| EXECUTION | OCO verified where relevant | **GREEN** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` |
| EXECUTION | Session calendars valid | **NOT_CHECKABLE** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` |
| EXECUTION | DST handling valid | **RED** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` |
| EXECUTION | News handling valid | **RED** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` |
| PORTFOLIO | Dependence matrix current | **GREEN** | `docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/FTMO_BOOK_DEPENDENCE_MATRIX_financed.json` |
| PORTFOLIO | Sleeve weights intentional | **GREEN** | `C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\roster.json` |
| PORTFOLIO | No accidental duplicate exposure | **GREEN** | `docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/FTMO_BOOK_DEPENDENCE_MATRIX_financed.md` |
| PORTFOLIO | XAU cluster documented | **GREEN** | `docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/FTMO_BOOK_DEPENDENCE_MATRIX_financed.md` |
| PORTFOLIO | First-passage simulation current | **GREEN** | `D:/QM/reports/state/ftmo_first_passage.json` |
| OPERATIONS | Sleeve P&L attribution working | **RED** | `D:/QM/reports/state/ftmo_sleeve_attribution.json` |
| OPERATIONS | Logs working | **GREEN** | `D:/QM/reports/state/ftmo_trial_pulse.json` |
| OPERATIONS | Recovery procedure documented | **GREEN** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |
| OPERATIONS | Demo account clean before attach | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |
| OPERATIONS | Post-attach verification complete | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |

A critical RED is NO-GO. A critical NOT_CHECKABLE is PENDING and cannot be treated as launch approval. This report is read-only and never launches or configures MT5.
