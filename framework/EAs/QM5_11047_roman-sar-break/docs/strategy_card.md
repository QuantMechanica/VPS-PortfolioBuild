---
ea_id: QM5_11047
slug: roman-sar-break
type: strategy
source_id: 9441393d-5ffc-5b43-87be-bd532110f204
source_citation: "Roman Zamozhnyy, Trademinator 3: Rise of the Trading Machines, MQL5 Articles, 2012-03-05, https://www.mql5.com/en/articles/350; attachment strategysar.mqh"
sources:
  - "[[sources/mql5-automated-trading-championship]]"
concepts:
  - "[[concepts/parabolic-sar-breakout]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/parabolic-sar]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDCHF.DWX, USDJPY.DWX]
period: H1
expected_trade_frequency: "Fixed Parabolic SAR/open-price crossover module from Roman Zamozhnyy's ATC-linked Trademinator article; conservative estimate 35-100 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited MQL5 article; R2 fixed SAR/open cross entry plus opposite-cross/SL/TP/time exit with plausible 35-100 trades/year/symbol; R3 FX DWX H1 testable; R4 fixed-parameter no-ML one-position."
---

# Roman Fixed SAR Breakout

## Quelle
- Source: [[sources/mql5-automated-trading-championship]]
- URL: https://www.mql5.com/en/articles/350
- Author / institution: Roman Zamozhnyy, MQL5 Articles; linked from Roman Zamozhnyy's ATC Champions League interview comments.
- Date: 2012-03-05
- Location: `strategysar.mqh` attachment, `NeedOpenSAR` / `NeedCloseSAR` code blocks in "Trademinator 3: Rise of the Trading Machines".

## Mechanik

### Entry
- Use fixed Parabolic SAR parameters on H1; do not use the article's genetic optimizer, fitness function, or online strategy selection.
- Short:
  - completed bar SAR crosses from below the open price to above the open price: `SAR[0] < Open[0]` and `SAR[1] > Open[1]`;
  - open sell at next bar open.
- Long:
  - completed bar SAR crosses from above the open price to below the open price: `SAR[0] > Open[0]` and `SAR[1] < Open[1]`;
  - open buy at next bar open.
- One active position per symbol/magic.

### Exit
- Close on either SAR/open cross direction change:
  - `SAR[0] > Open[0]` and `SAR[1] < Open[1]`, or
  - `SAR[0] < Open[0]` and `SAR[1] > Open[1]`.
- Close by protective SL or TP.
- Time exit after `max_bars_in_trade` if neither signal nor SL/TP fires.

### Stop Loss
- SL = 1.5 * ATR(14, H1).
- TP = 1.0 * SL for P2 baseline.
- Optional break-even at 0.75R.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.
- Exclude optimized deposit-share sizing and any Championship-style fitness/money-management layer.

### Zusaetzliche Filter
- Spread <= symbol median spread * 2.
- Skip if ATR(14, H1) is below rolling 20th percentile.
- Optional session filter: London+NY only.

## Concepts
- [[concepts/parabolic-sar-breakout]] - signal is a Parabolic SAR crossover through bar open price.
- [[concepts/trend-following]] - SAR direction change attempts to enter the new directional leg.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 article URL and source attachment with named author Roman Zamozhnyy. |
| R2 Mechanical | PASS | Source attachment provides explicit SAR/open cross entry and close conditions. |
| R3 DWX-testbar | PASS | Uses OHLC and standard Parabolic SAR on FX pairs available in DWX. |
| R4 No ML | PASS | Draft fixes parameters and removes GA/self-training/deposit-share optimization. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDCHF.DWX, USDJPY.DWX.

## Author Claims
- The source attachment gives explicit `NeedOpenSAR` and `NeedCloseSAR` conditions.
- The source tests the framework on H1 with EURUSD, GBPUSD, USDCHF, and USDJPY.
- The source's adaptive GA framework is not used in this V5 card.

## Parameters To Test
- SAR step: 0.01, 0.02, 0.03.
- SAR maximum: 0.1, 0.2, 0.3.
- SL ATR multiple: 1.0, 1.5, 2.0.
- TP/SL ratio: 0.75, 1.0, 1.25.
- Max bars in trade: 12, 24, 48.

## Initial Risk Profile
SAR reversal systems can whipsaw in range-bound markets. Risk is bounded by fixed SL/TP, optional time exit, fixed risk, one active position, and no adaptive optimizer.

## Pipeline-Verlauf
- G0: PENDING.
