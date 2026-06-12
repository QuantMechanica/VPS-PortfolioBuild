---
ea_id: QM5_12542
slug: katsanos-gold-multidiv-d1
type: strategy
source_id: katsanos-intermarket-2008-ch11
sources:
  - "[[sources/katsanos-intermarket-trading-strategies]]"
concepts:
  - "[[concepts/intermarket-divergence]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/cross-asset-filter]]"
indicators:
  - "[[indicators/intermarket-regression-divergence]]"
  - "[[indicators/intermarket-momentum-oscillator]]"
  - "[[indicators/stochastic]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Katsanos, M. (2008), Intermarket Trading Strategies, Wiley (OWNER-purchased copy; full-text mined 2026-06-12). Ch.11 compares 14 systems 1995-2007; regression-divergence variants were the top performers. CAVEAT logged: book results are IN-SAMPLE optimized (author admits, p.179) — treat all dollar figures as null; the pipeline judges."
r2_mechanical: PASS
r2_reasoning: "Closed-form: regression divergence Y_pred = r*sigmaY/sigmaX*X on 15-day yields (book eq. 9.9/9.10), IMO 200-day stochastic-style normalization with 3-day MA, stochastic(5,3) confirmation, ROC(10) intermarket direction filter, 50-bar time exit. All deterministic fixed parameters."
r3_data_available: PASS
r3_reasoning: "Base XAUUSD.DWX; partners XAGUSD.DWX (c=+1) and DXY proxy computed from 5 .DWX USD pairs (log-weighted basket, renormalized ICE weights, SEK omitted at 4.2pct). Multi-symbol data access in tester proven by basket EA QM5_10717 and pair EA QM5_1257."
r4_ml_forbidden: PASS
r4_reasoning: "Linear regression with FIXED lookback is closed-form arithmetic, not ML/fitting-in-the-loop; no adaptive parameters, no grid/martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 6
expected_pf: 1.5
expected_dd_pct: 10
last_updated: 2026-06-12
g0_approval_reasoning: "G0 2026-06-12 Claude: first card from the OWNER-purchased Katsanos book. Multiple-divergence gold system (book's best family) re-based onto OUR universe: XAG + DXY-proxy replace the unavailable XAU-miners index. Honest flags: in-sample book results; VERY low frequency (~6/yr at default thresholds) -> DL-070 swing-track Q08 floors are the existential risk; ATR disaster stop ADDED (book used none). R1-R4 PASS."
---

# Katsanos Gold Multiple Intermarket Divergence (D1, XAG + DXY-proxy)

## Source
- Katsanos, M. (2008), "Intermarket Trading Strategies", John Wiley & Sons, Ch. 9
  (indicator formulas 9.7-9.11, IMO) and Ch. 11 (fourteen-system gold comparison,
  pp. 175-188). OWNER-purchased copy; full text cached at
  `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.txt`.
- Precedent for the divergence-signal mechanic: Ruggiero, "Cybernetic Trading
  Strategies" (Wiley 1997), referenced by Katsanos pp. 126-127.

## Fidelity / adaptation note
Book partners are XAU (Philadelphia miners index), SLV, DXY. We hold no miners index;
this card uses **XAGUSD.DWX (positive partner)** and a **DXY log-basket proxy**
(weights renormalized w/o SEK: EUR 0.601, JPY 0.142, GBP 0.124, CAD 0.095, CHF 0.038;
proxy = -0.601*ln(EURUSD) + 0.142*ln(USDJPY) - 0.124*ln(GBPUSD) + 0.095*ln(USDCAD)
+ 0.038*ln(USDCHF), negative partner c=-1). The book's optimized IMO extremes
(60-90/5-25 per system) are REJECTED as curve-fit; defaults 80/20 per the book's own
general spec (Section 9.6) are used unoptimized.

## Market Universe
Target symbols: XAUUSD.DWX (base; partners XAGUSD.DWX + DXY proxy from EURUSD.DWX,
USDJPY.DWX, GBPUSD.DWX, USDCAD.DWX, USDCHF.DWX read via multi-symbol data access).

## Timeframe
D1 (closed-bar signals).

## Signal construction
For each partner P in {XAG (c=+1), DXYproxy (c=-1)}:
1. 15-day percentage yields of base (Y) and partner (X).
2. Regression divergence (book 9.9/9.10): div_P = c * ( r*sigma(Y)/sigma(X)*X ) - Y,
   with r, sigma over a FIXED 300-day window.
3. IMO_P = 100 * MA3(div_P - LL200(div_P)) / MA3(HH200(div_P) - LL200(div_P)).
Combined oscillator: IMO = (IMO_XAG + IMO_DXY) / 2 (equal weight — deterministic
simplification of the book's part-correlation weighting; noted as design choice).

## Entry
LONG (max positive divergence reversal; SHORT = mirror with 20-level and opposite
filters):
1. IMO(3-day EMA) was >= 80 and crosses BELOW 80 (reversal from extreme), signal
   valid 3 bars (book's alert extension).
2. Confirmation: Stochastic(5) crosses above its 3-day MA.
3. Direction filter: ROC(10) of XAG > 0 AND ROC(10) of DXYproxy < 0.
4. Combined divergence > 0.
One position per symbol per magic (HR14); framework news blackout.

## Exit
- Opposite IMO extreme reversal (IMO <= 20 turning up for longs), OR
- Time exit after 50 D1 bars (book rule), whichever first.

## Stop Loss
- 2.5 x ATR(14) disaster stop (ADDED — the book tested without stops and says
  "in practice, a stop-loss condition should always be used", p.180).

## Risk
RISK_FIXED backtest / RISK_PERCENT live; 1.0% per trade.

## Falsification
- Primary: must beat buy-and-hold-gold AND the existing simple gold-MR card families
  on PF at comparable DD over 2018-2026.
- Frequency falsification: if trades/yr < 3 at default 80/20 thresholds, the system
  is untestable under Q08 floors and the family is closed WITHOUT loosening
  thresholds (no fitting to pass gates).

## Q08 / Q11 Risks
- Q08: ~6 trades/yr is the EXISTENTIAL risk (DL-070 floor 40 over the window is not
  reachable single-symbol; survival path = portfolio track / Q09_PORTFOLIO like
  QM5_10692). Stated honestly up front.
- Q11: gold-complex bucket; check correlation vs existing XAU survivors (10069 etc.).

## FTMO Compliance Block
- DD <=5% daily / <=10% total; 1% risk/trade; low frequency caps exposure naturally.
- News blackout MANDATORY. No martingale/grid/averaging; no ML (fixed-window OLS is
  closed-form arithmetic).
