# Q09 correlation wall: remit and admissible path

Date: 2026-07-27  
Router task: `247c26a5-7cb5-49cf-a1f0-b0bff7a557cf`  
Disposition: read-only analysis; no gate row was rerun or changed.

## Executive answer

**Q09 is a portfolio-admission gate, and a one-sleeve FTMO account is outside
its diversification remit.** This does not make a Q09 failure false: it means
“do not add this sleeve to the current admitted book,” not “this sleeve cannot
be tested alone.” Standalone FTMO suitability still requires the upstream
strategy evidence and the challenge loss/target simulation; Q09 supplies no
waiver for those.

The six candidates are not intrinsically one correlated cluster. The current
Q09 results compare each against the large historical admitted-candidate book.
A read-only application of the unchanged gate function to only these six found
valid five-sleeve admission sequences. It cannot admit both USDJPY range
breakouts together: `9936` versus `13213` has effective correlation 0.90465.

## 1. What Q09 compares against

The production path calls `current_book()`, which returns `read_candidates()`,
then passes that book to `evaluate_candidate()`:

- `portfolio_admission.py:253-255`
- `portfolio_admission.py:560-578`

The output labels this basis `portfolio_candidates`
(`portfolio_admission.py:566-592`). `read_candidates()` selects the admitted
candidate registry, including its Q12-review-ready states
(`portfolio_common.py:216-262`). It is therefore **not the six-candidate
shortlist and not the live T_Live/DXZ manifest**. At the query cutoff the
registry contained 31 `Q12_REVIEW_READY` EA/symbol rows:

```sql
SELECT ea_id,symbol,state
FROM portfolio_candidates
WHERE state IN ('Q12_REVIEW_READY','LIVE','ADMITTED')
ORDER BY ea_id,symbol;
```

For that book, Q09 takes the worst measurable candidate-to-member Pearson
correlation over the shared daily span, with a monthly fallback for sparse
sleeves (`portfolio_admission.py:341-369`). It also computes correlation in the
book’s high-volatility regime and uses the stricter of full-sample and regime
correlation (`portfolio_admission.py:107-121,451-471`).

`corr_full` in a reason is a **binding measurement basis**, not a different
comparison population. The apparently bare historical reasons are older output:
the mandatory `:<basis>` suffix was introduced by the 2026-07-26 C1 gate port
(`portfolio_admission.py:48-57,472-475`). This explains the observed rows:

| Candidate | Completed | Reason | Current-book measurement |
|---|---|---|---:|
| 9936 USDJPY | 2026-07-27 | `no_diversification:corr_full` | corr_eff 0.20523 |
| 13213 USDJPY | 2026-07-25 | `no_diversification` | legacy artifact; max corr 0.23867 |
| 13036 GDAXI | 2026-07-26 | `correlation_above_max_corr:corr_full` | corr_eff 0.54477 |
| 10553 XAUUSD | 2026-07-16 | `correlation_above_max_corr` | legacy artifact; max corr 0.32993 |
| 10848 XAUUSD | 2026-07-14 | `no_diversification` | legacy artifact; max corr 0.18718 |
| 13301 GDAXI | 2026-07-27 | `CHALLENGER_SUPERIOR` | corr_eff 0.46765 |

Source query: latest `work_items` row per EA where
`phase='Q09_PORTFOLIO'`, plus each row’s bound `aggregate.json`.

## 2. Single sleeve on one prop account

The gate contract answers this directly:

- an empty admitted book returns `admit=True, reason='first_sleeve'`
  (`portfolio_admission.py:317-339`);
- all correlation and marginal-contribution calculations operate on
  `book + candidate` (`portfolio_admission.py:341-390`);
- the purpose is to protect a risk-parity production book from redundant or
  Sharpe-dilutive additions (`portfolio_admission.py:371-426`).

With exactly one sleeve there is no second return stream, no concentration
created by co-movement, and no marginal “with versus without” portfolio
question. Thus Q09 correctly applies to assembling a multi-sleeve book but does
not logically veto a standalone challenge. The honest operational split is:

