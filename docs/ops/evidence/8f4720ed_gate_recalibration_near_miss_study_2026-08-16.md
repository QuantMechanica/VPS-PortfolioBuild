# Near-miss gate recalibration study

Date: 2026-08-16 (Europe/Berlin)

Router task: `8f4720ed-34bd-43ed-aa1e-532d37de725d`

Branch: `agents/board-advisor`

Disposition: REVIEW. Recommendation: **do not change the Q04, Q05, or Q06 PF floors**. Preserve every recorded verdict. Use a three-EA targeted rework wave, not threshold requalification, to test whether the small cluster contains recoverable book material.

Source register: `C:/QM/repo/artifacts/near_miss_register_20260816.json`

## Executive result

- The register contains six XAUUSD rows, not five: QM5_10132, 10714, 10242, 1638, 10515, and 10501.
- XAUUSD concentration is not explained by run volume alone. XAUUSD supplied 43/166 terminal Q04–Q06 gate rows (25.9%) but 6/8 near misses (75%). Its near-miss rate was 14.0%, versus 1.6% for all non-XAU rows.
- The example `2-of-3 folds > 1.0 and third >= 0.98` rule would rescue only QM5_10132, QM5_9940, and QM5_10242. Their mean fold PFs are just 1.067, 1.049, and 1.027, all below the existing PASS_SOFT mean floor of 1.10.
- The two candidates with exact later-gate evidence do not strengthen the threshold case: QM5_10714 degrades from Q05 PF 1.03 to Q06 PF 0.99 and exceeds the Edge Lab 10% total-DD box; QM5_21504 reaches Q05 PF 1.00 exactly.
- A hypothetical Q09 calculation against the durable 28-sleeve book shows all eight reduce book Sharpe when added. Replacing the weakest incumbent improves Sharpe for seven, but none improves both Sharpe and MaxDD or reaches the +0.05 strong-Sharpe override. No candidate is challenger-superior.

## 1. Exposure-normalized concentration

The 72-hour denominator is the farm DB's terminal (`status=done`, non-null verdict) Q04, Q05, and Q06 rows updated from `2026-08-13T19:22:16+00:00`, matching the router's 72-hour decision window.

| Symbol cohort | Near misses | Terminal gate rows | Near-miss rate | Unique EA-symbol candidates | Near misses / unique candidates |
|---|---:|---:|---:|---:|---:|
| XAUUSD.DWX | 6 | 43 | 13.95% | 34 | 17.65% |
| XNGUSD.DWX | 1 | 9 | 11.11% | 6 | 16.67% |
| EURJPY.DWX | 1 | 3 | 33.33% | 2 | 50.00% |
| All symbols | 8 | 166 | 4.82% | 126 | 6.35% |
| Non-XAU combined | 2 | 123 | 1.63% | 92 | 2.17% |

The raw count is partly caused by XAUUSD throughput, but not entirely: XAU has 25.9% of terminal gate observations and 75% of near misses. A descriptive one-sided hypergeometric calculation for observing at least six XAU rows in eight draws from a 43/166 exposure base gives `p = 0.00414`. This is not a confirmatory test—the cluster and five-percent band were selected after observation—but it rejects the claim that the absolute concentration is merely proportional to candidate volume. It is evidence for an XAU-specific marginality cluster, not evidence that those strategies are profitable.

## 2. Defensible alternative-rule calculation

Existing Q04 `PASS_SOFT` requires:

- at least two of three folds strictly above PF 1.0;
- mean PF strictly above 1.10;
- no fold below 0.80.

The OWNER-framed diagnostic alternative is narrower around the floor but removes the 1.10 mean guard: at least two folds strictly above 1.0 and the third at least 0.98.

