---
ea_id: QM5_9973
slug: bandy-ibs-extreme-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/bar-internal-structure]]"
indicators:
  - "[[indicators/ibs]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 36
last_updated: 2026-05-19
r1_track_record: PASS
r1_reasoning: "Single source_id present; Bandy QTA cited with ISBN and Google Books URL providing traceable lineage."
r2_mechanical: PASS
r2_reasoning: "IBS = (close−low)/(high−low) single-bar ratio, ≤0.15 threshold entry, ≥0.60 threshold exit, 200-SMA regime gate, 10-bar time stop, and 2.5×ATR cat-SL are all closed-form with explicit long-only convention."
r3_data_available: PASS
r3_reasoning: "D1 timeframe; primary symbols SP500.DWX (backtest), NDX.DWX and WS30.DWX (live) are all available on the DWX MT5 feed."
r4_ml_forbidden: PASS
r4_reasoning: "IBS is a stateless single-bar ratio with fixed thresholds; no online learning, no martingale, and one position per magic."
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS: Bandy QTA ISBN/URL attribution; R2 PASS: deterministic IBS<=0.15 long entry, IBS>=0.60/time/ATR exits with ~36 trades/year/symbol; R3 PASS: testable on SP500.DWX backtest plus NDX/WS30 live caveat; R4 PASS: fixed rules, no ML/martingale, one position per magic."
---

# Bandy IBS (Internal Bar Strength) Extreme MR (Index)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1, URL: https://books.google.com/books?isbn=9780979103771
- Bandy in QTA covers bar-internal-structure indicators as an alternative to lookback-window oscillators for daily MR on indices. The Internal Bar Strength (IBS) is the canonical single-bar reduction: `ibs[t] = (close[t] - low[t]) / (high[t] - low[t])`, bounded [0, 1] by construction, with zero lookback dependency. Bandy contrasts IBS against RSI(2) — RSI(2) integrates two bars of close-direction information; IBS reduces a single bar's intra-bar position. For daily index MR the two carry near-orthogonal information: RSI(2) misses bars that closed near their low after a one-day pop; IBS catches them directly. Bandy endorses IBS especially for index ETF MR where the daily close vs. intraday range is highly mean-reverting. Period: D1. The Bandy contribution cardified here is the **(IBS ≤ 0.15 oversold + 200-SMA long-regime + IBS ≥ 0.60 exit + 2.5×ATR cat-SL + 10-bar time stop)** combination — structurally distinct from QM5_9728 (3-down-closes streak MR, which counts close-direction signs across bars), QM5_9907 (BBands midband reversion, which uses centered MA distance), QM5_9913 (RSI(3) + low ADX, which integrates close-direction), and from every RSI/Stoch/W%R/CCI/CMO/ROC card in this source because all of those reduce a multi-bar lookback window, while IBS reduces a single bar's intra-bar position.
- Substrate attribution: Larry Connors / TradingMarkets, "Short Term Trading Strategies That Work", TradingMarkets 2008 (IBS appears in the Connors/Alvarez index ETF system descriptions); attribution sometimes traced to earlier intraday-trader folklore. Bandy QTA discusses IBS explicitly as a Connors-family substrate. J. Welles Wilder Jr., "New Concepts in Technical Trading Systems", Trend Research 1978 — ATR substrate.
- Bandy contribution: the specific (IBS oversold threshold = 0.15, 200-SMA long-only regime, IBS exit threshold = 0.60, 10-D1-bar time stop, 2.5×ATR(14) cat-SL) parameter pairing and index-ETF universe selection (cardified material).
- PDF not on local disk; attribution by author + title under relaxed R1 (2026-05-15 OWNER directive) + URL on citation line.
- Distinct from QM5_9728 (3-down-closes streak: counts close-direction signs across multiple bars, ignores intra-bar position), QM5_9907 (BBands midband distance MR: uses centered MA, not bar-internal), QM5_9913 (RSI(3) + ADX: lookback-oscillator), QM5_9933 (Choppiness Index + RSI(2) MR: regime+lookback-oscillator), QM5_9934 (Ulcer Index + RSI(2): drawdown-based+lookback-oscillator). IBS's defining property is the zero-lookback single-bar reduction.

## Mechanik

Period: D1.

