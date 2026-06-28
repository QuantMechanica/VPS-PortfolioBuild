# Book-Completion Analysis — what EAs can complete the live book (2026-06-28)

4-subagent fan-out + synthesis on the question: which EAs complete the 12-sleeve live book for
live trading? Plus the two follow-up actions OWNER ratified: **A** (build stronger candidates in
the missing classes) and **B** (fix the admission methodology). Read-only analysis; the only DB
writes were the targeted enqueue + the DL-079 code fix.

## Baseline: the current book is already excellent

12 sleeves, risk-parity, real commission: **Sharpe ~2.00, mean pairwise corr ~0.00, max pair
+0.077**. MaxDD on the canonical $100k tester base (RISK_FIXED $1000 = 1%/trade) is **sub-1%**;
on the (non-canonical) $10k base it reads ~3.2% — both far under the FTMO 10% cap. The book is at
the mission's ~8-12 uncorrelated-sleeve target.

Codex also re-optimized the book EAs' params overnight (new D1-EMA + ATR-percentile filters, no
`.mq5` change); live setfiles carry them, T_Live consistent. Book improved 11→12 sleeves (12567
XAUUSD added) and Sharpe 1.74→2.00.

## Fan-out finding (unanimous across 4 angles): the one structural gap is EU equity (GDAXI)

The book is US-index + gold heavy (NDX×2, SP500, XAUUSD×3) + FX + XNGUSD. It has **no GDAXI/WS30
(EU/other equity), no XAGUSD (silver), no XTIUSD (crude oil)**. GDAXI is the highest-value,
only-immediately-addressable gap.

## But the available gap candidates do NOT improve the book

- **GDAXI EAs on hand (10115/10911/10938):** all admit on the overlap-window gate but **degrade
  the book on the authoritative full-history risk-parity basis** — they cut Sharpe 2.00→~1.89 for
  a negligible/noisy MaxDD change. They are near-breakeven (PF 1.0-1.1) and dilute a Sharpe-2.0
  book. Rejected.
- **Proven-mechanic ports to the gaps already ran and DIED at Q04** (net-of-cost walk-forward):
  12567→XTIUSD oil, 11128→GDAXI, 10940→GDAXI all Q03 PASS → Q04 FAIL. Naive porting of a proven
  mechanic does not survive the cost/robustness gates — the same Q04 wall that kills ~88%.
- **More US-index candidates (11128 NDX, 11124 SP500)** correlate ~0.5-0.6 to the existing index
  cluster → correlation-rejected. More of what the book has.

**Conclusion:** the 12-book is live-ready and at target. Forcing gap sleeves with currently
available EAs either dilutes Sharpe or dies at Q04. Genuine gap sleeves need *better, symbol-tuned*
edges — a real build effort, not seating what exists.

## B — DL-079 Sharpe-protective admission (DONE)

The admission gate's `diversifies = sharpe_improved OR maxdd_improved` admitted Sharpe-dilutive
sleeves on a noise-floor MaxDD "gain" (at $100k the book MaxDD is sub-1%, where the with/without
MaxDD delta is noise and can flip sign). Without the fix, running Q09 on 10115/10911 would have
PASS_PORTFOLIO-seated them and **degraded the live book**. Fix: `diversifies = sharpe_improved OR
(maxdd_improved AND NOT sharpe_degraded)`. Sharpe is scale-invariant and reliable while DD is far
under the cap. See [[decisions/DL-079_sharpe_protective_portfolio_admission]]. Tests 11/11.
Also repaired (again) a truncated 10440 NDX Common-Files stream (164→441 trades) that was masking
admission verdicts — recurring; a systemic durable→common sync fix is warranted.

## A — build stronger gap candidates (IN PROGRESS, mostly via the factory)

The broad gap funnel is **already saturated**: ~205 GDAXI, 261 WS30, 94 XTIUSD, 31 XAGUSD
work-items in flight (a bulk sweep enqueued ~00:52 today), including the proven mechanics. Adding
generic volume to a CPU-bound factory is low-value; the lever is surfacing/​harvesting survivors.

The one salvageable lead: **oil cum-rsi2 (12567 XTIUSD)**. Its Q04 FAIL was *not* an edge fail —
both active OOS folds were profitable (PF 999, +$423, +$726) but it traded only ~4×/3yr (D1 too
sparse; 0 trades in 2025) → below the 12-trade low-freq floor → INVALID. Action taken: a
trade-frequency tune (entry threshold 35→50, max-hold 5→8) enqueued as
`QM5_12567_..._XTIUSD.DWX_D1_backtest_tuned.set` (work-item 3b116ea4) to re-test through Q04. If
the loosened edge survives walk-forward, oil is a genuinely new asset class for the book. The
recent dormancy (0 trades 2025) is a yellow flag the gates will judge.

## Recommendation

1. Freeze the 12-book as the live-ready base (do not dilute with current gap EAs). [DL-079 enforces]
2. Let the saturated gap funnel run; harvest any survivor that reaches Q08 FAIL_SOFT and genuinely
   improves the book (DL-079 now gates correctly).
3. For genuine gap sleeves, invest in symbol-tuned hand-builds (the 12700 Balke / 12567 XAU pattern)
   — oil cum-rsi2 tune is the first; GDAXI needs a stronger edge than the PF~1.0 EAs on hand.
