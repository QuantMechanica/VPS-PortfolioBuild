# Portfolio-Gap Directed Edge Synthesis — filling the empty matrix cells

**Author:** Claude (research agent) · **Date:** 2026-06-21 · **Status:** research result / directed-edge spec
**Trigger:** DL-064 R-064-1. The robust book (6 Q08-FAIL_SOFT sleeves) is dangerously
concentrated — **0 Forex**, everything US-index mean-reversion + metal/index trend. Empty
cells (book matrix, `research_matrix.py --sleeves`): **trend/forex, mean_reversion/forex,
seasonality_volatility/forex, mean_reversion/commodity**. This brief gives a concrete,
sourced, near-zero-param, anticorrelated direction per cell. Discipline: economic cause
required, DEV/OOS where data exists, honest failure modes, no ML/grid/martingale, one
position per magic (or the 2-leg basket recipe QM5_10717).

---

## Cell 1 — mean_reversion / forex  →  ALREADY DISCOVERED, blocked by a pipeline bug

Two in-house cointegration survivors already exist (see
[CROSS_ASSET_FX_DISCOVERY_2026-06-09](CROSS_ASSET_FX_DISCOVERY_2026-06-09.md), my own
66-pair scan on our .DWX data):
- **QM5_12533 EURJPY~GBPJPY** — DEV net Sharpe **0.59 AND OOS 1.53**, +5.98%, 24 OOS trades,
  35-day half-life. The strongest (positive in BOTH windows). Common JPY leg + European-risk factor.
- **QM5_12532 AUDUSD~NZDUSD** — OOS net Sharpe 1.29, ~7 trades/yr; OOS-only (DEV 0.13), regime-sensitive.

**Why they're not in the book — structural, not strategic.** Both are market-neutral 2-leg
baskets, but the pipeline evaluates them **per-symbol at Q02**: each leg standalone fails the
PF gate because the edge lives in the *spread*, not either leg (12533's recent real verdict =
GBPJPY.DWX Q02 FAIL with evidence; the 22 earlier INFRA were the 06-19 launch_fault/log-bomb
storm, now resolved). 12532 reached Q04 and FAILED — consistent with the known **swap caveat**
(multi-day pairs holds incur swap, unmodeled; deferred `live_swap.json`).
**Actions (ops/pipeline, route to Codex):** (a) Q02 (and Q04) must judge the basket's COMBINED
net for `portfolio_scope: basket` cards, not per-leg; (b) inject swap for multi-day holds before
trusting the Q04 verdict on these. Highest ROI in the whole gap list — the edge is already
validated; only the harness is wrong. Conviction: **HIGH**.

---

## Cell 2 — mean_reversion / commodity  →  Gold/Silver ratio reversion (new card)

**Direction:** XAUUSD~XAGUSD cointegration pairs-trade — the *same* near-zero-param recipe as the
FX cointegration, on the precious-metals complex.
- **Economic cause:** gold and silver share the monetary/safe-haven/real-rate factor; the
  gold-silver *ratio* is a centuries-old, strongly mean-reverting series (structural, not
  data-mined). Divergences in ln(XAU)−β·ln(XAG) revert.
- **Mechanics (near-zero param):** spread S = ln(XAUUSD) − β·ln(XAGUSD), β from the cointegrating
  hedge; rolling z (lookback ~60 D1); enter |z|>2 (short the rich leg / long the cheap leg,
  risk-balanced), exit |z|<0.5. 2-leg basket on XAUUSD.DWX host (QM5_10717 recipe). XAGUSD.DWX +
  XAUUSD.DWX both present with full .DWX history.
- **Anticorrelation:** market-neutral on the metal *ratio* → orthogonal to the book's directional
  XAU trend sleeves (10513/10940). New logic (MR) in a new market (commodity).
- **Failure modes:** same basket-Q02 caveat as Cell 1; swap on multi-day holds; the GSR can trend
  for long stretches (2020 spike) → needs the z-exit discipline + a max-hold/half-life stop.
