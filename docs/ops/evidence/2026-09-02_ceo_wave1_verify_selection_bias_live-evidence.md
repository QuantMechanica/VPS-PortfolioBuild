# Adversarial Verification — Portfolio Selection-Bias finding, LENS = OUT-OF-SAMPLE / LIVE EVIDENCE

**Verifier task:** try hard to refute the finding. **Date:** 2026-09-02. **Mode:** read-only.
**Finding under test** (`wave1/portfolio_selection_bias.md`): *"After correcting for the true search size
(13,398 pairs), zero of the 24 live sleeves and zero of the 21 Q11-frontier survivors has a backtest
Sharpe distinguishable from the luckiest-of-noise benchmark (E[max SR]=1.44); the modeled book Sharpe
+2.4 is an in-sample selection artifact"* — with the surrounding claim that the live realized Sharpe of
**−3.25** is *"the market already returning this verdict"* and that the survivors have **zero true edge**.

**Verdict: REFUTED** — not the in-sample arithmetic (that is sound and I concede it), but the finding's
**inferential conclusion**: the out-of-sample / live evidence does **not** favour the null-edge hypothesis.
On the correct (governed-book) basis the live sample is statistically **uninformative** (Bayes factor ≈ 1–2
across all hypotheses), the finding's headline **−3.25 is mis-attributed** (it is the full account including
~−1,774 USD of untagged non-book trades), and the survivors' **held-out-year walk-forward OOS profit factors
are systematically > 1**. Correct state today: **UNDECIDABLE, leaning against zero-edge.** "Unproven" ≠
"proven null."

---

## 0. What I concede to the finding (not refuted)

- In-sample selection bias over a ~13,398-pair funnel is real; E[max SR] ≈ 1.44 annualized is the right order
  of magnitude for the luckiest-of-noise single look.
- The +2.4/+2.13 modeled book Sharpe, **by itself**, is not proof of edge.
- The book is genuinely **unproven**; Q08 sub-gate 8.2 (DSR) is largely inert. Those stand.

My refutation is confined to the claim the task foregrounds: that the survivors have **zero true edge** and
that **live evidence confirms it**. Both are overreaches on this lens.

---

## 1. The finding's "−3.25 live Sharpe" is mis-attributed to the modeled book

Primary live source (read-only): `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv`
(210 deal rows, account 4000090541, window 2026-04-24 → 2026-09-02T04:47Z). Realized net computed on **OUT**
deals (round-trip closes), `net_actual = profit+swap+commission+fee`. Reproduced with `/tmp/repro325.py`:

| Basis (since book go-live 2026-07-19) | Annualized Sharpe | N active days | Total realized |
|---|---|---|---|
| **FULL account incl. magic-0 untagged + dividends** | **−3.22** | 30 | −2,166 |
| gov + magic-0, no dividends | −3.22 | 30 | −2,169 |
| **GOVERNED sleeves only (magic ≠ 0)** | **−1.10** | 30 | **−468.89** |

The finding's −3.25 is the **full-account** figure. It includes two untagged **magic-0** positions that belong
to **no** governed sleeve (corroborated independently in `wave1/mnt036_delta_2026-09-02.md` §6):
- a **1.00-lot NDX** round-trip closing **−1,536.75** on 2026-07-27 (`[sl 28385.0]`, empty comment);
- a **0.43-lot EURUSD** close **−260.77** on 2026-07-24 (empty comment).
Together ≈ **−1,774 USD**, i.e. ~76 % of the account's since-go-live loss — a live-account **governance defect**
(manual/unlabelled trade or a magic-strip bug), *not* the 24-sleeve modeled product.

**The task's own framing instructs excluding the two untagged magic-0 trades.** On that correct basis the book
is **−468.89 USD over 81 trades / 30 active days ≈ −0.47 % on 100k**, realized Sharpe **−1.10**, not −3.25.
Per-magic breakdown (`/tmp/permagic.py`): **16 governed sleeves traded, 8 positive / 8 negative** — a coin-flip
split (best 10706/GBP +400, 13213/USDJPY +321; worst 11708/EURUSD −526, 11132/SP500 −360).

