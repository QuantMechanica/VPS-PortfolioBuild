# Q08 8.5 `empty_strategy_params` — QM5_11179 / USDJPY.DWX

Date: 2026-09-05

Task: `683f82ca-59c4-4f34-8cfc-681279905840`

Scope: read-only database classification plus a behavior-identical set-file repair; no verdict rewrite or queue mutation

## Result

This is a **set-file generation artifact defect**, not a genuinely parameter-free EA.
`QM5_11179_ft001-ema-ha.mq5` declares ten tunable `strategy_*` inputs, but the
exact Q08 baseline set file contained none. Q08.5 therefore correctly refused to
construct a neighborhood. The June set predates the generator fallback added in
commit `395eb5fc847993d6c405c466ba20bfbf42e31c43` on 2026-07-19.

The affected USDJPY baseline set was repaired by explicitly materializing the
same ten values that the compiled EA already used as input defaults. This does
not change strategy behavior. It does change the set-file identity, so the old
Q08 evidence remains INVALID and must not be rewritten or reused; any rerun must
be a new append-only work item minted by the CEO/OWNER process.

## Exact failed baseline

- Work item: `02cf605e-c90a-43ef-ab56-a5bcba7d636b`
- EA/symbol/phase: `QM5_11179` / `USDJPY.DWX` / Q08
- Baseline set:
  `C:/QM/repo/framework/EAs/QM5_11179_ft001-ema-ha/sets/QM5_11179_ft001-ema-ha_USDJPY.DWX_M5_backtest.set`
- Pre-repair SHA-256 recorded by `aggregate.json`:
  `7ef786c24e0c792be57acfb758d86205d58378c25e272140dc1ef7ec43643e9b`
- Post-repair SHA-256:
  `ca173ee6a44376f291ee6accfcb28565463227e0e3af6abfca25ba3bf8df91fb`
- Q08.5 detail:
  `neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params`

The complete pre-repair set content was:

```ini
;==========================================================
; QM5 Set File
; ea_id:        11179
; ea_slug:      ft001-ema-ha
; ea_version:   v5.0
; set_version:  s20260607-001
; symbol:       USDJPY.DWX
; timeframe:    M5
; environment:  backtest
; magic_slot:   2
; risk_mode:    FIXED
; portfolio_weight: 1
; build_hash:   6e22b9655730bff107ca1aa70b0aaf00fc93bf7e1b01325021b5f0b13f03d541
; author:       Development
; date:         2026-06-07
;==========================================================
qm_magic_slot_offset=2
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
; core filter library params; filter-on/off variants must be pre-declared
qm_filter_news_enabled=1
qm_filter_news_mode=3
qm_filter_regime_enabled=0
qm_filter_regime_lookback_bars=100
qm_filter_regime_bull_return_pct=2.0
qm_filter_regime_bear_return_pct=2.0
qm_filter_volatility_enabled=0
qm_filter_volatility_atr_period=14
qm_filter_volatility_lookback_bars=50
qm_filter_volatility_compression_ratio=0.75
qm_filter_volatility_expansion_ratio=1.25
; strategy-specific params from card must be appended below this line
; card_defaults_source=not_found
```

