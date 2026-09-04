# News-calendar semantic timestamp diagnostic

Generated UTC: 2026-09-04T23:12:15.801684+00:00
Report directory: `D:\QM\reports\news_calendar\diagnose_20260904T231135Z`

This is a report-only diagnostic. It does not participate in or change the news-calendar gate verdict.

## Headline

- Anchor checks: 542 PASS / 2700 FAIL across 3242 rows.
- Primary derived-column mismatches: 0 across 48627 rows.
- Cross-file identical instants: 46349 / 48627 matched rows.
- Native matches: 2211; per-currency buckets: `{"EUR": {"other": 243}, "GBP": {"other": 378}, "JPY": {"exact": 49, "other": 51, "within_5m": 12}, "USD": {"exact": 529, "other": 946, "within_5m": 3}}`.
- Zero months: `{"primary": ["2025-05", "2025-06", "2025-07", "2025-08", "2025-09", "2025-10", "2025-11", "2025-12", "2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06"], "secondary": ["2025-05", "2025-06", "2025-07", "2025-08", "2025-09", "2025-10", "2025-11", "2025-12", "2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06"]}`.

## Scheduled-anchor assertions

Expected UTC is computed from `qm.dst_rule.us.v1`: US DST starts at 07:00Z on the second Sunday of March and ends at 06:00Z on the first Sunday of November. NFP must also occur on the first Friday. All shares use a ±5 minute tolerance.

