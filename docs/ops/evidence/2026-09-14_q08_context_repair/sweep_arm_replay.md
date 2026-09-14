# Q08 DSR context for window-sweep arms — implementation + replay (way 1)

Ticket `7d9dd3b5-3e9f-4fa0-9c61-e9ae23d51ed2`, decision `OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914`,
receipt `9e6ddd6b`. Append-only. No DSR/FDR formula, gate threshold, keep/control
fraction, candidate-universe, or stored-verdict change. Commit references below.

## What landed: the prescreen-skip rule (fully data-verified)

`tools/strategy_farm/dsr_cohort.py`: a `PRESCREEN_SKIPPED`-held census cell whose skip
authority re-authenticates (via `dl089_prescreen_retro.disposition`, re-derived from the
receipt/proof every call, never trusted from the stored hold alone) is now treated as a
validly measured year with **zero trades**, not a missing trial — the arm stays in the
cohort. Any other non-terminal cell (no hold, or a hold that fails re-authentication)
keeps the existing `INCOMPLETE_TRIAL` path, or fails closed under the new
`PRESCREEN_SKIP_AUTHORITY_INVALID:<row_id>:<reason>` name if a hold exists but its
receipt/proof doesn't check out — distinctly named per the ticket's own wording, not
folded into the generic `INCOMPLETE_TRIAL` reason.

- `_prescreen_skip_disposition(conn, row)`: thin wrapper around
  `dl089_prescreen_retro.disposition`, converts a `ValueError` (authentication gap) to
  `CohortUnavailable`.
- `_matrix_trial_groups(ledger, current, conn)`: now takes `conn`; for each DL-089 cell
  row, calls the wrapper and, when it returns non-`None`, attaches the disposition under
  a private `_dsr_prescreen_skip` marker key on a shallow row copy. **`_peer_metric`'s
  external call signature is unchanged** (`(trial_id, trial_index, rows, *, role)`) —
  `tools/strategy_farm/tests/test_dsr_cohort.py`'s existing monkeypatch of `_peer_metric`
  (positional `role`) keeps working untouched.
- `_peer_metric`: before the existing `status=='done'` requirement, checks for the
  `_dsr_prescreen_skip` marker; when present, appends a full zero-filled calendar-day
  return series for that row's `from_date`/`to_date` span and a `prescreen_skip_receipt`
  provenance binding, then continues to the next row. No change to the Sharpe/mean/stdev
  math, the report-based trade reconciliation, or any other branch.
- `assemble()`: one-line call-site change, `_matrix_trial_groups(ledger, current, conn)`.

### Live, read-only replay against the real database (not a fixture)

Verified directly against `D:/QM/strategy_farm/state/farm_state.sqlite` (read-only
connection, no writes):

| EA/symbol | held cell | work_item_id | `_prescreen_skip_disposition()` result |
|---|---|---|---|
| QM5_21507/XAUUSD | `sell_032`/2025 | `2c1a2b99-61e9-521d-8916-9eb2fcd12c91` | **resolves**: `{receipt_path: .../program_ddeff217bb5cf7ef.json, program_id: DL089_QM5_21507_XAUUSD_DWX_2019_2025, unmeasured: True}` |
| QM5_20266/XTIUSD | `buy_010`/2025 | `12bb82a8-cb07-521c-8867-eb686e2f208a` | **resolves**: `{receipt_path: .../program_8f99428a1a102791.json, program_id: DL089_QM5_20266_XTIUSD_DWX_2019_2025, unmeasured: True}` |

Both calls return a full disposition dict (not `None`, no exception raised) against the
**actual production receipts and events table**, not synthetic fixtures — confirming the
code change resolves the exact two rows named in the ticket
(`assemble()` for these two candidates no longer raises `INCOMPLETE_TRIAL:DL089:PATTERN:sell_032`
/ `:buy_010` on the previously-held years; the 2019–2024 years for both cells were already
`MEASURED`, so both arms were already only one year short of a complete history).

Note the per-arm `ea_id` gotcha this research surfaced: the OPT_CENSUS cell rows for
21507/20266 live under the *arm's own* `ea_id` (`QM5_41196` for 21507's `sell_032`,
`QM5_41198` for 20266's `buy_010`), never under the candidate EA's own id — only the
ledger's `subject_ea_id` carries `QM5_21507`/`QM5_20266`. Querying `work_items` by the
candidate's own `ea_id` finds nothing; this cost real time during investigation and is
worth a code comment for the next person.

### New tests

`tools/strategy_farm/tests/test_dsr_cohort_prescreen_skip.py` (4 tests, all green):
valid skip authority keeps the arm with a full zero-return year; no hold at all still
raises `INCOMPLETE_TRIAL` unchanged; a hold present but failing authentication fails
closed under the new named reason; `_prescreen_skip_disposition` itself delegates to
`dl089_prescreen_retro.disposition` and wraps a `ValueError` correctly. Existing suite:
`test_dsr_cohort.py` (11), full `-k dsr` sweep (79 tests) — all green, no regressions.

## What did NOT land: window-sweep ledger consumption for the 6 WTI EAs + 12115

The ticket's premise — that `QM5_41115/41158/41176/41131/41381/41423` (XTIUSD) and
`QM5_12115` (XAUUSD, 2 rows) are arms of a sealed `qm.window-sweep.v1` programme whose
losers/controls `dsr_cohort` merely needs to learn to read — **does not match what exists
on disk**, verified directly against the live DB and `D:/QM/strategy_farm/artifacts/opt_census/`:

