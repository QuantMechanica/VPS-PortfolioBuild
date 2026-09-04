# Pattern fire-count pre-screen: diagnostic delivery, NOT ACCEPTED

Date: 2026-09-04. Router task: `1ff3fa26-5eb8-4d5d-b57f-91687cc83213`.
RESULT: implementation and reproducible diagnostics delivered; mandatory acceptance remains unmet. Leave in REVIEW. No enqueue, gate, selection, verdict, terminal, or MQL changes.

Code commit: `fc543aca21` on `agents/codex`, in `C:/QM/worktrees/codex`. Three files: `tools/strategy_farm/research/pattern_fire_count.py`, `tools/strategy_farm/research/verify_pattern_fire_count.py`, and `tools/strategy_farm/tests/test_pattern_fire_count.py`. The [integration patch](2026-09-04_pattern_fire_count.patch) contains that commit's code changes and is unapplied to the canonical scheduler checkout. This evidence and its data are committed separately on `agents/board-advisor`.

## Acceptance result and corrected evidence base

The 552 focused tests pass, including all 527 hand-constructed fixtures with recorded native MQL PASS results. Every one of the 77 predicates has positive and negative coverage; existing boundary fixtures also match. Tests cover IDs, required windows, direction, previous closed bar across weekends, pending-order creation, partial fills, exclusion of exit orders, UTF-16 reports, parser loss, missing volume/history, nonfinite input, NY-close/DST, transparent tick aggregation, and pruning receipts.

The comparison meets the numerical threshold on **480 measured arm/year cells**: zero false never-fires, zero false fires, 100% agreement. It does not establish the requested full-program acceptance. Two material limitations remain:

1. The native DWX archive contains `.tkc` files; no decoder is available in the repository. The delivered tick builder handles explicit `time_msc,bid` CSV/CSV.GZ and rejects a TKC-only archive. The actual diagnostic cache is an existing native CopyRates D1 export, not a new derivation from those tick files. No terminal was started to export it.
2. EURUSD's 1,085 done ledger cells include **924 pruning receipts**, seven baselines and only 154 measured arms. The receipts have disposition `skipped_as_excluded`, schema `qm.dl089-skipped-as-excluded/v1`, and no profit/trade metrics. They cannot demonstrate equivalence to baseline. GBPUSD has 329 measured cells (three baselines plus 326 arms), and 756 pending cells. Its 2019 and 2021 arm coverage is partial.

The earlier premise that 132/154 EURUSD arms were measured identical in every year is therefore not substantiated by this ledger. The counter instead predicts 87 zero-count arms across the seven available baseline reports. Prediction on baseline data and verification against measured arm results are separate quantities.

The harness exits **2**, records `accepted: false`, and the counter always emits `safe_to_skip: false`. Missing/pruned cells are listed explicitly, never imputed as unchanged or counted in the confusion matrix.

| Program | Measured arm/year comparisons | Predicted zero, equal | Predicted zero, different | Predicted positive, different | Predicted positive, equal | Agreement |
|---|---:|---:|---:|---:|---:|---:|
| QM5_11421 / EURUSD.DWX | 154 | 135 | 0 | 19 | 0 | 100% |
| QM5_10706 / GBPUSD.DWX | 326 | 160 | 0 | 166 | 0 | 100% |

EURUSD comparison coverage: 2019 = 154; 2020–2025 = 0 each. GBPUSD: 2019 = 140, 2020 = 154, 2021 = 32. All compared cells have the same stable EX5 identity as their annual baseline and matching symbol, period, model, EA and test dates. There are **no disagreements** to explain within this measured subset; every comparison includes work-item ID, summary hash, baseline hash and exact metrics. The harness has explicit disagreement records and explanation fields for future mismatches, including unresolved explanations when causality is not established.

## Method and bar alignment

The port preserves the implemented IDs (3–60, 77–84, 87–94, 98–100), each MQL required window and inclusive/strict comparisons. It uses sequential double additions, including for ATR, means, population variance and efficiency ratios; Python's compensated `sum` is avoided for those operations. Calendar predicates use the reference bar's civil opening date: third Friday is days 15–21, quarter end the final two calendar days of March/June/September/December. The down-regime count preserves the MQL behavior that includes dojis among non-bulls. Unknown IDs or missing/invalid history raise errors instead of producing a false zero. Source hash changes force review of the port.

Both census EAs explicitly use `PERIOD_D1` and `closed_shift = 1`, including the GBPUSD EA hosted on H1. They invoke their managed pattern gate before sending an entry request. The parser joins English MT5 HTML Deals `in` rows to Orders by order ID. It counts distinct filled entry orders, deduplicates partial fills, ignores exits, and validates a report's Total Trades field when present. Pending orders use **creation time**, not later fill time, for the gate reference. For example, EURUSD baseline 2019 order 20 was created at 00:04:13 and filled at 19:49:15 on June 25. Index zero is the prior available D1 bar; Monday refers to Friday when there is no weekend bar. The current broker day must exist and 101 prior bars must be available for the full predicate set. No lookahead into the current bar is used.

The matching arm is `buy_NNN` or `sell_NNN` according to the entry side. All candidate-order counts are also emitted as diagnostics because a blocked unfilled order can affect later state; they do not replace filled-entry counts. Coincidence with a baseline entry is not, by itself, a proof about a counterfactual execution path.

## Data derivation and spot-check limits

