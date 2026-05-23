# P8 Real News Replay and Runtime News Filter Spec

Created: 2026-05-08  
Replaced: 2026-05-20 synthetic news matrix selector  
Owners: CTO + CEO  
Scope: V5 pipeline P8 real news replay and EA runtime news gating.

## 1. Purpose

P8 must prove how an EA behaves under actual news-calendar constraints. It is not a synthetic multiplier gate.

P8 now has two evidence layers:

1. **Real MT5 mode reruns**: rerun the EA on the target symbol/timeframe with `qm_news_mode` patched to each supported mode.
2. **Deal replay analysis**: parse real MT5 deal timestamps from the resulting reports and map every entry to the actual UTC news calendar.

## 2. Runtime Contract

Every V5 EA must expose the framework news inputs from the first build:

```mql5
input group "News"
input QM_NewsMode qm_news_mode             = QM_NEWS_OFF;
input int         qm_news_pause_before_minutes = 30;
input int         qm_news_pause_after_minutes  = 30;
input int         qm_news_stale_max_hours      = 336;
input string      qm_news_min_impact           = "high";
```

The EA must call:

```mql5
QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode)
```

before any new entry. Position management and exits remain allowed unless the EA has a documented strategy-specific override.

## 3. Supported Modes

- `OFF`
- `PAUSE`
- `SKIP_DAY`
- `FTMO_PAUSE`
- `5ers_PAUSE`
- `no_news`
- `news_only`

## 4. Calendar

Canonical calendar:

- `D:/QM/data/news_calendar/news_calendar_2015_2025.csv`

Required fields:

- `timestamp_utc`
- `currency`
- `impact`
- `event`
- `actual`
- `forecast`
- `previous`

Validation:

- timestamps must be UTC
- impact must be `low|medium|high`
- duplicate `(timestamp_utc, currency, event)` rows are counted and reported

## 5. P8 Driver Inputs

`framework/scripts/p8_news_driver.py` must accept:

- `--ea`
- `--symbol`
- `--period`
- `--base-setfile`
- `--calendar-csv`
- `--from-date 2023.01.01`
- `--to-date 2025.12.31`
- `--run-mt5`
- `--mt5-modes all` or a comma-list such as `OFF,PAUSE`
- `--trade-report` optional repeatable fallback/evidence input

The driver creates temporary setfiles per mode by patching `qm_news_mode` and news-window inputs.
`qm_news_min_impact` is enforced by both the EA runtime filter and the replay analyzer.
For legacy TerminalWorker commands that still call P8 without `--run-mt5`, the driver may infer the active P8 `work_items` row from SQLite and run MT5 on the claimed terminal. Use `--no-auto-mt5` only for deliberate offline replay.

Runtime/replay windows:

- `PAUSE`, `no_news`, `news_only`: use `qm_news_pause_before_minutes` / `qm_news_pause_after_minutes`.
- `SKIP_DAY`: blocks the UTC event day for matching symbol currency.
- `FTMO_PAUSE`: 5/3/1 minutes for high/medium/low impact.
- `5ers_PAUSE`: 2/1/0 minutes for high/medium/low impact.

## 6. Selection Logic

For each symbol/profile:

1. Run or load all requested news modes.
2. Parse MT5 summaries and deal rows.
3. Reject modes below minimum trade count, profit factor, or net-profit threshold.
4. Rank eligible modes by:
   - profit factor descending
   - net profit descending
   - blocked trades ascending

Default thresholds:

- `min_trades = 30`
- `min_profit_factor = 1.0`
- `net_profit >= 0`

## 7. Required Artifacts

P8 output directory:

- `P8_QM5_<id>_result.json`
- `summary.json`
- `P8_summary.csv`
- `P8_real_news_replay.csv`
- `P8_trade_replay_inputs.json`
- `mt5_mode_runs/` when `--run-mt5` is used

`P8_result.json` must include:

- calendar stats
- source report paths
- MT5 mode metrics
- replay CSV path
- recommended mode by symbol
- thresholds used

## 8. Failure Modes

Hard fail:

- calendar invalid
- no MT5 report/deal rows parseable
- real MT5 mode rerun produces no summary
- no mode passes thresholds

Manual review:

- a mode technically passes but trades are concentrated around a small number of news events
- top-trade removal materially changes verdict

## 9. What P8 Does Not Authorize

P8 does not authorize T_Live. P9/P9b/P10 remain OWNER/Board/manual gates.
