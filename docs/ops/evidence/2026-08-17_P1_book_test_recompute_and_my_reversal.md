# P1 — The U bucket resolved (26% → 98%), and both of my strategic conclusions were wrong

## Resolving the U bucket without the missing field

`corr_eff` is unrecoverable: `corr_full` and `corr_regime` are absent in **all 29** old-schema
aggregates, and `corr_eff` is their maximum. So it cannot be reconstructed.

But the question `corr_eff` was being used to answer — *do these fail on redundancy or on
contribution?* — is answerable from what **is** stored. `sharpe_with/without` and
`maxdd_with/without` are present in 28 of 29, and the middle-zone rule is exactly a function of
those four numbers. Recomputing the book test:

| Inference | Pairs |
|---|---:|
| **fails the book test → contribution failure** | **42** |
| passed the book test yet rejected → redundancy (`corr_eff ≥ 0.40`) | 3 |
| insufficient fields | 1 |

**Coverage went from 17/66 (26%) to 45/46 of the readable set (98%), i.e. 45/66 = 68% of all
rejections.** The remaining 21 are the 20 with no evidence file (see P2) plus one with
insufficient fields. Artifact: `artifacts/portfolio_book_test_recompute_20260817.json`.

That is the answer to P3.1 with a defensible base: **rejection is overwhelmingly about
contribution, not redundancy — 42 against 3.**

## The finding I was about to report, and why it is wrong

The recomputation surfaced 19 pairs that **improve** book MaxDD yet were rejected because Sharpe
fell, some at a trivial-looking Sharpe cost:

```
QM5_1551  USDJPY   maxdd 0.3061 -> 0.2957  (-0.0103)   sharpe -0.0013
QM5_10291 SP500    maxdd 0.2194 -> 0.1967  (-0.0227)   sharpe -0.0038
QM5_9403  GDAXI    maxdd 0.2511 -> 0.2358  (-0.0153)   sharpe -0.0042
```

I was about to report that the admission rule is Sharpe-first while both books are
drawdown-constrained, and that this mis-calibration rejects candidates improving the very
dimension DZ (5%/20% DD) and FTMO (daily loss) are limited on.

**That conclusion is wrong, and the unit is why.** `portfolio_kpi.max_drawdown_pct` returns
`(peak − equity) / peak * 100.0` — a genuine percentage. So `maxdd_without = 0.2982` is
**0.2982 %**, not 29.82 %. Book MaxDD is **sub-1%**, and my 19 "improvements" are gains of
0.01–0.03 **percentage points** on a sub-1% figure.

Worse for my case: the code answers this objection in advance. `portfolio_admission.py`
carries the DL-079 rationale (OWNER-ratified 2026-06-28):

> *"The book is a high-Sharpe risk-parity portfolio whose MaxDD already sits FAR under the FTMO
> cap, so MaxDD headroom is abundant and a marginal MaxDD 'improvement' is not worth a Sharpe
> cost. On the canonical $100k base the book MaxDD is sub-1%, where the with/without MaxDD delta
> is dominated by which single day the peak lands on (noise) and can flip sign. The OLD rule
> `sharpe_improved or maxdd_improved` admitted Sharpe-DILUTIVE sleeves (e.g. 10115/10911 GDAXI:
> PF~1.0-1.1, they cut book Sharpe 2.00->1.89) on such a noise-floor MaxDD gain. Fix: a candidate
> diversifies iff it improves Sharpe, OR improves MaxDD WITHOUT degrading Sharpe. … (If DD ever
> approaches the cap, revisit to allow a DD-for-Sharpe trade in that DD-constrained regime.)"*

So the rule is a **deliberate fix for the exact failure I was about to champion**, it names the
sleeves that motivated it, and it states its own revisit condition — *if DD ever approaches the
cap*. That condition is **not met**: ~0.3% book MaxDD against a 5%/20% DZ cap is three orders of
magnitude of headroom.

The rule is also not zero-tolerance, as I assumed when recomputing: `SHARPE_DEGRADE_EPS = 1e-3`.
My recomputation used strict `>=`, marginally stricter than the code. The 42/3 split is
unaffected at that magnitude, but the assumption was wrong and is corrected here.

## What this reverses

**Two of my own conclusions fall, one from the previous round and one from the round before:**

1. **"The binding constraint is diversity."** Wrong. Only 3 of 45 rejections are redundancy.
2. **"The actionable target is book-MaxDD contribution at neutral Sharpe, and
   `return_to_maxdd` is the objective that would admit these."** Wrong, and for the same reason:
   with sub-1% book DD, `return_to_maxdd` improvements are noise-dominated too.

And it **answers a question I had escalated to OWNER as the central unblock**:
`VOL_REGIME_FILTER` requires `min_max_drawdown_pct = 12`. I reported that as a possible
mis-calibration because the survivor population tops out at 9.81%. It is not a
mis-calibration — the floor exists **precisely because** the objective is noise below it. No
candidate qualifying is the floor working, not failing.

**Recommendation for that decision, reversed: do not lower the 12% floor.** The correct reading
is that `VOL_REGIME_FILTER` has no admissible target because this book and its candidates are
low-drawdown by construction, which is a good property, not a blocked lever.

## What the real constraint is

With redundancy and drawdown both eliminated, what remains is plain and more sobering:

> **The pipeline is producing candidates that dilute a Sharpe-2.8 book.** 42 of 45 classifiable
> rejections fail because the candidate makes the book worse on the only metric that is not
> noise at this scale.

That points the optimisation lever at **Sharpe contribution** — not decorrelation, not drawdown.
A candidate is admissible if it raises book Sharpe, and the existing `EXIT_SURGERY` objective
(`annual_return_pct`) is a reasonable proxy only insofar as return improvements survive the
volatility they add. That is worth stating in the P8/P10 hypothesis work: **the falsification
criterion for a cohort entry should include "does not degrade book Sharpe", because that is what
the gate will actually test.**

## Method note

This correction exists because of two rules applied to my own analysis: *units belong to the
number*, and *check whether the missing quantity can be derived before declaring it
unclassifiable*. The first caught a wrong conclusion before it was reported; the second turned a
26% base into 98%. Neither required new measurement — only reading the code that produces the
number rather than trusting its name.

## Evidence

- `artifacts/portfolio_book_test_recompute_20260817.json` — the 45 classifications
- `artifacts/portfolio_rejection_zones_20260817.json` — the corr-based zone attempt it supersedes
- `tools/strategy_farm/portfolio/portfolio_kpi.py:126-140` — `max_drawdown_pct`, the unit
- `tools/strategy_farm/portfolio/portfolio_admission.py:392-420` — `diversifies`, DL-079
  rationale and `SHARPE_DEGRADE_EPS`
