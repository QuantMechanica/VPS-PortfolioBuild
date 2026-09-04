# EDGE-lab measurement log

Running log of every `tools/strategy_farm/research/edge_lab_stats.py` measurement.

**Why this file exists.** Until r3 this log lived as `## 8. Measurement log` inside
`docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md`. That document is SEALED: every
manifest records its sha256 in `rule_seal.doc_sha256` as the proof that the refutation
criteria predated the measurement. Appending the r2 log to it (commit `01d652bd3c`)
changed its bytes from 14,435 to 16,522 and its sha256 from
`cee886356945e38a7b56b482df3bcf3cc3d6b40a0e02b9d1e375d0296e311b37` to
`936667d5912c0cf3293f230cd1f687b7035cf8f544e8d9e4e3b6ea2c1b1d546e`, so the r2 manifest's
own seal stopped verifying against the file it names. **A sealed document may never be
written to by the thing it seals.** The section was moved here verbatim (see r2 entry
below), the sealed doc was restored to its exact pre-`01d652bd3c` bytes
(`git show f10c08b399:docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md`, 14,435 B,
sha256 `cee88635…`, git blob `9a33734c7947028c2e105d813c56757bd08f9b66`), and the tool
now additionally records `rule_seal.program_doc.git_blob_sha` and
`rule_seal.program_doc.read_at_commit` so a future append is detectable from a manifest
alone rather than only from a failed hash comparison.

---

## 2026-09-05 — r3 (fix round on the 2026-09-05 adversarial verify)

Tool `tools/strategy_farm/research/edge_lab_stats.py`
(sha256 raw `b506e3cc0385e188…`, LF `839e87b95a0786f2…`),
tests `tools/strategy_farm/tests/test_edge_lab_stats.py` — **97 passed** (r2: 79).

Invocation (identical to r2 apart from `--out`, and the program doc now resolves inside
the working worktree because the restored sealed doc lives there):

```
python -X utf8 tools/strategy_farm/research/edge_lab_stats.py \
    --hypothesis both --out docs/research/edge_lab/20260905_r3 \
    --now-utc 2026-09-05T00:00:00Z
```

**Verdicts are unchanged.** EDGE-1 UNDERPOWERED; EDGE-3 `XAUUSD.DWX|LDN_PM_1500`
DEAD_DECAY, `EURUSD.DWX|WMR_1600` REFUTED, `XAUUSD.DWX|LDN_AM_1030` NEGATIVE_CONTROL
(`r_excess` −0.0188, below the 0.10 void threshold, so the pipeline is not manufacturing
reversion). No verdict rule, threshold or criterion was changed in r3.

### Output identity vs the r2 copies

Every CSV that exists in `20260904T2045Z_r2/` is **byte-identical** in `20260905_r3/`
except `EDGE-1/event_windows.csv`, which gained eight appended columns and is identical
on all 39 r2 columns across all 1200 rows:

| file | r2 → r3 |
|---|---|
| `EDGE-1/baseline.csv`, `baseline_cells.csv`, `calibration.csv`, `calibration_events.csv`, `events.csv` | identical |
| `EDGE-3/fix_baseline_cells.csv`, `fix_baseline_hours.csv` | identical |
| `EDGE-1/event_windows.csv` | **intended**: `+ret_cl_p{5,15,30,60,90,120}`, `+mae_cl_p90_bp`, `+mfe_cl_p90_bp`; 0 of 1200 rows differ on the r2 columns |
| `EDGE-1/summary.json`, `EDGE-3/summary.json` | **intended**: additive blocks + 2 reworded `open_gaps` entries each; 1 removed count key (`counts.surprise_history_seed_rows`, split in two) and `counts.calibrated_instants` 106 → 150 |
| `EDGE-1/manifest.json`, `EDGE-3/manifest.json` | **intended**: relative `outputs.path` + `abs_path` + `out_root`, `code.hash_note` + `code.git_blob_sha`, nested `rule_seal.program_doc` (with git blob and read-at commit), per-output `note` |

No arm statistic, no cell statistic and no verdict moved. The EDGE-3 numbers are
unchanged even though its news mask grew from 106 to 150 instants, because the extra
instants all fall outside `is_start..oos_end` and no fix day is within an hour of one.

### Findings fixed (verifier 2026-09-05, PASS_WITH_FINDINGS)

**MAJOR 1 — COVID composition of the EDGE-1 primary cell was undeclared.**
Three of the 12 IS clusters carrying the headline are the 2020 Q2 payroll prints:

