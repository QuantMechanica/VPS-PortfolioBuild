# Evidence receipt — PATTERN_ABLATION programme design (2026-09-16)

**Programme:** PATTERN_FILTER (OWNER directive 3 §29 / interim §9), research+specification slice.
**Status:** DESIGN DELIVERED — nothing commissioned, nothing enqueued, no DB writes, no economic validation, no gate-contract edits, no commits.
**Author seat:** Kimi (interim OWNER delegation). **Commissioning seat:** Fable (OWNER seat).

## 1. Deliverables produced

| Artifact | Path |
|---|---|
| Programme design doc | `docs/research/PATTERN_ABLATION_PROGRAMME_2026-09-16.md` |
| Machine-readable trial plan (schema `qm.pattern-ablation/v1`) | `tools/strategy_farm/config/pattern_ablation.v1.json` |
| Hermetic schema test (11 tests) | `tools/strategy_farm/tests/test_pattern_ablation_config.py` |
| This receipt | `docs/ops/evidence/2026-09-16_pattern_ablation/receipt.md` |

**Test result:** `python -m pytest tools/strategy_farm/tests/test_pattern_ablation_config.py -v` → **11 passed in 0.49s** (Python 3.11.9, pytest 9.1.1). Hermetic: repo files only, no DB/network/D: access.

## 2. What was designed

A deterministic, non-combinatorial single-filter ablation programme: **11 bases × exactly 1 predicate each** (no stacks, no combinations, `combinations: []`), each with a pre-registered mechanistic hypothesis under the sealed **blacklist** semantics (`QM_PatternPermission.mqh:258` — a firing predicate blocks its side). 10 bases are qualified-pool members (contiguous Q02→Q14, `candidate_universe.csv`); the 11th (QM5_41475 H-CW, NDX lead) is the FTMO-gap priority and is **conditional** — dormant until its own Q02 PASS. All 26 qualified pairs + 3 frontier rows are dispositioned (selected or explicit non-selection with reasons, pinned by test).

Selected bases (priority order) → predicate (catalog id):

1. QM5_13213 balke-gmt3-range-breakout USDJPY H1 → **44 Wide Range Bar** (vol) — WRB order-placement bar = chase/displacement entries into a quiet-range edge.
2. QM5_13013 grimes-trendday-v2 NDX M15 → **84 Trend Exhaustion** (regime) — breakout into an exhaustion-flagged tape = terminal coil, not a trend day.
3. QM5_10706 tv-mon-ls GBPUSD H1 → **18 Spinning Top** (price-action, Unger) — indecision-body close-back-inside carries no rejection conviction for the Monday-sweep fade.
4. QM5_10700 tv-liq-break XAUUSD H1 → **83 Regime Transition** (regime) — contraction breaks in trend birth/death chop are noise breakouts.
5. QM5_11660 pp-wedge NDX H4 → **79 Ranging** (regime) — continuation signals in a ranging tape are coin flips.
6. QM5_10513 mql5-ichimoku XAUUSD D1 → **79 Ranging** (regime) — same mechanism replicated on a second strategy class/symbol.
7. QM5_11881 connors-rsi2-mean-reversion GBPUSD D1 → **60 Vol Expansion** (vol) — MR fades into expanding vol are knife acceleration.
8. QM5_41219 cum-rsi2-commodity-requal8 XAUUSD D1 → **88 Zscore High** (regime) — dip signals firing at statistical extension are early-knife longs.
9. QM5_11422 williams-18ma-outside-bar-entry-d1 USDCAD D1 → **3 Doji** (price-action, Unger) — doji trigger bars = failed-breakout population at the decision bar.
10. QM5_9641 bandy-cci-extreme-fade-mr-index WS30 D1 → **100 Quarter End** (time) — quarter-end flows manufacture persisting CCI extremes.
11. QM5_41475 cash-window-index-continuation-h1 NDX H1 (CONDITIONAL, G0) → **98 Volume Climax** (vol) — climax-shaped signal bars are event displacement that mean-reverts intraday.