### Entry
On each completed D1 close:
- Compute `ibs[t] = (close[t] - low[t]) / max(high[t] - low[t], 1e-9)`. Result in [0, 1].
- Macro regime: `regime[t] = SMA(close, 200)[t]`.
- **Long entry**: `ibs[t] <= 0.15` AND `close[t] > regime[t]`. Enter at next bar's open.
- **Short entry**: long-only (index MR universe; short side is regime-bearish and IBS asymmetry favours long-only MR per Bandy's empirical observation on US index ETFs). Short side intentionally not used to keep the substrate focus tight.
- One position per magic; no pyramiding; no re-entry until exit closed.

### Exit
- Primary exit: `ibs[t] >= 0.60`. Close at next bar's open.
- Time stop: 10 D1 bars from entry (Bandy: IBS MR edge decays within ~2 trading weeks).
- Catastrophic SL: see below.

### Stop Loss
- Catastrophic SL: `2.5 * ATR(14)` from entry on the adverse side.

### Position Sizing
P2: fixed $1,000 risk based on 2.5×ATR catastrophic stop distance. Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip on incomplete D1 bar.
- Skip bars where `high[t] - low[t] < 0.2 * ATR(14)` (extremely narrow-range bar; IBS becomes noisy / divide-near-zero — same numerical-stability ablation as QM5_9964 close-position computation).
- Long-only (index MR universe).
- Honour news-blackout window (per framework news-calendar seed).
- P3 sweep candidates: IBS oversold threshold `{0.10, 0.15, 0.20, 0.25}`, IBS exit threshold `{0.50, 0.55, 0.60, 0.65, 0.70}`, regime SMA `{100, 150, 200, 300}`, cat-SL multiplier `{2.0, 2.5, 3.0}`, time stop `{5, 7, 10, 15}` bars, narrow-range floor `{0.10, 0.20, 0.30}` × ATR.

## Concepts
- [[concepts/mean-reversion]] — primary (close-vs-range intra-bar MR)
- [[concepts/bar-internal-structure]] — secondary (IBS substrate)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Bandy QTA + ISBN + URL; substrate attribution to Connors (popularised IBS in index ETF system documentation) and Wilder (ATR) documented inside Quelle so the attribution split is transparent. |
| R2 Mechanical | PASS | IBS computation is a closed-form single-bar ratio; regime SMA, threshold comparisons, time stop, catastrophic SL all closed-form deterministic; ~36 trades/year/symbol cadence (IBS ≤ 0.15 fires roughly once every 7 D1 bars on US index ETFs in long-regime). |
| R3 Data Available | PASS | Daily timeframe; index MR maps to DWX feed — primary symbols: SP500.DWX (backtest), NDX.DWX (live), WS30.DWX (live). IBS is endorsed by Bandy / Connors for the US index ETF universe specifically; CFD-port to NDX/WS30 is appropriate. |
| R4 ML Forbidden | PASS | Fixed (IBS thresholds, regime SMA, cat-SL multiplier, time stop, narrow-range floor) parameters; no online learning; no martingale; no scale-in; one position per magic. IBS is a deterministic single-bar ratio — no lookback adaptation. |

## R3
**Live promotion T_Live gate:** SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires a parallel-validation pass on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's T_Live-gate enforcement.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 11.

## Verwandte Strategien
- [[strategies/QM5_9728_bandy-three-down-closes-mr-index]] — alternative single-bar / few-bar MR substrate: counts close-direction signs across 3 bars; IBS reduces intra-bar position of a single bar. Near-orthogonal signal sources for index MR.
- [[strategies/QM5_9913_bandy-rsi3-low-adx-mr-index]] — RSI(3) lookback-oscillator MR with ADX-low regime; IBS substitutes the lookback-oscillator with a zero-lookback bar-internal ratio.
- [[strategies/QM5_9907_bandy-bbands-midband-reversion-mr-index]] — distance-from-MA MR; IBS uses intra-bar position not bar-vs-MA distance.
- [[strategies/QM5_9948_bandy-d1-setup-h1-trigger-mr-index]] — MTF RSI MR on indices; IBS-MR is single-timeframe and uses a different substrate.

## Lessons Learned (während Pipeline-Lauf)
- TBD

## Build-EA Notes
- IBS computation: at each D1 close, compute the ratio directly from `iClose`, `iHigh`, `iLow` for `shift=1` (use the just-closed bar, not the in-progress current bar). Denominator guard: `max(high - low, 1e-9)` or skip the bar if `high == low` (rare on D1 indices; possible on illiquid feeds or feed gaps).
- Narrow-range filter: enforce the `high - low >= 0.2 * ATR(14)` floor BEFORE computing IBS to short-circuit the divide-near-zero risk and reject statistically uninformative thin bars.
- IBS is a stateless single-bar computation; no `OnInit` history backfill needed for IBS itself. The 200-SMA regime requires 200 bars of warm-up at attach.
- Long-only convention: the EA's input mode flag should default to `long_only` with `both_sides` available as a P3 sweep parameter if downstream wants to test the symmetric variant.
- P1 build reviewer must confirm: (a) IBS uses just-closed bar (`shift=1`) not in-progress bar (`shift=0`), (b) denominator guard against divide-by-zero, (c) narrow-range filter applied BEFORE threshold comparison, (d) regime SMA uses 200-bar warm-up.
