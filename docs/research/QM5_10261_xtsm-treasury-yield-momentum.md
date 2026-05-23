---
ea_id: QM5_10261
slug: xtsm-treasury-yield-momentum
g0_status: RESEARCH_DRAFT_READY
r1_track_record: ACADEMIC_PROVEN
r2_mechanical: HIGH
r3_data_available: YES
r4_ml_forbidden: YES
expected_trades_per_year_per_symbol: 24
---

# Thesis: Cross-Asset Treasury Yield Curve Momentum (XTSM)

This strategy mechanizes the "Hegemon" effect of U.S. Treasury yields on global risk assets. Based on Pitkäjärvi, Suominen, and Vaittinen (2020) and Sihvonen (2024), it uses momentum in the U.S. Treasury term structure as a lead-lag predictor for equity indices and JPY-based carry unwinds.

The core logic is that bond market returns (falling yields) act as a positive predictor for future equity returns due to the discount rate channel and risk-premium compression. Conversely, a steepening yield curve in a hawkish regime signals a future "risk-off" environment.

# Market Universe

- **Signal Proxies:** `US10Y`, `US30Y` (10-Year and 30-Year Treasury Bond Prices/Yields).
- **Traded Assets:** 
    - Indices: `NDX.DWX`, `WS30.DWX`, `DAX.DWX`.
    - Forex: `USDJPY.DWX`, `EURJPY.DWX` (Risk-off/Carry proxies).

# Timeframe

- **Signal Generation:** D1 (Daily) for regime/momentum calculation.
- **Execution:** H4 for entry timing to reduce noise while capturing the multi-day drift.

# Entry Mechanics

1. **Regime Filter (Level):** 
    - Calculate 20-day Time Series Momentum (TSM) on `US10Y`.
    - If `Close(US10Y) > SMA(20, US10Y)` (Falling yields), Regime = **BULLISH_RISK**.
    - If `Close(US10Y) < SMA(20, US10Y)` (Rising yields), Regime = **BEARISH_RISK**.

2. **Slope Filter (Curve):**
    - Calculate the 10Y-30Y spread (Slope).
    - If Slope is flattening (10Y outperforming 30Y), bias is toward **Defensive/Mean Reversion**.

3. **Trigger:**
    - **Long Equities:** Enter Long at H4 Open if Regime = **BULLISH_RISK** AND `Index_Close > EMA(50, Index_Close)`.
    - **Short Equities:** Enter Short at H4 Open if Regime = **BEARISH_RISK** AND `Index_Close < EMA(50, Index_Close)`.
    - **Long JPY (Risk-Off):** Enter Long JPY pairs (Short USDJPY) if Regime = **BEARISH_RISK** AND Slope is sharply flattening.

# Exit Mechanics

1. **ATR Trailing Stop:** 3.5 × ATR(14) on H4 timeframe.
2. **Signal Flip:** Exit immediately if the `US10Y` TSM flips (Close crosses SMA).
3. **Time Stop:** Max hold 10 trading days (2 weeks) to align with the typical bond-equity lead-lag duration documented in literature.

# Risk Controls

- **Fixed Risk:** 1000 currency units per trade (Standard V5 rule).
- **Weekend Flatten:** Force close all positions Friday 21:00 Broker Time.
- **News Blackout:** Pause entries 60m before/after FOMC, NFP, and CPI releases.

# Falsification Conditions

- Strategy is invalidated if the correlation between `US10Y` returns and `NDX` returns turns positive (i.e., both falling together in a liquidity crisis/deflationary shock) for more than 20 consecutive days.
- Zero alpha in the "Even Week" FOMC windows (where `QM5_10260` should dominate).

# Q08/Q11 Risks

- **Q08 (Crisis Slicing):** During the 2008 and 2020 crashes, the bond-equity relationship inverted or gapped. The `US10Y` TSM filter must be robust enough to flip to "Bearish" quickly.
- **Q11 (News Replay):** High sensitivity to "surprising" CPI/NFP prints that reprice the whole curve. The news blackout is critical to avoid "toxic" fills during the first 5 minutes of a data release.

# Implementation Notes

- Requires `SymbolInfoDouble` or `iCustom` to pull Treasury proxy data from the same broker (DarwinexZero provides `US10Y`, `US30Y`).
- Logic must handle potential data gaps in Treasury symbols if they trade on different hours than FX/Indices.
