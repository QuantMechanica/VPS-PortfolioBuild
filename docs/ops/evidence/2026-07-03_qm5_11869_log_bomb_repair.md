# QM5_11869 Q02 AUDUSD Log-Bomb Repair

Date: 2026-07-03
Agent: codex:agents/board-advisor

## Scope

- EA: `QM5_11869_ema40-80-cci-m5`
- Instrument: `AUDUSD.DWX`
- Phase: Q02
- Original work item: `42892431-9377-4cfc-af6d-446f3bddf2d4`
- Requeued work item: `620a2d29-2a85-4772-a247-560882d3ce97`

## Original Failure

The farm marked the AUDUSD Q02 work item as `INFRA_FAIL` with reason class `LOG_BOMB`.
Evidence is stored at:

`D:\QM\reports\work_items\42892431-9377-4cfc-af6d-446f3bddf2d4\log_bomb_evidence.json`

The evidence records a 536870912-byte journal cap breach on T5 during Q02.

## Diagnosis

- The EA source had no explicit high-volume `Print`, `Alert`, or similar logging loop.
- The AUDUSD backtest setfile was stale:
  - missing `qm_ea_id`
  - missing current strategy inputs
  - missing the current news-axis inputs
  - carrying `build_hash: pending`
- `OnTick` checked the news gate before management and exit handling. Current V5 pipeline expectations gate only new entries with news; management and exits stay live.

## Repair

- Regenerated the canonical backtest setfiles for `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`.
- Added explicit Q02 structural-baseline news-off inputs to each backtest setfile:
  - `qm_news_temporal=0`
  - `qm_news_compliance=0`
  - `qm_news_mode_legacy=0`
  - `qm_news_stale_max_hours=336`
  - `qm_news_min_impact=high`
- Moved the EA news gate below open-position management and exit logic so it gates only new entries.
- Updated `SPEC.md` revision history for the infra repair.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_11869_ema40-80-cci-m5`
  - Result: PASS
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_11869_ema40-80-cci-m5`
  - Result: PASS
  - Failures: 0
  - Advisory warnings: 16 framework-level DWX lazy-handle/release warnings
  - Build check report: `D:\QM\reports\framework\21\build_check_20260703_204741.json`
  - Compile summary: `D:\QM\reports\compile\20260703_204742\summary.csv`
- Recompiled `.ex5` SHA256:
  - `83037fa967002a4f4288f51e2a908bcaa7cc2f34a561d498015c0a4234ed1234`
- AUDUSD setfile SHA256:
  - `4f7e59437da221f21da129404f064928eb606ea1336bf5eced2f84e1ff466ef7`

Manual smoke/backtest was not launched because farm terminals T1-T5 were already occupied by active pipeline work. `T_Live` and the live manifest were not touched.

## Farm DB Coordination

- Claim backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11869_log_bomb_claim_20260703T202958Z.sqlite`
- Requeue backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11869_log_bomb_requeue_20260703T205716Z.sqlite`
- Original work item payload was updated with `repair_result`.
- New pending Q02 work item was inserted for `AUDUSD.DWX` with the repaired setfile path and validation hashes.