| release (UTC) | primary event | surprise z | cluster direction |
|---|---|---|---|
| 2020-04-03 12:30 | Non-Farm Employment Change | −8.896 | −1 |
| 2020-05-08 12:30 | Non-Farm Employment Change | +12.097 | +1 |
| 2020-06-05 12:30 | Non-Farm Employment Change | +37.346 | +1 |

`summary.regime_composition_sensitivity` now publishes the with/without pair in the same
shape as `cluster_direction_sensitivity`, and reproduces the verifier's recomputation
exactly:

| scope | n_eff | effect_bp | effect_sigma | t | se_cluster_bp |
|---|---|---|---|---|---|
| `ALL_IS_CLUSTERS` (sealed, headline) | 12 | 3.7863 | 0.2176 | 0.9392 | 4.0314 |
| `EX_COVID_2020Q2` (disclosure) | 9 | **2.0500** | **0.1178** | **0.3950** | 5.1903 |

The same three prints also inflate the 1095-day rolling surprise sd that every later
event's z is divided by. That denominator is now published per group per year
(`summary.surprise_history.rolling_sd_median_by_group_year`); for USD NFP:

| 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|
| 57,031 | 65,656 | 987,966 | 1,742,385 | 1,758,178 | 972,629 | 168,724 | 91,288 |

Consequence, measured rather than asserted: **no cluster primary between 2020-07 and
2023 reaches |z| ≥ 1** (max 0.8497, 2020-07-02) and the largest 2024-25 holdout
cluster-primary |z| is **0.9162** (2025-02-07). The holdout is therefore empty for two
reasons, not one, and `summary.holdout.empty_reason` +
`summary.holdout.trigger_diagnostics` now say both; the r2 text named only the calendar
coverage hole. A new `open_gaps` entry names the composition.

**No outlier policy was invented.** The verdict is still computed on all 12 clusters and
the ex-COVID block is reported beside it. `deviations_from_spec` carries a new
`NEEDS A SEAL` entry: an outlier policy must be sealed — what counts as a regime outlier,
whether the trailing sd is winsorised or re-estimated, and whether the holdout is
re-scored on the same basis — **before** EDGE-1 may be retried at a lower surprise-z
threshold. Choosing the threshold after seeing which clusters survive is the search the
whole file exists to prevent.

**MAJOR 2 — `event_windows.csv` was signed by the wrong direction for the headline.**
`ret_p*`, `mae_p90_bp` and `mfe_p90_bp` are signed by each row's OWN event direction
(`trade_dir`); the statistic signs by `cluster_trade_dir`. The two disagree on **330 of
1200** rows, so the headline could not be rebuilt from the published table. r3 appends
the cluster-signed twins `ret_cl_p{5,15,30,60,90,120}`, `mae_cl_p90_bp`, `mfe_cl_p90_bp`,
keeps the own-direction family (it is the right column for a per-event reading),
documents both in `summary.resolution.event_windows_signing`, in the `EW_HEADER` header
comment and in the manifest's per-output `note`, and adds
`summary.reproduction` with the exact recipe. A new test
(`test_headline_is_reproducible_from_the_published_cluster_signed_columns`) rebuilds
`primary_cell_result.effect_bp` from `events.csv` + `event_windows.csv` + `baseline.csv`
alone and asserts equality to 1e-9.

**MINOR 3 — sealed doc mutated.** Restored to its pre-`01d652bd3c` bytes; §8 moved here
verbatim; `rule_seal.program_doc.{git_blob_sha, read_at_commit, committed_blob_sha,
matches_committed_blob, path_in_repo, repo_root}` added. In this run
`matches_committed_blob` is **False** — correct and exactly the intended signal: the
restored blob `9a33734c…` differs from the still-committed mutated blob `1e13ecc7…` at
`read_at_commit` `178427f8fe`. The doc is also pinned `-text` in `.gitattributes` so
`core.autocrlf` cannot re-smudge the sealed bytes on checkout.

**MINOR 4 — calibrated-instant set depended on `--hypothesis`.** It is now computed once
in `main()` over the full calendar (`calibrated_instant_set`, 150 instants) and handed to
both hypotheses; only EDGE-1's confounding test keeps a window-truncated copy (106,
reported as `counts.calibrated_instants_confound_window`). The EDGE-1 baseline news halo
uses the full set, which is the conservative choice and provably changed nothing
(`baseline.csv` is byte-identical to r2). Test:
`test_calibrated_instant_set_is_hypothesis_independent` asserts `fix_days.csv` is
byte-identical under `--hypothesis both` and `--hypothesis EDGE-3`.

**MINOR 5 — gate-B circularity understated.** Gate B's ±90 min tickvol grid covers the
whole 90-minute holding window, so it conditions sample MEMBERSHIP on post-entry data.
The module docstring and `summary.calibration.stage0b_gate_b_circularity` now say so, and
`summary.stage0b_gate_b_sensitivity` publishes both scopes:

