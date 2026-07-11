# QM5_11903 Diverse-FX Q02 Infrastructure Recovery

## Outcome

`QM5_11903_lawler-supply-demand-zones-20-dma-h1` now has a current,
zero-warning binary, ten registered symbol/magic slots, canonical fixed-risk
setfiles, and three guarded pending Q02 rows. Seven additional FX symbols are
staged in the farm's deferred-symbol sidecar.

This restores a structural H1 supply/demand-zone sleeve across ten FX pairs.
The edge is deterministic and ML-free: a one-to-ten-bar narrow base, a
two-ATR expansion close, SMA(20) slope confirmation, and the first fresh zone
retest with a structural stop and primary 3R target.

## Selection And Claim

No faithful priority-1 diversity build was available. `QM5_1459` requires
unavailable lumber and IEF inputs, `QM5_1457` requires unavailable Treasury
and ETF inputs, and `QM5_13031` is an M15 XAU/index scalper in the already
saturated asset class. The mission's priority-2 diverse-instrument recovery
lane was therefore selected.

The farm task `35726d80-e5cb-4d01-bdc2-ce08c03ad2ee` was atomically claimed
by `codex:agents/board-advisor`. The EA had 120 historical
`failed / INFRA_FAIL` Q02 rows, all reportless infrastructure outcomes, with
no economic Q02 verdict, open Q02-Q03 work, or downstream result.

The card of record is `APPROVED`, R1-R4 PASS, expects approximately 30
trades/year/symbol, and cites Jasper Lawler's FlowBank supply/demand-zone
article with the underlying market structure attributed to Richard Wyckoff.

## Diagnosis

The retained rows ended as `summary_missing_retries_exhausted`; their logs and
summaries did not survive. A deterministic package audit found concrete
infrastructure defects:

1. No EA 11903 rows existed in `magic_numbers.csv` or the generated resolver.
2. All ten setfiles used slot zero, omitted `qm_ea_id` and the strategy inputs,
   and retained pending build metadata.
3. The `.ex5` was stale relative to the source/current framework package.
4. The EA used nine forbidden raw series calls, a global `PositionsTotal()`
   gate, and hard-coded point-to-pip scaling.
5. News filtering ran before position management and strategy exits.
6. `SPEC.md` was absent.

The pre-repair strict build check therefore failed with nine findings:
`D:/QM/reports/framework/21/build_check_20260711_081251.json`.

## Repair

Slots `0..9` and magics `119030000..119030009` were registered in the approved
symbol order and `QM_MagicResolver.mqh` was regenerated. Raw series reads were
replaced with a one-record `CopyRates` reader plus framework ATR/SMA helpers.
The reader is restricted to the shared H1 new-bar path and has a reviewed
`perf-allowed` tag for the bounded ten-candle structural scan. Zone state,
trend exits, and entries now share that edge; position checks are symbol/magic
scoped; pip buffers use framework conversions; and management/exits remain
reachable before the entry-only news gate.

All ten setfiles now contain unique slots, explicit strategy inputs,
`qm_ea_id=11903`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The missing spec was restored and the local strategy card
is an exact SHA256 match of the approved card.

The card's phrase “next visible” ZigZag target is not causally defined. The EA
uses the explicitly primary 3R target and does not add a forward-looking or
repainting target. It recognizes the first completed H1 bar that trades
through the limit level and submits at market on the following tick. Both
deterministic interpretations are explicit in `SPEC.md`; no parameter tuning
was performed.

## Validation

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Build guardrails | PASS, zero findings across source and ten setfiles |
| Symbol scope | `SINGLE_SYMBOL_OK`, zero violations |
| Build-skill guard | PASS: EA registry, magic rows, and EA directory present |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260711_084110/QM5_11903_lawler-supply-demand-zones-20-dma-h1.compile.log` |
| Build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260711_084321.json` |
| MQ5 SHA256 | `106EA1D65020AEAB8C70B04B2317552A7D223F36BDF81D0D49E67952ED259F30` |
| EX5 SHA256 | `8F80936DC1D808821A5F3699D6DF81FE0E2A3C5F1BB15C0FDB1E938AE780CCF1` |
| Approved/local card SHA256 | `90B67A82CFDE246D8B735D0798743E38D13E1F5678F09077D3904F9BFF61DF01` |

The final binary was compiled at the main EA path using the framework include
tree from a synthetic staged snapshot, with equality guards on the staged
resolver and normalized source blobs. A second clean-snapshot build check
compiled the same normalized source and also passed 0/0, preventing the binary
from depending on unrelated working-tree framework edits.

## Q02 Handoff

The OWNER three-symbol stage-1 cap is applied with an explicitly diverse
probe. EURUSD is the liquid source carrier, GBPJPY adds a non-USD cross, and
AUDUSD adds commodity/carry-sensitive exposure. Together they span EUR, USD,
GBP, JPY, and AUD.

| Symbol | Q02 work item | State |
|---|---|---|
| `EURUSD.DWX` | `1711f39f-a0cf-4425-bcce-7f4f45ac1503` | pending, attempt 0, unclaimed |
| `GBPJPY.DWX` | `5321b5b6-87a9-473c-9bbc-dbd9cd2e665f` | pending, attempt 0, unclaimed |
| `AUDUSD.DWX` | `496ee481-7b5c-408a-903f-8e1ecad6cd69` | pending, attempt 0, unclaimed |

`GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`,
`EURJPY.DWX`, and `AUDJPY.DWX` are in
`D:/QM/strategy_farm/state/q02_deferred_symbols.json` for promotion after a
stage-1 PASS or spare capacity.

Consistent backups were taken before each queue mutation:

- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11903_q02_enqueue_20260711T082413Z.sqlite`
- `D:/QM/strategy_farm/state/backups/q02_deferred_symbols_before_qm5_11903_20260711T082413Z.json`
- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11903_diversity_stage_correction_20260711T083009Z.sqlite`
- `D:/QM/strategy_farm/state/backups/q02_deferred_symbols_before_qm5_11903_diversity_stage_correction_20260711T083009Z.json`

## Runtime And Safety

`FACTORY_OFF.flag` was active and four existing MetaTester processes already
occupied backtest hosts. The capacity stop was honored: no smoke, backtest,
terminal, or worker was started or interrupted. The three rows remain pending
only.

No portfolio gate, `T_Live` path, T_Live manifest, AutoTrading setting, or
live setfile was touched.

Machine-readable evidence:
`artifacts/qm5_11903_fx_q02_infra_repair_requeue_20260711.json`.
