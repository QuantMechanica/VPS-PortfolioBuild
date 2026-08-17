# P0 — The portfolio arm, and why it is the actual bottleneck (2026-08-17)

## 1. The portfolio layer is not a blind spot. It is the largest subsystem in the repo.

I have written in two prior reports that the portfolio level "does not exist" as a built
layer. **That was wrong.** `tools/strategy_farm/portfolio/` holds roughly **160 modules**,
including working builders for *both* books under the DL-084 contract.

Mapping the proposed PB01–PB08 against what is already there:

| Proposed | Already exists |
|---|---|
| **PB01** candidate pool | `portfolio_admission.py` (1,110 lines), `portfolio_manifest.py`, `portfolio_freeze_gate.py` ("fail-closed truth-chain and input-SHA gate") |
| **PB02** sizing layer | `book_sizing.py` ("at the REAL deployed per-trade risk basis"), `portfolio_resize.py` (994 lines, hierarchy-capped, Darwinex Zero), `stage_tlive_presets_risk.py` |
| **PB03** path metrics | `portfolio_kpi.py`, `ftmo_phase1_mae.py` (intraday-DD via MAE reconstruction), `dormancy_exposure.py`, `ftmo_timebox_eval.py` |
| **PB04** correlation + tail coupling | **`portfolio_correlation.py`**, `sleeve_correlation.py`, `ftmo_decorrelation_test.py` — and it is already a **hard gate**, see §2 |
| **PB05** objective + stop rule | `fund_score.py`, `marginal_contribution_eval.py` (596 lines, DL-082 §4), `sleeve_improvement_targets.py` (OWNER 60/30 KPI) |
| **PB06** greedy selection by marginal contribution | `marginal_contribution_eval.py`, `book_reoptimizer.py`, `challenge_book_60d.py`, `runner_satellite_composer.py` |
| **PB07** compliance simulation | `ftmo_rules_engine.py` (1,188 lines, "the FTMO rule as FTMO actually writes it"), `ftmo_p1_mc.py` (933-line Monte-Carlo), `challenge_firstpassage.py`, `ftmo_governor_policy_v2.py` |
| **PB08** deployment path | `build_book_dxz.py`, `build_book_ftmo.py`, `portfolio_live_forward_from_logs.py`, `stage_tlive_presets_risk.py` |

**Every PB item has an existing counterpart.** The Portfolio Build must therefore be a
*reconciliation and gap-closing* exercise, not a green-field build. What is genuinely missing
is not modules but the answer to "which of these is authoritative, and do they agree" — the
same authoritative-source question that produced today's `ea_metrics` measurement error.

## 2. What Q09_PORTFOLIO actually checks

It is a **correlation-zoned marginal-contribution admission gate**, not a KPI threshold.
`q09_portfolio.py` delegates to `portfolio_q08_contribution.py`, whose verdict is one line:

```python
verdict = "PASS_PORTFOLIO" if admission.get("admit") else "FAIL_PORTFOLIO"
```

and `portfolio_admission.py` implements the DL-083 calibration:

- **`corr_eff` = the stricter (max) of the full-sample and high-volatility-regime**
  candidate-versus-book Pearson correlation;
- `corr_eff >= CORR_REJECT_MIN = 0.40` → **REJECT** (redundant or crisis-correlated);
- `corr_eff < CORR_ADMIT_MAX = 0.15` **and** positive marginal contribution → **ADMIT**
  (strong-diversifier zone);
- between the two → a **book-level** test: improves book Sharpe, **or** improves book MaxDD
  without degrading Sharpe;
- when the regime correlation is too noisy to bind, the regime basis is recorded `UNKNOWN` and
  the full-sample correlation binds alone.

**This is precisely what PB04 proposes to build.** The concern "two strategies at 0.2 on
average and 0.9 on loss days are the same thing for a daily-loss limit" is already the reason
`corr_eff` takes the **max** of the full-sample and high-vol-regime correlations. The
tail-coupling measure exists and already binds.

There are also `NEED_MORE_DATA` refusals wired throughout rather than verdicts on unproven
bytes — e.g. `q08_stream_sha256_mismatch` refuses rather than grading a stream that cannot be
tied by count *and* lineage to the Q08 run that produced it.

## 3. The bottleneck is the portfolio arm, not the news arm

Latest Q09_PORTFOLIO verdict per pair, across the whole fleet:

| Latest verdict | Pairs |
|---|---:|
| **FAIL_PORTFOLIO** | **66** |
| PASS_PORTFOLIO | 35 |
| NEED_MORE_DATA | 7 |
| **total** | **108** |

**61% of everything that reaches the portfolio arm is rejected there.** Compare the eight rows
stuck at Q09_NEWS. The news dam is 8 rows; the portfolio arm rejects 66 pairs. **The answer to
"does this move the bottleneck" is yes, and by an order of magnitude.**

