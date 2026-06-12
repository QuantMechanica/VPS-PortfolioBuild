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

---

# Wave 2 addendum (same day) — championship/regime/intermarket/Quantpedia sweep

**Run:** wf_fdbe7fd5 (100 agents). **Important integrity note:** the verification
phase was cut by the claude.ai monthly spend limit — all 25 claims show 0-0 votes
(NEVER VERIFIED, not refuted; the workflow's "all refuted" summary is an artifact).
Search+extraction completed. Claude re-verified the actionable claims inline.

## Inline-verified outcomes

- **KER dual-regime switching → CARDED (QM5_12541).** Kaufman Efficiency Ratio as the
  switch between trend logic and MR logic; formula is primary-literature solid
  (Kaufman 1995/2013), threshold claim (trend ≥ ~0.3-0.4) consistent with the
  StrategyQuant codebase entry (page 403s to fetchers; cited as secondary). Census
  confirmed: KAMA exists (11 cards) but a dual-logic switcher did not. Hysteresis
  0.35/0.20 in the card guards the threshold-fragility risk.
- **Oil→equity filter (#0096, Driesprong-Jacobsen-Maat "Striking Oil") → DEAD.**
  Quantpedia's own page cites follow-up research: oil returns no longer predict G7
  index returns post-2015. Not carded; logged as falsification study H9.
- **Quantpedia free-tier diff:** the ~15-17 universe-tradeable entries are dominated by
  families we hold (FX carry/momentum/value — all research-weak per 2026-06-09
  synthesis; TSM #0118 — contested, died at Q08) or R3-infeasible (term structure
  needs futures curves; FED model needs yields — no bond data in our universe).
- **ATC winners:** 2007 winner = neural net (no-ML: ineligible); remaining winner-rule
  archaeology is low-yield index pages — folded into router task 9a5dcdaf.
- **Katsanos, "Intermarket Trading Strategies" (Wiley 2008):** Ch.11 = fourteen
  mechanical gold systems, Ch.13 = DAX systems, with MetaStock code appendices.
  UNVERIFIED (book access needed) but the highest-density primary source surfaced by
  wave 2. → OWNER decision: acquire the book (~EUR 60) and we mine it directly.
- **Design guidance (unverified but consistent across two sources):** simple N-day
  time exits match/beat indicator exits for index MR; tight stops destroy index MR
  (only ~8.5%+ "disaster" stops don't hurt). Adopted in QM5_12541's MR leg.

## Spend-limit operational note

Workflow subagent verification burns claude.ai spend; the monthly cap cut wave 2 at
~60% of verification. Interactive lane unaffected. If more workflow waves are wanted
this month, OWNER must raise the cap at claude.ai/settings/usage; otherwise inline
verification (as done here) is the workaround.