| source | class | year | within ±5m | total | share |
|---|---|---:|---:|---:|---:|
| primary | CPI | 2015 | 6 | 36 | 0.167 |
| primary | CPI | 2016 | 0 | 36 | 0.000 |
| primary | CPI | 2017 | 10 | 36 | 0.278 |
| primary | CPI | 2018 | 5 | 36 | 0.139 |
| primary | CPI | 2019 | 6 | 36 | 0.167 |
| primary | CPI | 2020 | 9 | 36 | 0.250 |
| primary | CPI | 2021 | 8 | 36 | 0.222 |
| primary | CPI | 2022 | 10 | 36 | 0.278 |
| primary | CPI | 2023 | 5 | 36 | 0.139 |
| primary | CPI | 2024 | 6 | 36 | 0.167 |
| primary | CPI | 2025 | 2 | 9 | 0.222 |
| primary | CPI | 2026 | 4 | 4 | 1.000 |
| primary | FOMC_STATEMENT | 2015 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2016 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2017 | 2 | 8 | 0.250 |
| primary | FOMC_STATEMENT | 2018 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2019 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2020 | 3 | 9 | 0.333 |
| primary | FOMC_STATEMENT | 2021 | 3 | 8 | 0.375 |
| primary | FOMC_STATEMENT | 2022 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2023 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2024 | 0 | 8 | 0.000 |
| primary | FOMC_STATEMENT | 2025 | 0 | 2 | 0.000 |
| primary | FOMC_STATEMENT | 2026 | 1 | 1 | 1.000 |
| primary | NFP | 2015 | 1 | 12 | 0.083 |
| primary | NFP | 2016 | 0 | 12 | 0.000 |
| primary | NFP | 2017 | 0 | 12 | 0.000 |
| primary | NFP | 2018 | 0 | 12 | 0.000 |
| primary | NFP | 2019 | 0 | 12 | 0.000 |
| primary | NFP | 2020 | 0 | 12 | 0.000 |
| primary | NFP | 2021 | 0 | 12 | 0.000 |
| primary | NFP | 2022 | 0 | 12 | 0.000 |
| primary | NFP | 2023 | 0 | 12 | 0.000 |
| primary | NFP | 2024 | 0 | 12 | 0.000 |
| primary | NFP | 2025 | 0 | 4 | 0.000 |
| primary | NFP | 2026 | 2 | 2 | 1.000 |
| primary | PPI | 2015 | 3 | 24 | 0.125 |
| primary | PPI | 2016 | 0 | 24 | 0.000 |
| primary | PPI | 2017 | 6 | 24 | 0.250 |
| primary | PPI | 2018 | 4 | 24 | 0.167 |
| primary | PPI | 2019 | 3 | 24 | 0.125 |
| primary | PPI | 2020 | 7 | 24 | 0.292 |
| primary | PPI | 2021 | 3 | 24 | 0.125 |
| primary | PPI | 2022 | 6 | 24 | 0.250 |
| primary | PPI | 2023 | 2 | 24 | 0.083 |
| primary | PPI | 2024 | 2 | 24 | 0.083 |
| primary | PPI | 2025 | 2 | 6 | 0.333 |
| primary | PPI | 2026 | 2 | 2 | 1.000 |
| primary | RETAIL_SALES | 2015 | 8 | 24 | 0.333 |
| primary | RETAIL_SALES | 2016 | 10 | 24 | 0.417 |
| primary | RETAIL_SALES | 2017 | 3 | 24 | 0.125 |
| primary | RETAIL_SALES | 2018 | 7 | 24 | 0.292 |
| primary | RETAIL_SALES | 2019 | 6 | 24 | 0.250 |
| primary | RETAIL_SALES | 2020 | 2 | 24 | 0.083 |
| primary | RETAIL_SALES | 2021 | 5 | 24 | 0.208 |
| primary | RETAIL_SALES | 2022 | 5 | 24 | 0.208 |
| primary | RETAIL_SALES | 2023 | 0 | 24 | 0.000 |
| primary | RETAIL_SALES | 2024 | 0 | 24 | 0.000 |
| primary | RETAIL_SALES | 2025 | 1 | 6 | 0.167 |
| primary | RETAIL_SALES | 2026 | 2 | 2 | 1.000 |
| primary | UNEMPLOYMENT_CLAIMS | 2015 | 13 | 52 | 0.250 |
| primary | UNEMPLOYMENT_CLAIMS | 2016 | 10 | 52 | 0.192 |
| primary | UNEMPLOYMENT_CLAIMS | 2017 | 7 | 52 | 0.135 |
| primary | UNEMPLOYMENT_CLAIMS | 2018 | 6 | 52 | 0.115 |
| primary | UNEMPLOYMENT_CLAIMS | 2019 | 6 | 52 | 0.115 |
| primary | UNEMPLOYMENT_CLAIMS | 2020 | 13 | 53 | 0.245 |
| primary | UNEMPLOYMENT_CLAIMS | 2021 | 11 | 52 | 0.212 |
| primary | UNEMPLOYMENT_CLAIMS | 2022 | 8 | 52 | 0.154 |
| primary | UNEMPLOYMENT_CLAIMS | 2023 | 7 | 52 | 0.135 |
| primary | UNEMPLOYMENT_CLAIMS | 2024 | 8 | 52 | 0.154 |
| primary | UNEMPLOYMENT_CLAIMS | 2025 | 3 | 14 | 0.214 |
| primary | UNEMPLOYMENT_CLAIMS | 2026 | 7 | 7 | 1.000 |
| secondary | CPI | 2015 | 6 | 36 | 0.167 |
| secondary | CPI | 2016 | 0 | 36 | 0.000 |
| secondary | CPI | 2017 | 10 | 36 | 0.278 |
| secondary | CPI | 2018 | 5 | 36 | 0.139 |
| secondary | CPI | 2019 | 6 | 36 | 0.167 |
| secondary | CPI | 2020 | 9 | 36 | 0.250 |
| secondary | CPI | 2021 | 8 | 36 | 0.222 |
| secondary | CPI | 2022 | 10 | 36 | 0.278 |
| secondary | CPI | 2023 | 5 | 36 | 0.139 |
| secondary | CPI | 2024 | 6 | 36 | 0.167 |
| secondary | CPI | 2025 | 2 | 9 | 0.222 |
| secondary | CPI | 2026 | 4 | 4 | 1.000 |
| secondary | FOMC_STATEMENT | 2015 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2016 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2017 | 2 | 8 | 0.250 |
| secondary | FOMC_STATEMENT | 2018 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2019 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2020 | 3 | 9 | 0.333 |
| secondary | FOMC_STATEMENT | 2021 | 3 | 8 | 0.375 |
| secondary | FOMC_STATEMENT | 2022 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2023 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2024 | 0 | 8 | 0.000 |
| secondary | FOMC_STATEMENT | 2025 | 0 | 2 | 0.000 |
| secondary | FOMC_STATEMENT | 2026 | 1 | 1 | 1.000 |
| secondary | NFP | 2015 | 1 | 12 | 0.083 |
| secondary | NFP | 2016 | 0 | 12 | 0.000 |
| secondary | NFP | 2017 | 0 | 12 | 0.000 |
| secondary | NFP | 2018 | 0 | 12 | 0.000 |
| secondary | NFP | 2019 | 0 | 12 | 0.000 |
| secondary | NFP | 2020 | 0 | 12 | 0.000 |
| secondary | NFP | 2021 | 0 | 12 | 0.000 |
| secondary | NFP | 2022 | 0 | 12 | 0.000 |
| secondary | NFP | 2023 | 0 | 12 | 0.000 |
| secondary | NFP | 2024 | 0 | 12 | 0.000 |
| secondary | NFP | 2025 | 0 | 4 | 0.000 |
| secondary | NFP | 2026 | 2 | 2 | 1.000 |
| secondary | PPI | 2015 | 3 | 24 | 0.125 |
| secondary | PPI | 2016 | 0 | 24 | 0.000 |
| secondary | PPI | 2017 | 6 | 24 | 0.250 |
| secondary | PPI | 2018 | 4 | 24 | 0.167 |
| secondary | PPI | 2019 | 3 | 24 | 0.125 |
| secondary | PPI | 2020 | 7 | 24 | 0.292 |
| secondary | PPI | 2021 | 3 | 24 | 0.125 |
| secondary | PPI | 2022 | 6 | 24 | 0.250 |
| secondary | PPI | 2023 | 2 | 24 | 0.083 |
| secondary | PPI | 2024 | 2 | 24 | 0.083 |
| secondary | PPI | 2025 | 2 | 6 | 0.333 |
| secondary | PPI | 2026 | 2 | 2 | 1.000 |
| secondary | RETAIL_SALES | 2015 | 8 | 24 | 0.333 |
| secondary | RETAIL_SALES | 2016 | 10 | 24 | 0.417 |
| secondary | RETAIL_SALES | 2017 | 3 | 24 | 0.125 |
| secondary | RETAIL_SALES | 2018 | 7 | 24 | 0.292 |
| secondary | RETAIL_SALES | 2019 | 6 | 24 | 0.250 |
| secondary | RETAIL_SALES | 2020 | 2 | 24 | 0.083 |
| secondary | RETAIL_SALES | 2021 | 5 | 24 | 0.208 |
| secondary | RETAIL_SALES | 2022 | 5 | 24 | 0.208 |
| secondary | RETAIL_SALES | 2023 | 0 | 24 | 0.000 |
| secondary | RETAIL_SALES | 2024 | 0 | 24 | 0.000 |
| secondary | RETAIL_SALES | 2025 | 1 | 6 | 0.167 |
| secondary | RETAIL_SALES | 2026 | 2 | 2 | 1.000 |
| secondary | UNEMPLOYMENT_CLAIMS | 2015 | 13 | 52 | 0.250 |
| secondary | UNEMPLOYMENT_CLAIMS | 2016 | 10 | 52 | 0.192 |
| secondary | UNEMPLOYMENT_CLAIMS | 2017 | 7 | 52 | 0.135 |
| secondary | UNEMPLOYMENT_CLAIMS | 2018 | 6 | 52 | 0.115 |
| secondary | UNEMPLOYMENT_CLAIMS | 2019 | 6 | 52 | 0.115 |
| secondary | UNEMPLOYMENT_CLAIMS | 2020 | 13 | 53 | 0.245 |
| secondary | UNEMPLOYMENT_CLAIMS | 2021 | 11 | 52 | 0.212 |
| secondary | UNEMPLOYMENT_CLAIMS | 2022 | 8 | 52 | 0.154 |
| secondary | UNEMPLOYMENT_CLAIMS | 2023 | 7 | 52 | 0.135 |
| secondary | UNEMPLOYMENT_CLAIMS | 2024 | 8 | 52 | 0.154 |
| secondary | UNEMPLOYMENT_CLAIMS | 2025 | 3 | 14 | 0.214 |
| secondary | UNEMPLOYMENT_CLAIMS | 2026 | 7 | 7 | 1.000 |

