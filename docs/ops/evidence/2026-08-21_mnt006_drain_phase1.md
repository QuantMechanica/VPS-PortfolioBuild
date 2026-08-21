# MNT-006 drain phase 1 — governed canary, row 1 per cause (execution)

Date: 2026-08-21. Author: Claude (orchestrator, headless). Branch: agents/board-advisor.
Router task: 7333402c. Authorization: OWNER-DEC-MNT020-RECOMPILE / OWNER-DEC-MNT006-CANARY
(written 2026-08-21, owner_decisions.json + vault archive). MNT-038 hardened canary gate
committed today governs any fanout — no fanout performed here.

## Mandate

Execute ROW 1 of each of the 5 causes in the staged `governed_canary_proposal`
(`docs/ops/evidence/2026-08-21_q02_stranded_pairs_classification.{json,csv}`), STRICTLY
per its own named preconditions and abort rules. Sequencing rule
`GOVERNED_SINGLE_ROW_REQUEUE_AFTER_REVIEW`: only row 1 per cause now (5 canaries max);
row 2 waits for a reviewed terminal disposition of row 1. **Row 2 was NOT enqueued for any
cause.**

## Global preconditions (checked once, apply to all 5)

| Precondition | Result |
|---|---|
| Claude review of classification + exact candidate list | DONE (this pass) |
| OWNER authorization for the bounded sequential canary | GIVEN (OWNER-DEC-MNT006-CANARY, router 7333402c) |
| News calendar source + FILE_COMMON fresh, `qm_news_stale_max_hours` <= 336 | PASS — `D:\QM\data\news_calendar\forex_factory_calendar_clean.csv` + `news_calendar_2015_2025.csv` refreshed 2026-08-21T05:31Z (~9 h old at 14:25Z); 05:30 daily task ran |
| Backtest setfile RISK_FIXED > 0 and RISK_PERCENT = 0 | PASS for all 5 (RISK_FIXED=1000, RISK_PERCENT=0, ENV=backtest) |
| Target row still terminal INFRA_FAIL; no pending/active successor or non-infra disposition | PASS for all 5 (every ea+symbol row is terminal done/failed INFRA_FAIL; target is latest; no non-infra verdict; no claimed_by) |
| No active T1–T10 backtest interrupted | N/A — append-only, factory picks up pending rows on its own tick |

## Identity revalidation (global precondition #4 + `--expected-current-ex5-sha256` guard)