| scope | events verified | n_eff | effect_bp | effect_sigma | t |
|---|---|---|---|---|---|
| `GATE_B_ON` (sealed) | 200 | 12 | 3.786310 | 0.217600 | 0.939195 |
| `GATE_B_OFF` | 211 | 12 | 3.786310 | 0.217600 | 0.939195 |

`stage0b_gate_b_statistic_unchanged: true` — the 11 reinstated events are 4 distinct
Friday instants (2019-08-02, 2020-12-04, 2023-01-06, 2024-05-03) whose NFP primary all
carry |z| < 1, so none of them triggers. Matches the verifier's measurement exactly.

**MINOR 6 — SE docstring overclaimed, and the omitted term is NOT small.** Differencing
against a per-cell constant lets the between-cell baseline DISPERSION into `sd(diffs)`;
it does not propagate the cell means' own sampling error. r3 restates that accurately
**and adds the term explicitly** — correctly weighted per CELL, because triggers sharing
a cell share one baseline estimate and their errors are perfectly correlated:

```
se_baseline_component = sqrt( sum_c w_c^2 * se_c^2 )     w_c = trigger share of cell c
se_incl_baseline      = sqrt( se^2 + se_baseline_component^2 )
```

The divisor is the number of distinct cells (5 here), not of triggers, so it is of the
same order as `se`:

| arm | se | component | se_incl | t | t_incl |
|---|---|---|---|---|---|
| `XAUUSD.DWX|LDN_PM_1500` | 0.04978 | 0.04591 | 0.06772 | −2.4939 | **−1.8333** |
| `EURUSD.DWX|WMR_1600` | 0.02928 | 0.02928 | 0.04141 | −0.5858 | −0.4142 |
| `XAUUSD.DWX|LDN_AM_1030` | 0.03935 | 0.02478 | 0.04650 | −0.4769 | −0.4036 |

`se` / `t_stat` are deliberately left at the differenced-only definition — they are what
the criterion was computed with and moving them silently would be a criterion change —
and `se_incl_baseline_atr` / `t_stat_incl_baseline` are published beside them. **No
verdict moves:** all three arms are REFUTED on the doc-literal `R_FIX` basis, which
carries no t-statistic. It would have mattered on a SURVIVES-side arm.

**MINOR 7 — determinism test never compared the baseline tables.** New
`test_two_runs_with_baseline_rows_are_byte_identical` runs the fixture twice **without**
`--no-baseline-rows` and compares `EDGE-1/baseline.csv` and `EDGE-3/fix_baseline.csv`
plus every other output.

**MINOR 8 — `code.file_sha256` is checkout-dependent.** `manifest.code` gained the same
`hash_note` as the inputs block, naming `file_sha256_lf` as the authoritative key across
checkouts, plus `code.git_blob_sha`. This run demonstrates the point: raw
`b506e3cc0385e188…` ≠ LF `839e87b95a0786f2…` in this CRLF worktree, whereas the r2 run
recorded the two as equal only because it happened in an LF worktree.

**MINOR 9 — reused status and an arbitrary tie-break.** A group whose constant explains
fewer than `CALIB_MIN_VERIFIED_FRAC` of its own rows is now `VERIFY_FRAC_LOW`, not
`AMBIGUOUS` (which means something else: the tickvol peak moved between sample halves).
An exact tie for the modal home wall-clock minute is now `HOME_CLOCK_TIE` and drops the
group; it used to survive on the dict sort order and void one arbitrary half of the
group. `modal_home_clock()` is a unit-tested helper, `CALIB_STATUS_COUNT_KEY` enumerates
all six statuses, and `summary.calibration.status_semantics` publishes what each means.
Neither status fires on production data (0 groups), so `calibration.csv` is unchanged.

**MINOR 10 — outputs lived only in a scratchpad.** `manifest.outputs[].path` is now
relative to the `--out` root with `abs_path` kept as provenance and `out_root` recorded;
`EDGE-3/fix_days.csv.gz` is written next to the other tables as a deterministic gzip
(`mtime=0`, empty filename field) of the exact `fix_days.csv` bytes.

**Labelling nit (verifier claim 3).** `seed_rows_before_is_start` counted every row
outside the study window, including 6 after `oos_end` which seed nothing. Now split:
`seed_rows_before_is_start` **101**, `rows_after_oos_end` **6**,
`rows_outside_study_window` **107**, with `seed_label_note` recording the change.

### Additional defect found and fixed during r3 (not on the verifier's list)