Each trial: arms `baseline`/`buy_{pid}`/`sell_{pid}` × 2019–2025 + the sealed anchored WF windows (test 2022–2025); null NO_FILTER control mandatory; kill criteria (expectancy drop >5% rel. in ≥2/3 years, any year >10%; trade reduction >20% without ≥+5% rel. return_to_maxdd gain; activity-floor breach inadmissible; WF subset-stability failure inadmissible); census-anchored trade-reduction bands per trial. BH FDR within pre-registered families; **22 declared direction-trials** logged to `search_history_ledger` before any measurement and fed to Q16 DSR/PBO deflation.

## 3. How the trials enter the normal Q12 lane when commissioned

The programme runs **inside** the existing Q12 contract (DL-089, ROT) — the ablation never becomes a parallel gate.

### 3.1 Fixture-harness pre-gate (already green; command documented from code)

No census may enqueue before a green, hash-bound pattern-permission fixture harness row exists (`opt_census._harness_pass`, opt_census.py:430–490). The exact command pattern, from `farmctl.py`:

```
python tools/strategy_farm/farmctl.py enqueue-pattern-fixture-harness \
  --symbol EURUSD.DWX --period D1 --year 2024 \
  --from-date 2024.01.02 --to-date 2024.01.10 \
  --timeout-seconds 600 \
  [--compiled-probe <artifact-only fixture compile dir>] \
  [--terminal T<n>]        # optional pin, T1–T10 only
```

- Args defined at `farmctl.py:38070-38084`; dispatch at `farmctl.py:38890-38901`; implementation `enqueue_pattern_fixture_harness` at `farmctl.py:8969-9082`.
- Code-enforced preconditions: `--symbol` must be covered by the live custom-history isolation manifest (`D:\QM\strategy_farm\state\custom_history_isolation_activation.json`); the fixture EX5 (`QM_pattern_permission_fixture_runner`, `HARNESS_PP_FIXTURE_EA_LABEL`, farmctl.py:458) must exist under the fixture source dir (or the `--compiled-probe` dir after `pattern_fixture_compile_probe.verify_probe`); the repo bundle `framework/tests/fixtures/pattern_permission/_bundle/pattern_fixtures.csv` must exist.
- Side effects when run: copies the bundle to `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\pattern_fixtures.csv` (`COMMON_FILES_ROOT`, farmctl.py:494-496 — hardcoded, not %APPDATA%-derived; farmctl.py:9019-9033) and INSERTs one `kind='harness'`, `phase='HARNESS_PP_FIXTURE'`, `priority_track=True` work item.
- Current state: post-repair green receipts exist (append-only readjudication `ccd5acb4-af10-51ce-8b64-8953a6cb2a4b`, 535/535 native fixtures, per `docs/ops/evidence/2026-09-09_pattern_filter_repair.md` final section); `opt_census._harness_pass` resolves the newest green successor of anchor `83b89730-bb86-4c18-955a-efefe3039cc5`. Commissioning step 0 = Fable confirms that anchor still resolves (re-run the command above only if a fixture/predicate code change drifted the include — none is part of this programme).

### 3.2 Per-trial enqueue into the OPT_CENSUS lane (the normal Q12 lane)

```
# 1. plan: declaration + 1,085 governed setfiles (155 arms x 7 years), deterministic UUIDs
python tools/strategy_farm/opt_census.py plan \
  --ea-id QM5_13213 --ea-label QM5_13213_balke-gmt3-range-breakout \
  --symbol USDJPY.DWX --timeframe H1 \
  --base-setfile <governed _opt base setfile with opt_pp_buy1..3/opt_pp_sell1..3> \
  --output-dir <artifacts/pattern_ablation/QM5_13213_USDJPY/setfiles> \
  --plan-out <artifacts/pattern_ablation/QM5_13213_USDJPY/plan.json>

# 2. enqueue: harness + Q02 preconditions, ledger, idempotent INSERTs
python tools/strategy_farm/opt_census.py enqueue \
  --plan <plan.json> --ledger <ledger.json> \
  --db D:/QM/strategy_farm/state/farm_state.sqlite \
  --harness-work-item-id 83b89730-bb86-4c18-955a-efefe3039cc5

# 3. drive + inspect the DL-089 state machine (census -> WF selection -> ...)
python tools/strategy_farm/opt_census.py advance --ledger <ledger.json> --db D:/QM/strategy_farm/state/farm_state.sqlite
python tools/strategy_farm/opt_census.py report  --ledger <ledger.json> --db D:/QM/strategy_farm/state/farm_state.sqlite
```

