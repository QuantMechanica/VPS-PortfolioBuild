# QM5_11906 Diverse-FX Q02 Infrastructure Recovery

## Outcome

`QM5_11906_watthana-candlestick-rsi-stoch-ea-h1` now has registered
per-symbol magics, a current zero-warning binary, complete canonical
fixed-risk setfiles, and three guarded pending Q02 rows. Seven additional FX
pairs remain staged in the farm's deferred-symbol sidecar.

The approved H1 edge combines a long-shadow Japanese reversal candle with
RSI(14) and Stochastic(14) extremes. It is deterministic and ML-free, and its
source is the peer-reviewed 2018 IJTEF paper by Watthana Pongsena et al., DOI
`10.18178/ijtef.2018.9.6.622`.

## Selection And Claim

No faithful priority-1 diversity build was available. `QM5_1457` requires
unavailable Treasury/rates inputs, `QM5_1459` requires unavailable lumber and
IEF inputs and retains a data gate, and `QM5_13031` is an M15 XAU/index
strategy in the already saturated asset class. The diverse-instrument
infrastructure-recovery path was therefore selected.

The latest ten-symbol Q02 wave was atomically claimed as
`codex:agents/board-advisor:qm5-11906:20260711T062240Z`. All ten rows were
`failed / INFRA_FAIL`, none had a later phase, and no pending or active Q02-Q03
row existed for the EA.

## Diagnosis

The retained terminal rows reported `summary_missing_retries_exhausted` and
had no surviving run log or summary. A deterministic package audit found four
concrete infrastructure defects:

1. `magic_numbers.csv` had no active row for EA 11906, so the V5 framework
   could not validate any symbol/slot mapping during initialization.
2. Every backtest setfile used slot zero, omitted `qm_ea_id` and all fourteen
   strategy inputs, and retained `build_hash: pending`.
3. The checked-in `.ex5` was stale relative to the EA source and current V5
   includes.
4. News gating ran before position management and strategy exits instead of
   applying only to new entries.

## Repair

Canonical slots `0..9` and magics `119060000..119060009` were registered in
the approved card's symbol order, then `QM_MagicResolver.mqh` was regenerated.
All ten H1 setfiles were regenerated with the standard generator and now
contain their unique slot, `qm_ea_id=11906`, fourteen explicit strategy
parameters, `RISK_FIXED=1000`, and `RISK_PERCENT=0`.

The missing `SPEC.md` and local approved-card copy were restored. The EA now
caches its candle and oscillator state once per completed H1 bar, uses
magic-scoped position counting, and keeps news filters on the entry path so
management and exits remain active.

## Validation

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Symbol scope | `SINGLE_SYMBOL_OK`, zero violations |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260711_063804/QM5_11906_watthana-candlestick-rsi-stoch-ea-h1.compile.log` |
| Build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260711_063804.json` |
| MQ5 SHA256 | `37F58E9B7F4878703AC7C157BFFF31F7933B4B521B077B30C44527261E3F9928` |
| EX5 SHA256 | `308CFA7D308FF7009BC1EACEA777BC96B1BA1A3005A75ACDA733CC8789C77F15` |

## Q02 Handoff

The claimed rows were reset in place, avoiding duplicate queue entries. The
OWNER three-symbol stage-1 cap was applied deliberately: EURUSD is the paper
carrier, GBPJPY is a non-USD cross, and AUDUSD adds a commodity/carry-sensitive
major. Together they span EUR, USD, GBP, JPY, and AUD.

| Symbol | Q02 work item | State |
|---|---|---|
| `EURUSD.DWX` | `afecabd3-5168-48c4-b968-ce0e9eb72e62` | pending, attempt 0, unclaimed |
| `GBPJPY.DWX` | `c6a4d4e7-62af-4971-8868-a20d2fb9ad98` | pending, attempt 0, unclaimed |
| `AUDUSD.DWX` | `e9bf166a-b280-498c-b8f5-b0d0efd9b884` | pending, attempt 0, unclaimed |

`AUDJPY.DWX`, `EURJPY.DWX`, `GBPUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`,
`USDCHF.DWX`, and `USDJPY.DWX` were released from the repair claim and placed
in `D:/QM/strategy_farm/state/q02_deferred_symbols.json`. The canonical sweep
can promote them after a stage-1 PASS or when queue capacity is available.

Consistent backups taken before the queue mutation:

- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11906_fx_requeue_20260711T063850Z.sqlite`
- `D:/QM/strategy_farm/state/q02_deferred_symbols_before_qm5_11906_20260711T063850Z.json`

## Runtime And Safety

`FACTORY_OFF.flag` remains active, so no manual smoke/backtest was launched
and no tester CPU was added. The two pre-existing non-factory `terminal64`
processes were observed but not modified. No portfolio gate, `T_Live` file or
manifest, AutoTrading setting, or live setfile was touched.

Machine-readable evidence:
`artifacts/qm5_11906_fx_q02_infra_repair_requeue_20260711.json`.
