---
ea_id: QM5_12707
slug: commodity-tsmom-12m
type: strategy
source_id: 516fdfd0-0cc3-5474-8012-91879fbf79ed
sources:
  - "[[sources/urquhart-zhang-commodity-futures-momentum-reversal]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/past-return-signal]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named academic authors Zhang & Urquhart, peer-reviewed (Review of Behavioral Finance 2021), SSRN URL 3271841 verifiable — lineage intact."
r2_mechanical: PASS
r2_reasoning: "Signal = sign of (Close[0]-Close[252])/Close[252]; monthly rebalance with deterministic long/short/hold cases and fixed ATR(20) hard stop — fully mechanical."
r3_data_available: PASS
r3_reasoning: "XAUUSD, XAGUSD, XTIUSD, and XNGUSD are all available as DWX symbols with D1 history from 2017 covering 8+ complete 12-month windows."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; signal and ATR stop are price-history-derived and deterministic; 1 position per magic per symbol; no martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 12
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single source_id with SSRN/published attribution; R2 PASS deterministic 12M price-return sign with K=1 monthly rebalance, about 12 trade windows/yr/symbol after light gates; R3 PASS price-only port to DWX XAU/XAG/XTI/XNG; R4 PASS deterministic no ML, 1-pos-per-magic."
expected_pf: 1.25
expected_dd_pct: 22.0
---

# Commodity Time-Series Momentum 12-Month (TS-MOM J=12, K=1)

## Quelle
- Source: [[sources/urquhart-zhang-commodity-futures-momentum-reversal]]
- URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3271841
- Authors: Hanxiong Zhang, Andrew Urquhart
- Title: "Do momentum and reversal strategies work in commodity futures? A comprehensive study"
- Journal: *Review of Behavioral Finance*, 2021
- Location: Core methodology — time-series momentum, J=12 months formation, K=1 month holding (Table results showing TS-MOM J=12 K=1 as strongest time-series signal in energy and metals sectors)

## Mechanik

This is a single-symbol EA applied independently to each target symbol:
XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, and XNGUSD.DWX. Each symbol runs its own magic
number. Monthly rebalancing on D1.

### Entry

On the **first D1 bar of each calendar month** (when a new month opens):

1. Compute the 12-month past return: `R12 = (Close[0] - Close[252]) / Close[252]`
   where Close[252] = D1 close approximately 252 trading days (12 months) ago.
2. If `R12 > 0` and currently flat → open **LONG** at open of next D1 bar.
3. If `R12 < 0` and currently flat → open **SHORT** at open of next D1 bar.
4. If `R12 > 0` and currently SHORT → close SHORT, then open LONG.
5. If `R12 < 0` and currently LONG → close LONG, then open SHORT.
6. If `R12 > 0` and currently LONG → hold (no action).
7. If `R12 < 0` and currently SHORT → hold (no action).

This EA is **always in the market** (long or short), re-evaluated once per month.

### Exit

- Monthly rebalancing: at the first bar of each new month, exit before re-evaluating
  signal (cases 4, 5 above — position is always re-opened after signal check).
- Hard stop: see Stop Loss section.
- No intra-month profit target.

### Stop Loss

- Hard stop at `2.0 × ATR(D1, 20)` from entry price.
- Stop is set at entry and remains fixed for the 1-month holding window.
- If stopped out mid-month, EA re-enters at the next monthly rebalance date if signal
  still agrees.

### Position Sizing

- Backtest baseline: `RISK_FIXED = 1000 USD` per trade.
- Live: `RISK_PERCENT = 0.5` (risk 0.5% of equity per position).

### Zusätzliche Filter

- Skip entry during the 48 hours surrounding a scheduled high-impact news event on the
  traded commodity (crude inventory, FOMC, NFP for gold, EIA for oil/gas). Use news
  calendar blackout.
- Minimum `ATR(20) / Close > 0.003` (avoid ultra-low-vol periods where spread eats
  the edge).

## Concepts (was ist das für eine Strategie)
- [[concepts/time-series-momentum]] — primary: go long if 12M past return positive
- [[concepts/trend-following]] — secondary: extends position with trend direction

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Named academic authors (Zhang, Urquhart) + verifiable SSRN URL 3271841; published Review of Behavioral Finance 2021 |
| R2 Mechanical | UNKNOWN | Signal = sign of Close[0] vs Close[252]; entry/exit rules fully deterministic; ATR stop is deterministic |
| R3 Data Available | UNKNOWN | XAUUSD, XAGUSD, XTIUSD, XNGUSD all available as DWX symbols; D1 history from 2017 covers 8+ years |
| R4 ML Forbidden | UNKNOWN | No ML; 1 position per magic; ATR-based stop only; no adaptive sizing |

## Porting Note

The paper tests 29 commodity **futures** markets. We port to 4 commodity **CFDs**
(XAUUSD, XAGUSD, XTIUSD, XNGUSD). The futures total return includes a roll yield
component (front-contract roll) that we do not capture. The paper's time-series
momentum signal is derived from price return alone (spot component), which is directly
replicable on CFD instruments. Roll yield would be an additional alpha source not
available here, so live performance may differ from the paper's exact figures — but the
direction of the signal (12M price return sign) remains valid.

## Pipeline-Verlauf
- G0: 2026-06-27, PENDING

## Verwandte Strategien
- [[strategies/QM5_12708_commodity-tsmom-6m]] — same structure, 6M formation window
- [[strategies/QM5_12710_commodity-tsmom-12m-atr]] — same signal, ATR trailing exit instead of fixed monthly
- [[strategies/QM5_12711_commodity-tsmom-dual-6-12]] — dual signal requiring 6M and 12M agreement

## Lessons Learned
- (none yet)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
