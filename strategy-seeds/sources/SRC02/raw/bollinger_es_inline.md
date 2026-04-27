---
source_id: SRC02
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf"
extracted_section: "Inline Bollinger-band ES mean-reversion example (Chapter 2, 'How Will Transaction Costs Affect the Strategy?', pp. 22-23)"
book_pages: "22-23 (in Ch 2 'Fishing for Ideas')"
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# SRC02 raw evidence — Bollinger-band ES mean-reversion (inline example)

This file captures the verbatim text + mechanical-structure derivation for Chan's **inline ES Bollinger-band mean-reversion example**, which appears in Ch 2 "Fishing for Ideas" § "How Will Transaction Costs Affect the Strategy?" (book pp. 22-23). The example is **not labeled** Example 3.x by Chan — it is an in-flowing illustration of the transaction-cost effect, immediately preceding the cross-reference to Example 3.7. Because it has fully-specified entry / exit rules and explicit pre-cost / post-cost Sharpe numbers, it qualifies as a distinct mechanical strategy under DL-033 Rule 1.

The corresponding card lives at `strategy-seeds/cards/chan-bollinger-es_card.md`.

---

## A. Verbatim quote (book pp. 22-23, in Ch 2 § "How Will Transaction Costs Affect the Strategy?")

Source raw file: `raw/ch3_backtesting_pp31-73.txt` lines 612-624 (file extracts PDF pages 31-73 in PDF-page order, which actually maps to book pp. 12-66 due to front-matter Roman pagination).

> "If you are trading S&P 500 stocks, for example, the average transaction cost (excluding commissions, which depend on your brokerage) would be about 5 basis points (that is, five-hundredths of a percent). ... If you are trading ES, the E-mini S&P 500 futures, the transaction cost will be about 1 basis point. Sometimes the authors whose strategies you read about will disclose that they have included transaction costs in their backtest performance, but more often they will not. If they haven't, then you just to have to assume that the results are before transactions, and apply your own judgment to its validity.
>
> As an example of the impact of transaction costs on a strategy, consider this simple mean-reverting strategy on ES. It is based on Bollinger bands: that is, every time the price exceeds plus or minus 2 moving standard deviations of its moving average, short or buy, respectively. Exit the position when the price reverts back to within 1 moving standard deviation of the moving average. If you allow yourself to enter and exit every five minutes, you will find that the Sharpe ratio is about 3 without transaction costs—very excellent indeed! Unfortunately, the Sharpe ratio is reduced to −3 if we subtract 1 basis point as transaction costs, making it a very unprofitable strategy.
>
> For another example of the impact of transaction costs, see Example 3.7."

(p. 22 last paragraph through p. 23 second paragraph; running headers "22 QUANTITATIVE TRADING" and "Fishing for Ideas 23" preserved in the raw file.)

## B. Mechanical structure (Research-decoded)

### B.1 What Chan specifies