## Internal consistency

The primary file was checked against its own datetime for `day_of_week`, `hour`, `day`, and `is_first_friday`: `{}`.

## Cross-file and native comparison

Primary-vs-secondary delta histogram in minutes: `{"0": 46349, "1": 2278}`.
Secondary-vs-native delta histogram in minutes: `{"-1": 3, "-1000": 1, "-1005": 1, "-1020": 648, "-1050": 9, "-1080": 1, "-1095": 2, "-1110": 110, "-1125": 2, "-1140": 2, "-1155": 29, "-1170": 6, "-1185": 16, "-120": 2, "-1200": 16, "-1230": 3, "-1245": 1, "-1260": 2, "-1290": 3, "-1305": 1, "-1395": 1, "-140": 1, "-145": 1, "-150": 3, "-165": 4, "-17": 1, "-172": 1, "-176": 1, "-179": 1, "-180": 304, "-181": 1, "-183": 1, "-190": 1, "-195": 1, "-2": 1, "-210": 1, "-225": 2, "-238": 1, "-240": 59, "-242": 1, "-255": 2, "-285": 3, "-30": 3, "-345": 4, "-355": 1, "-360": 1, "-368": 1, "-370": 1, "-376": 1, "-378": 2, "-380": 1, "-382": 1, "-389": 1, "-391": 5, "-398": 1, "-399": 1, "-402": 1, "-404": 1, "-413": 2, "-417": 2, "-420": 3, "-422": 1, "-442": 1, "-445": 1, "-447": 1, "-451": 2, "-453": 1, "-454": 1, "-477": 1, "-478": 1, "-5": 2, "-50": 1, "-506": 2, "-510": 2, "-513": 1, "-58": 1, "-60": 128, "-660": 2, "-7": 1, "-75": 1, "-750": 5, "-810": 25, "-88": 1, "-930": 3, "-960": 135, "-985": 1, "-990": 4, "0": 578, "1": 4, "10": 1, "1049": 7, "135": 1, "2": 5, "210": 1, "510": 1, "6": 1, "60": 1, "66": 1, "989": 2}`.
The native export column named `broker_time` is treated as true UTC epoch; NFP 2023-02-03 (`1675431000`) resolves to 13:30Z.

## Coverage

Monthly table range: 2015-01 through 2026-09. Zero-row months are flagged in `monthly_coverage.csv`.

## Detector chronology

- The seed was copied on 2026-04-21. An anchor assertion or native-event comparison run that day would have rejected the displaced 08:30 ET classes immediately.
- The private lab recorded displaced NFP/CPI rows on 2026-07-11. The anchor and native delta reports would have made that observation durable and visible to the factory without altering the gate.
- The monthly coverage detector would have flagged the 2025-05 through 2026-06 hole on the first diagnostic run after the copy.

## Artifacts

- `summary.json`: machine-readable aggregate and input hashes.
- `anchor_detail.csv` / `anchor_summary.csv`: row-level and class/year anchor checks.
- `primary_derived_mismatches.csv`: derived-column discrepancies.
- `cross_file_comparison.csv`: same currency/event nearest-date comparison.
- `native_comparison.csv`: maintained FF-to-native name-map comparison for USD/EUR/GBP/JPY.
- `monthly_coverage.csv`: monthly row counts and zero-month flags.

No calendar bytes, gate results, verdict rows, T_Live files, terminals, or scheduled tasks were changed.