- Conviction: **HIGH** (classic robust stat-arb). **Same harness fix as Cell 1 unblocks it.**

---

## Cell 3 — seasonality_volatility / forex  →  London-session opening-range breakout (new card)

**Direction:** single-symbol intraday session ORB on a London-centric major (GBPUSD.DWX, alt EURUSD.DWX).
- **Economic cause:** the London open is the largest FX liquidity/volatility surge of the day
  (London+Europe session, ~07:00 London). Documented intraday volatility seasonality: the Asian
  range compresses, the London open expands it directionally. Time-of-day, not price-pattern → a
  genuinely different (orthogonal) signal source.
- **Mechanics (low param):** define the Asian-session range (00:00–07:00 London) high/low; place
  buy-stop at high+buffer and sell-stop at low−buffer for the London session; ATR stop; close at
  NY-session end or a fixed time-stop; one position per magic; news blackout on. Broker-time
  mapping per the DXZ NY-Close convention (GMT+2/+3 DST) — must be handled explicitly.
- **Anticorrelation:** intraday time-driven on FX → orthogonal to every existing D1 index/metal
  sleeve. Fills BOTH an empty logic row (seasonality/vol) and the empty Forex column.
- **Failure modes:** session/DST boundary bugs (the #1 risk — validate broker vs custom-symbol
  timestamps over a DST window first, per Test-Environment Ownership); spread at the open eats
  small breakouts (cost gate is the judge); choppy no-expansion days → time-stop. Needs M30/M1 or
  H1 data — H1 already exported in `T_Export` (CROSS_ASSET forward-idea menu).
- Conviction: **MEDIUM-HIGH**, and it's **single-symbol → clean through Q02** (no basket caveat) →
  fastest path to an actual Forex sleeve.

---

## Cell 4 — trend / forex  →  Rate-divergence Donchian breakout on USDJPY (new card)

**Direction:** Turtle-style channel breakout filtered to the one major that still trends — USDJPY
(rate-differential / policy-divergence driven), alt USDCAD.
- **Economic cause:** FX majors are mostly mean-reverting post-2010 (why this cell is hard), BUT
  rate-differential regimes produce durable secular trends (USDJPY 2021–2024 BoJ-vs-Fed). Time-
  series momentum is the most robust documented trend anomaly (Moskowitz-Ooi-Pedersen, *Time
  Series Momentum*, JFE 2012).
- **Mechanics (low param):** Donchian(55) breakout entry / Donchian(20) exit (Faith, *Way of the
  Turtle*, library-mined `LIBRARY_MINING_turtle-way`); ADX>25 regime filter to avoid the ranging
  majority; ATR-sized stop + trail; one position per magic.
- **Anticorrelation:** trend logic (book is MR-heavy) on FX (book has none).
- **Failure modes:** **the weakest cell** — FX trend whipsaws in ranging regimes; the ADX filter is
  a curve-fit risk (keep it fixed, no optimization). Honestly may die at Q04 like most trend EAs;
  card it but expect lower hit rate than Cells 1–3.
- Conviction: **MEDIUM** (lower than 1–3). Single-symbol → clean Q02.

---

## Priority / sequencing (fastest robust Forex sleeves first)

1. **Unblock Cells 1+4-as-basket via the harness fix** (basket combined-net Q02/Q04 + swap) — the
   forex/MR edge is *already validated*, only the gate is wrong. Highest ROI; route to Codex.
2. **Card Cell 3 (London ORB, GBPUSD)** — single-symbol, fast through Q02, fills Forex + Seasonality.
3. **Card Cell 2 (Gold/Silver ratio)** — reuses the basket recipe; unblocked by the same fix as Cell 1.
4. **Card Cell 4 (USDJPY Donchian)** — lowest conviction; card last.

All four are anticorrelated to the current US-index-MR + metal-trend book and respect the Hard
Rules (cited cause, mechanical, DWX-testable, no ML/grid/martingale). The pipeline (DL-072/073
cost + recalibrated gates) remains the honest judge.
