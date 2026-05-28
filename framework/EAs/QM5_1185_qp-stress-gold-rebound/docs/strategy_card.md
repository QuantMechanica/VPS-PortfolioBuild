---
ea_id: QM5_1185
slug: qp-stress-gold-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "qp-stress-gold-rebound Dujava 2024 Quantpedia + De Bondt-Thaler 1985 JoF lineage SPX+oil-stress one-day XAUUSD rebound R1-R4 PASS fixed thresholds no ML"
---

# Quantpedia Cross-Asset Stress Gold Rebound

## Quelle
- Source: Quantpedia encyclopedia, "Short-Term Correlated Stress Reversal Trading"
- Named author: Cyril Dujava, Quantpedia.
- Year-tagged citation: Dujava, C. (2024). "Short-Term Correlated Stress Reversal Trading." Quantpedia. Cross-asset stress-reversal lineage: De Bondt, W. & Thaler, R. (1985). "Does the Stock Market Overreact?" Journal of Finance 40(3).
- Location: "Simple Trading Strategy and Performance Evaluation" and cross-asset stress scenarios.

## Mechanik

### Entry
On each completed D1 bar:
1. Compute same-day close-to-close returns for `SP500.DWX` and the confirmed oil proxy (`XTIUSD.DWX` preferred; `XBRUSD.DWX` fallback).
2. If both `SP500.DWX` return and oil-proxy return are below `0.0%`, mark a correlated risky-asset stress day.
3. At the close of that stress day, open LONG `XAUUSD.DWX`.
4. Hold only one one-day gold rebound position per magic number.

### Exit
- Close `XAUUSD.DWX` at the next D1 close.
- Safety exit: close after 2 trading days if the next close is unavailable.

### Stop Loss
- Initial stop: 1.5x ATR(20) on XAUUSD.DWX D1.
- No trailing stop; one-day holding period is the primary exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Requires confirmed oil CFD symbol and SP500.DWX signal bars.
- This card trades the gold response leg; earlier Quantpedia stress card QM5_1157 focused on next-day equity rebound.
- Optional P3 variants: require both signal assets below `-0.5%`; replace oil with gold/equity stress for alternate target legs only if QB approves a split card.

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 using SP500.DWX as a required signal leg, T6 deploy requires a parallel-validation using NDX.DWX or WS30.DWX as the equity-stress proxy before AutoTrading enable.
