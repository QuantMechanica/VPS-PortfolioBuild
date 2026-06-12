# Structural/Flow-Edge Deep Research — white-space families

**Author:** Claude · **Date:** 2026-06-12 · **Method:** deep-research workflow
(wf_919217b8, 101 agents, 19 sources fetched, 89 claims extracted, 25 adversarially
verified by 3-vote panels: 18 confirmed / 7 killed) · **Trigger:** OWNER directive
"find prop-firm-crusher CFD strategies not yet covered" · **Pairs with:**
`EDGE_QUALITY_RESEARCH_SYNTHESIS_2026-06-09.md` (famous-anomalies sweep) and the
2026-06-12 fidelity initiative (QM5_12534/12535).

## Scope

Seven deliberately under-carded families (white-space scan vs 2,676 approved cards):
gold LBMA fix flows, index closing-auction/MOC, DAX/Xetra microstructure, post-OPEX/
witching, FX triple-swap-day, Art Collins patterns, niche-forum systems.

## Ranked verdicts

### 1. Zarattini noise-boundary intraday momentum — ALREADY OURS, PIPELINE-SETTLED
The single mechanization-ready candidate of the sweep (SSRN 4824172; mechanics verified
3-0 twice; headline 19.6% p.a. net REFUTED 1-2). **We already hold the faithful
implementation: QM5_1045** — cash-session-anchored boundaries (the exact CFD adaptation
the research flags as critical), HH:00/HH:30 checks, EOD flatten. Outcome: 13 Q02 PASS,
50 Q03 PASS, then **51 Q04 walk-forward FAIL — including SP500.DWX FAILs dated
2026-06-11, i.e. under the softer DL-071 PASS_SOFT regime.** Verdict: the best external
candidate is correctly implemented and genuinely dead on our data. Sibling QM5_1046
(Maróy VWAP/ladder exits) was built-never-tested → build task 43519522 primed
2026-06-12; this is the one open branch of the family.

### 2. Gold around-fix drift — UNRESOLVED, OWN STUDY REQUIRED (queued)
Caminschi-Heaney 2014 (JFM) verified: the documented edge was **insider leakage at the
fix-call START; explicitly zero post-publication/public-information edge** (3-0).
Post-2015 persistence of the structural drift (decline into AM fix, rise after PM fix)
is genuinely open: Nilsson 2015 (graphical, 6 months) says persisted; Crain 2020 (daily
data) and Aspris 2020 (6-week sample) cannot adjudicate. **No multi-year post-reform
intraday study exists — we can write it ourselves** (XAUUSD.DWX ticks, T_Export
terminal, windows around 10:30/15:00 London). Hypothesis: short into AM fix, long after
PM fix. NO card before the study.

### 3. Post-OPEX/witching week — RULE CLAIMS KILLED, cheap own test queued
Stivers-Sun (JBF 2013) is real but cross-sectional (high-option-activity stocks),
1988-2010, pre-0DTE. The "long index during OPEX week" rule claim and its 9.3%/0.61
performance were refuted 0-3 / 0-2. Quantpedia shows no post-2010 OOS. Verdict: NOT
READY; one cheap D1 own-data test on NDX/WS30/GDAXI decides.

### 4. Last-30-minutes index momentum (Gao JFE 2018) — REAL BUT COST-DEAD FOR US
Academically solid (Sharpe 1.08, SPY 1993-2013, verified verbatim) but ~3bp gross/trade,
weakest exactly on DIA/QQQ (in-sample R² 1.16%, OOS 0.70%), vs CFD spreads of several
bp+. DO NOT BUILD naive. (QM5_1045's all-day boundary variant was the stronger cousin —
and it died at Q04.)

### 5. DAX gap-fade — EMPIRICALLY DEAD (two independent German backtests)
trading-treff.de: -35% over ~2y (vs DAX +4%); hbreuer-trading.de FDAX variant:
66% win rate but ~21% DD, ~breakeven, "not tradeable" per author. The claimed
Xetra-close-reference improvement was refuted 0-3. High gap-fill base rate (~77-80%)
is a base-rate fact, not a net edge. DO NOT BUILD naive gap-fade; any revisit needs an
own GDAXI study with post-2016 Eurex session anchors.

### 6./7. Triple-swap-day, Art Collins, niche forums — UNMINED, NOT PROVEN-DEAD
Zero claims survived fetch+verification (sources too thin/unreliable). Distinguishing
"empty" from "unmined" needs primary-source access (Collins' books; forward-tracked
forum threads). Partially covered by router research task 9a5dcdaf (Balke/German scene/
fidelity-lint/Python track records).

## Actions taken 2026-06-12

- White-space + fidelity build cohort primed: QM5_1158, 10326, 10873, 10763, 10892,
  12534 (NNFX canonical), 12535 (ICT killzone sweep), 1046 (Maróy variant).
- Own-data studies to dispatch: (A) XAUUSD around-fix drift 2016→2026; (B) OPEX-week
  OOS on NDX/WS30/GDAXI D1.
- Full machine-readable result: workflow wf_919217b8 output (task w23rx13u4).

## Kill list (do not re-propose)

| Claim | Vote |
|---|---|
| Gold-fix public-information rule (react to published fix) | dead by 3-0 primary finding |
| Pre-fix anticipation drift window | 1-2 refuted |
| Zarattini 1,985%/19.6% p.a. net performance as stated | 1-2 refuted |
| "Long index during OPEX week" as buildable index rule | 0-3 refuted |
| OPEX-week 9.3% p.a./Sharpe 0.61 performance | 0-2 refuted |
| Naive DAX/FDAX gap-fade (any session-anchor variant) | dead, two independent backtests |
| Xetra-17:30-reference gap improvement (>€100/trade) | 0-3 refuted |

## Sources (verified claims only)

- Caminschi & Heaney 2014, J. Futures Markets 34(11) — wiley.com/doi/10.1002/fut.21636
- Crain, Hoelscher & Jones 2020 — bearworks.missouristate.edu (articles-cob/1565)
- Nilsson 2015, SSRN 2657767 · Aspris et al. 2020, SSRN 3562073
- Gao, Han, Li & Zhou 2018, JFE 129(2), SSRN 2552752
- Zarattini, Aziz & Barbon 2024, SSRN 4824172
- Stivers & Sun 2013 via Quantpedia option-expiration-week-effect
- trading-treff.de gap-fade backtest · hbreuer-trading.de FDAX gap study