Requested archive roots: `D:/QM/archive/Custom_master/ticks/EURUSD.DWX` and `.../GBPUSD.DWX`, each with 99 native monthly TKC files. Actual diagnostic sources: `D:/QM/mt5/T_Export/MQL5/Files/<symbol>_D1.csv`, produced by the existing native CopyRates export workflow. Cache paths are `D:/QM/data/research/d1_bars/<symbol>.csv`; adjacent `.provenance.json` files retain source and cache hashes and explicitly state that raw tick derivation/tester verification are false. MT5 numeric datetime fields encode broker civil time; applying a UTC offset to those exports again would be wrong.

The transparent tick builder's explicit UTC mode converts each timestamp to America/New_York civil time plus seven hours (GMT+2 winter/GMT+3 summer), then groups bid OHLC by broker midnight and counts tick records. It does not guess timestamps, infer proprietary TKC records, fill gaps, or claim that arbitrary exported tick rows reproduce native tick-volume semantics. Its cache manifest remains unverified until a governed native parity check exists.

Supplemental check: [probe source](2026-09-04_pattern_fire_count_bar_probe.py) and [all 40 sampled day comparisons](2026-09-04_pattern_fire_count_bar_probe.json). For each symbol, seed 20260904 selects 20 random overlapping days in 2019–2025. Native H1 exports aggregate to the D1 OHLC and tick volume **exactly on 20/20 days per symbol**. This is a cross-check between exports, not the requested check against tester journal/report OHLC references. The sampled baseline report directory retains `report.htm` and `tester.ini`; its summary-referenced tester log and logger sample are absent. Thus this delivery does not claim the mandatory 20 tester-bar references were verified.

## Fire-count output

| EA / symbol | Baseline years | Filled entry orders by year | Never-firing arms | Share | Arms with total count < 5 |
|---|---|---|---:|---:|---:|
| QM5_11421 / EURUSD.DWX | 2019–2025 | 3, 7, 19, 19, 10, 10, 13 | 87/154 | 56.49% | 117/154 |
| QM5_10706 / GBPUSD.DWX | 2019–2021 | 37, 32, 33 | 50/154 | 32.47% | 105/154 |

GBPUSD figures describe only the three observed baseline years. They are not a seven-year skip decision.

Full arm lists, annual counts, totals, source hashes and entry/reference-bar alignment:

- [EURUSD counts JSON](2026-09-04_pattern_fire_count_data/DL089_QM5_11421_EURUSD_DWX_2019_2025_counts.json) and [CSV](2026-09-04_pattern_fire_count_data/DL089_QM5_11421_EURUSD_DWX_2019_2025_counts.csv).
- [GBPUSD counts JSON](2026-09-04_pattern_fire_count_data/DL089_QM5_10706_GBPUSD_DWX_2019_2025_counts.json) and [CSV](2026-09-04_pattern_fire_count_data/DL089_QM5_10706_GBPUSD_DWX_2019_2025_counts.csv).
- [EURUSD verification and excluded receipts](2026-09-04_pattern_fire_count_data/DL089_QM5_11421_EURUSD_DWX_2019_2025_verification.json) and [comparison CSV](2026-09-04_pattern_fire_count_data/DL089_QM5_11421_EURUSD_DWX_2019_2025_verification.csv).
- [GBPUSD verification and pending cells](2026-09-04_pattern_fire_count_data/DL089_QM5_10706_GBPUSD_DWX_2019_2025_verification.json) and [comparison CSV](2026-09-04_pattern_fire_count_data/DL089_QM5_10706_GBPUSD_DWX_2019_2025_verification.csv).

Reproduce with `python C:/QM/repo/docs/ops/evidence/2026-09-04_pattern_fire_count_validate.py`. It runs the focused tests, the mandatory two-program harness against a read-only SQLite snapshot, and the supplemental bar probe. [Validation receipt](2026-09-04_pattern_fire_count_validation.json) records commands, file hashes, stdout/stderr and return codes `[0, 2, 0]`. The counter also exposes `count --program ... --symbol ... --bars ... --report YEAR=report.htm --output ...` and `build-bars --archive ... --timestamp-basis utc|broker --output ...`. The latter refuses the current native-only archive; it must not be represented as a completed archive build.

## Proposed Option B5 enqueue contract — design only

After a separate OWNER decision and accepted verification, the enqueue stage could evaluate total matching-entry counts across all seven preregistered baseline years and skip an arm only when count < N, proposed N = 5. Baselines still execute; declared trial count remains **154**, including skipped arms. A durable append-only skip receipt would bind program, symbol, direction, predicate, version/source hash, complete baseline report hashes, verified bar/cache provenance, alignment convention, annual counts, total count and authorized threshold.

Missing years, ambiguous report/order matching, unverified tick bars, binary/source mismatch, short history or failed verification must disable skipping. A skipped cell remains explicitly unmeasured; it is not synthesized into an equal baseline result or a PASS. Existing queued/running work and the current gate/selection rules remain governed by their own decisions. Integrating this proposal requires native tick/tester parity evidence and valid measured verification coverage; this delivery changes no census enqueue behavior.

## Review handoff

Deliverable is code plus tests plus evidence, not a document-only proposal. REVIEW disposition is **IMPLEMENTED_DIAGNOSTIC_ONLY / NOT_ACCEPTED**. Required next evidence is a governed native tick export/decoder with tester-bar parity, and an explicit resolution of the absent EURUSD arm results before claiming complete-program acceptance. The scheduled cycle did not launch terminals, run more census cells, alter pruning receipts, weaken news/risk guards, or advance main. The pre-existing dirty MagicResolver file in the code worktree was preserved byte-for-byte.