| EA / symbol | Folds | Mean | Minimum | Existing PASS_SOFT | Diagnostic 2-of-3 + 0.98 rule |
|---|---|---:|---:|---|---|
| QM5_10132 / XAUUSD | 1.050, 1.000, 1.150 | 1.067 | 1.000 | FAIL: mean < 1.10 | Would pass |
| QM5_9940 / EURJPY | 1.051, 0.988, 1.107 | 1.049 | 0.988 | FAIL: mean < 1.10 | Would pass |
| QM5_10242 / XAUUSD | 1.050, 0.980, 1.050 | 1.027 | 0.980 | FAIL: mean < 1.10 | Would pass |
| QM5_1638 / XAUUSD | 0.970, 1.030, 1.130 | 1.043 | 0.970 | FAIL | Fails third-fold floor |
| QM5_10515 / XAUUSD | 0.970, 1.000, 1.120 | 1.030 | 0.970 | FAIL | Fails; only one fold > 1.0 |
| QM5_10501 / XAUUSD | 1.050, 0.970, 1.100 | 1.040 | 0.970 | FAIL | Fails third-fold floor |

The proposed alternative would rescue 3/6 Q04 rows, but only by admitting mean PFs 3.0–7.3% below the current soft-pass mean floor. None of those three has exact Q05+ evidence on the same EA-symbol lineage. This is too little evidence to remove the existing mean-edge guard.

The Q05/Q06 near misses are single-gate PF observations and are not eligible for the Q04 fold rule:

- `QM5_21504:XNGUSD.DWX` Q05 PF = 1.000;
- `QM5_10714:XAUUSD.DWX` Q06 PF = 0.990.

## 3. Later-gate survival

Only two exact EA-symbol lineages already have Q05+ evidence.

### QM5_21504 XNGUSD

- Q04: `PASS_LOWFREQ`; pooled PF 1.987, 34 trades, active in 2/3 OOS years. The individual folds are zero trades, 2.088, and 1.822.
- Q05: `FAIL`; PF 1.000, 94 trades, DD 4.214%.

The low-frequency pooled edge does not hold over full history after costs: the observed PF is exactly the rejection floor. Low DD does not turn PF 1.00 into book material.

### QM5_10714 XAUUSD

- Q04: `PASS`; the evidence is dominated by a one-trade 2025 fold reported as PF 999, so the later full-history gates carry more information.
- Q05: `PASS`; PF 1.030, 198 trades, DD 16.662%.
- Q06 HARSH: `FAIL`; PF 0.990, 121 trades, DD 14.403%, with the authenticated 10% rejection stress input.

The candidate degrades under stress and both measured DDs exceed the active Edge Lab's <=10% total-DD box. It is not book material at the tested shape.

The remaining six near-miss lineages stop at Q04. No later-gate survival claim is available for them.

## 4. Hypothetical portfolio contribution

No near-miss candidate has a durable, Q08-authoritative stream. The available candidate JSONL files are volatile `Common/Files/QM/q08_trades` outputs from earlier runs. The calculation below is therefore explicitly **diagnostic and non-promotional**:

- durable book: the same 28 SHA-bound sleeve streams used by Q09;
- candidate: the available volatile stream, SHA recorded below;
- weights and metrics: Q09 inverse-volatility arithmetic on a $100,000 base;
- baseline: Sharpe 2.802693, MaxDD 0.261465%;
- swap target: weakest standalone-Sharpe incumbent `11165:EURUSD.DWX`;
- no stream was copied into the durable store and no Q08/Q09 verdict was written.

| Candidate | Standalone PF | Add Sharpe | Add MaxDD | Swap Sharpe | Swap MaxDD | Challenger-superior? |
|---|---:|---:|---:|---:|---:|---|
| QM5_10132 XAUUSD | 1.085 | 2.744120 | 0.257888% | 2.803248 | 0.272588% | No |
| QM5_21504 XNGUSD | 0.996 | 2.759899 | 0.293991% | 2.822550 | 0.297537% | No |
| QM5_10714 XAUUSD | 0.854 | 2.654051 | 0.382653% | 2.712117 | 0.372755% | No |
| QM5_9940 EURJPY | 1.034 | 2.767984 | 0.252608% | 2.828800 | 0.266794% | No |
| QM5_10242 XAUUSD | 1.039 | 2.757650 | 0.257970% | 2.817282 | 0.272677% | No |
| QM5_1638 XAUUSD | 1.097 | 2.777193 | 0.260086% | 2.831156 | 0.275003% | No |
| QM5_10515 XAUUSD | 1.101 | 2.764305 | 0.259818% | 2.819804 | 0.274709% | No |
| QM5_10501 XAUUSD | 1.109 | 2.759000 | 0.259839% | 2.817530 | 0.274732% | No |

