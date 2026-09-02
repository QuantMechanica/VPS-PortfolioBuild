# Portfolio-Level Selection-Bias / Deflated-Sharpe Check
**Auditor task:** Wave-1 portfolio selection-bias. **Date:** 2026-09-02. **Mode:** read-only.
**Script (reproducible):** `scratchpad/wave1/deflated_sharpe.py` → `dsr_results.json`.
Method: Bailey & López de Prado (2014) *Deflated Sharpe Ratio* + Harvey–Liu (2015) Bonferroni haircut.

---

## Bottom line (HIGH → CRITICAL for both money venues)

After correcting for the true size of the search that produced them, **not one of the 24 live-book
sleeves and not one of the 21 Q11-frontier survivors has a backtest Sharpe that is statistically
distinguishable from the luckiest strategy you would expect from pure noise.** The modeled book
Sharpe of **+2.4** (I reproduce **+2.13** from the sealed streams) survives the correction at
**~0%**: it is an in-sample selection artifact, not demonstrated edge. This is exactly what a
top-of-funnel selection over ~13,400 candidates predicts, and it is the most parsimonious
explanation for the live realized Sharpe of **−3.25** — the book regressed to its true (≈0, or
negative-after-cost) edge out of sample.

**The pipeline never applies this correction.** Q08 sub-gate 8.2 (`dsr_mc_fdr`, the *only* gate
meant to deflate for multiple testing) is a **trivial "deferred until ≥1 peer" pass in 141 of 166
Q08 rows (85%)** — it structurally never fires. Q08 8.7 PBO is a per-strategy CSCV neighborhood
measure (4 perturbations), not a portfolio-level selection correction.

---

## 1. The effective number of trials N (bounding the search)

From `work_items` (SQLite, read-only). One "trial" = one (EA,symbol) pair that received a baseline
backtest evaluation at Q02.

| Quantity | Value | Source |
|---|---|---|
| Distinct (EA,symbol) pairs **attempted** at Q02 | **14,721** | `COUNT(DISTINCT ea_id\|\|symbol) WHERE phase='Q02'` |
| Distinct (EA,symbol) pairs with a **done** Q02 backtest | **13,398** | `… AND status='done'` |
| Distinct EAs (strategies) reaching Q02 done | **3,001** | `COUNT(DISTINCT ea_id) …` |
| Distinct symbols | 297 | — |
| Total Q02 runs incl. retries | 75,835 | — |
| Q03 parameter-sweep runs (further looks) | 13,187 | conditional, not counted in N |
| OPT_CENSUS cells (further looks) | 9,842 | conditional, not counted in N |

**Headline N = 13,398** distinct backtested pairs. This is *conservative* — it ignores the Q03
sweeps and the ~1,085-cell/pair Q12 pattern census, which are additional independent looks. The
DL-089 `declared_trial_count=154` (memory) is **~87× too small**: it counts one pattern census, not
the funnel that selected the survivors.

## 2. Expected maximum Sharpe under the null (SR₀)

Bailey–LdP: if you run N independent strategies with **true Sharpe = 0** over *y* years, the best one
by luck alone shows an annualized Sharpe of
`SR₀ = (1/√y)·[(1−γ)·Z⁻¹(1−1/N) + γ·Z⁻¹(1−1/(N·e))]`, γ = 0.5772. Book history y = 7.47 yr.

| N scenario | N | **SR₀ (annualized)** |
|---|---|---|
| DL-089 declared trials | 154 | 0.98 |
| distinct EAs | 3,001 | 1.30 |
| **pairs backtested (headline)** | **13,398** | **1.44** |
| pairs × ~10 param configs | 133,980 | 1.63 |

**Interpretation:** selecting the single best of 13,398 noise strategies yields an annualized Sharpe
of **≈1.44 by chance**. Any survivor whose annualized backtest Sharpe is below ~1.44 carries no
statistical evidence of edge once the search size is honestly accounted for.

## 3. Observed vs deflated Sharpe — 24 live-book sleeves

Source: sealed trade streams `D:/QM/reports/portfolio/dxz_final_20260719/QM/q08_trades/*.jsonl`
(swap=0, commission=0 — the zero-cost modeled book). Per-trade Sharpe = mean(net)/std(net);
annualized with √(trades/yr); DSR benchmark SR₀ at N=13,398; DSR = Φ((sr−sr₀)/σ̂_SR) with
López de Prado's skew/kurtosis-adjusted σ̂.

