---
ea_id: QM5_1530
slug: connors-double-sevens-h4
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/n-day-extreme-pattern]]"
indicators:
  - "[[indicators/connors-double-7s-pattern]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; attributed to Connors & Alvarez Short-Term Trading Strategies That Work (TradingMarkets 2008) ch.9 via FF cluster."
r2_mechanical: PASS
r2_reasoning: "N-day-extreme close comparison, SMA(200,D1) regime filter, ATR stop, opposite-extreme exit, and time-stop are all deterministic."
r3_data_available: PASS
r3_reasoning: "Original US equity ETF universe ports cleanly to DWX H4 on NDX.DWX, WS30.DWX, EURUSD, and XAUUSD."
r4_ml_forbidden: PASS
r4_reasoning: "Pure close-vs-N-bar-extreme arithmetic with fixed N=7, ATR multiplier, and regime MA; no ML, no martingale, no grid, 1-pos-per-magic."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 cites Connors/Alvarez book and FF source; R2 deterministic Double-7s entry/exit/ATR/time-stop; R3 portable to DWX FX/indices incl SP500.DWX backtest caveat; R4 fixed-rule ML-free 1-pos-per-magic."
---

# Connors Double-7s Mean-Reversion (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]] (Connors Double-7s cluster cross-posted on FF Trading-Systems and equity systems boards)
- Page / Timestamp: Larry Connors + Cesar Alvarez, *Short-Term Trading Strategies That Work* (TradingMarkets Publishing 2008/2009) ch. 9 — "The 'Double Seven' Strategy". FF cluster ports the equity-original to FX majors + indices on H4. URL search "Connors Double 7s" / "double seven strategy".

## Mechanik

The **Double-7s** is Connors' canonical N-day-extreme mean-reversion pattern. Distinct from the RSI/oscillator-based Connors family (RSI-2 / CRSI / TPS / VIX-Stretch) by the **pure N-bar-extreme rule** — no oscillator math, just close-vs-N-bar-low/high comparison.

Connors original: SPY / IWM / QQQ on daily bars. FF port to H4 on FX majors + indices replaces the SMA(200,D1) regime filter with SMA(200,D1) on the host symbol and the 7-day window with a 7-H4-bar window.

### Entry
- **Long** (mean-revert from N-bar-low): price close above SMA(200,D1) (regime filter, long-only when uptrend) AND H4 close below the lowest H4 close of the prior 7 H4 bars (i.e., today's H4 close is the lowest of the last 7 closes) → market-buy at next H4 bar open
- **Short** (mean-revert from N-bar-high): price close below SMA(200,D1) AND H4 close above the highest H4 close of the prior 7 H4 bars → market-sell at next H4 bar open
- Re-arm rule: only one entry per "extreme-of-7" event — after entry, the next entry signal requires a fresh extreme break following an interim non-extreme close
- Magic = ea_id × 10000 + slot

### Exit
- **Profit-target exit**: close LONG when H4 close above the highest close of the prior 7 H4 bars; close SHORT when H4 close below the lowest close of the prior 7 H4 bars (i.e., reversion to opposite-side extreme)
- **Time-stop**: close after 14 H4 bars (≈ 2.3 days) if neither TP nor SL hit
- **Trailing**: none — pure mean-revert, fixed time horizon

### Stop Loss
- ATR-based: SL = 3.0 × ATR(14) from entry price (wide — mean-revert needs room to fade against entry)
- HR4 fixed-risk: P2-baseline `EA_INPUT_RISK_MODE = FIXED`, `RISK_FIXED = 1000`

### Position Sizing
- P2-baseline: RISK_FIXED = $1.000 per HR4
- T6-live: RISK_PERCENT = 0.5

### Zusätzliche Filter
- One position per magic at a time (HR14)
- Spread filter: skip entry if spread > 0.4 × ATR(14)
- News filter: standard QM news-calendar pause
- D1 trend-filter SMA(200) is mandatory — Connors 2008 explicit point: without the regime filter, N-bar-extreme fights long-term trend on instruments with strong directional bias and bleeds

## Concepts (was ist das für eine Strategie)
- [[concepts/mean-reversion]] — primary
- [[concepts/n-day-extreme-pattern]] — secondary (pure close-vs-N-bar-extreme primitive, distinct from oscillator-based mean-reversion)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | Larry Connors + Cesar Alvarez — *Short-Term Trading Strategies That Work* (TradingMarkets 2008/2009, ISBN 978-0-9772017-3-8) ch. 9; Connors Research with audited equity-market track record. R1 PASS |
| R2 Mechanical | PENDING | Fully mechanical: highest/lowest-close-of-N comparison + SMA(200,D1) regime filter + ATR-stop + extreme-of-N exit + time-stop. All native MT5 primitives (iClose, iHighest/iLowest on close-array, iMA, iATR) |
| R3 Data Available | PENDING | Original equity universe (SPY/IWM/QQQ). DWX FX majors + indices + XAUUSD on H4 all valid via porting; the Connors-canonical universe (S&P 500 ETF) ports to SP500.DWX (backtest-only, T6 caveat below) plus the live-tradable analogues NDX.DWX (≈ QQQ) + WS30.DWX (≈ DIA). EURUSD/GBPUSD/USDJPY also valid per FF cluster ports |
| R4 ML Forbidden | PENDING | Pure close-vs-extreme arithmetic; fixed N=7 window; fixed regime-MA period; fixed ATR multiplier; 1-pos-per-magic; no learning, no grid, no martingale, no averaging-in |

## R3 (porting / instrument)
Original Connors universe: US-equity ETFs (SPY, QQQ, IWM). Port to DWX: NDX.DWX (live-tradable analogue of QQQ), WS30.DWX (Dow-30 ETF analogue), GDAXI (DAX index), XAUUSD, EURUSD/GBPUSD/USDJPY FX majors.

**SP500.DWX backtest-only**: SPY/SPX-direct-port is testable on SP500.DWX (OWNER-provided ticks 2018-07→2026-05 on T1-T5, since 2026-05-16T19:15Z). **T6 live-promotion gate**: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's T6-gate enforcement.

## Pipeline-Verlauf
- G0: PENDING (Batch 33 draft 2026-05-19)
- P1: —
- P2: —

## Verwandte Strategien
- [[strategies/QM5_1450_connors-rsi2-pullback-h4]] — RSI-2 is Connors' simplest mean-revert primitive (oscillator-based); Double-7s is the N-bar-extreme primitive — pattern vs oscillator, distinct
- [[strategies/QM5_1505_connors-cumulative-rsi-h4]] — Cumulative-RSI sums consecutive-bar RSI(2); Double-7s uses close-vs-extreme — distinct
- [[strategies/QM5_1511_connors-tps-time-price-score-h4]] — TPS is the pyramid scale-in variant of RSI-2; Double-7s is a single-entry N-bar-extreme — distinct
- [[strategies/QM5_1492_connors-vix-stretch-h4]] — VIX-Stretch is the ATR-port; Double-7s uses N-bar-close-extreme — distinct
- [[strategies/QM5_1527_connors-crsi-composite-h4]] — CRSI is the 3-component composite (RSI/streak/ROC); Double-7s is pure N-bar-extreme — distinct mechanic family

## Lessons Learned (während Pipeline-Lauf)
- (none yet)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
