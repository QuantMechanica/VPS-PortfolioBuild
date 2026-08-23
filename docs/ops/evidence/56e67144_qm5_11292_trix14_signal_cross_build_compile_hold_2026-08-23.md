# QM5_11292 Build Evidence — Strategy Implemented, Governed Compile Held

- Task: `56e67144-da6b-48b8-89ae-ba7048da97a9` (`build_ea`, priority 50, assigned to Codex)
- EA: `QM5_11292_trix14-signal-cross`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11292_trix14-signal-cross.md`
- Current MQ5 SHA-256: `948212d0030c59c7423ad1b18eeacf727ccd063ec5e5a3d2caf06882bf097242`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed identity

The card declares `g0_status: APPROVED`, `ea_id: QM5_11292`, and slug
`trix14-signal-cross`. The active EA registry row matches that identity. Four active
magic rows bind slots 0-3 to EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, and AUDUSD.DWX.

## Card implementation

The prior tracked MQ5 was an empty strategy skeleton. This task replaced it with the
approved H1 mechanics:

- TRIX as the percentage rate of change of a triple EMA of closed prices;
- primary TRIX(14)/EMA(9)-signal crossover and the card-authorized zero-line P3 variant;
- next-bar market entry and opposite-cross close/reversal;
- 1.5 ATR(14) initial stop, 2.5 ATR(14) safety target, and break-even at +1R;
- 20-pip entry spread cap and optional card-authorized EMA(200) P3 context;
- current framework MAE lifecycle hook, central Friday close, and two-axis news blackout;
- request magic uses `qm_magic_slot_offset`, never a fixed basket slot;
- no ML, grid, martingale, external data API, or live operation.

Four H1 backtest presets were regenerated from the canonical generator. Every preset
uses its governed slot and contains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_news_stale_max_hours` remains bounded at 336 in the EA source.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 5 files checked, zero findings, stale-news ceiling 336 hours.
- `gen_setfile.ps1`: PASS for all four governed symbols.
- `git diff --check`: clean for the EA package.
- The stale untracked EX5 produced from the former empty skeleton was removed; no binary is represented as current-source evidence.

## Compile boundary

Direct strict `build_check.ps1` stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because T1-T10 terminal processes are active.
No terminal was started, stopped, interrupted, or bypassed.

The sanctioned command
`python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_11292_trix14-signal-cross`
was then refused without creating a row: reason `WORK_ITEMS_EXIST`. The refusal bound
the current source hash above and observed all four active magic rows. A fresh governed
compile must supersede or reconcile those prior rows before strict compile evidence can
exist. Smoke was not run, and no pipeline verdict is claimed.

The requested router transition to `REVIEW` was attempted after the source package was
committed. The router refused it with `D6_BUILD_IDENTITY_MISSING` because review dispatch
requires a JSON packet binding a committed current MQ5, a committed current EX5, all
setfiles, and `build_check_passed=true`. No such packet can truthfully exist while the
governed compile is held. The task is therefore dispositioned `BLOCKED`, not left with a
fabricated build identity or a stale binary.

Short verdict: `SOURCE_READY_COMPILE_HELD: implementation and static gates PASS; strict compile held by live-factory guard and prior work items.`