- **Book annualized Sharpe (24-sleeve, equal-notional daily, 100k): 2.13** — reproduces the modeled +2.4.
- Individual-sleeve **annualized** Sharpe: median **0.60**, max **1.24** (10919/XTIUSD, n=30).
- **Every one of the 24 sleeves has annualized Sharpe < SR₀=1.44.**
- **DSR ≥ 0.95 (survives selection correction): 0 / 24.**
- Sleeves whose per-trade Sharpe ≤ SR₀: **24 / 24.**
- Bonferroni haircut Sharpe (SR_HC): **0.000 for all 24** (Bonferroni p → 1).

Representative rows (full table in `dsr_results.json`):

| sleeve | n | sr(per-trade) | sr(annual) | sr₀ | DSR |
|---|---|---|---|---|---|
| 13213_USDJPY | 1587 | 0.071 | 0.99 | 0.099 | 0.12 |
| 13301_GDAXI | 742 | 0.097 | 1.05 | 0.144 | 0.09 |
| 10919_XTIUSD | 30 | 0.617 | 1.24 | 0.718 | 0.36 |
| 12969_USDJPY | 331 | 0.155 | 0.99 | 0.216 | 0.13 |
| 1556_XAUUSD | 53 | 0.252 | 0.70 | 0.540 | 0.02 |
| 11165_EURUSD | 260 | 0.031 | 0.18 | 0.244 | 0.00 |

## 4. Observed vs deflated Sharpe — 21 Q11-frontier survivors

Source: MT5 `report.htm` deal tables (per-closed-deal Profit column, parsed on the **same net-P&L
basis** as the book). Window 2017–2025 (~9 yr).

- Annualized Sharpe: median **0.39**, max **0.92** (20086/EURUSD).
- **DSR ≥ 0.95: 0 / 21.** Sleeves with sr ≤ SR₀: **21 / 21.**

**⚠ MT5's reported "Sharpe Ratio" is unusable and inflated ~5–11×.** On identical trade lists the
MT5 field reads 0.24–2.30 while the return-based per-trade Sharpe is 0.027–0.183. Cross-check on the
same backtest, QM5_20266/XTIUSD (n=437): MT5 Sharpe **0.57** vs return-based **0.052** (11×);
QM5_10403/XAUUSD (n=209): MT5 **0.96** vs **0.103** (9×). Any selection or reporting that trusts the
MT5 Sharpe field is reading a number an order of magnitude too high.

## 5. What fraction of the +2.4 book Sharpe survives?

**≈ 0%.** Two independent framings:

1. **Per-component:** the book's +2.13/+2.4 comes entirely from *diversification* of 24 sleeves.
   Diversification is only real if the components have real (even small) positive edge. The DSR shows
   **no component's edge is distinguishable from zero.** A portfolio of 24 individually-insignificant
   edges has expected out-of-sample Sharpe ≈ 0 (gross), negative after the swap/commission/spread the
   modeled book zeroed out. Realized **−3.25** is consistent with ≈0 gross minus costs and regime.

2. **Retained-edge multiplier:** average fraction of per-sleeve Sharpe left after subtracting SR₀ =
   **0.000** (all sr < sr₀). 2.4 × 0.000 ≈ **0.0**.

