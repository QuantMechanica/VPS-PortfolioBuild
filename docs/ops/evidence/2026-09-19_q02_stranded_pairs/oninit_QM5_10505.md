# QM5_10505 (mql5-macd-sar) / XAUUSD.DWX — OnInit root-cause dig

Task: `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b`. Never requeued; no verdict touched.

## Evidence used (real MT5, REAL_TICKS; no fresh run spawned this cycle)

- work_item `cc347183-5365-427e-b815-3879639c0d42`, 2026-09-11 09:43Z, verdict `INFRA_FAIL`.
- `evidence_path`: `D:\QM\reports\work_items\cc347183-5365-427e-b815-3879639c0d42\QM5_10505\20260911_094308\summary.json`
- `ex5_sha256`: `cc702479b617074e190b94833eb60cb9f9b5571cbfe6e39747633223b7a03bbb` — identical to the
  2026-08-12 attempt (`9586db87-...`), stable across a month.
- `oninit_failure_detected`: `true`.
- Decisive tester-log line:

  ```
  CS  2  11:43:16.940  Tester  tester stopped because OnInit returns non-zero code 1
  ```

Same `...returns non-zero code 1` wording as QM5_12582 (see that file for what this implies:
`OnInit()` executed and legitimately returned `INIT_FAILED`, i.e. the rejection is inside the
shared `QM_FrameworkInit`/`QM_FrameworkInitCoreAfterRuntimeStateArmed` path, not a pre-flight
tester-level parameter-binding refusal).

## A concrete, verifiable defect found by diff — orphaned `.set` keys

`framework/EAs/QM5_10505_mql5-macd-sar/sets/QM5_10505_mql5-macd-sar_XAUUSD.DWX_H1_backtest.set`
sets these keys:

```
qm_filter_news_enabled=1
qm_filter_news_mode=3
qm_filter_regime_enabled=0
qm_filter_regime_lookback_bars=100
qm_filter_regime_bull_return_pct=2.0
qm_filter_regime_bear_return_pct=2.0
qm_filter_volatility_enabled=0
qm_filter_volatility_atr_period=14
qm_filter_volatility_lookback_bars=50
```

**None of these correspond to a currently-declared `input` in
`QM5_10505_mql5-macd-sar.mq5`** — the full current input list (`grep -n "^input"`) is:
`qm_ea_id, qm_magic_slot_offset, qm_rng_seed, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_temporal, qm_news_compliance, qm_news_stale_max_hours, qm_news_min_impact,
qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
qm_stress_reject_probability, strategy_timeframe, strategy_macd_fast, strategy_macd_slow,
strategy_macd_signal, strategy_psar_step, strategy_psar_maximum, strategy_atr_period,
strategy_atr_sl_mult, strategy_take_profit_rr`. There is no "filter library" (`qm_filter_*`)
group in the source at all. The `.set` file also omits `qm_ea_id` entirely (harmless here —
the source default is already `10505`), which is itself a sign it was not regenerated from
the current card/source via `framework/scripts/gen_setfile.ps1` for this build.

This is genuine `.set`/source **drift** — the deployed backtest set predates a source
refactor that removed the filter-library inputs (or was hand-edited/copied from a sibling EA
that still has them). MT5's tester is generally tolerant of unknown `.set` keys (they are
skipped rather than rejected outright), so this by itself does not conclusively explain the
`INIT_FAILED` return — but it is a real, fixable hygiene defect independent of that question,
and it means this `.set` file cannot be trusted as evidence of "current card defaults" until
regenerated.

## Checked, not assumed — ruled out as the sole/direct cause

- **Not a source-level hard input pin**: `grep -n "QM_InputRequire" QM5_10505_mql5-macd-sar.mq5`
  → 0 hits.
- **Not a missing/mismatched magic registry row**: `framework/registry/magic_numbers.csv` has
  `10505,mql5-macd-sar,3,XAUUSD.DWX,105050003,...,active`, matching the set file's
  `qm_magic_slot_offset=3`.
- **Not an out-of-range risk/portfolio input**: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` in the set file — all within the validator's accepted ranges on paper.
- **Not a build-drift flip mid-window**: identical `ex5_sha256` between 2026-08-12 and
  2026-09-11.

## Not yet determined

Which internal `QM_FrameworkInitCoreAfterRuntimeStateArmed` branch fires. No worker-level log
survived for this work item, and the raw MT5 journal is purged. `logger_sample_path` is
`null`.

## No fresh reproduction this cycle — why

Same infra constraint as the other three pairs (Custom-history symbol, no safe non-factory-claim
lane available this session) — see `oninit_rootcause_4216dd75.md`.

## Classification

**Disposition: `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD`**, plus a standalone, independently
actionable **build-hygiene defect**: regenerate
`QM5_10505_mql5-macd-sar_XAUUSD.DWX_H1_backtest.set` from the current card defaults via
`framework/scripts/gen_setfile.ps1` to drop the orphaned `qm_filter_*` keys and add an explicit
`qm_ea_id=10505` line, *before* any instrumented-rebuild diagnostic run, so that a future
reproduction isn't confounded by a stale set file. **No requeue performed.**
