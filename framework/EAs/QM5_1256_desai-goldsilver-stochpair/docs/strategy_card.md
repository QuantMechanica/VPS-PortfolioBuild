---
ea_id: QM5_1256
slug: desai-goldsilver-stochpair
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/correlation-filter]]"
  - "[[indicators/stochastic-oscillator]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "SSRN Desai-Trivedi-Joshi 2013 R1-R4 PASS: named authors+SSRN URL, deterministic stoch-on-ratio + corr>0.90 filter, XAUUSD.DWX+XAGUSD.DWX native, no ML/adaptive"
---

# Desai-Trivedi-Joshi Gold/Silver Stochastic Pair

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- Paper: Jay Desai, Arti Trivedi, Nisarg A. Joshi, "The Case of Gold and Silver: A New Algorithm for Pairs Trading", SSRN, posted 2013-04-10.
- URL: ssrn.com/abstract=2152324
- Location: SSRN abstract describes a gold/silver market-neutral pairs rule using correlation greater than 0.90 and stochastic entry/exit points.

## Mechanik

### Entry
- Trade only if rolling 60-day correlation between `XAUUSD.DWX` and `XAGUSD.DWX` is greater than 0.90.
- Compute the gold/silver ratio `R = XAUUSD close / XAGUSD close` on H1 bars.
- Compute Stochastic %K/%D on `R` using default test parameters K=14, D=3, slowing=3.
- If `%K` crosses below 20 and then back above 20, go long gold / short silver with beta-neutral notional sizing.
- If `%K` crosses above 80 and then back below 80, go short gold / long silver with beta-neutral notional sizing.

### Exit
- Close the pair when Stochastic %K crosses the 50 midline in the direction of mean reversion.
- Time stop: close after 10 trading days if the midline exit has not occurred.

### Stop Loss
- Pair stop: close both legs if ratio z-score moves 2.5 standard deviations further against entry.
- Emergency stop: close both legs if combined pair loss reaches 1.5R.

### Position Sizing
- P2 baseline: fixed combined pair risk USD 1,000.
- Split notional by rolling 60-day volatility so that gold and silver legs contribute similar dollar volatility.

### Zusaetzliche Filter
- Skip if either leg spread exceeds 2x its 20-session median spread.
- Skip if one leg is unavailable or has missing bars in the prior 60 trading days.
- Allow one active pair position per magic number.

## Concepts
- [[concepts/pairs-trading]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Named authors and SSRN URL: Jay Desai, Arti Trivedi, Nisarg A. Joshi, ssrn.com/abstract=2152324. |
| R2 Mechanical | PASS | Correlation threshold plus stochastic ratio entry/exit is deterministic; side-parameters are V5 defaults for P2/P3. |
| R3 Data Available | PASS | `XAUUSD.DWX` and `XAGUSD.DWX` provide direct precious-metal CFD proxies. |
| R4 ML Forbidden | PASS | No ML, neural net, online learning, martingale, or unbounded grid. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1129_gatev-distance-pairs]] - equity distance pairs; this card is a precious-metals stochastic-ratio pair.
- [[strategies/QM5_1245_urquhart-gold-intraday-ma]] - gold technical rule, but single-leg trend rather than pair mean reversion.

## Lessons Learned
- TBD
