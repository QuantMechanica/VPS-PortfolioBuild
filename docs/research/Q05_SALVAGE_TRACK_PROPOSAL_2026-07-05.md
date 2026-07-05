# Q05 Salvage Track — proposal (2026-07-05, OWNER-triggered)

**Trigger:** OWNER 2026-07-05: more book EAs are the absolute lever; anything that
passes Q04 and dies marginally at a single downstream stress test may still add
diversification and total profit. This document quantifies that population and
proposes a governed salvage lane. **No gate is changed by this document** — per the
standing rule (gates deliberately conservative, DL-071/072/073 context) any change
requires OWNER ratification.

## The funnel numbers (farm_state, 2026-07-05)

- 236 (ea,symbol) pairs have ever passed **Q04** (the hard 88%-mortality gate).
- Their terminal downstream state: **Q05 FAIL 138** (plus 28 Q05-INFRA), Q08
  FAIL_HARD 16, Q06 FAIL 6, Q07 FAIL 5, Q09 FAIL_PORTFOLIO 10 — only ~10% ever
  reach Q08+. **Q05 is the second wall.**
- Q05 criterion (spec): slippage +2 pips, spread ×2, commission ×2 (i.e. DOUBLE
  costs), verdict PF > 1.0 AND DD < 15%, ≥20 trades, full history.

## Q05-FAIL margin distribution (137 items with evidence, 0 purged)

| Reason | n |
|---|---|
| pf_below_floor (PF ≤ 1.0 @2× costs) | 92 |
| dd_above_ceiling (DD ≥ 15%) | 45 |
| trades_below_floor | 8 |

Margins: **PF ≥ 0.90 under double costs: 57** · PF 0.75–0.90: 27 · PF < 0.75
(structurally dead): 12.

## Shortlist — marginal AND risk-sane (stressed PF ≥ 0.90 AND stressed DD ≤ 20%)

23 items; 2 are already FTMO Round25 legs via the real-cost report.htm chain
(QM5_10700 XAU 1.32/16.9 — died on DD ceiling only; QM5_11476 USDJPY 0.98/9.6),
**which proves the company already trades stress-gate near-misses profitably in
the prop track.** The 21 fresh ones, gap-family hits bolded:

| EA | Symbol | PF@2× | DD% | Trades |
|---|---|---|---|---|
| **QM5_12532** | **AUDNZD-COINTEGRATION (pairs gap!)** | 0.95 | **2.7** | 204 |
| **QM5_10163** | **EURUSD** (gap) | 0.92 | 9.6 | 767 |
| **QM5_11113** | **GBPUSD** | 1.00 (floor is >1.0 strict) | 11.7 | 304 |
| **QM5_9929** | **GBPUSD** | 0.98 | 10.7 | 183 |
| **QM5_10041** | **GBPUSD** | 0.95 | 13.3 | 3744 (high-freq FX — commission-sensitive) |
| **QM5_11708** | **AUDUSD** | 0.92 | 6.9 | 139 |
| **QM5_12511** | **WS30 (symbol not in any book!)** | 0.91 | 7.4 | 55 |
| QM5_10366 / 10432 / 10627 / 10166 | SP500 | 0.95/0.94/0.98/0.90 | 3.8–9.2 | 67–231 |
| QM5_10171 / 10230 | NDX (PF fine, died on DD 17–18) | **1.14 / 1.13** | 17.9/17.0 | 413/295 |
| QM5_10035 / 10427 / 1045 / 10781 | NDX | 0.92–0.99 | 4.4–15.8 | 50–625 |
| QM5_10589 / 10982 / 12959 / 10489 | XAUUSD (family saturated) | 0.93–1.00 | 17–19.4 | 109–984 |

Context: PF 0.95 at DOUBLED costs typically implies a comfortably profitable PF at
real (1×) costs — these are cost-stress casualties, not edge failures. Q04
(walk-forward, real costs) they all passed.

## Proposed governance (OWNER decision required)

**SALVAGE lane — main track untouched:**
1. Population: Q04-PASS + Q05-FAIL with stressed-PF ≥ 0.90 AND stressed-DD ≤ 20%
   (23 today), minus known defect classes.
2. Salvage gate: **re-run Q05 at 1.5× costs** (still a genuine stress buffer vs
   the cost-free .DWX basis; 2× stays the main-track gate). Pass → continue the
   NORMAL cascade Q06→Q07→Q08→Q09 unchanged.
3. Portfolio judgment stays supreme: Q09 admission (corr ≤ 0.30, Sharpe-protective)
   decides; priority to gap families (pairs/12532, EURUSD, GBP/AUD, WS30, SP500).
4. Probation class in the book: half inv-vol weight, collective cap ≤ 15% of book
   risk, 42d burn-in review — mirrors the FTMO-track precedent (10700/11476).
5. Selection-bias control: the full trial count (137 screened → N salvaged) is
   recorded here; PBO/DSR context applies to any performance claims.

**Expected yield (honest):** Q06-HARSH and Q08 will kill several; 3–6 genuinely
new Q09 candidates in under-represented families is the realistic outcome — which
is precisely what BOOK_GAP_SCAN_2026-07-05 says the book needs.

**Cost:** ~23 stress re-runs (~30–90 min each, normal queue) + one small runner
variant (cost-multiplier parameter in the Q05 stress-setfile generation).

## Status

- [ ] OWNER ratifies salvage lane (this doc = decision basis)
- [ ] Claude implements 1.5× re-screen variant + enqueues shortlist
- [ ] Results feed Q06+ cascade; admissions via normal Q09
