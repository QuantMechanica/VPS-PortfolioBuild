# Friday Orchestration Smoke — Gemini

Date: 2026-05-22
Task ID: `1a043144-85be-4d8a-b366-20ea5aa437a3`

## T7 — Cross-sectional Volatility-Premium Harvesting

- **Structural cause:** Investors consistently overpay for insurance against extreme moves in certain currencies (e.g., safe havens like JPY) while underestimating the stability of high-yielders. This creates a cross-sectional "volatility risk premium" (VRP) that can be harvested mechanically.
- **Price signature:** Rank the 8-currency basket by the ratio of trailing 30-day realized volatility to the rolling 12-month average volatility. Long the currencies with the highest relative vol-compression (most "stable" vs history), short the currencies with the highest relative vol-expansion (most "distressed" vs history). D1/Weekly rebalance.
- **Persistence:** Behavioral bias in risk pricing and institutional mandate constraints (hedging requirements) keep the premium persistent.
- **Falsification:** If the VRP-weighted basket does not outperform an equal-weighted basket of the same currencies over a 24-month rolling window, the risk premium is either too thin or arbitraged away.
- **Q08 / Q11 risk:** High risk during broad volatility spikes (March 2020) where all correlations go to 1. Mitigation: stop-trading filter on VIX-equivalent spikes.
- **FTMO fit:** Strong. Market-neutral-ish, swing horizon, news-safe.
