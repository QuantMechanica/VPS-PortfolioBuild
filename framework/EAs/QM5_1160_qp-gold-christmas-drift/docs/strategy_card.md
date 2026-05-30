---
ea_id: QM5_1160
slug: qp-gold-christmas-drift
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia Gold Christmas Drift - XAUUSD.DWX

## Quelle

- Primary source: Pauchlyova, M., Quantpedia, Thanksgiving and Christmas Trading Strategies.
- Underlying pre-holiday anomaly literature: Frieder, L. and Subrahmanyam, A. (2004), Nonsecular Regularities in Returns and Volume, Financial Analysts Journal 60(4), pp. 29-34, DOI 10.2469/faj.v60.n4.2640.

## Mechanik

### Entry

Each December:
1. Define Christmas Day as December 25.
2. Determine `D-2` as the second U.S. trading day before Christmas.
3. Open LONG XAUUSD.DWX at the close of `D-2`.

### Exit

- Close LONG XAUUSD.DWX at the close of `D+5`, the fifth U.S. trading day after Christmas.
- If the broker has no bar on the scheduled exit day, close at the next available D1 close.

### Stop Loss

- Hard stop at 2.0x D1 ATR(20) from entry.
- Time stop at `D+5` close is mandatory.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter

- Use U.S. holiday/trading calendar for the D offsets to match the GLD source study.
- Require 60 valid XAUUSD.DWX D1 bars before entry.
- Optional P3 variant: global gold-holiday drift basket from Quantpedia's related cultural-calendar article, but default card uses only the Christmas D-2 to D+5 rule.
