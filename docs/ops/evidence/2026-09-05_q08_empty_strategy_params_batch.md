# Q08 `empty_strategy_params` baseline repair batch

Date: 2026-09-05

Task: `543ad11a-9cb2-402e-a4dd-2f3932f50a92`

Implementation commit: `4f18224a5b0dff6193c2657d140e2fc19f424f64`
on `agents/codex`

Scope: behavior-identical materialization of the EAs' existing `strategy_*`
input defaults in eight Q08 baseline set files. No rerun, verdict rewrite,
pipeline transition, news/risk/framework change, or terminal action was made.

## Result

Eight empty baseline sets across six EAs now explicitly carry every `strategy_*`
input declared by their EA. The values are the exact source defaults; omitted
inputs already used those values at runtime, so this repairs Q08 neighborhood
construction without changing strategy behavior.

The sweep also named `QM5_11132_tm-cum-rsi2_NDX.DWX_D1_backtest.set`, but that
file already contained all nine `strategy_*` inputs in `agents/codex`. Per the
task's non-goal (do not touch sets that already carry strategy lines), it was
verified and left unchanged.

## Repaired baselines

| EA | Symbol / TF | Set path | SHA-256 before | SHA-256 after | Defaults | EA source lines |
|---|---|---|---|---|---:|---|
| QM5_10771 | XAUUSD.DWX / H1 | `framework/EAs/QM5_10771_tv-trail-hunter/sets/QM5_10771_tv-trail-hunter_XAUUSD.DWX_H1_backtest.set` | `d4ae9003d4b4a418a5b1ef22bdde39e96868bf8087167760dd036e6cab7773a1` | `126c051268fbe170d76e8583195905efbb49013d9d91f73c8004d2b8f97de525` | 13 | `QM5_10771_tv-trail-hunter.mq5:76-88` |
| QM5_10771 | USDJPY.DWX / H1 | `framework/EAs/QM5_10771_tv-trail-hunter/sets/QM5_10771_tv-trail-hunter_USDJPY.DWX_H1_backtest.set` | `994dc93d8bfdbcbb3c50150fe5b6bf1b2cf1522a1d0983135b56b39aa1dce3da` | `ef283734e1216eee9f6d8fbc88a64c1f20d50ae577e790e9bab86b1d7ca7e996` | 13 | `QM5_10771_tv-trail-hunter.mq5:76-88` |
| QM5_9573 | NDX.DWX / H4 | `framework/EAs/QM5_9573_brooks-ib-breakout-failure-h4/sets/QM5_9573_brooks-ib-breakout-failure-h4_NDX.DWX_H4_backtest.set` | `93f5b7370f1fe5139dae2da8f3266fde13a18185de0c23b61ae2119a97c1f1b8` | `935ab170cebe98a60727b3d63522d3927f92d0fa0e522d48b044e2c545ff9b93` | 10 | `QM5_9573_brooks-ib-breakout-failure-h4.mq5:41-50` |
| QM5_9573 | USDCHF.DWX / H4 | `framework/EAs/QM5_9573_brooks-ib-breakout-failure-h4/sets/QM5_9573_brooks-ib-breakout-failure-h4_USDCHF.DWX_H4_backtest.set` | `cc3a167d7bab729cc14597569a6a348f0aca56e0fc5f8e2cac587ec95d33de97` | `d43a1c2255887781abceadb2136c004c5e2dcb60f9bbec790ac14e86fa283d6a` | 10 | `QM5_9573_brooks-ib-breakout-failure-h4.mq5:41-50` |
| QM5_10148 | EURNZD.DWX / D1 | `framework/EAs/QM5_10148_tii-signal/sets/QM5_10148_tii-signal_EURNZD.DWX_D1_backtest.set` | `814787a2c9fa4ca55ee27a9de0dcb9cb0e5bf7c6b1b325458ca8af3c7c2c6fd1` | `0d91974c912bb5ead354201b79031b2ec95afd8b2e66eb79cf71a5435278ac04` | 6 | `QM5_10148_tii-signal.mq5:79-84` |
| QM5_10848 | GDAXI.DWX / H1 | `framework/EAs/QM5_10848_tv-mtf-ambush/sets/QM5_10848_tv-mtf-ambush_GDAXI.DWX_H1_backtest.set` | `c22db9387ef832a6651de683f4724ad3dae03f6fd3522dc70dfbb9673debc7f7` | `b1a1b1349e4d246cd7e5b647a3df9843373496adf8fbc6dd8d7a5b130fca45fa` | 12 | `QM5_10848_tv-mtf-ambush.mq5:81-92` |
| QM5_10287 | XAUUSD.DWX / D1 | `framework/EAs/QM5_10287_cinar-ichimoku/sets/QM5_10287_cinar-ichimoku_XAUUSD.DWX_D1_backtest.set` | `bec3bf9900528fb5b1b1fbad489749292819d26fab141d044f7ad05846813978` | `29c9b35b425bbfdcda47722579024174d854072008dfd7691221920263bc344b` | 6 | `QM5_10287_cinar-ichimoku.mq5:76-81` |
| QM5_1230 | XAUUSD.DWX / D1 | `framework/EAs/QM5_1230_carver-dynvol-mav/sets/QM5_1230_carver-dynvol-mav_XAUUSD.DWX_D1_backtest.set` | `efb6cf1d7e7e6660d4d5dc129085f0ae1b4bb25e31c08701b48167f90027f520` | `f49085a15d915b5f91c5d67573664cc1a7ad816ad8ebb4bba12b2e146121465a` | 10 | `QM5_1230_carver-dynvol-mav.mq5:76-85` |

All eight sets retain `RISK_FIXED > 0` and `RISK_PERCENT=0`. The only additions
are the explanatory repair comment and exact strategy defaults. For the
`ENUM_TIMEFRAMES` default `PERIOD_CURRENT`, the set-file value is its exact MQL5
integer representation, `0`, following `gen_setfile.ps1` serialization.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_gen_setfile.py -q`:
  `9 passed in 3.02s`.
- The test was extended with all eight repaired baseline identities. For each,
  it parses the EA input names and set assignments and asserts equality.
- Direct `q08_5_neighborhood_runner.parse_setfile_assignments` results:
  QM5_10771 XAUUSD=13; QM5_10771 USDJPY=13; QM5_9573 NDX=10;
  QM5_9573 USDCHF=10; QM5_10148 EURNZD=6; QM5_10848 GDAXI=12;
  QM5_10287 XAUUSD=6; QM5_1230 XAUUSD=10.
- An independent exact-default comparison normalized only MQL5 boolean spelling
  and `PERIOD_CURRENT=0`; all eight sets matched their EA declarations.
- `git diff --check` on the eight sets and the test: PASS (line-ending notices
  only; no whitespace error).

## Read-only later-phase identity check

Database: `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`, with
`PRAGMA query_only=ON`.

Query scope: every Q10-prefixed or Q14-prefixed work item whose
`setfile_sha256` equals one of the eight pre-repair SHA-256 values above.

Result: `old_sha_later_phase_bindings=0`.

No later-phase row binds to an old set identity. No database row was changed.
Historical Q08 INVALID evidence remains immutable; any rerun is an append-only
OWNER/CEO action outside this task.
