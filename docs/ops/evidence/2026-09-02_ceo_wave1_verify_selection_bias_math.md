# Adversarial verification — Portfolio selection-bias / Deflated-Sharpe finding
**Lens:** MATH / METHOD. **Mode:** read-only, independent re-derivation. **Date:** 2026-09-02.
**Verdict: NOT REFUTED (finding CONFIRMED).** The math is correct, the units are handled correctly,
and the `0/24` and `0/21` conclusions are robust across every defensible choice of N and every
defensible annualization basis. My scripts:
`verify_recompute.py`, `verify_flip_and_frontier.py` (this dir).

---

## 1. What I re-derived from scratch (not trusting the report's script)

I re-read `deflated_sharpe.py`, then wrote two independent scripts that recompute everything from the
sealed streams and the DB, with my own moment/Sharpe/E[max]/DSR code.

### 1a. Trial census N — reproduces exactly
Independent DB query (`file:...farm_state.sqlite?mode=ro`, `PRAGMA busy_timeout=30000`):
| quantity | report | my query |
|---|---|---|
| distinct (EA,symbol) pairs done at Q02 | 13,398 | **13,398** |
| distinct pairs attempted | 14,721 | **14,721** |
| distinct EAs done | 3,001 | **3,001** |

Headline **N = 13,398** is correct and is a genuine lower bound (it excludes the 13,187 Q03 sweep
runs and 9,842 OPT_CENSUS cells, which are additional independent looks).

### 1b. Bailey–López de Prado E[max SR] — formula and implementation correct
`E[max SR] = σ · [(1−γ)·Z⁻¹(1−1/N) + γ·Z⁻¹(1−1/(N·e))]`, γ=0.5772. The argument of the second term
is `1−1/(N·e)` (correct; = `1 − N⁻¹e⁻¹`). Reproduced `E[max SR]_annual = 1.438` at N=13,398 (report:
1.44). Acklam PPF / erf-based CDF validated against known quantiles.

### 1c. Book and sleeve Sharpes — reproduce exactly
| metric | report | my recompute |
|---|---|---|
| book annualized Sharpe (equal-notional daily, √252) | 2.13 | **2.126** |
| sleeve annualized Sharpe (per-trade × √tpy): median / max | 0.60 / 1.24 | **0.599 / 1.242** (max 10919_XTIUSD) |
| book sleeves DSR≥0.95 | 0/24 | **0/24** |
| book sleeves per-trade sr ≤ sr₀ | 24/24 | **24/24** |
| frontier ann Sharpe median / max | 0.39 / 0.92 | **0.394 / 0.923** (max 20086/EURUSD) |
| frontier DSR≥0.95 | 0/21 | **0/21** |
| frontier sr ≤ sr₀ | 21/21 | **21/21** |

Every headline number reproduces. This is not a case of a mis-stated result.

---

## 2. The units question (the task's central suspicion) — the report is CORRECT

The task flagged: *"the report used y=7.47yr — check its units … daily obs ≈ 2,270 days."* I settled this
definitively. **E[max SR] must be in the same units as the observed Sharpe it is compared to.**

- For an **annualized** SR estimate, the null standard error is `σ_ann = √f / √T = √f / √(f·y) = 1/√y`
  (y in **years**), because annualizing multiplies SR by √f and its variance by f, and T = f·y. So the
  report's `σ = 1/√7.47` for the annualized E[max SR] is the **mathematically correct** choice, **not** a
  units bug. The hypothesized "should have used T=2,270 days" error **does not exist**: 2,270 would be
  the right T only if you worked in **per-day** units and compared to a **per-day** observed Sharpe
  (~0.05), which the report never does.
- For the **per-trade** DSR (the actual `0/24` verdict), the report uses `σ = 1/√T` with T = n_trades,
  compared to the per-trade Sharpe. Units consistent.
- I checked for the classic cross-unit mistake (annualized observed vs non-annualized null, or vice
  versa). **The report never mixes them.** §3's "annualized < 1.44" is annualized-vs-annualized; its
  "per-trade sr ≤ sr₀" and DSR column are per-trade-vs-per-trade. Clean throughout.