The backtest risk contract was and remains compliant: `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

## EA input list

Source: `framework/EAs/QM5_11179_ft001-ema-ha/QM5_11179_ft001-ema-ha.mq5:76-85`.

| Input | Type | Default |
|---|---:|---:|
| `strategy_ema_fast` | int | 20 |
| `strategy_ema_mid` | int | 50 |
| `strategy_ema_slow` | int | 100 |
| `strategy_stoploss_pct` | double | 10.0 |
| `strategy_roi_0_pct` | double | 5.0 |
| `strategy_roi_20_pct` | double | 4.0 |
| `strategy_roi_30_pct` | double | 3.0 |
| `strategy_roi_60_pct` | double | 1.0 |
| `strategy_max_spread_atr_pct` | double | 10.0 |
| `strategy_ha_warmup_bars` | int | 120 |

The repair appends those exact defaults to the USDJPY baseline set. No framework,
news, risk, or strategy value was weakened or changed.

## Classifier path

The deterministic classification is produced through these sites:

1. `framework/scripts/q08_5_neighborhood_runner.py:158` parses only explicit
   `strategy_*` assignments from the baseline set.
2. `framework/scripts/q08_5_neighborhood_runner.py:293` raises
   `ValueError("baseline setfile has no strategy parameters: ...")` when the
   parsed assignment map is empty.
3. `framework/scripts/q08_davey/aggregate.py:296-331` converts that exact error
   into the blocking Q08.5 INVALID detail; lines 317-318 emit
   `baseline_setfile_defect:empty_strategy_params`.

The current generator already prevents recurrence for a missing card:
`framework/scripts/gen_setfile.ps1:701-709` falls back to EA input defaults.
`tools/strategy_farm/tests/test_gen_setfile.py` covers that path, including
numeric, boolean, enum/timeframe, and string serialization.

## Read-only DB sweep

Method: SQLite URI `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`,
`PRAGMA query_only=ON`; selected all Q08 rows whose stored verdict is INVALID and
then matched the stored `payload_json.verdict_reason` for
`empty_strategy_params`. Snapshot time: 2026-09-05 Europe/Berlin.

There were 10 Q08 INVALID rows total, and all 10 carried this reason. They cover
7 distinct EAs:

| Updated UTC | Work item | EA | Symbol | Set file |
|---|---|---|---|---|
| 2026-08-20 00:28:03 | `796a235d-3ea6-4876-8a6a-61f20580f654` | QM5_11132 | NDX.DWX | `QM5_11132_tm-cum-rsi2_NDX.DWX_D1_backtest.set` |
| 2026-08-20 00:29:31 | `ada7e788-1fe7-43af-a3ba-651185a44d91` | QM5_10771 | XAUUSD.DWX | `QM5_10771_tv-trail-hunter_XAUUSD.DWX_H1_backtest.set` |
| 2026-08-20 02:47:53 | `1556654d-7fee-484a-bda8-2962d56db5ba` | QM5_9573 | NDX.DWX | `QM5_9573_brooks-ib-breakout-failure-h4_NDX.DWX_H4_backtest.set` |
| 2026-08-20 15:44:55 | `e49c68e1-5856-465c-9f6d-57ea83658ab6` | QM5_10148 | EURNZD.DWX | `QM5_10148_tii-signal_EURNZD.DWX_D1_backtest.set` |
| 2026-08-21 04:05:16 | `580f4783-cd4b-47bc-9329-badbd3ae47ed` | QM5_10848 | GDAXI.DWX | `QM5_10848_tv-mtf-ambush_GDAXI.DWX_H1_backtest.set` |
| 2026-09-03 09:45:03 | `8dccfffe-80d5-4015-9526-5a2aa9af2339` | QM5_10771 | USDJPY.DWX | `QM5_10771_tv-trail-hunter_USDJPY.DWX_H1_backtest.set` |
| 2026-09-03 11:03:20 | `5e1949cf-9d8b-4acf-a8b6-1e9036ccaca9` | QM5_9573 | USDCHF.DWX | `QM5_9573_brooks-ib-breakout-failure-h4_USDCHF.DWX_H4_backtest.set` |
| 2026-09-04 05:32:19 | `8c0de140-37bb-4f43-b811-98c00d1c2839` | QM5_10287 | XAUUSD.DWX | `QM5_10287_cinar-ichimoku_XAUUSD.DWX_D1_backtest.set` |
| 2026-09-04 06:08:25 | `32c48193-4013-4763-a119-860f77a8bf5c` | QM5_1230 | XAUUSD.DWX | `QM5_1230_carver-dynvol-mav_XAUUSD.DWX_D1_backtest.set` |
| 2026-09-04 22:01:26 | `02cf605e-c90a-43ef-ab56-a5bcba7d636b` | QM5_11179 | USDJPY.DWX | `QM5_11179_ft001-ema-ha_USDJPY.DWX_M5_backtest.set` |

The same read-only sweep found no Q10 work item for QM5_11179, so repairing this
set does not break any later closing-gate identity. The other nine rows are
reported only; their set files and verdicts were not changed.

## Verification

- Direct call to Q08.5 `parse_setfile_assignments` on the repaired USDJPY set:
  10 assignments, with the expected values and no duplicate/empty cells.
- `python -m pytest tools/strategy_farm/tests/test_gen_setfile.py -q`:
  `1 passed in 1.59s`.
- `git diff --check -- <set file>`: PASS.
- No terminal was started or interrupted; T_Live and AutoTrading were untouched.
- No database row, pipeline verdict, calendar file, or gate threshold was changed.

## Governed next action

Leave the historical Q08 row INVALID. If OWNER chooses to retry QM5_11179 /
USDJPY.DWX, mint a fresh append-only Q08 work item bound to the repaired set-file
SHA-256. Do not overwrite or reinterpret work item `02cf605e-...`.
