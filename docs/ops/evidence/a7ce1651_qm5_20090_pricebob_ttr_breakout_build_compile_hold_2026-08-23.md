# QM5_20090 Build Evidence — Package Completed, Governed Compile Held

- Task: `a7ce1651-e695-4528-9d52-e989defed3ee` (`build_ea`, priority 50, assigned to Codex)
- EA: `QM5_20090_pricebob-ttr-brooks-stoporder-breakout-audusd`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20090_pricebob-ttr-brooks-stoporder-breakout-audusd.md`
- Current MQ5 SHA-256: `f4214fd460318d1ed9aad2c8f5da0fba611469a766aa79ab5ff20a9572066169`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed identity

The card declares `g0_status: APPROVED`, `ea_id: QM5_20090`, and slug
`pricebob-ttr-brooks-stoporder-breakout-audusd`. The active registry identity
matches, and magic slot 0 is actively bound to the card's single symbol,
AUDUSD.DWX.

## Card and framework alignment

The existing strategy body implements the approved M5 four-bar tight-trading-range
proxy, ATR-relative box qualification, paired buy-stop/sell-stop bracket, opposite
box-edge stop, one-box measured-move target, OCO cancellation, three-brackets-per-
session cap, and session-end flattening. This task completed the package and current
framework alignment without changing those mechanics:

- added the missing current MAE evidence hook and zero-initialized both entry requests;
- moved the central news gate to new entries only so OCO cancellation and session-end
  exits continue during blackout windows;
- added an M5 chart guard and deterministic input validation;
- regenerated the missing AUDUSD.DWX M5 backtest preset with governed slot 0,
  `RISK_FIXED=1000`, and `RISK_PERCENT=0`;
- added the required seven-section strategy spec;
- kept `qm_news_stale_max_hours=336`, mandatory two-axis news blackout, one position
  per magic, and no ML/grid/martingale/live operation.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 2 files checked, zero findings, stale-news ceiling 336 hours.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero violations.
- `gen_setfile.ps1`: PASS for AUDUSD.DWX/M5/backtest.
- `git diff --check`: clean for the EA package.

## Compile boundary

Direct strict `build_check.ps1` stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because T1-T10 terminal processes are active.
No terminal was started, stopped, interrupted, or bypassed. The former tracked EX5
had no governed `COMPILE_EA` evidence and became stale when the framework wiring was
corrected, so it was removed rather than represented as current-source evidence.

The sanctioned command
`python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_20090_pricebob-ttr-brooks-stoporder-breakout-audusd`
accepted governed work item `d15aa222-9473-4a1a-b765-d5dedef7f287`, bound to the M5
setfile and single active magic. Activation is fail-closed under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; no current EX5 or strict build PASS exists yet.
Smoke was not run, and no pipeline verdict is claimed.

Short verdict: `SOURCE_READY_COMPILE_HELD: static gates PASS; governed compile d15aa222 pending under worker-rollout activation hold.`
