# News Calendar Seed Asset

Copied: 2026-04-21

Purpose: preserve the V1-V5 news/calendar dataset for the fresh V5 Paperclip and VPS setup. This is a setup dependency for any EA, backtest, or validation run that uses news filters, news pauses, economic calendar windows, or event-impact analysis.

## Files

| File | Source path | Size | Rows | SHA256 |
|---|---|---:|---:|---|
| `news_calendar_2015_2025.csv` | `C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\Common\Files\ICT_Quant_Lab\news_calendar_2015_2025.csv` | 4,430,868 bytes | 47,992 | `1DC345FC262683EBFB5A60F03F0295DD51E9D3C48342E47A088CD9C8234A307E` |
| `forex_factory_calendar_clean.csv` | `C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\Common\Files\forex_factory_calendar_clean.csv` | 4,300,927 bytes | 48,001 | `C2B196EE2A097E2B45E4A8C4CA39D50A240D23D0214A4FA7FC06398006D66A69` |

## VPS Placement Rule

Canonical VPS copy:

```text
D:\QM\data\news_calendar\
```

DevOps must then place or copy the required CSV into each MT5 terminal data path expected by the active EA. Do not assume every EA reads the same filename or folder.

Known legacy locations to check during migration:

```text
%APPDATA%\MetaQuotes\Terminal\Common\Files\ICT_Quant_Lab\news_calendar_2015_2025.csv
%APPDATA%\MetaQuotes\Terminal\Common\Files\forex_factory_calendar_clean.csv
<terminal-data>\MQL5\Files\forex_factory_calendar_clean.csv
```

## Paperclip Bootstrap Instruction

Paperclip must be told during Phase 0 that this seed asset exists and is mandatory for any news-aware backtest.

Required setup issue:

```text
P0: Register news calendar seed asset and install on VPS
```

Done evidence:

- Files copied from this folder to `D:\QM\data\news_calendar\`.
- SHA256 hashes verified after copy.
- Row counts verified after copy.
- EA-specific expected filename/path documented before the first news-aware run.
- Missing news file is classified as `SETUP_DATA_MISSING`, not as strategy failure.

