# Q11 / P8 Real News Replay

Updated: 2026-05-20
Issue: QUA-911

## Purpose

Q11 selects a deploy-safe news mode policy from real MT5 news-mode reruns and deal replay against the actual UTC news calendar. Deprecated `news_matrix.csv` inputs are compatibility markers only and cannot produce a hard PASS.

## Canonical Calendar Schema

Canonical file path:
- `D:/QM/data/news_calendar/news_calendar.csv`

Required CSV columns:
- `timestamp_utc` (ISO-8601 UTC, example `2026-05-01T12:30:00Z`)
- `currency` (ISO currency code, example `USD`)
- `impact` (`low|medium|high`)
- `event`
- `actual`
- `forecast`
- `previous`

Validation rules:
- All required columns must exist.
- `timestamp_utc` must parse as UTC offset zero.
- `impact` must be one of `low|medium|high`.

## P8 Driver Command

```bash
python framework/scripts/p8_news_driver.py \
  --ea QM5_1001 \
  --symbol EURUSD.DWX \
  --period H1 \
  --base-setfile D:/QM/reports/pipeline/QM5_1001/sets/QM5_1001_EURUSD.DWX_H1_backtest.set \
  --calendar-csv D:/QM/data/news_calendar/news_calendar_2015_2025.csv \
  --mode all \
  --mt5-modes all \
  --from-date 2023.01.01 \
  --to-date 2025.12.31 \
  --run-mt5
```

PowerShell phase wrapper (opt-in integration):

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/run_phase.ps1 `
  -EAId QM5_1001 `
  -Phase P8 `
  -UseP8NewsDriver `
  -RunnerArgs @('--symbol','EURUSD.DWX','--period','H1','--base-setfile','D:/QM/reports/pipeline/QM5_1001/sets/QM5_1001_EURUSD.DWX_H1_backtest.set','--calendar-csv','D:/QM/data/news_calendar/news_calendar_2015_2025.csv','--mode','all','--mt5-modes','all','--from-date','2023.01.01','--to-date','2025.12.31','--run-mt5')
```

Supported `--mode` profiles:
- `full`
- `ftmo`
- `5ers`
- `dxz`
- `no-news`
- `news-only`
- `custom` (with `--custom-modes OFF,PAUSE,...`)
- `all` (default; runs all profiles including custom)

## Outputs

Under `D:/QM/reports/pipeline/<ea_id>/P8/`:
- `P8_<ea_id>_result.json`
- `P8_summary.csv`
- `P8_real_news_replay.csv`
- `P8_trade_replay_inputs.json`
- `mt5_mode_runs/`
- `phase_runner_log.jsonl`

`P8_summary.csv` emits per-profile/per-symbol recommended mode and verdict.

Hard PASS requires:
- `P8_<ea_id>_result.json` verdict `MODE_SELECTED`
- `details.parameters.run_mt5=true`
- non-empty MT5 rerun evidence under `details.mt5_mode_metrics`
- no synthetic `news_matrix.csv` as the deciding evidence
