# News-Calendar Sandbox Fix — 2026-05-23

## Symptom

Every QM EA with `qm_news_mode != QM_NEWS_OFF` failed `OnInit` in the
tester with no Print output. The EA structured log showed:

```
SETUP_DATA_MISSING  reason: calendar_file_missing_or_unreadable
path: D:\QM\data\news_calendar\news_calendar_2015_2025.csv
```

surfaced when the 2026-05-22 bulk-enqueue filled the queue with EAs
defaulting to `qm_news_mode=QM_NEWS_PAUSE` (the h4-pattern batch +
the Edge Lab Direction-1 EAs). EAs with `qm_news_mode=OFF` kept
running because `QM_FrameworkInit` tolerates a news-init failure when
news mode is OFF.

## Root cause

`QM_NewsInit` (in `framework/include/QM/QM_NewsFilter.mqh`) calls
`FileOpen("D:\QM\data\news_calendar\news_calendar_2015_2025.csv", ...)`.
MT5 build 5833 rejects that absolute path with `err=5002`
(`ERR_FILE_WRONG_FILENAME`) — MQL5 `FileOpen` is sandboxed to
`MQL5\Files\` (or `<Common>\Files\` with `FILE_COMMON`) and refuses
paths with a drive-letter colon.

A diagnostic probe (`QM_Probe_NewsFile.mq5`) confirmed:
- `D:\QM\data\news_calendar\...` (any combination of sandbox / COMMON): err 5002.
- `news_calendar_2015_2025.csv` (bare, sandbox or COMMON): err 5004 — MT5
  searches `MQL5\Files\` or `Common\Files\` correctly, the file is
  simply not deployed there.

So the historical absolute-path read has never worked on this MT5
build; it only happened to be silent for EAs whose default news mode
was OFF.

## Fix

Two parts:

1. **Deploy** the news CSVs into the MT5 Common folder so that
   `FILE_COMMON` resolves the basename:

   ```
   C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
       news_calendar_2015_2025.csv
       forex_factory_calendar_clean.csv
   ```

   One physical copy serves all 10 terminals and every tester agent.

2. **Patch** `QM_NewsFilter.mqh` to add a basename-in-COMMON fallback
   after the absolute path is refused. Backward-compatible — the
   existing sandbox + COMMON attempts run first, the basename-in-COMMON
   fallback only fires when both fail:

   - New helper `QM_NewsBasename(path)` returns the last `\` / `/`
     segment.
   - In `QM_NewsReadFileBytes` and `QM_NewsLoadCsv`, after the existing
     two `FileOpen` attempts return `INVALID_HANDLE`, retry with
     `QM_NewsBasename(path)` + `FILE_COMMON`.

3. **Recompile** every QM EA so that the patched include is baked into
   each `.ex5`. Done 2026-05-23 — 207 / 209 EAs compiled clean. The
   two failures (`QM5_6002_macro-thorp-reversion`, `QM5_7003_quant-real-
   yield-arb`) are pre-existing placeholder stubs and unrelated.

## Operational note — keep the Common-folder copy in sync

When the news calendar source at `D:\QM\data\news_calendar\` is
refreshed (touch / re-download), the Common-folder copy must be
refreshed too — otherwise the EA reads stale data via the fallback.
Until the runner is wired to do this automatically, the seed-refresh
script must also copy to:

```
C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
```

## Verification

`QM_Probe_NewsFile.mq5` re-run after the deploy reports
`[ OPEN OK ] COMMON path=news_calendar_2015_2025.csv` with the real
file size. The first work_item run after Factory ON produces a real
report (not `INFRA_FAIL / calendar_file_missing_or_unreadable`).
