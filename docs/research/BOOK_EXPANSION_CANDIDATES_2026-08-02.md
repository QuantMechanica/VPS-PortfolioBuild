# DXZ book-expansion candidates — hash, lineage, and marginal-book adjudication

**Date:** 2026-08-02

**Router task:** `ad53e116-4f9f-416a-8f72-7355f01e2628`

**Authority:** OWNER 2026-08-02; recommendation only

**Disposition:** **NO CANDIDATE IS READY FOR ADMISSION.** Three candidates merit
conditional repair in the order `11422/USDCAD`, `13013/NDX`,
`13036/GDAXI`. No manifest, queue, terminal, baseline, deploy, or live state was
changed.

## Decision

The 12 off-book `Q10=PASS` identities are real, but a Q10 PASS by itself is not
an admission credential. Applying the requested stop-at-first-failure sequence
leaves **zero immediately admissible candidates**:

- five Q10 reports are hash-bound to the single current repo binary;
- one (`1328`) is bound to the intended Brooks binary but the EA ID now has two
  current directories/binaries, so the build identity is not clean;
- two (`10145`, `20048`) are proven stale by binary-hash mismatch;
- four older Q10 reports (`10183`, `10128`, `13013`, `10123`) predate
  `run_smoke/v2` execution-identity capture. Their reports contain no EX5 hash,
  so current-binary vintage is **unproven**, not inferred from mtime;
- every identity has an upstream lineage defect under the current contract.
  The most common decisive defects are absent `Q03`, hard/infra gate outcomes,
  missing evidence files, stale upstream evidence, and the current `Q09_NEWS`
  rows being `PENDING_RUNNER` rather than evidence-bearing `CONFIG_LOCKED`
  predecessors.

The fresh DL-083 marginal calculation nevertheless identifies three useful
repair targets. `11422/USDCAD` is the clearest return diversifier and introduces
a symbol absent from the book. `13013/NDX` raises Sharpe but is not a new
exposure. `13036/GDAXI` reduces drawdown and is low-correlated, but lowers
Sharpe and has a thin Q10 PF of 1.04. These are **conditional research
priorities**, not admission recommendations.

## Evidence basis and method

Read-only inputs:

- farm DB: `D:/QM/strategy_farm/state/farm_state.sqlite`;
- deployed-book record:
  `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json`;
- identical 24-sleeve membership with sealed stream basis:
  `D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json`;