Code-enforced preconditions (`opt_census.py`): `_harness_pass` (green fixture row + bound native proof, lines 430–490); `_q02_pass` (the census EA owns a done/PASS Q02 row, lines 493–514); `validate_base_setfile` (opt_pp inputs present, `RISK_FIXED > 0`, `RISK_PERCENT = 0`, `environment: backtest`, lines 198–217); `enqueue` pins `planned_trials == 1085` (line 523) and stamps `declared_trial_count = 154` into every cell payload (line 579).

**Read-out discipline:** the sealed census measures the full 77×2 matrix; the ablation read-out is restricted to the pre-registered single predicate per direction (the config's `trial_id`). Adoption only via the sealed selection rule (≥2/3 years ≥+5% return_to_maxdd, activity floor, WF stability) — Q12 stays ROT. A reduced 3-arm plan (21 cells) would need a Fable-approved code change; not assumed (design doc open question Q3).

### 3.3 Commissioning sequence and authority

1. **Fable signs** a commission artifact at `decisions/YYYY-MM-DD_pattern_ablation_commission.md` naming this config (SHA-pinned), the trial subset to start (recommendation: ABL-001 first), and any exclusions.
2. **Ledger first:** the operator seat appends the 22 declared direction-trials to `D:/QM/reports/state/search_history_ledger.jsonl` (families `pattern_filter.*`) **before** the first enqueue.
3. **Per base:** verify base setfile → `opt_census.py plan` → `enqueue` → `advance` → ablation read-out vs kill criteria → report.
4. **Positive read-out:** the base already owns its full census program (step 3); the sealed WF selection runs via `advance`; only a sealed selection promotes a filter into the Q13→Q14 chain, with Q16 deflation over the total declared trials.
5. **Negative read-out:** hypothesis closed, recorded in `experiment_memory_ledger.jsonl`; no retry under a new predicate without a new pre-registered thesis.

No AI seat commissions its own trials; the farm executes only against Fable's signed artifact.

## 4. Boundaries honored

- New files only: the 3 deliverables + this receipt; `git status` on those paths shows untracked-only, no modifications, no commits (central commit pass).
- No DB writes (all DB references are read-only documentation of code paths; no command in §3 was executed).
- No gate-contract edits: Q12/DL-089 quoted, never modified; the config pins "Q12 remains sole authority".
- No economic validation: every census number cited is labeled descriptive.

## 5. Evidence index

- Catalog: `docs/research/PATTERN_FILTER_CATALOG.md` (77 predicates; census fields per predicate; §22 ablation design; cap=3 disposition).
- Q12 contract: `decisions/DL-089_pattern_filter_wf_census_v3.md`; `tools/strategy_farm/config/gate_manifest.v4.json` (Q12 block); vault `03 Pipeline/Q12 Pattern Filter Selection.md`; `docs/ops/PIPELINE_PHASE_SPEC.md`.
- Gate code: `framework/include/QM/QM_PatternPermission.mqh` (BLACKLIST v1, closed-bar fail-closed); `tools/strategy_farm/opt_census.py`; `tools/strategy_farm/farmctl.py:8969-9082, 38070-38084, 38890-38901`.
- Defects: `docs/ops/evidence/2026-09-09_pattern_filter_repair.md`; `docs/research/UNGER_PATTERN_CENSUS_FINDING_2026-09-12.md`.
- Pool/value: `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/candidate_universe.csv`; `D:/QM/reports/state/book_evolution_dxz.json` + `book_evolution_ftmo.json`; `audit/dxz_live_book.md`; `audit/ftmo_fitness_candidates.md`; CAMP-2026-0001 receipt; `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md`.
- Base specs: `framework/EAs/QM5_<id>_<slug>/SPEC.md` per selected base.