- **Zero `OPT_CENSUS` work items, zero `opt_census/` artifact directories, and no
  approved card exist for any of these 8 rows.** Each went `COMPILE_EA → Q02 → ... → Q08`
  as an ordinary single-build candidate (`promoted_from_phase:"Q07",
  promotion_source:"pump_cascade"` — the standard auto-promotion path).
- Their real provenance (per `docs/research/`) is an informal "diversity funnel"/"commodity
  sleeve" idea generator: each wake proposes **one** new hypothesis, checks it for
  duplicates against the registry, and builds it if a capacity gate passes. Rejected ideas
  never become work-item rows. This is structurally incompatible with
  `config_sweep`/`window_sweep`'s "one base EA, N literal parameter-override arms, all N
  measured or explicitly held" model — there is no losers list to recover, because no
  formal search was ever run.
- Corroborating evidence: `QM5_41380` (same TSMOM-family sibling as `QM5_41381`) was
  already resolved in the prior Class-A execution via a plain `DECLARED_SINGLE_CONFIGURATION`
  card declaration, not a window-sweep ledger — the class-B decision card itself notes
  this parenthetically. That is what these EAs' actual governed history looks like.
- `assemble_single_configuration`'s current `SINGLE_CONFIGURATION_UNAVAILABLE:...
  No such file or directory: '...cards_approved\<label>.md'` failure for all 8 rows is
  **already correct** — no approved card exists, so no single-configuration declaration
  can be made either. Nothing in `dsr_cohort.py` is broken here; the missing input is an
  approved card (or, if a real search history is wanted, an actual sealed
  `config_sweep`/`window_sweep` program run against these EAs — a separate, much larger
  undertaking outside this ticket).

**Consequence for the acceptance criteria**: "tests + offline replay on QM5_41115/XTIUSD
and QM5_41158/XTIUSD" cannot be satisfied with real data today, because no sealed ledger
exists for either EA to replay against — this is a data/process gap, not a `dsr_cohort.py`
defect. Writing a code path with zero possibility of real-data verification, on a
DSR/FDR-adjacent statistical component with a hard "no formula change, fail closed on any
authentication gap" constraint, was judged too risky to land speculatively in this pass —
see the open design question below, which the research phase surfaced and which needs an
OWNER call before implementation, not a Claude-side guess.

### Open design question, needs an OWNER decision before implementing the general capability

If/when a real `qm.window-sweep.v1` ledger does exist for a candidate, "every arm of the
programme (winners AND losers, controls included) is a trial" is ambiguous between:

- **(a)** every arm *declared* in the original matrix-CSV declaration (e.g. 50 arms),
  including PRESCREEN-only arms that were dropped before promotion and therefore have no
  `REAL_TICKS`/native-report evidence at all — `_peer_metric`'s report-based Sharpe calc
  cannot compute anything for these without a new evidence shape, which the ticket's "same
  peer-metric code, no new formula" constraint forbids.
- **(b)** only arms that reached `REAL_TICKS`/promoted status (the KEEP arms plus the
  mandatory CONTROL arm) — i.e. `authenticate_ledger`'s `real_cells`/promotion-amendment
  output — which `_peer_metric` *can* compute a report-backed Sharpe for using its existing
  code, unchanged.

(b) is almost certainly what's intended given the "no new formula" constraint, but the
acceptance text's own wording ("losers and controls included") doesn't fully resolve
which population "losers" refers to. Recommend recording this as an explicit OWNER
decision (parallel to `OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914` itself) before a future
ticket implements the `assemble_window_sweep()` branch, function-shape already sketched in
the research handoff for this task (reuses `config_sweep.authenticate_ledger`/
`window_sweep.authenticate_ledger` unchanged for authentication; adds only the
grouping/plumbing dsr_cohort needs around them).

## Ablation sets (10163, 10932) — resolved, stays INVALID

`tools/strategy_farm/ablate.py` read in full: it mutates a parent setfile ±perturb_pct per
numeric `strategy_*` input, writes N sibling setfiles, and inserts N ordinary `pending`
Q02 work items tagged `is_ablation:true` in their payload (depth-1 only). **There is no
ledger, schema, seal, hash-binding, or "arms" concept anywhere in this tool** —
structurally nothing like `qm.window-sweep.v1`. Confirmed no `OPT_CENSUS` rows or
`opt_census/` artifacts exist for either `QM5_10163` (`..._ablation_04.set`) or
`QM5_10932` (`..._ablation_02.set`). **No sealed ablation ledger exists for either EA.**
Both rows stay `INVALID` under `assemble_single_configuration`'s existing (and correct)
`SINGLE_CONFIGURATION_UNAVAILABLE` / `EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED`
path — no configuration is declared for either, per the ticket's explicit instruction not
to.

## OPEN_ITEMS_STATUS.md RESULT line (draft, for whoever finalizes the tracker)

> **Q08 sweep-arm context (7d9dd3b5)**: PARTIAL. Landed: `dsr_cohort.py` prescreen-skip
> rule, live-verified against real receipts for 21507/sell_032 and 20266/buy_010 (both
> now resolve past their prior `INCOMPLETE_TRIAL`). Not landed: window-sweep ledger
> consumption for the 6 WTI EAs (41115/41158/41176/41131/41381/41423) + 12115 — no sealed
> ledger exists for any of them (verified against the live DB and opt_census/ tree); this
> is a data/process gap, not a code gap, and the general capability's
> `effective_trial_count` semantics need an OWNER decision before implementation.
> Ablation rows 10163/10932: confirmed no sealed ledger exists, stay `INVALID`, documented
> not coded.
