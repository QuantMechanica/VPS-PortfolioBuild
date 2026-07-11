# QM5_11072 diverse-FX Q02 infrastructure repair and re-enqueue

## Outcome

`QM5_11072_binario-ma-band` is rebuilt from the approved EarnForex Binario
card and re-enqueued at Q02 on four D1 forex instruments: `EURUSD.DWX`,
`GBPUSD.DWX`, `USDJPY.DWX`, and `USDCAD.DWX`. The canonical Q02 task is
`decf54eb-cc29-41d1-b4b9-f5625cb2bf35`; its four work items are pending with
zero attempts and no skips.

This is a diversity/throughput unit, not a raw build. The approved build backlog
did not contain a faithfully executable higher-diversity card: the lumber/bond
cards depend on instruments absent from the DWX matrix, while the remaining
XAU/NDX card does not improve the certified book's asset-class concentration.
The farm claim `d6e022d7-227c-4df6-beac-0860112ef807` protected this distinct
EA throughout the repair.

## Why the prior lineage was infrastructure-only

All prior Q02 rows were `INFRA_FAIL`; there was no Q02 business verdict and no
downstream phase. Review task
`f617d199-c4c2-4ac2-895f-887289f0cc1c` rejected only the build smoke: its T9
report was zero bytes and its tester log showed a different EA on a different
symbol. The same review explicitly passed the strategy mechanics, no-ML rule,
RISK_FIXED interface, magic registry, naming, symbol coverage, and framework
corset, and said that no MQ5 change was required to satisfy the review itself.

Package inspection nevertheless found useful infrastructure hardening:

- the retained EX5 was stale relative to the current framework;
- all four setfiles had `build_hash: pending`, obsolete generic filter inputs,
  and no `strategy_*` parameters;
- the completed-D1 EMA-high/EMA-low channel was read twice on every real tick
  while managing a position; and
- the news return preceded Friday close, position management, and exit logic.

## Repair

The EA now caches the completed D1 channel by
`QM_CalendarPeriodKey(PERIOD_D1)`, so its two pooled EMA values are refreshed
only when the source bar can change. News policy gates new exposure only;
Friday close, channel stop/target management, and strategy exits remain active
during a blackout. Entry requests are zero-initialized and the exit loop is
restricted to the chart symbol.

All four setfiles were regenerated with the official generator. Each uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, the registered magic slot (0-3), and the
approved `strategy_ma_period=144`, `strategy_pip_difference=20`, and
`strategy_take_profit_pips=115` inputs. The approved card is copied into the EA
package and the SPEC records the recovery.

Current hashes:

- MQ5: `1D54F4606ADE6FDD2961379B8947B7622BAE4F94EF1296F2BA1938EE88290C0B`
- EX5: `E226F246A715CB89B54FF21C2DE7A674D0B65609D2F46E0293DD7BC85C9131F5`

## Verification

- build skill guard: PASS
- SPEC validation: PASS
- build guardrails: PASS
- final scoped build check: PASS, 0 failures / 0 warnings
  (`D:\QM\reports\framework\21\build_check_20260711_215550.json`)
- detached-clean strict compile: PASS, 0 errors / 0 warnings
  (`D:\QM\reports\compile\20260711_214514\summary.csv`)
- preserved compile log:
  `D:\QM\reports\compile\20260711_214514\QM5_11072_binario-ma-band.compile.log`

The reviewer required a clean smoke on a dedicated free terminal with at least
three trades. One Model-4 run was executed on T8 for `EURUSD.DWX`, D1, 2024.
It passed with a valid current-EA report, the real-tick marker, no OnInit
failure, and 26 trades:

`D:\QM\reports\smoke\QM5_11072\20260711_214832\summary.json`

The smoke observed PF 0.78 and net profit -1735.36. That is recorded rather
than promoted: this run proves trade generation and clears the sole review
directive; the 2017-2022 Q02 rows remain responsible for the economic verdict.
The original `REJECT_REWORK` is preserved in the review payload, which now also
records the clean smoke evidence and `APPROVE_FOR_BACKTEST` resolution.

## Q02 handoff

| Symbol | Work item | State |
|---|---|---|
| EURUSD.DWX | `6a5f6678-d8a5-4ada-bcae-fee49ec685c9` | pending |
| GBPUSD.DWX | `8b93dfe1-94d8-427a-87fc-60f35f304b3d` | pending |
| USDJPY.DWX | `84c505e7-b5e4-4f9f-b2c0-69a9944471c9` | pending |
| USDCAD.DWX | `5a6ce70f-38e6-4a3d-b953-8c935a4865f2` | pending |

Farm-state backups:

- claim: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11072_q02_repair_claim_20260711T213839Z.sqlite`
- review/enqueue:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11072_review_repair_enqueue_20260711T215518Z.sqlite`

`FACTORY_OFF.flag` remains asserted, so the enqueue did not dispatch a phase
runner. The single T8 build smoke exited cleanly and stayed below the seven-job
CPU ceiling. No T_Live file or process, AutoTrading setting, portfolio gate, or
T_Live manifest was touched.
