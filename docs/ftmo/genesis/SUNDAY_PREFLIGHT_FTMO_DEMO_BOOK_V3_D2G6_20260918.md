# Sunday preflight — FTMO_DEMO_BOOK_V3_D2G6_20260918_REHEARSAL

Decision: **NO_GO**. Scope: `READ_ONLY_PRE_SUNDAY_REHEARSAL`.

| Area | Check | State | Evidence / reason |
|---|---|---|---|
| CODE_ARTIFACT | All included EAs compile with 0 errors / 0 warnings | **GREEN** | `C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\RECEIPT_alias_builds.md` |
| CODE_ARTIFACT | Exact installed EX5 binding | **GREEN** | `7/7 installed EX5 hashes match` |
| CODE_ARTIFACT | Exact installed setfile binding | **GREEN** | `7/7 setfile hashes match` |
| CODE_ARTIFACT | Magic registry clean | **GREEN** | `C:\QM\repo\framework\registry\magic_numbers.csv` |
| CODE_ARTIFACT | No unknown artifact drift | **RED** | `Genesis verification status DRIFT (4 drift rows)` |
| CODE_ARTIFACT | Sleeve attribution pre-launch dry-run reconciles to 0.00 | **GREEN** | `D:/QM/reports/state/ftmo_sleeve_attribution.json` |
| CODE_EXECUTION | All sleeve presets bind the fresh live calendar, never a backtest CSV | **RED** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` |
| ACCOUNT_RISK | Account governor present and hash-bound | **GREEN** | `C:\QM\repo\framework\EAs\QM5_13206_ftmo-account-governor\QM5_13206_ftmo-account-governor.mq5` |
| ACCOUNT_RISK | Daily Loss anchor mode correct | **RED** | `configuration_status=MISSING_GOVERNED_INITIALIZER; anchor_mode=None` |
| ACCOUNT_RISK | Prague rollover helper and configuration present | **RED** | `C:\QM\repo\framework\include\QM\QM_FTMOGovernorPolicy.mqh` |
| ACCOUNT_RISK | Maximum Loss logic present | **GREEN** | `C:\QM\repo\framework\include\QM\QM_FTMOGovernorPolicy.mqh` |
| ACCOUNT_RISK | Combined open-risk calculation present | **GREEN** | `C:\QM\repo\framework\include\QM\QM_AccountRiskReservation.mqh` |
| ACCOUNT_RISK | Kill-Switch test evidence | **RED** | `docs/ops/evidence/2026-09-21_4fd8222f_ftmo_d2g6_kill_switch_anchor_diagnosis.md` |
| ACCOUNT_RISK | Book-generation identity | **RED** | `generation_id=FTMO_DEMO_BOOK_V3_D2G6_20260918_REHEARSAL; book_tag=None` |
| ACCOUNT_RISK | KS_DAY_ROLLOVER observed after a no-tick boundary | **RED** | `docs/ops/evidence/2026-09-22_ftmo_kill_switch_governed_initializer/task_d6189118-c2e7-4517-a914-049c89d19a75/verification.json` |
| ACCOUNT_RISK | Balance 100000.00 with zero positions and orders immediately before attach | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |
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
| OPERATIONS | Sleeve P&L attribution working | **GREEN** | `D:/QM/reports/state/ftmo_sleeve_attribution.json` |
| OPERATIONS | Logs working | **GREEN** | `D:/QM/reports/state/ftmo_trial_pulse.json` |
| OPERATIONS | Recovery procedure documented | **GREEN** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |
| OPERATIONS | Terminal and every attached sleeve chart allow automated trading | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |
| OPERATIONS | Request WARN 200 / LIMIT 500 with a 60-second burst alarm | **GREEN** | `docs/ops/evidence/2026-09-22_ftmo_kill_switch_governed_initializer/task_d6189118-c2e7-4517-a914-049c89d19a75/README.md` |
| OPERATIONS | Demo account clean before attach | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |
| OPERATIONS | Post-attach verification complete | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` |

A critical RED is NO-GO. A critical NOT_CHECKABLE is PENDING and cannot be treated as launch approval. This report is read-only and never launches or configures MT5.