That also explains the Q10 famine I reported earlier without understanding it. Since
2026-07-29 Q10 binds `required_verdicts=["PASS_PORTFOLIO"]`, and most candidates do not have
it.

## 4. The finding that matters most: the survivor pool predates the gate

**Twelve pairs hold a `Q10 PASS` while their latest — and only — portfolio verdict is
`FAIL_PORTFOLIO`:** QM5_12989/XAUUSD, QM5_13013/NDX, QM5_13301/GDAXI, QM5_10123/XAUUSD,
QM5_10128/XAUUSD, QM5_10145/XAUUSD, QM5_10183/XAUUSD, QM5_20048/XTIUSD, QM5_13213/USDJPY,
QM5_10142/SP500 and two more.

I checked whether this is a live bypass before reporting it as one. **It is not.**

- `required_verdicts=["PASS_PORTFOLIO"]` and `assert_q10_dependency_gate` both entered the code
  in commit `b62cf0638`, **2026-07-29**.
- Every Q10 row in question is dated **2026-07-20 to 2026-07-26** — before the gate existed.
- All of them carry **zero rows** in `work_item_dependencies` (`deps=0`), confirming they were
  created by the pre-gate path.

So the gate is sound and is not being circumvented today. But the consequence is sharper than a
bypass would be:

> **The entire Q10 survivor pool — 40 PASS verdicts, the population feeding the whole
> optimisation track — was granted before the portfolio dependency was enforceable. For twelve
> of those pairs the portfolio arm has since returned FAIL. Under today's rules those twelve
> would not hold a Q10 PASS.**

This belongs in the verdict-validity register at high priority. It is not a defect in anything;
it is a cohort that was admitted under an earlier contract, and the optimisation cohort
(`opt_program.v1.json`, 9 frozen pairs) is drawn from exactly this pool.

## 5. Reproducibility: state is not recorded, and that is the open risk

Searched `portfolio_q08_contribution.py` for any record of the book state at check time —
`book_sha`, `portfolio_sha`, `manifest_sha`, `incumbent`, `book_state`, `snapshot`: **no
matches.** The gate correlates the candidate against "the book", but I found no evidence that
*which* book — its composition and weights at that moment — is written into the verdict
evidence.

If that holds after the deeper check that `portfolio_admission` deserves, then **no
FAIL_PORTFOLIO is reproducible**, and a non-reproducible momentary snapshot is currently
blocking 66 pairs and, through the dependency, the pipeline's exit. I am *not* asserting it yet:
the admission module is 1,110 lines, the state may be recorded under a different name, and
`portfolio_freeze_gate.py` ("input-SHA gate") suggests some SHA discipline exists somewhere.
**This is the single most important thing to settle next**, and it is a read-only investigation.

## 6. The circularity, stated for decision

Q09_PORTFOLIO admits a candidate by correlating it against the live book. The Portfolio Build
decides what is in the book. So the book decides who qualifies for the book. Two clean
resolutions, and they are mutually exclusive:

- **Freeze a reference portfolio** for admission — the gate measures against a dated, hashed
  composition, making every verdict reproducible and comparable across time; the cost is that
  admission drifts from the live book.
- **Subsume the gate into the build** — no standalone admission verdict; the selection run
  decides membership by marginal contribution directly, and Q09_PORTFOLIO stops being a gate.
  The cost is losing a per-candidate verdict that the pipeline currently depends on.

I recommend **freezing a reference portfolio**, for one reason: the pipeline's other gates are
all reproducible against fixed inputs, and a gate whose verdict depends on when it ran cannot
participate in an evidence chain. Subsuming would also require rewriting the Q10 dependency.
**This is an OWNER decision and is not being implemented.**

## 7. Revisiting a portfolio verdict — what would trigger one, without triggering it

`_promote_q08_soft_fails_to_q09_portfolio` inserts a Q09_PORTFOLIO row only when
`NOT EXISTS (… phase='Q09_PORTFOLIO')` for that `(ea_id, symbol)`. So a second portfolio verdict
**cannot** arise from the pump. It requires either deleting the existing row (destroys evidence)
or an explicit new-row path that the promotion logic does not offer today.

There is also `requeue_q09_stranded_sleeves.py` — "staged, provenance-gated requeue of terminal
Q09_PORTFOLIO `NEED_MORE_DATA` sleeves" — which addresses the 7 `NEED_MORE_DATA` pairs but
**not** `FAIL_PORTFOLIO`. So the 66 rejected pairs have no re-evaluation path at all right now.
Nothing was triggered.

## Evidence

- `tools/strategy_farm/portfolio/` — module inventory
- `tools/strategy_farm/portfolio/portfolio_admission.py:48-107` — DL-083 correlation zones
- `tools/strategy_farm/portfolio/portfolio_q08_contribution.py:329` — the verdict line
- `tools/strategy_farm/farmctl.py:14232-14238` — the Q10 dependency; `b62cf0638` (2026-07-29)
- `decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md` — threshold source