- **single sleeve / single FTMO account:** use the sleeve’s gate-clean standalone
  evidence and FTMO path simulation; record Q09 as “not applicable to this
  deployment topology,” not PASS;
- **two or more sleeves, or later addition to an admitted book:** Q09 applies in
  full. Do not weaken, bypass, or tune it.

This distinction does not rescue both USDJPY breakout variants as a “book.”
Their directly recomputed effective correlation is 0.90465, consistent with the
independent r=0.905 and 269 identical-trade finding.

## 3. `CHALLENGER_SUPERIOR` for 13301

The current row-bound aggregate is:

`D:\QM\reports\work_items\db5027ee-9326-40bc-b87f-dcfdf346d3fa\QM5_13301\Q09_PORTFOLIO\GDAXI_DWX\aggregate.json`

It says `13301:GDAXI.DWX` beat incumbent **`10911:GDAXI.DWX`** in a replacement
test:

- incumbent correlation to challenger: 0.4676537640;
- current-book Sharpe: 2.7760930819;
- swapped-book Sharpe: 2.8191172426;
- current-book MaxDD: 0.2479143938%;
- swapped-book MaxDD: 0.2173300459%;
- `sharpe_improved=true`, `dd_improved=true`,
  `challenger_superior=true`.

The comparison is current enough to remain a valid **swap proposal**: the
aggregate was regenerated 2026-07-27 and its swap book includes the then-current
candidate set. It is not an executed swap. Code deliberately leaves
`admit=False` and converts the reason to `CHALLENGER_SUPERIOR`; OWNER approval
and manifest protocol remain mandatory
(`portfolio_admission.py:477-525`). The pending decision is therefore:
**replace 10911 with 13301**, not add 13301 beside it.

## 4. In-force thresholds and an admissible book

The legacy `--max-corr=0.30` remains only as an output/CLI compatibility field
and no longer gates (`portfolio_admission.py:53-58,592-600`). The binding C1 /
DL-083 zones are:

| Effective correlation (`max(corr_full, corr_regime)`) | Decision |
|---|---|
| `>= 0.40` | reject as redundant/crisis-correlated |
| `< 0.15` plus positive marginal contribution | admit |
| `0.15 <= corr_eff < 0.40` | admit only if delta-Sharpe `>= 0.020` |

The high-vol regime is the top quartile of 20-day rolling book volatility and
requires 20 measurable regime days; normal daily overlap requires 60 days
(`portfolio_admission.py:69-90,144-172`).

### Named admissible sequence among the six

Using `evaluate_candidate()` unchanged and read-only against successive members
of the six-sleeve set, this five-sleeve sequence passes:

1. `13036:GDAXI.DWX` — first sleeve;
2. `10848:XAUUSD.DWX` — admitted, corr_eff -0.02412, delta-Sharpe +0.38034;
3. `10553:XAUUSD.DWX` — admitted, corr_eff 0.25216, delta-Sharpe +0.02674;
4. `13301:GDAXI.DWX` — admitted, corr_eff 0.09758, delta-Sharpe +0.37018;
5. `9936:USDJPY.DWX` — admitted, corr_eff 0.06660, delta-Sharpe +0.33534.

`13213` cannot join that version because it duplicates 9936. Conversely, a
five-sleeve sequence substituting `13213` for `9936` also passes:

`13036 -> 10848 -> 10553 -> 13301 -> 13213`

The final 13213 step has corr_eff 0.08021 and delta-Sharpe +0.13498.

These are counterfactual **candidate-book constructions**, not permission to
rewrite the existing admitted registry. They show that “all six failed against
the current 31-row book” does not mean “none can form a diversified book.”
What cannot pass together is the exact pair `9936 + 13213`.

## Recommendation

For OWNER’s fixed one-account-at-a-time campaign, select a single sleeve on its
standalone FTMO evidence and mark Q09 not applicable to that topology. If the
programme returns to a multi-sleeve account, do not add these candidates to the
legacy 31-row registry blindly: review the 13301-for-10911 swap and construct a
fresh, explicitly approved candidate book using one—not both—USDJPY breakout
variants. Future sourcing should still target genuinely different clocks,
markets, and payoff shapes; “smoothness” alone does not provide diversification.