**Sensitivity (how charitable must you be for the book to survive?):** even at the most generous
N = 154 (DL-089's own declared count), only **4/24** sleeves clear SR₀=0.98 and **0/21** frontier do.
At the honest N = 13,398, **0/24 and 0/21**. The conclusion is robust across two orders of magnitude
of N.

## 6. The pipeline does not correct for this — structural gap

- **Q08 8.2 `dsr_mc_fdr`** (the multiple-testing/DSR gate): **141/166 Q08 rows (85%)** record it as
  `no_candidate_cohort_first_entry_trivial_pass … DSR deflation deferred until >=1 peer(s)`. The
  deflation is deferred to a peer cohort that is never assembled → it **never deflates**.
- **Q08 8.7 PBO**: mean 39.17 vs threshold 40 (many near the fail edge); exactly-0.00 in 9% of rows.
  It is a CSCV neighborhood measure (4 perturbations, source `Q08.5_neighborhood`), i.e. per-strategy
  overfit — **it does not and cannot correct portfolio-level selection across 13,398 candidates.**
- Net effect: the pipeline's overfit defenses are *per-sleeve*; the *portfolio selection* burden —
  the one that actually predicts the live −3.25 — is unmeasured anywhere in the gate stack.

---

## Why it matters for the money goal

- **DXZ:** the first question a DarwinIA/allocator quant desk asks is "what is your Sharpe deflated
  for the search that produced it?" The honest answer today is **~0**. Racing to 25 selection-biased,
  factor-concentrated survivors optimizes the *assembly* of an unproven product; it does not create
  edge. The live −3.25 is the market already returning this verdict.
- **FTMO:** the "positive-EV at 0.50×" claim rests on pass-probabilities derived from the *modeled*
  +2.4 series. If the true per-component edge is ≈0, P(hit +10% before −10%) collapses toward a
  coin-flip and break-even fee collapses. FTMO EV must be re-derived on deflated (or 2026-OOS) return
  stats before any purchase.

## Recommended actions

| # | Action | Who | Effort | Zone |
|---|---|---|---|---|
| 1 | Adopt the deflated-Sharpe (SR₀ at N=funnel) as a **book-eligibility input** alongside Q14-terminal count. Treat "25 pairs" as necessary-not-sufficient; a book of DSR≈0 sleeves is not allocatable. | claude-interactive → owner (ROT: adds a criterion) | 2h | ROT (new gate criterion → OWNER) |
| 2 | **Wire Q08 8.2 to actually deflate**: once ≥N peers exist (they do — 3,001 EAs), compute DSR against the real cohort instead of trivial-passing. Today it is inert in 85% of rows. | codex build / claude review | 6–8h | YELLOW (fixes an existing gate that is silently no-op; thresholds unchanged) |
| 3 | **Stop trusting MT5's Sharpe field anywhere** it is surfaced (dashboards, selection, reports) — it reads 5–11× high. Use return-based Sharpe from trade streams. | claude-headless | 2h | GREEN |
| 4 | Before any FTMO purchase Vorlage, **re-run the EV model on deflated / 2026-OOS return stats**, reporting EV as a range that spans the DSR≈0 case. | claude-headless | 4h | GREEN (feeds an OWNER money decision) |
| 5 | Add a portfolio deflated-Sharpe line to the MNT-036 edge-read: it reframes "slippage vs absent edge" — selection bias is the third, most likely answer and is knowable *today* without waiting. | claude-interactive | 1h | GREEN |

## Assumptions & limitations (explicit)

- **SR₀ null variance** taken as the theoretical `1/T` (per-trade) / `1/y` (annualized) under
  SR_true=0, normal returns. Using the empirical cross-trial dispersion of survivor Sharpes would
  *raise* SR₀ (survivors are pre-selected, so their spread understates the full-funnel spread) →
  the correction here is, if anything, **too lenient**.
- Per-trade Sharpe uses net P&L (account currency); scale-invariant, so live inverse-vol weighting
  does not change per-sleeve Sharpe. The book aggregate (2.13) is equal-notional daily on a 100k base
  and is a cross-check on the modeled +2.4, not the live-weighted book.
- Trials are treated as independent; real trials are positively correlated (same EA across symbols,
  same symbol across EAs), so the *effective* N < 13,398 and true SR₀ is modestly lower — but SR₀ is
  logarithmic in N (N=3,001 still gives 1.30; N=154 gives 0.98), and the conclusion (0/24, 0/21)
  holds down to N≈150. Correlation does not rescue the book.
- The +2.4 figure is the stated modeled book Sharpe (audit/critique); I corroborate it at +2.13 from
  the sealed streams rather than taking it on faith.
- DSR/haircut computed with a from-scratch normal CDF/PPF (Acklam) — scipy unavailable on the VPS;
  validated against the 4 EAs common to both evidence sets.

**Contrarian label:** this finding *challenges the current doctrine* that "get to 25 terminal pairs
→ book." It argues the 25-pair target, pursued without a deflated-Sharpe gate, assembles a
statistically-null product. Evidence is above; the counter-argument (diversification of many weak-but-
real edges can be real) is acknowledged and tested — and fails, because *no* component edge is
distinguishable from zero at any defensible N.
