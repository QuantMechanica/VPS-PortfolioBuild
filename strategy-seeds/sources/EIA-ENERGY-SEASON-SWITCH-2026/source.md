# EIA-ENERGY-SEASON-SWITCH-2026

## Source Lineage

- U.S. Energy Information Administration, Energy Explained: Gasoline price fluctuations, https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php
- U.S. Energy Information Administration, Today in Energy: seasonal natural gas consumption and storage withdrawal context, https://www.eia.gov/todayinenergy/detail.php?id=22892

## Extraction Notes

The EIA gasoline page describes recurring gasoline price seasonality, with spring and late-summer effects linked to driving demand, refinery maintenance, and gasoline specification changes. The EIA natural gas source describes recurring winter demand and storage withdrawal behavior, with natural gas consumption responding strongly to weather-driven heating demand.

This card converts those public structural observations into a deterministic market-neutral Darwinex basket:

- Summer refined-products/oil window: long `XTIUSD.DWX`, short `XNGUSD.DWX`.
- Winter gas-heating window: short `XTIUSD.DWX`, long `XNGUSD.DWX`.
- Both legs must confirm the intended seasonal direction versus an 84-day D1 SMA.

No runtime EIA data, news feed, machine learning model, optimization data, or external CSV is used by the EA. The source only justifies the fixed structural calendar windows.

## Duplicate Check

Existing V5 builds already cover XTI/XNG ratio reversion, XTI/XNG breakout, XTI/XNG cross-sectional momentum, XNG RSI, XNG month ORB, WTI month ORB, and several single-instrument WTI seasonality or product-spread ideas. This source packet is for a different paired seasonal allocation rule with explicit oil-versus-gas direction by season.