- incumbent sealed bundle: `D:/QM/reports/portfolio/dxz_final_20260719`;
- candidate durable Q08 streams:
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/`;
- strict qualification census:
  `D:/QM/strategy_farm/artifacts/portfolio/ftmo_qualification_20260802.json`;
- live registries:
  `framework/registry/ea_id_registry.csv` and
  `framework/registry/magic_numbers.csv`.

`tools/strategy_farm/portfolio/marginal_contribution_eval.py` was run once for
each candidate against the incumbent book. It aligns candidate and incumbent
daily net-P&L streams, recomputes capped inverse-vol weights at the book's
9.75% total-risk budget, and reports the candidate's correlation to the
incumbent shared-equity trace, delta Sharpe, delta maximum drawdown, worst-day
delta, and annualized net contribution. The 12 machine-readable decision
papers are under:

`D:/QM/strategy_farm/artifacts/portfolio/book_expansion_20260802/`

The Q08 aggregates declare `commission_basis=worst_case_dxz_ftmo`; the durable
rows contain realized `profit`, `commission`, `swap`, and `net`. Therefore the
marginal calculation is spread-inclusive and net of the Q08 venue-cost model.
It is not a new pipeline verdict and not FTMO-native execution evidence.

## Step 1 — binary vintage

`Q10 hash` is the EX5 hash captured in the Q10 `run_smoke/v2` summary. `UNBOUND`
means the historical summary schema did not record one; it does not mean that
the bytes differed.

| Candidate | Current repo EX5 SHA-256 | Q10 EX5 SHA-256 | Vintage verdict |
|---|---|---|---|
| `13036/GDAXI` | `1cfe279753f0d73bc8a9d7ac92abf15643fbb4ba72853cec621d9b89575809ab` | same | PASS |
| `1328/EURJPY` | Brooks: `8b9b19e48e81bd2e666766f3bbfc216aa3a8c47e5cccaf77712f713d5f928262`; second EA-1328 binary: `df62e9e9f6350185bdc486f8e37b1e6b410357019ead376d45b9e61a3bd70c9b` | `8b9b19e48e81bd2e666766f3bbfc216aa3a8c47e5cccaf77712f713d5f928262` | Brooks bytes match; build identity fails later |
| `10142/SP500` | `caa9207647456f300e78900193a44b79b6c3643ad33782087991031c14521a83` | same | PASS |
| `10692/NDX` | `c7bbe5d26298dd10d4c5e3853330154120d84df38d5bbd84dbf888c1fdb08840` | same | PASS |
| `10938/GDAXI` | `939a4f0a3a67ca7aec267df9d2a273e68f8676639d72c8f9caa5c6b2da709bda` | same | PASS |
| `11422/USDCAD` | `159e616880681047f5c071850b42615aa046a7f1d301255d22ffeeba5726f064` | same | PASS at Q10; upstream is stale |
| `10145/XAUUSD` | `ebe9ca4c848cf6b0648417be51990318eb8ef4fa5e755146204e13e6f49192dc` | `268c228190d87f069b01a4a25e97752c051c3a3ebcae5b5c8cce24d1ff4bdccf` | **FAIL — stale** |
| `20048/XTIUSD` | `5c689d241cb29e79fa4153c8738fd27774167c2b381a7cdadef7daa84c3a9d73` | `3e583c2af728b13d2f83ca11709ffdb713c5115ab4f90850af0afea476f06d85` | **FAIL — stale** |
| `10183/XAUUSD` | `2c33af263d70e4d5a287cbcff04a393ee707cfd5438c0a4a9e1582789f0c1987` | `UNBOUND` | **UNPROVEN — rerun required** |
| `10128/XAUUSD` | `0d53e12208e39784c778145f607ed29d84b7a37e155d71caa767aba503064499` | `UNBOUND` | **UNPROVEN — rerun required** |
| `13013/NDX` | `c0038770ceac17691e79f0f05eea9cd75b02a6229c380a07675bee02f41d917a` | `UNBOUND` | **UNPROVEN — rerun required** |
| `10123/XAUUSD` | `c8be5bc42bb3218ad05740c4bf39888785795e62861050f3a0c315586acb5c51` | `UNBOUND` | **UNPROVEN — rerun required** |

The exact Q10 aggregates are under
`D:/QM/reports/work_items/<work-item>/QM5_<id>/Q10/<symbol>/aggregate.json`;
the work-item IDs appear in the adjudication table below.

## Steps 2–3 — lineage, build, registry, and risk contract

The current strict chain is `Q02` through `Q10`, including an evidence-bearing
news configuration before Q10. A missing file is not rehabilitated by a DB
`PASS` string. A later soft or hard failure is not rehabilitated by an older
Q10 PASS.

| Candidate / Q10 work item | First decisive lineage/build failure | Build / registry / set verdict |
|---|---|---|
| `13036/GDAXI` / `788d2371` | `Q03` absent; current `Q09_NEWS` is `PENDING_RUNNER` | One EA dir; active magic `130360001`; fixed-risk set clean |
| `1328/EURJPY` / `312d2888` | `Q02` evidence file missing; `Q03` absent | **FAIL:** two `QM5_1328_*` dirs/binaries; intended magic `13280023`; set risk clean |
| `10142/SP500` / `c78efefc` | `Q02=FAIL`; Q02–Q06 evidence files missing | One EA dir; active magic `101420000`; set risk clean |
| `10692/NDX` / `10c85a72` | `Q04=FAIL`; `Q05` absent; several evidence files missing | One EA dir; active magic `106920005`; set risk clean |
| `10938/GDAXI` / `e4130503` | stale `Q02=FAIL`; `Q05=INFRA_FAIL`; multiple evidence files missing | One EA dir; active magic `109380003`; set risk clean |
| `11422/USDCAD` / `6f9400fa` | Q02–Q08 evidence predates current build; current `Q09_NEWS` is `PENDING_RUNNER` | One EA dir; active magic `114220004`; set risk clean |
| `10145/XAUUSD` / `7c0b521a` | Q03–Q10 evidence predates current build; Q10 hash mismatch | One EA dir; active magic `101450034`; set risk clean |
| `20048/XTIUSD` / `25adbc0c` | Q02–Q10 stale; `Q04=PASS_SOFT` | One EA dir; active magic `200480000`; set risk clean |
| `10183/XAUUSD` / `2e13a544` | Q02/Q03 evidence files missing; `Q04=PASS_SOFT`; Q10 unbound | One EA dir; active magic `101830034`; set risk clean |
| `10128/XAUUSD` / `c3ea0dcb` | current-mtime Q02–Q10 chain, but Q10 binary hash unbound and `Q09_NEWS=PENDING_RUNNER` | One EA dir; active magic `101280034`; set risk clean |
| `13013/NDX` / `f8a81085` | Q04–Q06 evidence files missing; `Q07=INFRA_FAIL`; Q10 unbound | One EA dir; active magic `130130000`; set risk clean |
| `10123/XAUUSD` / `c042c58f` | Q02 stale; Q03 evidence missing; latest Q08 is `FAIL_SOFT`; Q10 unbound | One EA dir; active magic `101230034`; set risk clean |

Focused build-guardrail verification scanned all 13 directories (both EA-1328
directories included): every directory individually passed with
`max_news_stale_hours=336` and no findings. Every Q10-lineage backtest set has
`RISK_FIXED=1000` and `RISK_PERCENT=0`. The directory-level pass does not cure
EA-1328's cross-directory identity collision.

## Step 4 — marginal contribution to the existing 24-sleeve book

Positive `ΔMaxDD` is worse; negative is better. `max |corr|` is the maximum
absolute candidate-to-incumbent-book correlation over the evaluator's three
time thirds and high-volatility subset. The tool label is shown for
transparency but has **no admission authority**.

| Candidate | Tool label | Weight | ΔSharpe | ΔMaxDD pp | Δworst day pp | Ann. net contribution | Overall corr | max \|corr\| | Exposure assessment |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| `13036/GDAXI` | ADMIT-CANDIDATE | 0.236730 | -0.040950 | **-0.138351** | +0.003140 | +0.0777%/yr | +0.0355 | 0.0815 | Existing GDAXI; useful DD diversifier, weak expectancy |
| `1328/EURJPY` | REJECT | 0.244749 | -0.028802 | +0.125123 | +0.001540 | +0.0533%/yr | -0.0063 | 0.0687 | New symbol, but below 0.06% ops floor and degrades book |
| `10142/SP500` | WEAK | 0.669065 | -0.004317 | **+0.544862** | -0.236669 | +0.2085%/yr | +0.0475 | 0.1117 | Existing SP500; materially worse DD |
| `10692/NDX` | ADMIT-CANDIDATE | 0.084738 | +0.002294 | **-0.125567** | -0.074285 | +0.1769%/yr | -0.0044 | 0.0522 | Existing NDX; DD help, negligible Sharpe gain |
| `10938/GDAXI` | ADMIT-CANDIDATE | 0.227258 | -0.007212 | -0.051410 | +0.022266 | +0.1790%/yr | +0.0214 | 0.0637 | Existing GDAXI; mild DD help only |
| `11422/USDCAD` | ADMIT-CANDIDATE | 0.148436 | **+0.029226** | +0.048714 | -0.008893 | **+0.3156%/yr** | +0.0207 | 0.0628 | **New USDCAD exposure; strongest conditional addition** |
| `10145/XAUUSD` | WEAK | 0.229055 | -0.011558 | +0.350954 | -0.206531 | +0.5121%/yr | +0.2320 | 0.2660 | Sixth XAU sleeve; duplicate exposure and worse DD |
| `20048/XTIUSD` | ADMIT-CANDIDATE | 1.000000 | +0.012601 | -0.067699 | +0.062275 | +0.1376%/yr | +0.0123 | 0.0192 | Same symbol as existing XTI sleeve; modest conditional benefit |
| `10183/XAUUSD` | REJECT | 0.385043 | -0.035382 | +0.161699 | -0.108775 | +0.3486%/yr | +0.1938 | 0.2318 | Sixth XAU sleeve; degrades Sharpe and DD |
| `10128/XAUUSD` | REJECT | 0.287894 | **-0.108712** | **+0.427481** | -0.097597 | +0.0783%/yr | +0.1919 | 0.2353 | Sixth XAU sleeve; clear book degradation |
| `13013/NDX` | ADMIT-CANDIDATE | 0.336751 | **+0.026782** | +0.061698 | +0.032994 | +0.2875%/yr | +0.0170 | 0.1076 | Existing NDX; expectancy addition, slight DD cost |
| `10123/XAUUSD` | REJECT | 0.316861 | -0.022745 | +0.052130 | -0.273926 | +0.4724%/yr | +0.2384 | 0.2708 | Sixth XAU sleeve; duplicates exposure and lowers Sharpe |

The pre-add book max drawdown is approximately 2.1999% on every aligned
candidate window. Small differences in the pre-add Sharpe are expected because
each candidate defines a slightly different common calendar overlap.

## Ranked conditional shortlist

There is no ready-to-admit shortlist. If Claude chooses to spend repair time,
the evidence supports this order:

1. **`11422/USDCAD` — repair.** It adds a genuinely new symbol, has the best
   ΔSharpe (+0.0292), low regime correlation (0.0628), and the strongest
   annual contribution among the non-XAU diversifiers (+0.3156%/yr). The
   +0.0487 pp DD change is inside the evaluator's 0.05 pp neutral band. It must
   re-establish Q02–Q09 on the current binary before a hash-bound Q10 rerun.
2. **`13013/NDX` — repair if NDX concentration is acceptable.** It improves
   Sharpe by +0.0268 with max regime correlation 0.1076, at a small +0.0617 pp
   DD cost. It adds expectancy, not a new market. Missing Q04–Q06 artifacts and
   `Q07=INFRA_FAIL` must be repaired before a bound Q10.
3. **`13036/GDAXI` — repair as a DD diversifier only.** It has the best DD
   improvement (-0.1384 pp) and low max regime correlation (0.0815), but lowers
   Sharpe by 0.0410 and its Q10 PF is only 1.04. It is worth one clean-lineage
   check, not open-ended machine time.
4. **`20048/XTIUSD` — reserve only.** The marginal numbers are mildly positive,
   but it duplicates the existing XTI exposure, the full chain is stale, and
   Q04 is only `PASS_SOFT`. It ranks below the three candidates above.

`10692/NDX` and `10938/GDAXI` have attractive DD numbers but are not repair-only
cases: their recorded hard/infra gate failures must stand unless a separately
authorized, current-binary rerun is justified. They are not shortlisted here.

## Adds nothing to the current book

- **`1328/EURJPY`:** new symbol, but annual contribution is below the calibrated
  ops floor, Sharpe falls, DD rises, and the EA ID has two current builds.
- **`10142/SP500`:** duplicates SP500 and increases book DD by 0.545 pp.
- **`10145/XAUUSD`:** stale vintage, sixth XAU exposure, lower Sharpe, and
  +0.351 pp DD.
- **`10183/XAUUSD`:** sixth XAU exposure; both Sharpe and DD deteriorate.
- **`10128/XAUUSD`:** strongest book degradation in the set despite its
  standalone qualification state.
- **`10123/XAUUSD`:** latest Q08 is soft-fail and a sixth XAU sleeve lowers
  Sharpe.

## Repair commands and machine-time budget

No enqueue was executed. Under the current CLI, there is **no honest executable
command that fully repairs any of the three shortlisted lineages today**:

- candidate-specific `--ea ... --phase Q03` is rejected because `Q03` is not a
  cascade phase;
- the append-only exact-row Q02 rerun helper accepts only terminal
  `INFRA_FAIL` source rows, not stale `PASS` or strategy-`FAIL` rows;
- a new Q10 requires an evidence-bearing `Q09_NEWS=CONFIG_LOCKED` predecessor,
  while these identities currently have `PENDING_RUNNER` placeholders.

The exact first **supported** repair command for `13013/NDX` is below. It
preserves the terminal Q04 row and reruns from the current Q02 PASS; subsequent
Q05–Q10 commands must use the newly produced predecessor IDs and cannot be
precomputed honestly.

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_13013 --phase Q04 `
  --from-work-item-id 129df6ea-4f80-465b-8988-57b9d2f511f4 `
  --append-only-rerun-of 8f67fd04-bb12-4b54-b9c3-b6866000bcdc `
  --rerun-reason "BOOK_EXPANSION_2026-08-02_RESTORE_MISSING_Q04_EVIDENCE"