Cross-check of the number's stability across annualized conventions (my `verify_recompute.py`):
| null σ convention | E[max SR] @ N=13,398 |
|---|---|
| `1/√y`, y=7.47 (report) | 1.438 |
| `√252/√T_cal`, T_cal≈2,731 daily obs (task's suggested track length) | **1.194** |

Even the task's alternative track-length gives 1.19, and the correctly-computed daily observed Sharpe
(§3 below) maxes at 0.87 — still below. The verdict is invariant to this choice.

---

## 3. The one way to "break" the finding — and why it is an invalid method

The task asked specifically for the **daily-returns √252** recompute. There are two variants, and the
distinction is the whole game:

| observed annualized Sharpe basis | median | **max** | E[max SR]@13,398 | flips? |
|---|---|---|---|---|
| per-trade × √(trades/yr) *(report)* | 0.599 | 1.242 | 1.438 | **no (0/24)** |
| daily over **all calendar days** × √252 *(clean)* | 0.490 | **0.873** | 1.194 | **no (0/24, stronger)** |
| daily over **active days only** × √252 | 1.668 | **10.184** | 6.403 | yes — but method invalid |

Only the **daily-active-only** basis flips it, and it is a **degenerate/invalid annualization**: it
computes a daily Sharpe over only the days a sparse strategy traded, then annualizes by √252 as if there
were 252 such days per year. For 10919_XTIUSD (n=30 trades) this yields an absurd 10.18. A competent quant
uses either the per-trade basis or the daily-all-calendar basis (flat days = 0 return) — and **both of
those confirm the finding**, the daily-all-calendar basis even more decisively (max 0.87 ≪ 1.19). So the
"daily √252" recompute the task asked for does **not** overturn the finding; done correctly it strengthens
it.

---

## 4. At which N would `0/24` flip? — it doesn't, at any defensible N

Two metrics, both computed in `verify_flip_and_frontier.py`:

- **DSR ≥ 0.95 (the report's headline metric, SE-adjusted):** `0/24` for **every N from 50 to 50,000**.
  The best sleeve's DSR peaks at **0.770 (N=50)** and never reaches 0.95. Algebraically, the luckiest
  sleeve (10919, n=30) needs N ≤ ~15 to reach DSR 0.95 — i.e. you'd have to pretend fewer than ~15
  strategies were ever tried. **Impossible to flip at any honest N.**
- **Point-screen (per-trade sr > sr₀, no SE):** 5/24 at N=50 → 3/24 at N=154 → 1/24 at N=1,000 →
  **0/24 at N≥3,001**. The honest N=13,398 is an order of magnitude past the flip. The report's §5
  sensitivity ("4/24 clear SR₀ at N=154") refers to this point-screen and is honestly disclosed; it is a
  *point-estimate* screen, not the DSR, and it too collapses to 0 well below the true N.

Frontier: DSR `0/21` and sr≤sr₀ `21/21` at N=13,398; max annualized 0.923 < any null down to N≈100.

---

## 5. Minor report errors I found — none change the conclusion

1. **"zero-cost modeled book (swap=0, commission=0)" is factually wrong.** The `net` field the Sharpe is
   built on already bakes in commission (Σ = **−40,253**, 19/24 sleeves) and swap (Σ = **−7,002**,
   14/24 sleeves). So book Sharpe 2.126 is already **post-commission-and-swap** (only spread/slippage is
   plausibly absent). This weakens one *secondary* sentence in §5 ("negative after the swap/commission/
   spread the modeled book zeroed out") — two of those three costs are already inside net — but the DSR
   selection-bias math is computed on net either way and is untouched.
2. **MT5 Sharpe inflation is 11–22×, not "5–11×".** On identical deal lists: 20086/EURUSD MT5 2.30 vs
   return-based 0.126 (**18×**); 20086/NDX 21.7×; 10911/GDAXI 20.2×. The report *understated* the
   inflation; its recommendation to stop trusting the MT5 Sharpe field is, if anything, more warranted.

---

## 6. Methodological soundness of the DSR construction itself

- Using **V = 1/T** (theoretical null variance of one SR estimate) as σ in E[max SR], rather than the
  empirical cross-sectional dispersion of the 13,398 trial Sharpes, is **conservative** (lenient toward
  the strategies): heterogeneous track lengths + heterogeneous true edges make the empirical dispersion
  larger than 1/√T, which would *raise* the bar. The report states this correctly in its limitations.
- **Trial correlation:** treating N as independent overstates N; positive correlation lowers effective N
  and SR₀. But SR₀ is logarithmic in N (N=3,001→1.30, N=154→0.98) and the SE-adjusted DSR is 0/24 down to
  N=50, so correlation cannot rescue the book. Correct.
- **Absence-of-evidence vs proof:** the strict statistical statement is "no component edge is
  distinguishable from zero after selection correction," which does not *prove* zero edge. The report's
  "in-sample selection artifact" phrasing is mildly stronger than the pure test warrants — but it is
  corroborated by the **out-of-sample live realized Sharpe of −3.25**, which is the market supplying the
  missing confirming evidence. The conclusion is well-supported, not an overreach.

---

## 7. Verdict

**refuted = false.** I tried to break the finding on its strongest math/method seams — a units bug in the
annualized null (none: 1/√y is correct), an annualization basis that lifts survivors over the bar (only
the invalid daily-active-only basis does; both defensible bases confirm), and an N at which the verdict
flips (the DSR never flips for N≥~15; the point-screen flips only below N≈3,000, far under the honest
13,398). All core numbers reproduce to 3 significant figures. The two errors I did find (the "zero-cost"
mischaracterization and the understated MT5-inflation multiple) are peripheral and, if anything, cut in
the finding's favor. The selection-bias / deflated-Sharpe conclusion — **0/24 sleeves and 0/21 frontier
survivors have a Sharpe distinguishable from best-of-noise, and the +2.4/+2.13 book Sharpe is not
demonstrated edge** — is mathematically sound and robust.

Confidence: **0.90.**
