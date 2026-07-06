# Selection-Bias Quantification of the Live Book — PSR / DSR / MinTRL (2026-07-06)

**Question (Fable program #2):** we selected 15 live sleeves out of thousands of
trials. How much of the book's Sharpe 2.03 survives an honest deflation for
selection bias (Bailey & López de Prado: Probabilistic / Deflated Sharpe Ratio)?
This computation did not exist anywhere in the pipeline (the existing
`pbo_calculator.py` is CSCV at the per-EA sweep level, Q08.7).

**Artifacts:** `D:\QM\strategy_farm\artifacts\portfolio\book_dsr_2026-07-06\`
(`book_dsr_results.json`, `book_dsr_compute_2026-07-06.py`). Series = the S3
15-sleeve frozen-stream composite, **validation-anchored**: the rebuilt daily
series reproduces the ratified Sharpe to 2.027059 (±0.001 tolerance) and MaxDD
5.156 — same machinery, same convention. Spot-checked by hand (PSR z=5.53,
worst-case SR0=1.52 ann) before publication.

## Results

**Book series:** T=1826 daily obs (2017-10..2025-12), daily SR 0.1277 (ann 2.027),
skew **+0.39** (positive — the good side), excess kurtosis +3.05.

**PSR** — probability the true Sharpe exceeds SR*, given the track's own noise
(non-normality-adjusted):

| SR*_ann | 0.0 | 0.5 | 1.0 | 1.5 |
|---|---|---|---|---|
| PSR | 0.99999998 | 0.99998 | 0.997 | **0.925** |

**DSR** — PSR against SR0 = the Sharpe the LUCKIEST of N zero-edge trials would
be expected to show. N-grid spans every defensible trial count; V (cross-trial
SR variance) in 4 variants (null-model + 3 empirical estimates from the 37
Q09-evaluated candidates):

| N (meaning) | worst variant DSR |
|---|---|
| 37 (Q09-evaluated) | 0.9994 |
| 130 (Q09 pool) | 0.997 |
| 949 (Q04-attempted EAs) | 0.982 |
| 2,253 (all EAs through Q02) | 0.967 |
| **12,523 (every EA×symbol trial ever)** | **0.916** |

Even treating the book as the single luckiest pick out of every trial the farm
ever ran, with the most punitive variance variant: **≥92% probability the edge
exceeds what luck alone would produce.**

**Model honesty — where the deflation model bends in our favor and against us:**
- *Conservative for us (all three structural):* DSR models best-of-1-from-N;
  the book is a **portfolio of 15** (independent-ish picks + diversification —
  its Sharpe is not one lucky draw). Trials are heavily correlated (12.5k
  EA×symbol pairs share 2,253 EAs, shared symbols/windows), so effective N is
  far below 12.5k. And selection was NOT Sharpe-maximization: most gates select
  on mechanism/cost/frequency/correlation, which BLdP deflation over-penalizes.
- *Against us:* the empirical V comes from Q09 survivors (dispersion compressed
  by the shared book component). **Break-even inversion:** DSR falls to 0.50
  only if the honest cross-trial annual-SR dispersion were ≥0.52 AND selection
  were pure max-SR over 12.5k independent trials. Observed survivor dispersion
  is 0.39; the independence and max-SR premises are both false in our process.
  Conclusion stands: **selection bias does not plausibly explain this book.**

**MinTRL — the operationally new result:** minimum LIVE track needed to confirm
SR at 95% (using the book's moments):

| confirm | daily obs | ≈ months |
|---|---|---|
| SR > 0 | 162 | 7.7 |
| SR > 0.5 | 285 | 13.6 |
| SR > 1.0 | 629 | 30.0 |

**→ The 42-day probation review cannot statistically confirm ANY Sharpe level**
(even SR>0 needs ~162 trading days). Policy implication (recommended, no gate
change): reframe the 42d review as what it can actually test — gross-defect /
behavioral-conformance / trade-frequency-vs-backtest checks — and note that the
now-repaired KS distribution kill-switch (audit A1/D1) is precisely the right
instrument for early live-vs-backtest divergence, needing far fewer observations
than SR confirmation. Weight promotion at 42d should cite behavior, not SR.

**Per-sleeve context:** 5 of 15 sleeves cannot individually reject SR≤0 at 90%
on their own monthly tracks (10513/XAU, 10911/GDAXI, 11132/SP500, 11421/AUDUSD,
11421/EURUSD) — expected for low-frequency sleeves; their evidence lives at book
level. Implication for challenger-swap decisions: a weak STANDALONE track is not
by itself a demotion argument for these — and symmetric caution on promotions.

**FTMO relevance:** PSR(SR*>1.5) = 0.925 — the book very likely runs a true
Sharpe above 1.5. Nothing in the deflation argues for reducing the ratified
Two-Speed scale plan; the risk to challenge outcomes remains path/DD risk (MC
studies), not edge-existence risk.

**Caveats recorded:** series convention excludes ~240 zero-activity trading days
(inherited from the ratified machinery — anchor fidelity chosen over convention
debate; direction of effect noted in artifacts); Q08-level empirical V not
computable (ea_metrics carries no sharpe at Q08); Q09-based V variants span
2.2×, DSR conclusion robust across all of them.