The committed r2 tables did **not** match their own manifest's `sha256`: the tool writes
LF, git stored LF, and `core.autocrlf` smudged them to CRLF on checkout, so every
`raw_match` was False and only the LF-normalised hash agreed. This is the same class as
MINOR 8, but it hit the published evidence itself. The r2 working copies were normalised
back to LF (git blobs unchanged — `git diff` is empty for them) and
`docs/research/edge_lab/**/*.csv` and `**/*.json` are pinned `-text` in `.gitattributes`,
alongside the repo's existing 2026-09-03 raw-byte-evidence block. All r2 and r3 tables
now verify against their manifests by raw sha256 in any checkout.

### Files NOT committed (size), with their identity and regeneration command

| file | bytes | sha256 |
|---|---|---|
| `EDGE-3/fix_days.csv` | 6,515,719 | `ae36e0e9b509bade42c0ae68c64ab1470c470ab8994ef4f72191a88ab78d2ccc` |
| `EDGE-3/fix_baseline.csv` | 24,022,005 | `3b50865ee8814dff4e305c0791cb8acacc2013c19fe028971afb2d22358efc10` |

`fix_days.csv` ships compressed as `EDGE-3/fix_days.csv.gz` (1,298,094 B, sha256
`47e26f9f506ca3653a296aab715103b78f058607042a9ecc7544fc5c9294c743`); `gunzip -c` of it
reproduces the raw sha256 above. `fix_baseline.csv` is regenerated (together with
everything else) by re-running the invocation at the top of this entry — it is a pure
function of the pinned input shas and `--now-utc`, and the manifest records its sha256 as
`EDGE-3/fix_baseline.csv`.

### Caveats unchanged from r2

M5 BID bars only, gross returns, no intrabar path so no stop is measurable, spread
unmodelled, `known_at_utc` absent from the calendar. `sealed_before_measurement=false`
(the tree is dirty during a fix round) — **no seal is claimed for this run**.

---

## 2026-09-05 00:50Z — r2 (moved verbatim from EDGE_DISCOVERY_PROGRAM_V1 §8)

The text below is the `## 8. Measurement log` section as it was appended to the sealed
program doc by commit `01d652bd3c`, reproduced unchanged. It is history: several of its
statements were superseded by the r3 entry above (notably the holdout explanation, which
named only the calendar hole).

> ### 2026-09-05 00:50Z — edge_lab_stats.py r2 (workflow wf_35b7e0ed, task 315041f7)
>
> - Tool: `tools/strategy_farm/research/edge_lab_stats.py` (deterministic CLI; DST rules qm.dst_rule.us.v1 / uk.v1 ported from QM_DSTAware.mqh; Stage-0 tick-volume timestamp calibration + Stage-0b per-event voiding; sealed cluster rank map; frozen-IS holdouts). Tests: `tools/strategy_farm/tests/test_edge_lab_stats.py` (79). Two adversarial r1 reviews returned FAIL (4 blockers, 10 majors); all addressed in r2; r2 itself awaits an independent verify before any number here is cited outside this log.
> - Outputs (compact copies): `docs/research/edge_lab/20260904T2045Z_r2/EDGE-1/` and `EDGE-3/` (the 24 MB `fix_baseline.csv`, 6.5 MB `fix_days.csv` stay in the session scratchpad; regenerate with the manifest invocation).
> - **EDGE-1 (news surprise drift): UNDERPOWERED, not refuted, not supported.** Primary cell (|z|>=1, entry +5 min, hold 90 min): effect +0.218 sigma vs 0.40 floor on 12 independent clusters (floor 300), t = 0.94; holdout 2024-25 empty (no NFP print at |z|>=1). Sign is aggregation-rule dependent (+3.8 bp sealed rank / -0.2 bp row-mean / -4.9 bp unanimous). Tradeable entries 2.0/yr per symbol (< Q02 floor 5). Binding constraint is the calendar, not the market: only 3 of 124 high-impact groups yield a verifiable release instant; Stage-0b voids 24 % of those events.
> - **EDGE-3 (London fix): XAUUSD 15:00 arm DEAD_DECAY (doc-literal R_FIX basis); 10:30 negative control ~0 (pipeline not manufacturing reversion); WM/R 16:00 arm see summary.json.** R_EXCESS is confounded with time of day (declared deviation).
> - **Data finding (P0, escalated separately, `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md`):** both production calendar files store US 08:30-ET releases ~17 h early for 78 % of 2018-2025 rows (NFP/Retail Sales/Unemployment Rate 100 %); coverage hole 2025-05..2026-06. 2026 rows correct.
> - Caveats unchanged: M5 BID bars only, gross numbers, no intrabar stops, `sealed_before_measurement=false` (dirty tree) — no seal claimed.
