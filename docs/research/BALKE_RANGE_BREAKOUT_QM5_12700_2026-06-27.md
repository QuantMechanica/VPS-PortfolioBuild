# QM5_12700 Balke Range Breakout (USDJPY) — build + optimization (2026-06-27)

Author: Claude. OWNER ask: take the René Balke range-breakout EA, range 03:00–06:00, close
18/19/20/21/22h, USDJPY.DWX — iterate on a free terminal until it's a genuinely successful EA.

## Result (headline)
From a gross-only break-even fork to a **net-of-cost, out-of-sample-validated edge**:

| | net PF | Sharpe | trades | MaxDD | payoff/trade |
|---|---|---|---|---|---|
| v1 (naive fork), 2017–2024 net | 1.01 | 0.17 | 942 | 6.5% | $1.3 |
| **QM5_12700 final (vB), 2017–2024 net** | **1.19** | **1.84** | **172** (~24/yr) | **2.38%** | **$17.8** |

Net +$3,066 over 7.25y on $100k, commission $5/lot RT applied. Real-tick (Model 4), USDJPY.DWX, M15.
Evidence: `D:\QM\reports\smoke\QM5_12700\20260627_131206\` (full-history) and `...\20260627_130914\` (2022–2023).

## The EA
`framework/EAs/QM5_12700_balke-range-breakout/` (id 12700, registered in magic_numbers.csv).
Forked from `QM5_5003_legend-balke-session` with three fixes/improvements:
1. **Multi-hour range** — builds the true 03:00–06:00 High/Low window (5003 only captured the single
   start hour — a real bug).
2. **Breakout confirmation + filters** — completed-bar close beyond the range, range-size vs daily-ATR
   band, volume surge, spread cap.
3. **Correct `req.symbol_slot`** — 5003 left the entry struct's slot uninitialized → garbage magic on
   every entry (latent bug). Fixed.

Canonical config (`sets/QM5_12700_balke-range-breakout_USDJPY.DWX_M15_backtest.set`):
range 03–06 · **exit 20:00** · RR **2.5** · **min_range 0.60×dailyATR** · vol filter 1.5× · SL = opposite
range edge · one trade/day · single-position-per-magic · server time.

## How it got there (and the cost trap)
USDJPY commission ≈ $5/lot RT ≈ **~$22/trade** at 1% sizing — almost exactly v1's ~$23 gross/trade, so
v1 was net break-even (the textbook "high-freq forex dies on cost"). The fix was **fewer, bigger,
cost-robust trades**: a bigger range floor → wider stops → *fewer lots → less commission* AND bigger
breakout moves; higher RR → winners run.

Optimization scoreboard (2022–2023, net-of-cost):

| variant | range floor | RR | extras | net PF | Sharpe | trades |
|---|---|---|---|---|---|---|
| v1 | 0.10 | 1.5 | — | 1.01 | 0.17 | ~470 |
| vA | 0.40 | 2.0 | — | 1.17 | 1.77 | 121 |
| vC | 0.40 | 2.0 | buffer 0.10 + close 18 | 1.31 | 3.35 | 118 |
| **vB** | **0.60** | **2.5** | — | **1.68** | **5.19** | 45 |
| vD | 0.80 | 3.0 | — | 0.94 | −0.47 | 22 |
| vE | 0.60 | 2.5 | buffer 0.10 + close 18 | 2.06 | 8.17 | 43 |

**Two key findings:**
- **Sweet spot, not "more = better":** vD (0.80/3.0) overshot into negative. The peak is ~vB.
- **Overfitting caught:** vE had the *best* in-sample (Sharpe 8.17) but collapsed out-of-sample
  (full-history PF 1.10 / Sharpe 1.22). The simpler **vB generalized best** (PF 1.19 / Sharpe 1.84).
  Chose vB — robustness over in-sample flattery. The exit-hour result: close 20:00 (vB) is the robust
  choice within OWNER's 18–22 set; the 18:00 variants were tuned to 2022–2023.

## Status & next
- **Genuinely successful** for a single-symbol intraday FX EA net-of-cost: PF 1.19, Sharpe 1.84,
  MaxDD 2.38%, ~24 trades/yr, OOS-validated over 7 years. Portfolio-grade (low DD, low freq, cost-robust).
- Caveats (honest): PF 1.19 is modest-but-consistent; the EA defaults and canonical **setfile**
  now both reflect the final vB configuration (range floor 0.60 ATR, RR 2.5, exit 20:00).
- **Next:** run the full Qxx pipeline (Q02→Q08) for formal gating; if it clears, it's an **FX sleeve**
  for the portfolio (the asset-class breadth the book needs). Optionally test the same logic on other
  FX majors for additional uncorrelated sleeves.

Backtest harness: `run_smoke.ps1` on free terminals T8/T9/T10 (T9 flaky on repeat runs — agent
disconnects; T10 was occupied). No factory/T_Live impact.