All eight dilute book Sharpe on ADD. Seven improve Sharpe versus the weakest-incumbent swap, but all seven worsen MaxDD and none reaches the +0.05 strong-Sharpe override. QM5_10714 worsens both. The provisional portfolio evidence therefore does not justify weakening an upstream floor.

Candidate stream SHA-256 values, in table order:

```text
081d0dcace0c9dd7a676afcb34d432a2a908dc3743a5cb5489d1ef47e0ec31ec
f23ad7d0647588ac21a20aa461696bdca782fe6e473f8b4be3a26cbc872c6c85
82b95f6b8ac5dcd94b0b05d85913fa3bb0b99903d20d2ab216f0fb7015899e12
7d8050f2706fc410aeb10c43ae6ba48734d771ab274685a03209a0f72eec5a7a
a065ed0826a47a4b3792e9b4f1586d3baa03ba134b5a112761f7b3ece899f95c
1ff7139c7099ae30c20fa1da869f36195cf28185626e79caf9d09e333a56624b
6b652a4ab9c055106bea2bcacd2f9719a49be53df9e4d35c33e300eabc4518bc
afd0a2780d483df655980d75964d5db6224756cea59cb9e08def196d6f2ff38f
```

## 5. Recommendation and targeted rework wave

### Floor decision

Do **not** change the floors and do not retroactively requalify any row. The current PASS_SOFT rule already tolerates one weak fold while requiring a meaningful mean edge. The diagnostic 0.98 rule would exchange that evidence requirement for three candidates whose average folds remain only 1.027–1.067, and the available later-gate/portfolio evidence is not supportive.

If OWNER wants a durable label for future measurement, add a non-promotional `NEAR_MISS_WATCH` analytics tag with no cascade effect; do not make it a verdict or an enqueue condition until an independently accumulated cohort demonstrates later-gate and Q09 value.

### Targeted rework, in order

1. `QM5_9940:EURJPY.DWX` — meets the diagnostic fold shape; best swap Sharpe among those three (2.828800), and ADD improves MaxDD. Rework the strategy mechanics only if a specific defect or predeclared variant exists; otherwise rerun unchanged evidence is not authorized.
2. `QM5_10242:XAUUSD.DWX` — meets the diagnostic fold shape and has the lowest measured provisional regime correlation (0.076) among the XAU candidates with a measurable regime basis, but it still dilutes ADD Sharpe and is not challenger-superior.
3. `QM5_1638:XAUUSD.DWX` — does not meet the 0.98 rule, but has the strongest provisional swap Sharpe (2.831156) and PF 1.097. It belongs in a mechanics-rework study, not a floor exception.

`QM5_10132` is a useful control because it meets the diagnostic fold shape, but its swap is essentially flat (+0.000555 Sharpe with worse DD); do not prioritize it ahead of the three above. Do not target QM5_10714 or QM5_21504: later evidence already shows stress degradation or no economic edge. QM5_10515 and QM5_10501 fail the diagnostic fold shape and dilute ADD Sharpe.

## Safety boundary

- no gate threshold, classifier, verdict, work-item state, or cascade changed;
- no candidate requalified and no pipeline evidence invented;
- no Q08 stream promoted into the durable store;
- no `T_Live`, AutoTrading, deploy-manifest, terminal, or active-backtest action;
- no main or `C:/QM/worktrees/cto_main` mutation.