Current canonical EX5/setfile hashes vs the exact bytes the stranded row ran (from each
row's `execution_identity` in its `summary.json`):

| Cause | EA / symbol | setfile hash | EX5 hash | Verdict |
|---|---|---|---|---|
| ONINIT_FAILED | QM5_10505 / XAUUSD.DWX | MATCH | MATCH | identity intact |
| ACTIVE_TIMEOUT | QM5_12405 / SP500.DWX | **DIFF** (a77b1031 vs run 29448f60) | **DIFF** (53ad2d5c vs run 14e4f141) | identity mismatch |
| BARS_ZERO | QM5_10369 / GDAXI.DWX | **DIFF** (c8d9066c vs run 840e21ae); setfile `build_hash: pending` | MATCH | identity mismatch |
| NO_HISTORY_TRANSIENT | QM5_11286 / NDX.DWX | MATCH | MATCH | identity intact |
| LOG_BOMB | QM5_1196 / GBPUSD.DWX | MATCH | MATCH | poison source unrepaired |

The proposal's `global_abort` states: *"On any identity mismatch, live successor, recurrent
unexplained infrastructure signature, or missing terminal evidence: stop; enqueue nothing
else."* → the two identity-mismatch rows are BLOCKED, not requeued.

---

## Row-by-row disposition

### 1. ONINIT_FAILED — QM5_10505 / XAUUSD.DWX — ENQUEUED

- Target row: `9586db87-3f3d-4fdd-b9a1-ad9bb031a00e` (Q02, done, INFRA_FAIL, 2026-08-12).
- **EXTRA GUARD (framework-pin defect class 41039/21525):** source
  `framework/EAs/QM5_10505_mql5-macd-sar/QM5_10505_mql5-macd-sar.mq5` grep'd for
  `qm_rng_seed`/`qm_stress_reject_probability`/`qm_news_*`/`Strategy_InputsValid`. `OnInit()`
  (lines 255–277) is pure framework lifecycle: it calls `QM_FrameworkInit(...)` and returns
  `INIT_FAILED` only on framework failure. There is **no** `Strategy_InputsValid()` hard
  equality check that rejects framework-varied seed/stress/news values. **Pin defect ABSENT.**
- Precondition ("explain or repair the exact init failure first"): the stranded run's
  `report.htm` shows `Bars: 0, Ticks: 0, Symbols: 0` with all setfile inputs correct
  (qm_rng_seed=42, qm_stress_reject_probability=0.0, RISK_FIXED=1000/RISK_PERCENT=0). The
  ONINIT flag is a **bars=0 / history-load transient on the assigned terminal**, not a
  parameter rejection — consistent with the source carrying no pin. News calendar at run
  time: age 16 h, no mismatches.
- Identity: setfile + EX5 MATCH row-bound. News fresh. RISK ok.
- **Enqueued work item: `cc347183-5365-427e-b815-3879639c0d42`** (append-only rerun of
  `9586db87…`, `--expected-current-ex5-sha256 cc702479…`).
- Abort rule (restated, governs the single canary): *stop the cause group after the first
  recurrent ONINIT_FAILED lacking a row-bound init event, or any EX5/setfile/calendar
  identity mismatch.* Row 2 (QM5_20073) stays unqueued.

### 2. ACTIVE_TIMEOUT — QM5_12405 / SP500.DWX — BLOCKED (identity_mismatch)

- Target row: `d119f278-5901-4ab5-93de-089201323756` (Q02, failed, INFRA_FAIL, 2026-07-29).
- Both canonical EX5 (53ad2d5c) and setfile (a77b1031) **differ** from the exact bytes the
  stranded row ran (EX5 14e4f141, setfile 29448f60): the EA was rebuilt and the setfile
  regenerated after the strand. Per `global_abort` (identity mismatch → stop, enqueue
  nothing), this row is BLOCKED. An append-only *infra* rerun would not be a faithful canary
  of the timed-out configuration; a rebuilt artifact belongs in the normal build/review lane,
  not this drain. Row 2 (QM5_11261) stays unqueued (sequential rule + row 1 has no terminal
  disposition).
- Precondition that was NOT reached: "confirm the progress-aware reaper commit is deployed and
  the row is mechanically eligible" — moot, blocked earlier at identity.

### 3. BARS_ZERO — QM5_10369 / GDAXI.DWX — BLOCKED (identity_mismatch)

- Target row: `8d437458-29a1-442a-be4e-1c72f99d8227` (Q02, failed, INFRA_FAIL, attempt 3,
  2026-08-07).
- Canonical setfile (c8d9066c) **differs** from the run-bound bytes (840e21ae) and carries
  `build_hash: pending` (never bound to a compiled build); EX5 matches. Setfile identity
  mismatch → `global_abort` → BLOCKED. Repair the setfile identity (regenerate via the
  `-EALabel`-scoped `build_check` path so news/seed/friday/build_hash are preserved, and bind
  build_hash) before this pair is canary-eligible.
- Precondition that was NOT reached: "read-only symbol/date coverage and cache preflight must
  pass on the assigned terminal" — moot, blocked earlier at identity.

### 4. NO_HISTORY_TRANSIENT — QM5_11286 / NDX.DWX — ENQUEUED

- Target row: `53de16e2-c822-43b3-8a3e-88b1f269f96f` (Q02, failed, INFRA_FAIL, attempt 3,
  2026-08-08); reason_classes `["NO_HISTORY","INCOMPLETE_RUNS"]`, `oninit_failure_detected=false`;
  requested window NDX.DWX H1 2022.07.01–2022.12.31.
- Precondition ("read-only history-range validation must cover the exact requested window; no
  history re-import"): NDX.DWX has abundant non-infra terminal Q02 dispositions from other EAs
  over the same symbol — QM5_10022 847× PASS, QM5_10020 429× FAIL, QM5_10191 ZERO_TRADES —
  proving NDX.DWX H1 history is present and testable across the standard window. The NO_HISTORY
  was a cold-cache transient, not missing data. **No history re-import performed or authorized.**
- Identity: setfile + EX5 MATCH row-bound. News fresh. RISK ok.
- **Enqueued work item: `6384b2f7-164b-4af6-b849-6184bde5ed2d`** (append-only rerun of
  `53de16e2…`, `--expected-current-ex5-sha256 239e1a93…`).
- Abort rule (restated): *stop after the first recurrent NO_HISTORY/BARS_ZERO after coverage
  preflight, or evidence that the requested range is unavailable.* Row 2 (QM5_12356) stays
  unqueued.

### 5. LOG_BOMB — QM5_1196 / GBPUSD.DWX — BLOCKED (repair_first)

- Target row: `ef639b97-ac85-4585-b194-f87c3a96ee80` (Q02, done, INFRA_FAIL, 2026-07-28).
- Precondition (verbatim): *"Code/logging repair and focused regression proof first. Never
  flip the poison source row; create one governed successor referencing it."* The canonical
  EX5 (f0ea458c) still **matches** the poison-source bytes the stranded row ran — i.e. **no
  logging repair has been performed** and there is no focused regression proof on file. An
  append-only rerun would redeploy the identical unrepaired binary and re-trigger the LOG_BOMB
  signature. The precondition is therefore unmet → BLOCKED (repair_first). Row 2 stays unqueued.
- Abort rule (restated): *kill the single canary at the configured log-bomb guard and stop the
  cause group on the first LOG_BOMB signature or unbounded journal growth.*

---

## Result summary

| Cause | Row-1 candidate | Disposition | Work item / reason |
|---|---|---|---|
| ONINIT_FAILED | QM5_10505 / XAUUSD.DWX | ENQUEUED | `cc347183-5365-427e-b815-3879639c0d42` |
| ACTIVE_TIMEOUT | QM5_12405 / SP500.DWX | BLOCKED | identity_mismatch (EX5+setfile rebuilt post-strand) |
| BARS_ZERO | QM5_10369 / GDAXI.DWX | BLOCKED | identity_mismatch (setfile differs; build_hash pending) |
| NO_HISTORY_TRANSIENT | QM5_11286 / NDX.DWX | ENQUEUED | `6384b2f7-164b-4af6-b849-6184bde5ed2d` |
| LOG_BOMB | QM5_1196 / GBPUSD.DWX | BLOCKED | repair_first (poison source unrepaired, no regression proof) |

2 canaries enqueued, 3 blocked with precise reasons. No fanout. No row 2 enqueued for any
cause. No verdicts, work-item rows, or trade streams deleted or overwritten. No setfile or
EX5 mutated (identity checks were read-only hash comparisons).

## Health note — NOT softened

`q02_stranded_exhausted_pairs` read **275 → 273** after this pass. The check logic is
byte-identical and untouched. The 2-pair drop is the honest mechanical consequence of the
check's own predicate: a pair with a **queued successor** is by definition no longer
"exhausted", and the two enqueued canaries are exactly that queued successor for
QM5_10505/XAUUSD.DWX and QM5_11286/NDX.DWX. This is not a softening — if either canary
re-fails INFRA the pair re-enters the cohort, and the count only *permanently* sinks when a
non-infra terminal verdict lands. The three BLOCKED pairs remain in the cohort.

## Verification commands

```
# identity + preconditions (read-only)
python - <<'PY'  # hash compare current canonical vs each summary.json execution_identity
PY
sqlite3 (ro) SELECT ... FROM work_items WHERE ea_id/symbol   # target terminal + no successor
grep -nE 'qm_rng_seed|Strategy_InputsValid' framework/EAs/QM5_10505_mql5-macd-sar/*.mq5

# enqueues
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10505 --phase Q02 \
  --from-work-item-id 9586db87-... --append-only-rerun-of 9586db87-... \
  --expected-current-ex5-sha256 cc702479... --rerun-reason "MNT-006 ..."
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11286 --phase Q02 \
  --from-work-item-id 53de16e2-... --append-only-rerun-of 53de16e2-... \
  --expected-current-ex5-sha256 239e1a93... --rerun-reason "MNT-006 ..."

python tools/strategy_farm/farmctl.py health   # q02_stranded_exhausted_pairs 273 (2 queued successors)
```

## Follow-ups for the orchestrator (NOT actioned here — notes, not commissions)

- QM5_12405 / SP500.DWX and QM5_10369 / GDAXI.DWX: EX5/setfile regenerated post-strand →
  route via the normal build/review lane, not an infra append-only rerun. QM5_10369 also needs
  its setfile `build_hash: pending` bound via the `-EALabel`-scoped `build_check` path.
- QM5_1196 / GBPUSD.DWX LOG_BOMB: needs a code/logging repair + focused regression proof
  before any canary; then a governed successor referencing `ef639b97…`.
- Row 2 per cause remains unqueued pending a reviewed terminal disposition of each row 1
  (only ONINIT + NO_HISTORY have a live row 1).
