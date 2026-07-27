# QM5_20180 joint FTMO backtest execution

Date: 2026-07-27  
Router task: `e88c9f3c-0d62-4781-82a9-c928168ed52f`  
Terminal: T9 only  
Verdict: **FIDELITY GATE FAIL — stopped after sleeve 0**

## Result

The first replay ran successfully on reserved T9, but the mandatory admission
gate failed:

```json
{
  "joint_trades": 1255,
  "gated_trades": 1252,
  "matched": 1148,
  "unmatched_joint": 107,
  "unmatched_gated": 104,
  "match_rate": 0.914741
}
```

Required admission is `match_rate == 1.0`. Observed match rate is 0.914741, a
shortfall of 0.085259 (8.5259 percentage points). The replay has three more
trades than the gated reference and 107 joint trades without an exact gated
key match.

Per the protocol, execution stopped immediately. Sleeve 1 was not replayed and
the two-sleeve joint configuration was not run. No parameter or comparison key
was changed to improve the result.

## Preconditions

`farmctl mt5-slots` at 2026-07-27T12:27:27Z confirmed:

- T9 reservation created 2026-07-27T11:47:16.738846Z;
- reserved by `claude`;
- reason references the QM5_20180 joint FTMO run;
- expiry 2026-07-27T21:47:16.738846Z;
- no T9 terminal process was active;
- the T9 worker remained alive, with claim-time reservation preventing a
  factory claim.

The run used the supported `run_smoke.ps1` runner. `terminal64.exe` was not
started manually. No other terminal, T_Live, AutoTrading, Factory OFF/ON, or
custom-history import was touched.

The service-account FILE_COMMON calendar gate passed at age zero with
`qm_news_stale_max_hours=336`. Canonical commission group hash was injected and
restored unchanged:

`25314333af81faf48e2afe2db5d52beea640cc74ec33a85a46b7c43aadb921dd`.

## Exact replay

Configuration:

- EA: `QM5_20180_ftmo-joint-sim-backtest-only`
- set:
  `QM5_20180_ftmo-joint-sim-backtest-only_USDJPY.DWX_H1_replay_s0.set`
- symbol/timeframe: `USDJPY.DWX / H1`
- model: 4
- window: `2017.01.01` through `2025.12.31`
- deposit/currency/leverage: `100000 / USD / 100`
- terminal: T9
- runs: one

Runner result:

- `PASS / OK`
- total trades in tester report: 1,255
- real-ticks marker: true
- no OnInit failure or log bomb
- logger events captured: 12,047

The shell invocation occupied approximately 1,027 seconds (17m 7s). Peak RAM
was not captured by the supported runner and is **NOT ESTABLISHED**; no number
is inferred from another run.

## Evidence

- runner summary:
  `D:/QM/reports/joint_20180/s0/QM5_20180/20260727_122752/summary.json`
- report:
  `D:/QM/reports/joint_20180/s0/QM5_20180/20260727_122752/raw/run_01/report.htm`
- tester log:
  `D:/QM/reports/joint_20180/s0/QM5_20180/20260727_122752/raw/run_01/20260727.log`
- exact generated tester ini:
  `D:/QM/reports/joint_20180/s0/QM5_20180/20260727_122752/raw/run_01/tester.ini`
- logger sample:
  `D:/QM/reports/joint_20180/s0/QM5_20180/20260727_122752/logger_sample.jsonl`
- harvested replay stream:
  `D:/QM/reports/joint_20180/harvest/20180_s0.jsonl`
- gated reference:
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`
- comparator:
  `C:/QM/repo/tools/strategy_farm/compare_joint_replay.py`

The comparator exited nonzero exactly because `match_rate != 1.0`.
Representative first unmatched joint key:

```text
entry=1510651994 close=1510670955 net=-1022.03 volume=6.6
```

## Required measurements

Because the sleeve-0 fidelity gate failed, the protocol says the instrument is
not admitted and joint measurements must not be produced:

- sleeve-1 match rate: **NOT RUN**
- realised daily P&L correlation: **NOT ESTABLISHED**
- true account-equity path: **NOT ESTABLISHED**
- observed maximum daily loss: **NOT ESTABLISHED**
- observed maximum drawdown: **NOT ESTABLISHED**
- observed intraday `EQUITY_LOW` -5% breach count: **NOT ESTABLISHED**
- comparison with pessimistic MAE proxy: **NOT ESTABLISHED**
- joint-run wall clock / peak RAM: **NOT ESTABLISHED**

This is a complete protocol outcome. The next action is build/fidelity review
of the 107 unmatched joint trades and 104 unmatched gated trades under the
fixed window, commission, data and comparison contract. It is not a license to
tune the replay until it passes.
