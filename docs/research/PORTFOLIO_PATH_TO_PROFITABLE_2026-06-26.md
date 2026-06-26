# Path to a Clean, Profitable EA Portfolio — Evidence & Plan (2026-06-26)

Author: Claude (operation lead). Owner question: *"Wie kommen wir jetzt zu einem sauberen
EA Trading Portfolio, das profitabel ist?"*

This is grounded in current DB/stream state, not memory. Every number below is reproducible
from the cited artifact.

## 1. The honest book today (not the flattering one)

`book_monitor_state.json` advertises **MaxDD 4.4 % / Sharpe 3.31** on 5 FAIL_SOFT sleeves.
That number is **not trustworthy**, for two reasons the analysis exposed:

- It is computed on a **daily-PnL** series that is ~99 % zeros (these sleeves trade
  14–457 times over **7.74 years**). Sharpe on a near-empty series is an artifact of a
  handful of trade days, not a risk-adjusted return.
- It uses the **observed** drawdown (a single lucky path), not a robust estimate.

Recomputed properly (`D:/QM/reports/portfolio/book_analysis_2026-06-26.json`,
6 sleeves incl. reconstructed 10692:NDX):

| Book | Sleeves / instruments | MaxDD (obs) | MC-p95 DD | Sharpe | Net (7.74y) |
|---|---|---|---|---|---|
| Naive risk-parity (all) | 6 / 4 | 4.86 % | — | 1.67 | $4,298 |
| **R-064-2-admitted (monthly-corr ≤0.30, must diversify)** | **4 / 4** | 5.64 % | **13.96 %** | 1.95 | $5,126 |

Sized to the drawdown budget (leverage = budget ÷ MC-p95 DD, linear scaling):

- **DXZ 20 % total-DD budget → ~9.5 %/yr**
- **FTMO 10 % total-DD budget → ~4.7 %/yr** (MC-p95 DD already eats the budget → must *de*-lever)

**Conclusion:** the book is real and net-positive after cost, genuinely uncorrelated, but
**below the ≥20 %/yr mission** at any defensible drawdown budget. The seed is sound; the book
is too thin.

## 2. The unlock: the diversification test was mismatched to our own edges

The funnel deliberately selects **low-frequency structural edges** (high-freq dies on cost at
Q04). But the portfolio layer then tests diversification on a **daily-PnL correlation** with a
60-day overlap floor. Empirically, on the real pool **15/15 sleeve pairs have insufficient
daily overlap** (max 18 shared active days). So the gate could **never certify a 2nd sleeve** —
the live `portfolio_candidates` table has sat at **1 entry** since 2026-06-03, and the live
Q09 gate parked the rest as `NEED_MORE_DATA` with a `sparse_overlap_watchlist` flag the authors
left as an acknowledged TODO. The two halves of the pipeline were at cross-purposes.

On a **monthly** basis the structure is clear and usable (same artifact):

- `11124:SP500` ↔ `11132:SP500` = **+0.57** — the one genuinely redundant pair (drop one).
- `10692:NDX` ↔ SP500 = **−0.12 / −0.13** — NDX **diversifies** (corrects the earlier
  "NDX ≈ SP500" assumption; recovering it *is* worth it).
- mean pairwise monthly corr **+0.029** — the book is genuinely uncorrelated.

### Fix implemented (this branch, tested + validated)

`portfolio_admission.py`: when daily overlap is insufficient, fall back to a **monthly
shared-live-span correlation** (0-filled, ≥24 shared months, ≥6 active months each). Gate on
shared *span*, never co-active months (a co-active guard perversely certifies redundant
same-instrument pairs and rejects cross-asset diversifiers). 21 portfolio tests green; real-pool
proof: SP500↔SP500 **+0.57 → rejected**, XNG↔SP500 **+0.18 → admitted**.

Status: **on `agents/board-advisor`, not merged.** Production effect requires merge→main +
canonical pull, then re-enqueue Q09 for the watchlist candidates.

## 3. Remaining low-frequency throttles (next, after merge)

1. **30-trade Q09 floor** (`DEFAULT_MIN_PORTFOLIO_TRADES`) kills 10513:XAU (22) and
   12567:XNG (14) — valid structural edges. Lowering it trades statistical power for breadth;
   an **OWNER call** (cf. DL-070 swing track). Recommend ~20 with a wider-CI caveat.
2. **`diversifies` test still runs on daily equal-weight metrics** — undercounts the
   monthly-diversification benefit (e.g. gold was rejected `no_diversification` vs SP500 despite
   corr +0.09). Move the diversifies check to the same monthly/risk-parity basis as the
   correlation test. Smaller, follow-on change.

## 4. The quantified path to ≥20 %/yr

Diversification math: portfolio Sharpe ≈ sleeve-Sharpe × √(N / (1+(N−1)ρ)). At ρ≈0 (proven on
the monthly basis), going from 4 → ~12 uncorrelated sleeves cuts MC-p95 DD from ~14 % toward
~8 %, which lets us lever into the DXZ 20 % budget at ~2.5× → **~20 %/yr**. This matches the
"~8–12 sleeves" target from prior work, now derived from the book's own numbers.

**Breadth is the single lever that fixes return AND credibility (PBO) at once** — more
uncorrelated sleeves is also what drives portfolio PBO below the coin-flip the lone candidate
(10692, PBO 51 %) shows today.

### Standing reservoir policy (Schritt 3)

Steer build/research toward **instrument and asset-class gaps**, not more of {XAU, SP500, NDX,
GDAXI}. A marginal edge on a *new* bucket is worth more to the book than a strong edge on gold
#3. Priority order of absent buckets:

1. **FX** (low-freq, cost-robust): EURUSD/USDJPY/EURJPY/AUDCAD already appear thinly at Q05 —
   the structurally-uncorrelated column, currently empty in the book.
2. **Crypto** (BTC/ETH if .DWX routable), **energy beyond XNG** (XTIUSD sets exist),
   **rates/bond proxies**.
3. **GDAXI**: 4 EAs knock at Q08 but all FAIL_HARD — diagnose unprofitable vs fixable
   cost/param defect before building more DAX.

Wire this as matrix-directed demand (the `research_matrix.sleeve_coverage` / directed-research
machinery already exists; point it at the *traded-instrument* gap, not just logic×market).

## 5. Concrete next actions

1. **OWNER decision:** merge the monthly-correlation admission fix to main. (Unblocks portfolio
   growth past 1 certified sleeve.) — gated on review.
2. After merge: re-enqueue Q09 for the FAIL_SOFT watchlist; re-dump the two NDX streams
   (10692, 10440 — currently infra-flaky `METATESTER_HUNG`) so the book includes them natively.
3. **OWNER decision:** the 30-trade Q09 floor (keep / lower to ~20).
4. Move the `diversifies` test to the monthly basis (follow-on PR).
5. Keep the reservoir pointed at instrument gaps until the certified book reaches ~12
   uncorrelated sleeves across ≥6 instruments / ≥4 asset buckets.

Evidence: `D:/QM/reports/portfolio/book_analysis_2026-06-26.json`,
`D:/QM/reports/state/book_monitor_state.json`, farm DB `work_items`/`portfolio_candidates`.
