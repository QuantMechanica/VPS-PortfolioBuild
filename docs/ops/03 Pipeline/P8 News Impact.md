# P8 News Impact

Updated: 2026-05-08
Issue: QUA-911

## Purpose

P8 selects a deploy-safe news mode policy from backtest matrix evidence and validates the runtime calendar input contract before phase verdict emission.

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
  --news-matrix framework/scripts/tests/fixtures/p8_matrix.csv \
  --calendar-csv D:/QM/data/news_calendar/news_calendar.csv \
  --mode all
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
- `phase_runner_log.jsonl`

`P8_summary.csv` emits per-profile/per-symbol recommended mode and verdict.