**→ The finding attributes a −1,774 untagged-position defect to "the strategies don't work."** Concrete
attribution error in its use of live evidence.

## 2. The live sample cannot distinguish any hypothesis (it is underpowered)

Governed book, since 07-19 (`/tmp/live_analyze.py`, `/tmp/bayes.py`, `/tmp/power.py`):

- Per-trade Sharpe = **−0.045**, n=81, **t = −0.41** → cannot reject 0 (p≈0.68).
- Daily annualized Sharpe = **−1.10**, N=30 active days, **SE ≈ 2.90** → **95 % CI [−6.79, +4.59]**.
  This interval contains **0, +2.13, +2.4, and strongly negative** values simultaneously.

Direct power framing (daily vol $225.6, 30 active days):

| Hypothesis | Expected 30-day P&L | Observed −469 is… |
|---|---|---|
| Modeled book +2.40 | +1,023 ± 1,236 | −1.21 σ (not significant) |
| Reproduced book +2.13 | +908 ± 1,236 | −1.11 σ |
| Zero edge (null) | 0 ± 1,236 | −0.38 σ |

Both the +2.4 model **and** the null sit inside the noise band. Bayes factors on the observed daily Sharpe
(sampling variance `(1+½θ²)/N`, Lo/Bailey):

| Comparison | Bayes factor | Reading (Kass–Raftery) |
|---|---|---|
| **NULL (0) vs MODEL (+2.4)** | **1.92** | "not worth more than a bare mention" |
| NULL (0) vs BOOK (+2.13) | 1.73 | bare mention |
| **NULL (0) vs NEG (−2.4)** | **1.03** | **zero discrimination** |
| MLE (−1.10) vs NULL (0) | 1.07 | likelihood surface flat |

To reach a **decisive** BF≥10 separating null from +2.4 would need **~200 active trading days** *if the data sat
exactly at zero* (BF: 30d→1.4, 60d→2.0, 126d→4.2, 252d→17). We have 30.

**→ The live −3.25 (or the corrected −1.10) "returns" no verdict.** The finding's own sister document says so
explicitly: `oos-2026-confirmation-feasibility.md` §5 — *"−1.3σ over ~40 days … statistically underpowered
(a handful of trades per sleeve) … does not isolate it from slippage/cost, selection bias, or the partial-book
execution problem."* That **contradicts** the `portfolio_selection_bias.md` headline that −3.25 is "the market
already returning this verdict." Internal inconsistency across the same audit wave.

## 3. Held-out-year walk-forward OOS tilts AGAINST zero edge

The pipeline's Q04 gate is a genuine **anchored walk-forward**: fold Fk trains on 2017…(2021+k) and tests on the
held-out year (2023 / 2024 / 2025). The OOS year is **not** in the fit. Evidence:
`D:/QM/reports/work_items/<id>/QM5_<ea>/Q04/<SYM>/aggregate.json.gz` `folds[].pf_net` (net of DXZ commission
6.35/lot). Extracted for all survivors (`/tmp/q04_oos.py`, `/tmp/wf_pool.py`):

- 25 survivor pairs carry Q04 WF evidence → **74 held-out-year folds**.
- **61/74 (82 %) OOS folds have PF > 1.0 net of commission.**
- OOS fold PF: median **1.344**, geometric mean **1.465**, **trade-weighted mean 1.43 over 3,442 OOS trades**.
- **24/25 pairs ≥ 2/3 OOS folds positive; 13/25 all-3-folds positive.**
- Example (frontier 11422/USDCAD): held-out PF **1.33 / 1.68 / 2.12** (2023/24/25); 20086/EURUSD **4.04/1.21/2.46**;
  live sleeve 12969/USDJPY **2.43/1.28/1.28**; 13301/GDAXI **1.07/1.50/1.43**.

