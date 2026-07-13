# Master-EA Phase 1.5 — q08 Per-Magic Row Design Note

Date: 2026-07-13
Branch: `agents/codex-master-ea-p15`

## Scope

Phase 1.5 adds the opening-deal magic to every q08 `TRADE_CLOSED` JSONL row.
It does not add a master EA or strategy modules, change trade behavior, alter
the two-pass ownership rules, or touch another stream or serializer.

## Function changed

`QM_FrameworkQ08EmitFromHistory()` in `framework/include/QM/QM_Common.mqh`
now keeps a parallel `owned_magic[]` value beside every `owned_pos[]` value
collected in Pass 1. The value is read from that qualifying opening deal's
`DEAL_MAGIC` and passed unchanged to the existing
`QM_FrameworkOwnsMagicSymbol()` ownership predicate.

In Pass 2, the existing reverse position-id lookup also retrieves the magic at
the matched array index. That opening-deal value is emitted as the additive
top-level JSON property `"magic"`. The closing deal's magic is deliberately not
used because broker-generated SL/TP closing deals can carry magic zero.

## Backward compatibility

The stream is a format superset: all existing properties keep their names and
meaning, and `magic` is additive. Existing Q08/Q09, portfolio, and live-pulse
consumers either select known properties or ignore unknown ones. The Q08 loader
already accepts an optional top-level magic filter. A single-magic EA needs no
special case; each row simply carries its host magic.

## Verification

- Strict force rebuild of `QM5_12567_cum-rsi2-commodity`: PASS, 0 errors / 0
  warnings.
  - Compile log: `framework/build/compile/20260713_101156/QM5_12567_cum-rsi2-commodity.compile.log`
  - Summary: `D:\QM\reports\compile\20260713_101156\summary.csv`
  - Rebuilt EX5 SHA-256: `F1AC14BAFFFDA62ED4A2BC3BBEA5A7DE90B47B06C3F5F25F79A78577192678D1`
- Requested recent-year smoke: PASS on T6, XAUUSD.DWX D1, 2025, Model 4,
  one run: 11 trades / net $2,247.62. All 11 q08 rows had magic 125670003.
  - Summary: `D:\QM\reports\smoke\QM5_12567\20260713_101416\summary.json`
- Full brief gate: PASS on T6, XAUUSD.DWX D1, 2017-01-01 through 2025-12-31,
  Model 4, one run: 73 trades / net $4,676.76. The q08 stream had 73 rows,
  zero missing or wrong magic values, only magic 125670003, and summed net
  $4,676.76.
  - Summary: `D:\QM\reports\smoke\QM5_12567\20260713_101643\summary.json`
  - Evidence: `D:\QM\reports\framework\22\20260713_101643_QM5_12567_T6_XAUUSD_DWX_run_smoke.md`
  - Stream: `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12567_XAUUSD_DWX.jsonl`
- Focused consumer compatibility tests: PASS, 51 tests covering
  `portfolio_common`, Q08 subgates, and `live_book_pulse`.

Sample full-history row:

```json
{"event":"TRADE_CLOSED","magic":125670003,"time":1548450000,"entry_time":1548118861,"mae_acct":-128.76,"net":627.89,"profit":627.89,"swap":0.00,"commission":0.00,"volume":0.37,"notional":47998.62,"symbol":"XAUUSD.DWX"}
```

No T1/T2 smoke lane or T_Live path was used.
