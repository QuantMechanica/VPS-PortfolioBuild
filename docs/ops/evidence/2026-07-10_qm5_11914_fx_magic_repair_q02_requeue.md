# QM5_11914 Diverse-FX OnInit Repair and Q02 Requeue

## Outcome

`QM5_11914_ciurea-100sma-cross-h4` was atomically claimed from the farm's
unassigned `RECYCLE` backlog, repaired against the current V5 framework, and
returned to the paced Q02 queue. Three H4 FX work items are pending; the other
seven target pairs are retained in the standard deferred-symbol sidecar. No
manual smoke or backtest was started.

## Why This EA

- The remaining pending build cards did not offer a faithful low-frequency
  diversity build: QM5_1457 needs unavailable Treasury/bond series, QM5_1459
  needs unavailable lumber/Treasury series, and QM5_13031 is an XAU/NDX M15
  scalper.
- QM5_11914 adds ten FX carriers while the surviving Q08 soft cohort is
  concentrated in indices, metals, and energy.
- The source publishes four-year results on the exact primary pairs: EURUSD
  recorded 216 trades and 29.86% account growth; GBPUSD recorded 269 trades
  and 55.08% growth.
- The signal is mechanical and low-frequency: an H4 close-cross of SMA(100),
  with an ATR stop and a bounded time exit. It contains no ML or adaptive
  parameter logic.

## Diagnosis and Repair

The farm retained repeated Q02 infrastructure failures for the EA. Work item
`590f3764-086a-4afb-8347-1449d2656f23` produced real MT5 evidence with
`ONINIT_FAILED` and `INCOMPLETE_RUNS`. The initialization defect was
deterministic: EA ID 11914 was active in `ea_id_registry.csv`, but it had no
entry in `magic_numbers.csv` or `QM_MagicResolver.mqh`. The old per-symbol
setfiles also all used slot 0 and ended with `card_defaults_source=not_found`.

The repair:

- allocated collision-free magics `119140000` through `119140009` for the ten
  approved DWX FX symbols and regenerated the resolver;
- regenerated all ten H4 backtest setfiles with the correct per-symbol slot,
  card parameters, current build hash, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`;
- zero-initialized entry requests and explicitly populated the expiration;
- replaced raw series reads with framework-pooled closed-price reads;
- moved the news blackout below management and exits so it gates entries only;
- added the required Q01 `SPEC.md` and build-time strategy-card copy.

## Verification

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Build guardrails | PASS, no findings |
| Symbol scope | `SINGLE_SYMBOL_OK`, no leaks |
| Active magic duplicates | 0 |
| Strict build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260710_220755.json` |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260710_220809/QM5_11914_ciurea-100sma-cross-h4.compile.log` |
| MQ5 SHA256 | `dc23528a0088396df409a19ae399886fe65a4277dfd4f4124e3bd50ce9d7ca09` |
| EX5 SHA256 | `efa7c5a73a143005ca9a031027d259b40f1d61e0aa0ca58e6d8b0acfc60e458e` |

## Paced Q02 Handoff

The standard three-symbol stage-one policy enqueued the two source-tested
pairs plus a JPY-major portability test:

- `EURUSD.DWX` - `639dbff0-4d85-4173-9b4f-715256068f2e`
- `GBPUSD.DWX` - `45471ccd-2d7f-453d-a75b-3c551b945ea3`
- `USDJPY.DWX` - `36675969-1d6d-425f-8061-b0c2650d4b0e`

USDCAD, USDCHF, AUDUSD, NZDUSD, EURJPY, GBPJPY, and AUDJPY remain in
`D:/QM/strategy_farm/state/q02_deferred_symbols.json` for paced promotion.

The factory's OFF interlock was observed. Only pending DB rows were created;
no terminal, tester, smoke, or backtest process was launched.

## Safety Boundary

No `T_Live` path, AutoTrading state, portfolio gate, deploy manifest, or live
setfile was touched.

Machine-readable evidence:
`artifacts/qm5_11914_fx_magic_repair_q02_requeue_20260710.json`.
