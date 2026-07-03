# EIA-DPR-XTI-MOM-2026

## Source

- U.S. Energy Information Administration, Drilling Productivity Report:
  https://www.eia.gov/petroleum/drilling/
- U.S. Energy Information Administration, Drilling Productivity Report FAQ:
  https://www.eia.gov/petroleum/drilling/faqs.php

## Use In QM5_12996

The source is used as structural lineage for a monthly U.S. shale/tight-oil
production information window. The EA does not read EIA pages, CSV files, APIs,
release schedules, analyst forecasts, rig-count feeds, or production data at
runtime. It tests whether the market's own `XTIUSD.DWX` D1 reaction inside a
fixed mid-month DPR proxy window continues after ATR, Donchian, and SMA
confirmation.

## Reputable-Source Notes

- EIA is the official U.S. energy statistics agency.
- The DPR FAQ says the report is monthly and describes the rig count,
  drilling-efficiency, new-well-yield, and legacy-production variables.
- EIA notes that after June 11, 2024, DPR data moved into STEO tables. The card
  therefore treats this as a historical/mid-month information-window proxy for
  backtest validation, not as a live external-data parser.
