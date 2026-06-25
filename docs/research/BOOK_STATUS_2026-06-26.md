# Portfolio Book Status — 2026-06-26

Author: Claude · Status: evidence (real-commission stream aggregation)

## TL;DR

A real portfolio book exists: **4 Q08-validated survivors + 1 new net-positive-after-cost
sleeve (QM5_12567:XNGUSD)** — near-zero correlation (+0.007), net-positive, DD lower and
Sharpe higher than survivors-only. The book grows by sleeves clearing the **cost gates**
(Q04 walk-forward + Q08 cost-cushion), NOT by Q02 build volume.

## The central finding

Q02 PASS is **gross of commission** (.DWX custom symbols apply $0 commission/swap in the
MT5 tester). After REAL commission (`live_commission.json`) is applied to the per-trade
streams, **most Q02-passing sleeves are net-negative** — they only "passed" because the
backtest was cost-free. This is the 0.2% funnel yield made visible at the portfolio layer.

### Per-sleeve net (real commission, risk-parity book inputs)

| Sleeve | Phase | Net (real comm) | Trades |
|---|---|---|---|
| 10940:XAUUSD | Q08 survivor | +$6,729 | 35 |
| 11132:SP500 | Q08 survivor | +$4,637 | 43 |
| 10513:XAUUSD | Q08 survivor | +$2,877 | 22 |
| 11124:SP500 | Q08 survivor | +$1,715 | 33 |
| **12567:XNGUSD** | **new (Q02)** | **+$5,208** | 20 |
| 12566:XAGUSD | new (Q02) | −$483 | 6 |
| 12569:UK100 | new (Q02) | −$789 | 5 |
| 9121:XAUUSD | new (Q02) | −$1,420 | 7 |
| 12564:XTIUSD | new (Q02) | −$16,258 | 48 |
| 9121:EURUSD | new (Q02) | −$12,069 | 40 |
| 9121:USDJPY | new (Q02) | −$17,088 | 50 |

### Book variants (risk-parity, real commission)

| Book | Sleeves | Net | MaxDD* | Sharpe |
|---|---|---|---|---|
| Survivors-only (Q08 validated) | 4 | +$3,674 | 9.6% | 1.94 |
| Survivors + all new Q02 sleeves | 11 | −$1,995 | 10.2% | −2.97 |
| Net-positive-after-cost only | 5 | +$4,327 | 4.7% | 3.41 |

\* DD is daily-aggregated here (optimistic — hides intra-day drawdown). The conservative
reference for survivors-only is **19.94%** from `build_real_portfolio.py` (per-trade equity).
Use the relative deltas, not the absolute daily DD.

## Interpretation

1. **Diversification works mechanically** — 8 distinct instruments, mean pairwise correlation
   +0.007 (≈ zero), combined DD below any single sleeve's standalone DD.
2. **But edge must survive cost.** Adding gross-Q02 sleeves drags the book negative. Only
   net-positive-after-cost sleeves belong in it.
3. **One genuine new winner so far: QM5_12567:XNGUSD** (Connors cum-RSI2 on natural gas) —
   +$5,208 after commission at Q02. Promising; pending Q04/Q08 confirmation.

## What actually grows the book

NOT Q02 build volume. The lever is sleeves clearing **Q04 (walk-forward)** and **Q08
(cost-cushion)** — the gates that prove net-positive-after-cost robustness. The ~30 EAs now
in the pipeline (6 survivor ports + 12 queue EAs this session + the Codex backlog) feed it;
each net-positive-after-cost survivor joins the book.

## Recommended next steps

1. Fast-track **QM5_12567 (cum-rsi2-commodity)** through Q03/Q04/Q08 — it has the only
   net-positive-after-cost new stream; confirm XNGUSD (and test XTIUSD/XAGUSD/XAUUSD).
2. Treat the **cost gate as the real selector** — consider injecting real commission earlier
   (Q02/Q03) so the funnel stops promoting gross-only sleeves (the "backtests are cost-free"
   fix, previously specced).
3. Rebuild this book as new sleeves reach Q08; target ≥8 net-positive-after-cost sleeves
   across distinct instruments to push conservative DD well under 20% with buffer.
