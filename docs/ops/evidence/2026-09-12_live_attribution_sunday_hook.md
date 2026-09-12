# Live attribution refresh and Sunday hook

Task: `308c8009-3556-4972-8103-80e8804cbdf6`  
Date: 2026-09-12  
RESULT: REVIEW — current AccountMonitor deal history was snapshotted read-only, 24 current sleeves were attributed, magic-0 was separated, and the existing Sunday task path now emits JSON and Markdown attribution.

## Read-only receipt

The live terminal was not started, stopped, reconfigured, or written. AutoTrading and orders were untouched. `live_deal_attribution.py` reads the AccountMonitor-owned export and deployment pointer, then writes only under `D:/QM/reports/portfolio/live_attribution/`.

Source export:

- `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv`
- mtime UTC: `2026-09-11T17:59:58.928461+00:00`
- last deal UTC: `2026-09-11T18:00:00Z`
- SHA-256: `6802a2ae4cefa75c8f9b57cc4ac643cafa7f217408318d65f4b94eb89e286ada`

Generated receipts:

- `D:/QM/reports/portfolio/live_attribution/20260912/live_deals_normalized.csv` — SHA-256 `6802a2ae4cefa75c8f9b57cc4ac643cafa7f217408318d65f4b94eb89e286ada`
- `D:/QM/reports/portfolio/live_attribution/20260912/sunday_live_attribution.json` — SHA-256 `672ee4df5b801ef9479188c68130bf32d1c82b797dcc2f3bed2f1ffdea3f23c3`
- `D:/QM/reports/portfolio/live_attribution/20260912/sunday_live_attribution.md` — SHA-256 `62ef12459c824051bba15017eeb493fc4c6cfa75edf4dd12cb3fdcacf0168e28`

Window: `2026-07-24T00:00:00Z` through the last exported deal. A close is a full broker position lifecycle with an `OUT`, `OUT_BY`, or `INOUT` deal. Net is the lifecycle sum of `net_actual`, gross win/loss are sums of positive/negative position net, PF is gross win divided by absolute gross loss, lots are entry-deal volume, and the histogram uses the first entry's UTC hour.

## Owner-facing result

Seven current sleeves are net losers in the observed window:

| Magic | EA | Symbol | Closes | Net | PF |
|---:|---:|---|---:|---:|---:|
| 15670007 | 1567 | EURUSD | 1 | -195.56 | 0.000 |
| 105130003 | 10513 | XAUUSD | 2 | -214.48 | 0.071 |
| 109390001 | 10939 | GBPUSD | 2 | -264.70 | 0.000 |
| 111320000 | 11132 | SP500 | 3 | -455.99 | 0.163 |
| 111650002 | 11165 | AUDCAD | 4 | -68.50 | 0.752 |
| 114210000 | 11421 | EURUSD | 4 | -513.28 | 0.000 |
| 117080000 | 11708 | EURUSD | 3 | -615.69 | 0.000 |

Eight current sleeves have zero closes (`flat` in this report): magics `109190001`, `125670002`, `125670003`, `127780000`, `129690000`, `129890003`, `131170000`, and `131280000`. This does not assert zero open exposure. The full per-magic table, including nine positive sleeves and the 24-bin entry-hour histogram, is in both generated report formats.

Manual magic 0 is separate: one closed NDX position, net `-1539.50`, entry lots `1.0000`. Balance/dividend rows are excluded from trade attribution.

## Existing weekly hook

No scheduled task was created. `QM_NewBook_LiveVsBook_Sunday` remains the existing weekly Sunday task and still invokes:

`powershell.exe -NonInteractive -ExecutionPolicy Bypass -File "C:\QM\repo\scripts\sunday_livevsbook_compare.ps1"`

That script now runs the attribution producer after the comparator and records both exit codes plus the output directory. A direct execution returned `compare_exit=0 attribution_exit=0` and wrote the three receipts above. The comparator's pre-existing verdict remained `UNKNOWN` because no bound drawdown reference is supplied, manifest Sharpe is absent, and four sleeves have telemetry gaps; this task does not reinterpret that pipeline evidence.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_live_deal_attribution.py -q` — `1 passed`.
- Direct producer — `per_magic=24`, `manual_closes=1`.
- Existing Sunday script — exit `0`; log: `D:/QM/reports/state/sunday_livevsbook_compare.log`.
- Scheduled task state after proof: `Ready`; action unchanged; no new scheduled task.