```

Estimated terminal cost: **1.5–3.0 hours** for Q04 through Q10 if each gate
passes, plus queue wait. Stop at the first non-pass.

The other conditional repairs require a small router ticket to add a
candidate-specific, append-only Q03/current-binary and stale-PASS Q02 rerun
path before enqueueing:

| Candidate | First required repair | Estimated terminal cost after tooling exists |
|---|---|---:|
| `11422/USDCAD` | append-only current-binary Q02, then Q03→Q10 | 2–4 terminal-hours |
| `13036/GDAXI` | candidate-specific Q03, then rebind Q04→Q10 | 2–4 terminal-hours |
| `10128/XAUUSD` | finish evidence-bearing Q09 news config, then append-only hash-bound Q10 | 15–30 terminal-minutes plus Q09 |
| `10145/XAUUSD` | current-binary Q03, then Q04→Q10 | 2–5 terminal-hours |

Giving a syntactically accepted broad-fanout command in place of a
candidate-specific repair would spend unrelated machine time and would not
prove this lineage. No such substitute is recommended.

## Verification

Focused checks run from `C:/QM/repo`:

```text
python tools/strategy_farm/validate_build_guardrails.py <13 candidate dirs>
PASS: 13/13 directories; max_news_stale_hours=336; zero findings

python tools/strategy_farm/portfolio/marginal_contribution_eval.py ...
PASS: 12/12 decision papers produced; no DB/queue/terminal writes
```

The farm DB was opened with SQLite `mode=ro`. T_Live was not contacted; the
book membership came from the countersigned manifest and durable published
state. The marginal labels are analytical outputs only. Admission remains
Claude review plus OWNER authority.
