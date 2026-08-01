# QM5_10989 EURUSD Q02 History-Sync Recovery

Date: 2026-08-01
Agent: Codex headless paced fleet
Branch: `agents/board-advisor`

## Outcome

Recovered the `EURUSD.DWX` carrier of
`QM5_10989_ftmo-bo-retest` from a terminal-history infrastructure failure and
enqueued exactly one authenticated Q02 rerun. The failed row and its evidence
remain intact; the farm's append-only rerun path created a distinct pending
row bound to the same MQ5, EX5, setfile, symbol, timeframe, and fixed-risk
contract.

- Failed evidence row: `1fb9002f-22d4-4730-a8cb-cff7b2c62a19`
- New Q02 row: `248b29a0-3f77-4f7a-9168-37ae6db43f00`
- New-row state at handoff: `pending`, unclaimed, `attempt_count=0`
- Farm repair task: `60a1ee36-652e-429c-9911-b0cda7bc6e7f`
- Exclusive claim key:
  `manual:codex:agents/board-advisor:QM5_10989:q02-eurusd-history-sync-recovery`
- Terminal steering: `avoid_terminals=["T6"]`

No manual backtest was launched. The existing paced workers may claim the
pending row after this handoff.

## Diversity And Selection

No priority-1 build was admissible under the standard build contract. The
pending rates/lumber cards require unavailable DWX inputs, while the strongest
genuinely unbuilt structural FX card (`QM5_11457`) has an EA-ID allocation but
no preallocated magic rows. The build skill explicitly requires both registry
allocations to exist before implementation. Other registry-complete unbuilt
cards were indicator ports or duplicates of mechanics already in the farm.

This made the priority-2 EURUSD recovery the best non-duplicate unit. The
approved FTMO Academy card is a structural M30 Donchian breakout followed by a
required retest and acceptance close. Its estimated cadence is about 60
trades/year/symbol (roughly one filtered setup per week), and the target basket
adds FX exposure to a survivor set currently concentrated in indices, metals,
and energy.

Approved card:
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_10989_ftmo-bo-retest.md`

## Diagnosis

The 2026-07-28 run-smoke summary surfaced `ONINIT_FAILED` and
`INCOMPLETE_RUNS`, but the execution evidence shows that the EA did not cause
the initialization failure:

- Source and deployed EX5 files matched byte-for-byte and remained stable.
- The source MQ5 and EURUSD setfile matched their authenticated work-item
  bindings.
- T6 synchronized the controller-side EURUSD history and ticks, then the local
  MetaTester agent logged `EURUSD.DWX: history synchronization error` at
  `19:04:42` and disconnected before any EA input or `INIT_OK` log appeared.
- The resulting report had an empty expert/symbol, `M0 1970`, and zero bars.

This is a T6 local-agent history synchronization fault misclassified at the
surface as ONINIT, not a stale binary, magic-registry defect, or strategy
verdict. The repair therefore preserves all strategy artifacts and steers the
rerun away from T6.

Evidence:

- Summary:
  `D:\QM\reports\work_items\1fb9002f-22d4-4730-a8cb-cff7b2c62a19\QM5_10989\20260728_170342\summary.json`
- T6 tester log: `D:\QM\mt5\T6\Tester\logs\20260728.log`
- Farm work log:
  `D:\QM\strategy_farm\logs\work_item_1fb9002f-22d4-4730-a8cb-cff7b2c62a19.log`

## Farm Handoff

Before any farm mutation, the live SQLite database was backed up to:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10989_eurusd_history_sync_recovery_20260801T191020Z.sqlite`

The recovery first wrote an exclusive `infra_repair` claim and annotated the
failed row. It then used
`farmctl.append_only_exact_row_rerun`, whose guards authenticated the terminal
INFRA_FAIL source row, absence of competing open work, fixed-risk preset, and
exact execution-artifact identities. The new row carries the failed row's
stable payload plus append-only provenance and the T6 exclusion. Exactly one
matching EURUSD Q02 row was open at validation time.

The backtest CPU ceiling was not reached: 3 factory terminals were active at
the pre-enqueue gate and 2 at the post-enqueue observation, both below the
configured ceiling of 7. No dispatch was forced.

## Validation

- Live farm database `PRAGMA quick_check`: `ok`
- Pre-mutation backup `PRAGMA quick_check`: `ok`
- Fixed-risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- MQ5 SHA-256:
  `25975ac15c35006c565ea9779515391fa1feffe35889ca2442d588a1e01845ab`
- EX5 SHA-256:
  `3761277dbc737951df68dfa3f115d4f316e7208aee1a64dc6ebac83ad2a336c0`
- EURUSD setfile SHA-256:
  `4e568e41b2ddea4cc9b0b029591062653e38d9557b3719db09927508223067a7`
- Expected identity: `QM\QM5_10989_ftmo-bo-retest`, `EURUSD.DWX`, `M30`

No EA mechanics, setfile parameters, T_Live process, AutoTrading setting,
portfolio gate, deploy manifest, or live artifact was changed.
