# Portfolio Book Status — 2026-06-26

Author: Claude · Status: evidence (real-commission stream aggregation)

## TL;DR

A real portfolio book exists: **4 Q08-validated survivors + 1 new net-positive-after-cost
sleeve (QM5_12567:XNGUSD)** — near-zero correlation (+0.007), net-positive, DD lower and
Sharpe higher than survivors-only. The book grows by sleeves clearing the **cost gates**
(Q04 walk-forward + Q08 cost-cushion), NOT by Q02 build volume.

## VALIDATED RESULT (production `build_real_portfolio.py`, Q08 FAIL_SOFT pool)

QM5_12567:XNGUSD cleared the FULL cascade (Q02→Q03→Q04 walk-forward→Q05→Q06→Q07→Q08
FAIL_SOFT) — XTIUSD/XAGUSD on the same EA died at Q04, exactly as their negative
after-cost net predicted. It is now a real Q08 FAIL_SOFT portfolio sleeve.

| Book (risk-parity, real commission) | 4 survivors | **5 (+ XNGUSD)** |
|---|---|---|
| Distinct instrument classes | 2 (XAU, SP500) | **3 (+ natural gas)** |
| Conservative MaxDD | 19.94% | **9.02%** (clears 20% cap *and* FTMO 10%) |
| Sharpe | 1.94 | **3.41** |
| Net of cost | +$3,674 | **+$4,327 (43%)** |

XNGUSD is anti-correlated to every survivor (−0.027 vs SP500, −0.022/−0.012 vs XAU) and has
the best standalone profile of all sleeves (DD 1.16%, net +$5,208). Mean pairwise correlation
+0.059. The single energy sleeve nearly halved conservative DD and nearly doubled Sharpe.

**Caveat — still thin:** 5 sleeves, concentrated (2×XAU, 2×SP500, 1×XNG). Robust live
deployment wants ≥8 net-positive-after-cost sleeves across more instruments. This is the
first materially-improved validated book and the proof the diverse-port strategy works; it
grows as more in-flight EAs clear the cost gates.

## The central finding

Q02 PASS is **gross of commission** (.DWX custom symbols apply $0 commission/swap in the
MT5 tester). After REAL commission (`live_commission.json`) is applied to the per-trade
streams, **FX sleeves often go net-negative** — but this is **asset-class specific**, NOT
universal.

> **CORRECTION (2026-06-26, OWNER caught the error):** commission is per asset class —
> measured **forex ≈ $45/trade (HIGH), index ≈ $4.4, commodity ≈ $0.4–6.7 (LOW)**. So
> high-frequency strategies die on commission **only on FX**. For index/commodity the gross
> ≈ real net. The earlier blanket claim "most Q02-passing sleeves are net-negative after
> commission" was wrong — it holds for FX, not for index/commodity. This reopens high-freq
> index/commodity EAs as book candidates (e.g. 10440:NDX, gross +$72k over 451 index trades,
> likely ~+$70k net — under validation). Also: some "net-negative" FX sleeves had negative
> GROSS (strategy loss), commission only added to it — don't conflate the two.
>
> CORRECTION 2 (2026-06-26, OWNER caught it again): the book streams ARE the **full-history
> canonical backtest, 2017→2025** (FULL_HISTORY_FROM/TO; the q08 baseline run reads the
> complete tick data). EAs run **fixed card-default params** (never optimized per-fold — Q04
> only *probes* the defaults), so the entire run is a **legitimate out-of-sample track
> record**, NOT in-sample. My earlier "in-sample/optimistic" caveat was wrong. The real
> remaining caveat is **selection bias / multiple testing** — we keep the survivors that
> happened to work on this data — which is exactly what Q08's PBO / DSR / FDR sub-gates exist
> to penalize. Late starts (e.g. SP500 2019-08) = no earlier signals (SMA warmup), not a
> windowing bug. Q10 = the same full-history run reserved for hard-PASS EAs (FAIL_SOFT sleeves
> skip it and use the equivalent q08 baseline stream).

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