**Honest caveat (I steel-manned the finding here):** these OOS folds are **inside the selection loop** — "Q04
PASS" is *defined* by good walk-forward, so conditioning on "survivor" guarantees good OOS PF; the binomial
p-values (6.97e-9 vs p₀=0.5) are therefore **not** a clean significance test of edge. But two things survive the
caveat: (a) survivors were **not** selected on a single in-sample Sharpe — so applying E[max SR]=1.44, the max of
N single-look Sharpes, to the **full-history** Sharpe deflates the **wrong statistic**; the real selection event
is "passes Q02+Q03+3-fold-WF+Q05+Q06+Q07+Q08", whose noise pass-probability ≪ 1/N; (b) a strategy delivering
PF≈1.4 net of cost across three genuinely held-out years is **not** the signature the "zero true edge" claim
predicts.

## 4. Earlier forward periods — non-confirmatory to positive

- **Pre-go-live governed** (2026-06-29…07-17, `/tmp/pregolive.py`): 11 OUT deals, net **+1,708.58** — but tiny n
  and dominated by 10440/NDX **+1,492.77** (a sleeve that itself carries a Q10 FAIL, per mnt036 §4). Uninformative,
  but **positive**, not negative.
- **FTMO 100k trial** (`ftmo_trial_pulse.json`): **PARKED** (OWNER-DEC-FTMO-PARK-UNTIL-25), equity **99,835.97**
  (−0.16 %), 0 open positions. No active forward signal to evaluate.

Neither earlier period confirms the null; if anything both lean flat-to-positive.

---

## 5. Conclusion on the null-edge hypothesis (OUT-OF-SAMPLE / LIVE lens)

| Evidence stream | Verdict on "zero true edge" |
|---|---|
| Live governed book (corrected, 30d, 81 trades) | **Undecidable** — CI [−6.8,+4.6], BF≈1–2 |
| Full account incl. untagged (finding's −3.25) | **Inadmissible** — 76 % is a non-book governance defect |
| Q04 walk-forward held-out years (74 folds) | **Leans against** zero edge (82 % PF>1; caveat: selection-conditioned) |
| Pre-go-live forward + FTMO trial | Non-confirmatory (flat-to-positive) |

The null-edge hypothesis is **NOT favoured** by any genuinely out-of-sample stream. It is **undecidable** today,
**leaning against** via walk-forward. The finding conflates *absence of evidence for edge* (true; the book is
unproven) with *evidence of absence of edge* (false on this evidence). Its live-confirmation claim rests on a
mis-attributed −3.25 and a 30-day sample with no discriminating power.

## 6. Cheapest decisive test (agreement point)

Both my analysis and the finding's sister document converge: the **2026-Q1 OOS diagnostic**
(`2026-01-01 … 2026-04-06`, deployed binaries, ~**55 runs ≈ 2.5–3 terminal-hours**, `diagnostic_non_admission`,
plan-dry-run first). It is genuinely **post-selection** (later than every 2017–2025 gate window), carries **zero
live-execution / untagged-trade noise**, and diffs each sleeve's 2026 PF/expectancy against its sealed 2017–2025
stats — the only clean way to separate "strategies stopped working" (regime decay / true null) from "live
execution & untagged-position problems." That test, not the 30-day live tape, decides the null.

---

## Reproducibility

- `/tmp/q04_oos.py` → `/tmp/q04_oos_results.json` (Q04 WF OOS PF per survivor); `/tmp/wf_pool.py` (pooled).
- `/tmp/live_analyze.py`, `/tmp/permagic.py`, `/tmp/repro325.py`, `/tmp/bayes.py`, `/tmp/power.py`
  (live governed-book stats, per-magic split, −3.25 reproduction, Bayes factors, power).
- Sources: `live_deals_normalized.csv` (T_Live, read-only), `live_book_pulse.json`,
  `live_book_dd_guard_state.json`, `ftmo_trial_pulse.json`, `D:/QM/reports/work_items/*/Q04/*/aggregate.json.gz`,
  `farm_state.sqlite` (RO). Cross-checks: `wave1/mnt036_delta_2026-09-02.md`,
  `wave1/oos-2026-confirmation-feasibility.md`.
