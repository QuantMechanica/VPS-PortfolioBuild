---
ea_id: QM5_10263
slug: ecb-policy-cycle-drift
g0_status: RESEARCH_DRAFT_READY
r1_track_record: ACADEMIC_PROVEN
r2_mechanical: HIGH
r3_data_available: YES
r4_ml_forbidden: YES
expected_trades_per_year_per_symbol: 8
---

# Thesis: ECB Monetary Policy Cycle Information Drift

This strategy exploits the "information channel" of European Central Bank (ECB) monetary policy. Research (Kapp & Kristiansen, 2021) suggests that ECB rate decisions, when accompanied by a press conference and forecast revisions, signal the central bank's private information about Eurozone economic health. 

Unlike the Fed's global risk-appetite influence, the ECB's impact is regional. Equity markets (`DAX.DWX`) often drift in the direction of the "information surprise" (e.g., a hawkish move signaling growth) over the 48 hours following the 14:45 CET press conference.

# Market Universe

- **Signal:** ECB Monetary Policy Decision + Press Conference Timing.
- **Traded Assets:** 
    - Indices: `DAX.DWX` (Primary), `CAC40.DWX`.
    - Forex: `EURUSD.DWX`, `EURGBP.DWX`.

# Timeframe

- **Execution:** M15 for precise entry after the 14:45 CET press conference volatility peak.
- **Hold Duration:** 24–48 hours (Post-event drift window).

# Entry Mechanics

1. **Event Gate:** 
    - Only execute on ECB Decision Days (8 times per year).
    - **Wait Window:** Wait for the 14:45 CET (13:45 UTC) press conference to conclude.

2. **Information Surprise Detector:**
    - Use a 15-minute price momentum filter after the press conference starts.
    - **Bullish Drift:** If `DAX` Close(15:15 CET) > DAX Close(14:45 CET) AND `EURUSD` has not spiked > 1% (avoiding pure currency-shock reversals).
    - **Bearish Drift:** If `DAX` Close(15:15 CET) < DAX Close(14:45 CET) AND `EURUSD` has not crashed > 1%.

3. **Trigger:**
    - Enter at 15:30 CET (14:30 UTC) in the direction of the 30-minute post-presser momentum.

# Exit Mechanics

1. **Time Stop:** Forced exit 48 hours after entry (End of T+2 trading day).
2. **Volatility Stop:** 2.5 × ATR(14) from entry price (H1 timeframe).
3. **Target:** 2.0 × Risk (Fixed RR).

# Risk Controls

- **Fixed Risk:** 1000 currency units per trade.
- **Symmetric Long/Short:** Enabled.
- **News Blackout:** This strategy *is* the news; however, standard P8 News Impact rules apply for unrelated releases (e.g., U.S. CPI) during the hold period.

# Falsification Conditions

- Strategy is invalidated if the `DAX` return during the 48-hour window is negatively correlated with the post-presser momentum for 3 consecutive ECB meetings.
- Failure to outperform a simple "Even Week" FOMC long-bias on DAX.

# Q08/Q11 Risks

- **Q11 (News Replay):** High sensitivity to the *content* of the press conference (forward guidance). The strategy relies on the "drift" being a rational adjustment to new information, which may fail during extreme policy reversals (e.g., emergency cuts).
- **Liquidity:** Wide spreads during the 14:45 CET window require careful execution.

# Implementation Notes

- Requires a high-quality economic calendar to trigger the "ECB Day" logic.
- Broker time translation to CET/UTC is critical.
