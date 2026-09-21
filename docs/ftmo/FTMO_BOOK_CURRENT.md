# FTMO_BOOK - current (v1, 2026-09-21)

**Authority:** OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921 (`decisions/2026-09-21_owner_ftmo_book_portfolio_not_hero_ea.md`).
**Machine mirror:** `D:/QM/reports/state/ftmo_book_current.json` (schema `qm.ftmo-book-current/v1`).
**Basis of this v1:** frozen 2026-09-18 evidence (first-passage run `ftmo_first_passage.json` 03:49Z, `docs/ftmo/FTMO_ALT_ROSTER_DEPLOYABLE2_2026-09-18.md`)
plus a 0-factory-hour quicklook over the frozen W38 Q08 streams (`docs/ops/evidence/2026-09-21_ftmo_book_portfolio_directive/d2g6_book_stats_quicklook.json`).
The authoritative account-level simulation (chronological trades, open P/L, costs, Daily/Max Loss, marginal deltas, dependence matrix) is
commissioned as Codex ticket `e5c49db2`; the Mission Control panel as `1a5da47c`. Fields marked NOT_YET_MEASURABLE are exactly that.

## 1. Current FTMO_BOOK = demo roster D2g6 (deployed 2026-09-18 04:50Z, book risk 1.71875 %)

| Sleeve | Symbol / TF | Risk % | Role | Trades | /bd | E[R] | PF | R/bd @1 % | USD/bd @weight | med hold |
|---|---|---|---|---|---|---|---|---|---|---|
| QM5_10403 | XAUUSD D1 | 0.3125 | Gold trend (D1 turtle) | 207 | 0.101 | +0.065 | 1.288 | 0.0066 | 2.07 | 75.7 h |
| QM5_10700 | XAUUSD H1 | 0.3125 | Gold alpha (H1 swing) | 373 | 0.175 | +0.165 | 1.319 | 0.0289 | 9.04 | 19.7 h |
| QM5_10706 | GBPUSD H1 | 0.3125 | GBP swing alpha (H1, 46 % overnight) | 360 | 0.168 | +0.192 | 1.331 | 0.0322 | 10.06 | 7.7 h |
| QM5_11422 | USDCAD D1 | 0.3125 | stabilizer (USDCAD D1 trend, low density) | 195 | 0.095 | +0.094 | 1.246 | 0.0090 | 2.80 | 41.0 h |
| QM5_13213 | USDJPY H1 | 0.15625 | VELOCITY_SLEEVE (session-flat USDJPY, 0 % overnight) | 1596 | 0.743 | +0.064 | 1.149 | 0.0479 | 7.48 | 7.2 h |
| QM5_41219 | XAUUSD D1 | 0.3125 | Gold mean-reversion (D1, very low density) | 72 | 0.040 | +0.071 | 1.716 | 0.0029 | 0.90 | 48.0 h |

Validated = all six passed the FTMO admission gate (binary identity, no `.DWX` literal, sealed setfile bytes, financed contribution positive)
and are deployed on the FTMO demo (cycle day 3.251 of 14; NOT representative yet; open defect: kill-switch day anchor, diagnosis `4fd8222f`, fix `d6189118`).
Near-validated = none beyond the candidates in section 4.

## 2. Book-level economics (closed-P/L quicklook, window 2017-10-09..2025-12-30, 2147 bd)

| Metric | Value |
|---|---|
| BOOK_TRADES_PER_DAY | 1.306 |
| BOOK_ACTIVE_DAYS (share of bd with a closed trade) | 0.85 |
| BOOK_R_PER_DAY (sum at 1 % risk) | 0.126 R/bd |
| BOOK_USD_PER_DAY at roster weights | 31.9 USD/bd = 0.032 % of 100k per bd |
| BOOK_MAX_DD (closed P/L, roster weights) | -5740 USD |
| BOOK_DAILY_LOSS_BREACH_PROB / MAX_LOSS_BREACH_PROB (phase 1) | 0.0 / 0.0152 |
| BOOK_EXPECTED_TIME_TO_CHALLENGE_TARGET | median 286 bd (p10 125 / p90 621) |
| End-to-end to first payout | median 487 bd |
| P_CHALLENGE_PASS / P_FIRST_NET_FTMO_PAYOUT_LCB | 0.9634 / **0.8839** |
| BOOK_CONCENTRATION | USD-ENB 4.11 of 6; XAUUSD x3; 13213 = 55 %% of financed drift |
| BOOK_COST_DRAG | cost stress x1.5 + 2 USD/lot: E2E 0.9034 -> 0.8494; XAU spread/swap live UNMEASURED |

## 3. Dependence summary (daily closed P/L, quicklook - full matrix = ticket e5c49db2)

