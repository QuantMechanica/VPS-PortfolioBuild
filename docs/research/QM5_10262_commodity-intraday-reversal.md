---
ea_id: QM5_10262
slug: commodity-intraday-reversal
g0_status: RESEARCH_DRAFT_READY
r1_track_record: PRACTITIONER_PROVEN
r2_mechanical: HIGH
r3_data_available: YES
r4_ml_forbidden: YES
expected_trades_per_year_per_symbol: 50
---

# Thesis: Commodity Intraday News-Shock Reversal

This strategy exploits the tendency of high-liquidity commodities (Gold, Crude Oil) to "overreact" to intraday news shocks and institutional liquidity sweeps, followed by a mean-reversion move back to the session's value area. 

The strategy focuses on the U-shaped volatility profile of the commodity markets, specifically targeting the period after the COMEX open (Gold) and EIA reports (Oil), where "stop-hunting" often precedes a reversal.

# Market Universe

- **Primary Assets:** `XAUUSD.DWX` (Gold), `XTIUSD.DWX` (Crude Oil - WTI).
- **Secondary Assets:** `XAGUSD.DWX` (Silver).

# Timeframe

- **Execution:** M15 for precise entry after a volatility spike.
- **Session Focus:** London AM Fix and NY Morning Session.

# Entry Mechanics

1. **Volatility Catalyst:**
    - Identify a "News Shock" or "Liquidity Sweep": An M15 bar with a range > 2.5 × ATR(14) that penetrates a recent high/low.
    - **Time Window (Gold):** 13:00 - 15:30 UTC (NY Morning / COMEX Open).
    - **Time Window (Oil):** Wednesday 15:30 - 17:00 UTC (EIA Inventory Release).

2. **Trigger (The Reversal):**
    - Wait for the "Exhaustion Bar": An M15 bar that closes back inside the previous bar's range or shows a significant wick (Pin Bar) in the direction of the reversal.
    - **Long Entry:** After a sharp move down, if the current M15 close > Prior M15 Close AND RSI(7) < 30 (oversold bounce).
    - **Short Entry:** After a sharp move up, if the current M15 close < Prior M15 Close AND RSI(7) > 70 (overbought fade).

# Exit Mechanics

1. **Target:** Exit at the VWAP (Volume Weighted Average Price) of the current session or a 1:1.5 Risk/Reward ratio.
2. **Hard Stop:** 1.5 × ATR(14) from entry price.
3. **Time Stop:** Exit at the end of the NY session (20:00 UTC) if target not hit.

# Risk Controls

- **Fixed Risk:** 1000 currency units per trade.
- **Max Trades:** 1 trade per symbol per day (prevent over-trading news).
- **Friday Flatten:** No trades after 18:00 UTC Friday.

# Falsification Conditions

- Strategy is invalidated if the "news shock" bar is followed by 3 consecutive M15 bars closing in the same direction (indicating a strong breakout/trend rather than a reversal).
- Failure to mean-revert to the session open price within 4 hours.

# Q08/Q11 Risks

- **Q11 (News Replay):** This strategy is *designed* for news, but it risks "toxic" execution if the news event is a structural shift (e.g., OPEC production cut, Geopolitical escalation). The P8 News Impact gate must be used to filter for "standard" releases vs "black swan" events.
- **Slippage:** High sensitivity to slippage during the news release. P5b stress tests must use calibrated latency.

# Implementation Notes

- Requires an MQL5 news calendar or a fixed schedule for EIA reports.
- VWAP calculation must reset at the start of each session (London/NY).