| Element | Specification |
|---|---|
| Universe | ES — E-mini S&P 500 futures, CME |
| Bar | 5-minute (Chan: "If you allow yourself to enter and exit every five minutes") |
| Indicator | Bollinger bands — a moving average and ±2 moving standard deviations of price |
| Long entry | price < MA − 2·σ |
| Short entry | price > MA + 2·σ |
| Exit | "Exit the position when the price reverts back to within 1 moving standard deviation of the moving average" — i.e., \|price − MA\| ≤ 1·σ |
| No stop-loss | not specified (Chan's general anti-stop-loss-on-MR-models stance, Ch 7 p. 143, applies by default) |
| Pre-cost Sharpe | ≈ +3 |
| Post-cost Sharpe | ≈ −3 (with 1 bp transaction cost) |

### B.2 What Chan does NOT specify

| Underspecified element | Default to assume in card |
|---|---|
| Moving-average **lookback period** N (the bandwidth window) | **Bollinger's textbook default is 20 bars** (Bollinger 2001); flag as primary P3 sweep axis. Chan provides no value. |
| Whether MA is simple or exponential | **Simple moving average** (Bollinger's textbook convention; Chan's `mean(spread(trainset))` in Ex 3.6 also uses arithmetic mean) |
| Whether σ is sample (N−1 denominator) or population (N denominator) | **Sample std** (standard convention; matches Chan's `std()` in Ex 3.6 MATLAB) |
| Bar-close vs intra-bar trigger | **Bar-close trigger** (consistent with Chan's "allow yourself to enter and exit every five minutes" — implies signal eval on the M5 close) |
| Position size | Not specified; V5 maps to standard risk-mode framework at sizing-time |
| Stop-loss | Chan's Ch 7 p. 143 verbatim disposition: "a stop loss in this case [reversal model] often means you are exiting at the worst possible time. ... it is much more reasonable to exit a position recommended by a mean-reversal model based on holding period or profit cap than stop loss." Default: NO native stop-loss; rely on V5 framework kill-switch. |

### B.3 Performance framing

This is a **deliberate failure example** — Chan introduces it specifically to demonstrate that high-Sharpe pre-cost strategies can collapse into negative-Sharpe strategies under realistic 1 bp transaction costs at high trading frequency. The strategy fires every time the M5 close pierces the ±2σ band; estimated trade frequency at high noise levels is several entries per session, so 1 bp × ~50-200 round-trips per day = ~50-200 bp/day in costs, which exceeds the per-trade reversion edge.

→ **Pipeline implication**: this card is **expected to fail at P9b Operational Readiness** when realistic Darwinex `US500.DWX` spreads are applied (typical 0.5-2 points on a ~5000 quote ≈ 1-4 bp; broadly matches Chan's 1-bp assumption). G0 / P2 / P3 may pass on noise-free data; P9b is the genuine gate.

### B.4 V5 deployment mapping

| Chan's universe | V5 Darwinex equivalent | Notes |
|---|---|---|
| ES (E-mini S&P 500 futures, CME, $50/index-point contract) | `US500.DWX` (Darwinex CFD on the S&P 500 index) | Tick-size and contract-size differ; CTO confirms at G0 sanity-check. |

## C. Cardability verdict per DL-033 Rule 1

| Filter | Verdict |
|---|---|
| Mechanical (no discretionary judgment) | ✓ pass — Bollinger ±2σ entry / ±1σ exit is a deterministic rule |
| No Machine Learning | ✓ pass — moving average + std are classical statistics |
| No martingale / grid | ✓ pass — one position at a time; no escalation |
| No paywall bypass | ✓ pass — own-source extraction |
| No `.DWX`-suffix violation | flag — ES needs explicit re-mapping to `US500.DWX` at CTO sanity-check (`dwx_suffix_discipline` in `hard_rules_at_risk`) |
| `scalping` (V5 hard rule §11 allowability) | **borderline** — M5 with average ~1-3 bar hold qualifies as "very-short-hold" per `strategy_type_flags.md` § E `scalping` definition; **P5b VPS-realistic latency calibration required** (V5 admits scalping but mandates P5b stress) |
| Source-spec completeness | acceptable — only the lookback period N is unspecified, treatable as a P3 sweep axis |

**Verdict: CARDABLE.** Differs from Davey's Ch 1 hogs-triple-MA SKIP (which had no entry/exit rules at all) — Chan provides full entry/exit logic, just leaves the bandwidth lookback open.

## D. Vocabulary-gap note (carries forward from S01)

Section A of `strategy_type_flags.md` has no flag for "Bollinger band reversion" / "z-score band reversion on a single-leg series." The closest available descriptors are:

- `n-period-min-reversion` — wrong (uses N-bar MIN, not N-bar MA + Nσ band)
- the `signal-reversal-exit` flag from Section B fits the EXIT side (z reverts back across the entry threshold)

S01 already proposed the gap-filling pair `cointegration-pair-trade` (entry) + `mean-reach-exit` (exit). Bollinger ES adds a third needed flag: an entry flag for **single-leg z-score-band reversion** (call it `zscore-band-reversion` or `bollinger-band-reversion`). Research will batch-propose all three gap-filling flags to CEO + CTO once a third example surfaces — currently the count is two SRC02 cards needing the same vocabulary additions.

For now the S02 card uses `signal-reversal-exit`, `mean-reversion`-equivalents from the closest available flags (none ideal), `symmetric-long-short`, and `scalping` from § E.
