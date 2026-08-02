# DXZ book substitution — candidate versus incumbent swap matrix

**Date:** 2026-08-02

**Router task:** `842230b0-a146-4f83-801b-87eb77e3de73`

**Authority:** OWNER 2026-08-02; recommendation only

**Disposition:** **NO SWAP BEATS BOTH THE UNCHANGED 24-SLEEVE BOOK AND THE
SIMPLE-ADDITION ALTERNATIVE.** The full matrix contains 30 same-symbol swaps
and zero recommendations. No manifest, queue, terminal, baseline, deploy, or
live state was changed.

## Decision

The negative result is clean and robust:

- none of the four XAU candidates improves the status quo across Sharpe,
  maximum drawdown, worst day, and annualized book return;
- the nearest risk-only case is `10938/GDAXI` replacing `10911/GDAXI`:
  Sharpe is effectively flat (`-0.001064`) and maximum drawdown improves
  (`-0.176787` percentage points), but annualized book return falls by
  `0.1665` percentage points and its worst day is worse than the simple-add
  alternative;
- replacing the baseline-less `10440/NDX` with either NDX candidate improves
  maximum drawdown, but materially lowers Sharpe, worsens the worst day, and
  lowers annualized book return. The kill-switch coverage gap is not a reason
  to accept a worse replacement;
- SP500 and XTI replacements both lower Sharpe and annualized book return;
- every candidate still carries the vintage/lineage defect already recorded
  in `BOOK_EXPANSION_CANDIDATES_2026-08-02.md`. A swap cannot bypass it.

The book should remain unchanged. `11422/USDCAD` and `1328/EURJPY` have no
same-symbol incumbent and remain addition-only cases under the predecessor
decision.

## Inputs and method

This analysis reuses, without changing, the predecessor's inputs:

- unchanged book:
  `D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json`;
- sealed incumbent bundle:
  `D:/QM/reports/portfolio/dxz_final_20260719`;