Max |r| = 0.099, max worst-20-day overlap = 2 days, max lower-decile co-exceedance = 1.92x independence.
**Flag:** 10403/41219 XAU D1 trade-day overlap 3.9x independence, loss-day overlap 2.7x (same regime days), no tail co-exceedance. Verdict: the sleeves do not fail together; the book problem is speed, not dependence.

| Pair | r | downside r | loss-day overlap x indep | trade-day overlap x indep | lower-decile co-exceed x indep | worst-20 overlap |
|---|---|---|---|---|---|---|
| 11422/10403 (USDCAD/XAUUSD) | 0.099 | -0.42 | 2.34 | 3.56 | 0.0 | 0 |
| 10403/41219 (XAUUSD/XAUUSD) | -0.087 | -0.416 | 2.69 | 3.89 | 0.0 | 0 |
| 13213/10706 (USDJPY/GBPUSD) | 0.058 | -0.3 | 1.02 | 1.0 | 1.45 | 0 |
| 13213/10403 (USDJPY/XAUUSD) | -0.055 | -0.434 | 0.98 | 1.05 | 1.92 | 2 |
| 10700/10403 (XAUUSD/XAUUSD) | 0.026 | -0.489 | 1.42 | 1.77 | 0.0 | 0 |
| 13213/11422 (USDJPY/USDCAD) | 0.025 | -0.358 | 1.08 | 0.97 | 1.34 | 0 |
| 10700/11422 (XAUUSD/USDCAD) | 0.025 | -0.573 | 1.64 | 1.72 | 0.0 | 0 |
| 10706/10700 (GBPUSD/XAUUSD) | -0.019 | -0.512 | 1.26 | 1.12 | 0.0 | 0 |

## 4. Candidate table (living)

| Candidate | Standalone edge | Density | Tail | Dependence | Marginal payout probability | Book action |
|---|---|---|---|---|---|---|
| H-V4 / QM5_41485 | harness SEL +0.141R / PF 1.30 / 0.85 per bd (not tester-measured) | 0.85/bd | harness worst-year DD 20.8R SEL / 25.04R VAL | same symbol + same mechanism class as 13213 -> replacement candidate unless |r| < 0.5 at Q08 | NOT_YET_MEASURABLE | **TEST (revision 2 in Codex critique round 2 afb38e9a; build 41485 + USDJPY Q02 canary next)** |
| 11708 EURUSD (anon-market-squeeze-d1) | +0.015R / PF 1.15 / 0.088 per bd | - | - | genuine diversification (ENB 4.11 -> 4.68 with 11910) | NEGATIVE at +0.3125 %: LCB 0.8839 -> 0.8556 (with 11910) | **HOLD (does not pay for its risk on the full sample)** |
| 11910 NZDUSD (larry-williams-18ma-2outside-bars-d1) | +0.039R / PF 1.17 / 0.033 per bd | - | - | genuine diversification | NEGATIVE at +0.3125 % (with 11708) | **HOLD** |
| H-CW 41475 / H-MR 41476 / H-FXMR 41477 | UNMEASURED (0 work items) | - | - | - | NOT_YET_MEASURABLE | **HOLD until prescreened by the M1 harness (0 factory hours) - index M1 history exists for NDX/SP500/GDAXI/UK100/WS30** |
| 21505 XAGUSD / 13054 XTIUSD | - | - | - | - | - | **BLOCKED (.DWX symbol literal in the as-compiled source; sealed setfile drift)** |

## 5. Strongest failure mode and missing behaviour

- **Strongest failure mode:** SLOW: median 286 bd to the Challenge target (487 bd end-to-end) at 31.9 USD/bd; the book is not breach-prone (daily-loss breach 0.0, max-loss 0.0152).
- **Strongest missing behaviour:** A session-flat, low-overlap, high-density sleeve that earns in the New-York / index cash session, where the current book has ZERO exposure (all sleeves except 13213 are overnight swing; 13213 is Tokyo/London USDJPY). Secondary: a second independent return engine on XAUUSD that is NOT a D1 trend/mean-reversion clone of 10403/41219 (activity clustering flag).
- **Next candidate needed:** 1) H-V4 (USDJPY NY pre-open) as VELOCITY_SLEEVE - measure marginal book value vs replacing the 13213 window; 2) harness prescreen of the NY/index cash-session family on NDX/SP500/GDAXI (H-CW/H-MR mechanics) before any build; 3) account-level simulator (e5c49db2) to turn every candidate into a delta table.

## 6. Loop state (CBE for FTMO)

1. Current book established (this file). 2. Failure mode measured: slow. 3. Missing behaviour named above. 4. Hypotheses: H-V4 (velocity, USDJPY)
in critique round 2; NY/index-session family to be prescreened by the M1 harness. 5-7. Prescreen -> build survivors -> MT5. 8. Marginal contribution:
simulator e5c49db2. 9-10. Add only if the book improves; conservative re-weighting. Roles per OWNER section 20: velocity / stabilizer / gold alpha /
counter-regime - no sleeve has to win every role.
