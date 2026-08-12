# QM5_11032 Diversity Build and Q02 Handoff

- Date: 2026-07-31
- Branch: `agents/board-advisor`
- EA: `QM5_11032_atc-horiz-chan`
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11032_atc-horiz-chan.md`
- Source lineage: Andrey Voitenko, MQL5 Automated Trading Championship article 538 (2010-12-15)

## Outcome

QM5_11032 is a deterministic M5 horizontal-channel breakout with no strategy-indicator, ML, grid, or martingale dependency. Its approved basket is `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`, with an expected frequency of about 100 trades/year/symbol. It was the highest-diversity build-ready structural card found after filtering the approved reservoir for active EA/magic registrations, supported DWX symbols, absent EX5 binaries, and live farm claims.

The legacy build task `21a85c2f-7c79-4b16-b914-a32f1bd34cae` had exhausted three attempts on an MQL5-illegal `(void)broker_time` cast. The repair removes that one obsolete cast; strategy mechanics are unchanged. A strict binary, four `RISK_FIXED=1000` backtest setfiles, and a governed staged Q02 cohort now exist.

## Farm Coordination

- Exclusive agent claim: `f435eaf4-1d9b-4278-91e3-ce01154a7784`
- Claim key: `manual:codex:agents/board-advisor:QM5_11032:q01-build-q02-handoff`
- Provisional QM5_20072 infra claim was released as `BLOCKED / SELECTION_RELEASED` before this build began.
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11032_claim_20260731T145009Z.sqlite` (`PRAGMA quick_check=ok`)
- Pre-reopen DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11032_build_reopen_20260731T150122Z.sqlite` (`PRAGMA quick_check=ok`)
- Legacy build task was compare-and-swap reopened from `failed` to `active`, then the standard build recorder closed it `done` at `2026-07-31T15:01:52Z`.

## Validation

- `validate_spec_doc.py`: `PASS` (1 PASS, 0 FAIL)
- Strict build check: `D:\QM\reports\framework\21\build_check_20260731_145329.json` — `PASS`, 0 failures, 0 warnings
- Standalone strict compile: `D:\QM\reports\compile\20260731_145524\summary.csv` — `PASS`, 0 errors, 0 warnings
- Build result contract: `docs/ops/evidence/2026-07-31_qm5_11032_build_result.json`

Artifact SHA-256 identities:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `566406a233ef9b9769cffa7fe4ddbd05881a2e1578c728efd8b677aeb629f4d2` |
| EX5 | `83984a0f72ee5e1bf3f3daff603bf5061ba11def50d15df088f8e6ed5c864c50` |
| EURUSD set | `65bfac41fceb0e209237e918bba1e1156ae6afc966b62edd1696490ec31eec0a` |
| GBPUSD set | `56c6f46b72771b16284e68b8dee4b19e243f2100428ea69587beddda6017eecd` |
| USDJPY set | `47410402668b85c8facaf12120f44e96b23534fdb0b813d66334af16d264992d` |
| XAUUSD set | `d66cff64d742f9038ece2ac38fd6b817ea8f6cea0106e1bc40eb1e41021367e3` |

All setfiles bind `RISK_FIXED=1000`, `RISK_PERCENT=0`, the registered symbol slot, and the card-default strategy parameters.

## Smoke Classification

Exactly one governed build-smoke call was dispatched through `-Terminal any`; it was admitted to T9, so the backtest CPU ceiling was not hit. T9 returned infrastructure-only `NO_HISTORY / INCOMPLETE_RUNS` for all four internal attempts. Evidence is `D:\QM\reports\smoke\QM5_11032\20260731_145552\summary.json`.

The source/deployed EX5 and setfile identities remained stable, Model 4 was selected, and no `OnInit` failure occurred. The standard build recorder therefore converted `framework_error` to `deferred_p2_smoke` and left the strategy verdict to Q02 rather than treating zero bars as zero trades.

## Q02 Handoff

The standard staged cohort controller enqueued three priority-track Q02 work items at `2026-07-31T15:01:52Z`:

| Symbol | Work item | State at handoff |
|---|---|---|
| EURUSD.DWX | `cb8939e8-6ad1-49d8-841a-1ae2325f761e` | pending |
| GBPUSD.DWX | `20937b40-2f9b-4c18-a755-d6cb4fa73c5c` | pending |
| XAUUSD.DWX | `2771654f-4b07-46a3-8f00-32b845db4ec0` | pending |

`USDJPY.DWX` is durably recorded in `D:\QM\strategy_farm\state\q02_deferred_symbols.json` with `priority_track=true`, cohort size 4, and build-task binding; it was staged, not dropped.

No T_Live files, AutoTrading controls, portfolio gates, deploy manifests, or live manifests were touched.