- candidate streams:
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades`;
- capped inverse-volatility weighting from
  `tools/strategy_farm/portfolio/marginal_contribution_eval.py`;
- cap `1.0`, total-risk budget `9.75`, and starting capital `100,000`.

For each candidate, all 24 incumbent streams and the candidate stream were
aligned once on the same calendar. Three portfolios were then recomputed on
that identical matrix:

1. the unchanged 24-sleeve baseline;
2. all 24 incumbents plus the candidate (the predecessor's addition case);
3. the candidate replacing one same-symbol incumbent.

Weights were independently recomputed with the same capped inverse-volatility
rule for each portfolio. All deltas in the swap tables are `swap - unchanged
baseline`; positive maximum-drawdown delta is worse, while positive worst-day
delta is better. `swap-add` is `swap - simple addition` in the order
`Sharpe / MaxDD / worst day`.

`candidate/rest corr` reports overall daily correlation and the maximum
absolute correlation across the three disjoint time thirds and high-volatility
subset. `swap/base corr` gives the same overall/maximum profile for the
resulting swap book versus the unchanged book. Candidate-aligned windows run
from 2017-10-09 through 2025-12-30 and contain 2,028–2,082 daily observations.

### What “beats” means

A swap is called an improvement only if it weakly Pareto-dominates both the
unchanged baseline and simple addition on:

- Sharpe (higher is better);
- maximum drawdown (lower is better);
- worst day (higher/less negative is better); and
- annualized net book return (higher is better),

with at least one strict improvement in each comparison. The predecessor's
noise bands (`0.020` Sharpe, `0.05` drawdown percentage points) were also
checked as a sensitivity: the result remains zero because every near case
still loses either annualized book return or worst-day quality.

## Reproduced simple-addition alternatives

The recalculation reproduces the predecessor's published composite deltas
exactly. Annual contribution here is the candidate's contribution at its
addition weight.

| Candidate | add ΔSharpe | add ΔMaxDD pp | add Δworst day pp | candidate ann. contribution |
|---|---:|---:|---:|---:|
| `10145/XAUUSD` | -0.011558 | +0.350954 | -0.206531 | +0.5121%/yr |
| `10183/XAUUSD` | -0.035382 | +0.161699 | -0.108775 | +0.3486%/yr |
| `10128/XAUUSD` | -0.108712 | +0.427481 | -0.097597 | +0.0783%/yr |
| `10123/XAUUSD` | -0.022745 | +0.052130 | -0.273926 | +0.4724%/yr |
| `13036/GDAXI` | -0.040950 | -0.138351 | +0.003140 | +0.0777%/yr |
| `10938/GDAXI` | -0.007212 | -0.051410 | +0.022266 | +0.1790%/yr |
| `13013/NDX` | +0.026782 | +0.061698 | +0.032994 | +0.2875%/yr |
| `10692/NDX` | +0.002294 | -0.125567 | -0.074285 | +0.1769%/yr |
| `10142/SP500` | -0.004317 | +0.544862 | -0.236669 | +0.2085%/yr |
| `20048/XTIUSD` | +0.012601 | -0.067699 | +0.062275 | +0.1376%/yr |

## Pair matrix

`Cand ann.` is the candidate's annualized net contribution at its swap weight.
`Book ann. Δ` is the total swap-book annualized net-return change after all
weights are recomputed. The repair code in every row is mandatory before any
admission discussion; codes are defined after the matrix.

### XAUUSD — 20 swaps

| Candidate → removed incumbent | ΔSharpe | ΔMaxDD pp | Δworst pp | Cand ann. | Book ann. Δ | swap-add S/DD/W | candidate/rest corr o/max | swap/base corr o/max | Repair | Beats? |
|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| `10145 → 1556` | -0.046127 | +0.620708 | -0.105795 | +0.5504% | +0.4503% | `-0.034569 / +0.269753 / +0.100736` | `0.1639 / 0.2073` | `0.9743 / 0.9806` | R1 | NO |
| `10145 → 10403` | +0.018075 | +0.411162 | -0.069148 | +0.5250% | +0.1367% | `+0.029633 / +0.060208 / +0.137383` | `0.1199 / 0.1622` | `0.9824 / 0.9890` | R1 | NO |
| `10145 → 10513` | -0.014024 | +0.266475 | -0.243906 | +0.5301% | +0.2438% | `-0.002466 / -0.084480 / -0.037375` | `0.1886 / 0.2192` | `0.9697 / 0.9763` | R1 | NO |
| `10145 → 12567` | -0.086987 | +0.894172 | -0.309020 | +0.5614% | +0.6699% | `-0.075429 / +0.543217 / -0.102489` | `0.2285 / 0.2609` | `0.9628 / 0.9736` | R1 | NO |
| `10145 → 12989` | -0.052254 | +0.412200 | -0.235974 | +0.5263% | +0.1335% | `-0.040696 / +0.061246 / -0.029443` | `0.2213 / 0.2605` | `0.9640 / 0.9725` | R1 | NO |
| `10183 → 1556` | -0.080873 | +0.446798 | -0.050110 | +0.3733% | +0.0964% | `-0.045491 / +0.285099 / +0.058665` | `0.1466 / 0.1943` | `0.9699 / 0.9818` | R2 | NO |
| `10183 → 10403` | -0.025593 | +0.103344 | -0.011965 | +0.3572% | -0.1795% | `+0.009789 / -0.058356 / +0.096810` | `0.1226 / 0.1807` | `0.9742 / 0.9802` | R2 | NO |
| `10183 → 10513` | -0.045870 | +0.188976 | -0.142073 | +0.3606% | -0.0775% | `-0.010487 / +0.027277 / -0.033298` | `0.1662 / 0.2074` | `0.9662 / 0.9718` | R2 | NO |
| `10183 → 12567` | -0.108363 | +0.710603 | -0.197255 | +0.3805% | +0.3042% | `-0.072981 / +0.548904 / -0.088480` | `0.1815 / 0.2245` | `0.9637 / 0.9704` | R2 | NO |
| `10183 → 12989` | -0.075840 | +0.215158 | -0.135010 | +0.3581% | -0.1834% | `-0.040458 / +0.053458 / -0.026235` | `0.1801 / 0.2291` | `0.9638 / 0.9693` | R2 | NO |
| `10128 → 1556` | -0.159440 | +1.233811 | -0.053392 | +0.0840% | -0.0829% | `-0.050729 / +0.806330 / +0.044205` | `0.1513 / 0.1973` | `0.9687 / 0.9781` | R3 | NO |
| `10128 → 10403` | -0.071643 | +0.250088 | +0.046046 | +0.0802% | -0.3641% | `+0.037069 / -0.177393 / +0.143643` | `0.0526 / 0.0996` | `0.9872 / 0.9936` | R3 | NO |
| `10128 → 10513` | -0.104878 | +0.463579 | -0.130904 | +0.0810% | -0.2626% | `+0.003834 / +0.036097 / -0.033307` | `0.1252 / 0.1738` | `0.9734 / 0.9791` | R3 | NO |
| `10128 → 12567` | -0.203996 | +1.114116 | -0.187874 | +0.0857% | +0.1243% | `-0.095284 / +0.686635 / -0.090277` | `0.2309 / 0.2795` | `0.9546 / 0.9667` | R3 | NO |
| `10128 → 12989` | -0.153407 | +0.489083 | -0.123837 | +0.0804% | -0.3684% | `-0.044695 / +0.061601 / -0.026240` | `0.1832 / 0.2364` | `0.9629 / 0.9690` | R3 | NO |
| `10123 → 1556` | -0.066090 | +0.221916 | -0.026923 | +0.5066% | +0.3068% | `-0.043345 / +0.169786 / +0.247003` | `0.1883 / 0.2195` | `0.9711 / 0.9757` | R4 | NO |
| `10123 → 10403` | +0.014174 | +0.113029 | -0.082127 | +0.4841% | +0.0122% | `+0.036919 / +0.060899 / +0.191799` | `0.1091 / 0.1757` | `0.9858 / 0.9907` | R4 | NO |
| `10123 → 10513` | -0.022787 | -0.102237 | -0.313244 | +0.4888% | +0.1170% | `-0.000042 / -0.154367 / -0.039318` | `0.1883 / 0.2194` | `0.9710 / 0.9780` | R4 | NO |
| `10123 → 12567` | -0.102230 | +0.486750 | -0.379875 | +0.5166% | +0.5208% | `-0.079485 / +0.434620 / -0.105949` | `0.2435 / 0.2772` | `0.9614 / 0.9771` | R4 | NO |
| `10123 → 12989` | -0.064298 | +0.101404 | -0.304902 | +0.4853% | +0.0088% | `-0.041553 / +0.049274 / -0.030976` | `0.2288 / 0.2616` | `0.9639 / 0.9776` | R4 | NO |

The two positive-XAU-Sharpe rows (`10145→10403`, `10123→10403`) both worsen
maximum drawdown and worst day. The sole XAU row with meaningful drawdown
relief (`10123→10513`) worsens Sharpe and worst day, and does not beat simple
addition. XAU replacement is therefore not supported.

### GDAXI — 4 swaps

| Candidate → removed incumbent | ΔSharpe | ΔMaxDD pp | Δworst pp | Cand ann. | Book ann. Δ | swap-add S/DD/W | candidate/rest corr o/max | swap/base corr o/max | Repair | Beats? |
|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| `13036 → 10911` | -0.037274 | -0.218684 | -0.015192 | +0.0788% | -0.2782% | `+0.003676 / -0.080333 / -0.018332` | `0.0257 / 0.0768` | `0.9606 / 0.9837` | R5 | NO |
| `13036 → 13301` | -0.121526 | -0.121077 | -0.003488 | +0.0783% | -0.6969% | `-0.080576 / +0.017273 / -0.006628` | `0.0326 / 0.0978` | `0.9590 / 0.9825` | R5 | NO |
| `10938 → 10911` | -0.001064 | -0.176787 | +0.004189 | +0.1816% | -0.1665% | `+0.006148 / -0.125377 / -0.018077` | `0.0085 / 0.0557` | `0.9610 / 0.9876` | R6 | NO |
| `10938 → 13301` | -0.085727 | +0.059387 | +0.015779 | +0.1804% | -0.5864% | `-0.078515 / +0.110797 / -0.006487` | `0.0140 / 0.0489` | `0.9597 / 0.9872` | R6 | NO |

`10938→10911` is the best swap in the matrix for drawdown with neutral
Sharpe, but it removes `0.2520%/yr` of incumbent contribution, adds only
`0.1816%/yr` directly, and finishes `-0.1665%/yr` below the baseline after
reweighting. Simple addition preserves more annual return and a better worst
day. This is not a genuine improvement.

### NDX — 4 swaps

| Candidate → removed incumbent | ΔSharpe | ΔMaxDD pp | Δworst pp | Cand ann. | Book ann. Δ | swap-add S/DD/W | candidate/rest corr o/max | swap/base corr o/max | Repair | Beats? |
|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| `13013 → 13128` | -0.082640 | +0.259334 | -0.066452 | +0.3222% | +0.4737% | `-0.109423 / +0.197636 / -0.099446` | `0.0282 / 0.1090` | `0.9638 / 0.9750` | R7 | NO |
| `13013 → 10440` | -0.041207 | -0.138688 | -0.156002 | +0.2894% | -0.3703% | `-0.067989 / -0.200386 / -0.188996` | `0.0156 / 0.1143` | `0.9593 / 0.9791` | R7 | NO |
| `10692 → 13128` | -0.101854 | -0.051822 | -0.193524 | +0.1996% | +0.6504% | `-0.104149 / +0.073745 / -0.119239` | `-0.0051 / 0.0461` | `0.9656 / 0.9804` | R8 | NO |
| `10692 → 10440` | -0.061867 | -0.312483 | -0.186558 | +0.1781% | -0.2511% | `-0.064161 / -0.186917 / -0.112273` | `-0.0147 / 0.0523` | `0.9606 / 0.9838` | R8 | NO |

Removing 10440 would close the one intentional KS-baseline gap, but both
candidate replacements materially lower Sharpe and worsen the worst day. The
separate 10440 upstream-repair/retirement decision remains controlling.

### SP500 and XTIUSD — 2 swaps

| Candidate → removed incumbent | ΔSharpe | ΔMaxDD pp | Δworst pp | Cand ann. | Book ann. Δ | swap-add S/DD/W | candidate/rest corr o/max | swap/base corr o/max | Repair | Beats? |
|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| `10142 → 11132` | -0.022825 | +0.143555 | -0.149937 | +0.2190% | -0.3745% | `-0.018508 / -0.401307 / +0.086732` | `0.0194 / 0.0702` | `0.9642 / 0.9701` | R9 | NO |
| `20048 → 10919` | -0.155307 | +0.636440 | +0.008962 | +0.1376% | -0.6855% | `-0.167908 / +0.704139 / -0.053313` | `0.0128 / 0.0195` | `0.9679 / 0.9754` | R10 | NO |

Low correlation is not enough: both swaps destroy more incumbent return than
the candidate replaces and materially weaken the composite.

## Candidate repair preconditions

These are reused from the predecessor's vintage/lineage adjudication. They
apply to every matrix row carrying the code; no swap is a shortcut.

| Code | Candidate | Mandatory repair before any swap review |
|---|---|---|
| R1 | `10145/XAUUSD` | Q03-through-Q10 is stale; Q10 EX5 hash mismatches current. Rebuild the complete current-binary chain and evidence-bearing Q09 before a new Q10 |
| R2 | `10183/XAUUSD` | Restore missing Q02/Q03 evidence, resolve `Q04=PASS_SOFT`, then produce hash-bound Q09/Q10 on one current configuration |
| R3 | `10128/XAUUSD` | Produce evidence-bearing Q09_NEWS and an append-only Q10 that binds the current EX5; historical Q10 has no EX5 hash |
| R4 | `10123/XAUUSD` | Rerun stale Q02, restore Q03, resolve latest `Q08=FAIL_SOFT`, then bind Q09/Q10 to the repaired chain |
| R5 | `13036/GDAXI` | Add candidate-specific Q03, re-establish Q04-through-Q09, then rebind Q10 despite its current EX5 match |
| R6 | `10938/GDAXI` | The recorded Q02 hard fail and Q05 infra fail stand; only an authorized current-binary full-line repair can revisit them |
| R7 | `13013/NDX` | Restore missing Q04–Q06 evidence, resolve `Q07=INFRA_FAIL`, then produce evidence-bearing Q09 and hash-bound Q10 |
| R8 | `10692/NDX` | Resolve recorded `Q04=FAIL`, missing Q05, and missing evidence before any later-gate rerun |
| R9 | `10142/SP500` | Resolve `Q02=FAIL`, restore missing Q02–Q06 evidence and stream MAE, then rebuild the remaining current-binary chain |
| R10 | `20048/XTIUSD` | Q02-through-Q10 is stale, Q04 is only `PASS_SOFT`, and Q10 hash mismatches current; full current-binary requalification required |

## Incumbent removal cost

Raw Q10 status comes from the read-only farm DB. It is not relabeled as
current-live vintage here. KS status and live trade observations come from
`D:/QM/reports/state/live_book_pulse_postdeploy_20260802.json` at
`2026-08-02T08:29:10Z`.

`Observed live tenure` is a lower bound from the earliest captured
`ENTRY_ACCEPTED` event in that durable pulse, not a claim about time before the
retained log. “No accepted entry captured” does not mean the sleeve was never
live; each such sleeve is present in the July 24 live manifest.

| Incumbent | Raw Q10 status (rows) | Q10 PF / DD / trades | KS at pulse | Observed live trade tenure | Incumbent ann. contribution removed | Removal consequence |
|---|---|---|---|---|---:|---|
| `1556/XAUUSD` | PASS (1) | `1.93 / 2.683% / 53` | LOADED `17d64052...` | first captured 2026-07-13; 19.5 days, 3 entries | +0.4613%/yr | destroy one live sleeve and Q10-derived baseline |
| `10403/XAUUSD` | PASS (1) | `1.31 / 7.339% / 209` | LOADED `42c60569...` | first captured 2026-07-23; 9.4 days, 10 entries | +0.3749%/yr | destroy one live sleeve and Q10-derived baseline |
| `10513/XAUUSD` | PASS (1) | `1.98 / 4.140% / 104` | LOADED `5588dca1...` | first captured 2026-07-29; 3.4 days, 1 entry | +0.3502%/yr | destroy one live sleeve and Q10-bound baseline |
| `12567/XAUUSD` | PASS (2) | `1.61 / 2.373% / 73` | LOADED `6dc6d076...` | no accepted entry captured; live by July 24 | +0.4151%/yr | remove XAU sleeve/baseline; separate XNG sleeve remains |
| `12989/XAUUSD` | PASS (1) | `1.72 / 6.479% / 51` | LOADED `2b4a5364...` | no accepted entry captured; live by July 24 | +0.3989%/yr | destroy one live sleeve and Q10-derived baseline |
| `10911/GDAXI` | PASS (2) | `1.15 / 14.782% / 331` | LOADED `5e36499b...` | first captured 2026-06-30; 32.6 days, 6 entries | +0.2520%/yr | destroy the longer-observed GDAXI sleeve and baseline |
| `13301/GDAXI` | PASS (2) | `1.28 / 14.491% / 742` | LOADED `c82137b0...` | first captured 2026-07-27; 6.0 days, 6 entries | +0.6255%/yr | destroy the higher-contribution GDAXI sleeve and baseline |
| `13128/NDX` | PASS (1) | `2.29 / 1.249% / 57` | LOADED `a6e70fe5...` | no accepted entry captured; live by July 24 | +0.4801%/yr | destroy the only Q10-PASS NDX sleeve/baseline |
| `10440/NDX` | **FAIL (1)** | `1.07 / 31.006% / 490` | **ABSENT** | first captured 2026-07-02; 31.1 days, 2 entries | +0.4042%/yr | live evidence is lost, but no KS baseline exists; see separate vintage adjudication |
| `11132/SP500` | PASS (1) | `1.49 / 3.014% / 73` | LOADED `1e85adae...` | first captured 2026-06-28; 34.4 days, 3 entries | +0.3572%/yr | destroy the sole SP500 sleeve and baseline |
| `10919/XTIUSD` | PASS (1) | `4.84 / 1.851% / 30` | LOADED `90a71886...` | no accepted entry captured; live by July 24 | +0.7441%/yr | destroy the sole XTI sleeve and baseline |

Removing any `KS_BASELINE_LOADED` incumbent takes an armed, monitored identity
out of the live book. Re-admission would require a new OWNER decision and
fresh identity/baseline verification; the raw baseline file is not authority
to restore it. The 10440 exception has no baseline to destroy, but it still has
over a month of captured live trade evidence and remains governed by
`docs/ops/evidence/2026-08-02_10440_q10_path.md`.

## Ranked result

There is no qualifying ranked list. For reviewer orientation only, the least
bad non-qualifying cases are:

1. `10938→10911/GDAXI`: meaningful drawdown relief and neutral Sharpe, but
   worse annual return and no dominance over simple addition; R6 is also a
   hard lineage barrier.
2. `13036→10911/GDAXI`: more drawdown relief, but material Sharpe and annual
   return loss; R5 applies.
3. `13013→10440/NDX`: removes the uncovered sleeve and improves drawdown, but
   loses Sharpe, worst-day quality, and annual return; R7 applies.

These are diagnostics, **not swap recommendations**.

## Focused verification

```text
unchanged incumbent streams loaded from sealed bundle: 24/24
candidate streams loaded from sealed Q08 basis: 10/10
same-symbol pairs evaluated: 30/30
simple-addition ΔSharpe/ΔMaxDD/Δworst reproduced predecessor: 10/10 exact
swap portfolios: capped inverse-vol, cap 1.0, total risk 9.75
swap rows beating unchanged baseline and simple addition: 0/30
incumbent Q10 rows checked read-only: 11/11 identities
post-deploy KS events checked: 10 LOADED, 1 ABSENT (10440), matching 23/24 pulse
```

The farm DB was opened with SQLite `mode=ro`. T_Live was not contacted. No
enqueue, baseline generation, manifest edit, deployment, terminal action, or
pipeline verdict occurred. Admission and removal remain Claude review plus
OWNER authority.
