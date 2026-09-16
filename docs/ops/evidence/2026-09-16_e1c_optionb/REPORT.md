# E1-C Option B (with conditions) — delta revalidation execution report

Generated UTC: 2026-09-16 (execution window ~14:00–15:00Z)
Executor: Kimi (interim delegation), task `e1c-optionb`, worktree preflight PASS on
`agents/board-advisor` (base `423866c7`), write scope `tools/strategy_farm`,
`tools/strategy_farm/config`, `docs/ops/evidence/2026-09-16_e1c_optionb`.

## Required 9-metric output (first complete pass, reconciles exactly to 99)

```
NEWS_TAINT_TOTAL=99
UNCHANGED_EQUIVALENT=91
VERDICT_FLIP=0
DELTA_NOT_EXACT=0
EVIDENCE_INCOMPLETE=8
HOLDS_RELEASED_OPTION_B=91
FULL_REMEASUREMENT_OPTION_A=8
NEW_RUNNABLE_WORK=91
FORECAST_RUNNABLE_HOURS_ADDED=0
```

Reconciliation: 91+0+0+8 = 99 = 91+8. Machine-checked asserts in
`tools/strategy_farm/research/e1c_delta_revalidate.py`; authority: `summary.json`
(`summary_sha256` bound, verified by the release tool before applying).

## Calendar bytes used (hash-documented per condition)

| role | bytes | sha256 |
|---|---|---|
| old tainted bundle (pinned) | `D:\QM\data\news_calendar\q09_bundles\q09cal-20150101-20260809-0bb19b5bb9790b76\events.csv` | `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` (= taint config entry, = live pin manifest `content_sha256`) |
| new clean primary (LIVE published) | `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` | `c48ad8b4bf667001ef7204d37f5420504f853ac25aa6f0a70152b3d743a1c134` |
| new clean secondary (identity recorded) | `D:\QM\data\news_calendar\forex_factory_calendar_clean.csv` | `e15b6fe1f80f2f6a82a612f16ef7aaf6b9cc450d3eba1c3a94690ceee2f3b935` |
| live bundle manifest | `D:\QM\data\news_calendar\news_calendar_bundle_manifest.json` | declared `6d7d64b60bb72278e6c65cfb1e738b84a1d9fc5cf11488b573cc136cc1356320` |

## Deterministic finding that drives the classification

Over every held row's evidence window the two calendars' event sets are **identical**
(same `(instant, event_name, impact)` rows per currency):

- 2019-01-01..2025-12-31 (all promoted-row windows): byte-count- and row-identical per
  currency (e.g. USD 7895=7895, EUR 6266=6266, zero added/removed/changed).
- 2026-01-01..2026-04-06 (all 55 diagnostic windows): both calendars are EMPTY — the
  2025-05..2026-06 gap exists in BOTH files (shared upstream gap; backfill is the
  separate human-gated registry-repair/refresh program, NOT this pass).

Consequence: every row's relevant delta is empty. VERDICT_FLIP is unreachable by
construction — the calendar is not an input to either gate
(`q09_news_contract.adjudicate` / `q10_confirmation._decide_verdict` /
`q07_multiseed.evaluate_seeds` consume sealed backtest metrics only); a non-empty delta
would have failed closed to DELTA_NOT_EXACT. Equivalence is certified against the LIVE
bytes above; if the registry repair backfills 2025-05..2026-06, equivalence must be
re-certified before any further Option-B release.

## Gate logic used for verdict recomputation (found, not invented)

- Matrix evidence (`q09-news-evidence/v2|v3`, cells): `q09_news_contract.adjudicate` —
  reproduced `CONFIG_LOCKED` on a sealed v3 sample; no held row used this shape.
- Legacy Q09 aggregate: `framework/scripts/q10_confirmation._decide_verdict`
  (PF_FLOOR=1.0, DD_PCT_MAX=25.0) + the recency-gate outcome recorded in the sealed
  aggregate. All 24 legacy Q09-sourced rows reproduced exactly (verdict AND reason,
  e.g. `pf=1.210:dd_pct=9.82`).
- Q07 multi-seed aggregate: `framework/scripts/q07_multiseed.evaluate_seeds` over the
  embedded `per_seed_detail`. All 6 such rows reproduced exactly (e.g.
  `variance_pct=7.50<20.0:min_pf=1.150`).

## Condition-6 semantics test (tools/strategy_farm/tests/test_e1c_taint_guard_semantics.py, 4/4 pass)

1. **enabled + tainted hash** → `PINNED_CALENDAR_TAINTED` reason; sweep applies the
   hold; claim blocked. A naive per-row release (hold-table UPDATE only) is
   **re-applied by the next sweep** — the guard re-applies holds from the config
   entry alone. No per-row persistent release existed for Q09_NEWS rows.
2. **enabled + clean hash** → sweep RELEASEs (note "Untainted pinned bundle or
   explicit policy rollback"); claimable. Pin-level/global, not per-row.
3. **disabled** → `guard_claim` inert, but the sweep short-circuits and **existing
   holds stay active** — claims remain blocked by the generic active-hold SQL check.
   "Disabled" ≠ "holds released".
4. **hash-absent (tainted=[])** → decision returns None via the documented "explicit
   removal is the documented policy rollback" branch; sweep RELEASEs existing holds.

Rollback label check: none of these effects is opposite its label; the config's own
`rollback` text was verified against code behavior (state 4 releases; state 3 does
NOT release existing holds — documented divergence).

## Release mechanism actually used (per the verified semantics)

Because state 1 proves a plain per-row hold release is re-applied, the release uses
the code's own per-row counter-path pattern (exact analog of `release_scoped_item` /
scoped-B marker), implemented in `tools/strategy_farm/news_calendar_taint.py`:

- `release_e1c_item()` stamps an append-only payload marker
  (`qm.e1c-optionb-release-marker/v1`, decision `OWNER-E1C-OPTIONB-20260916`)
  hash-bound to the row's delta record (`record_sha256` = canonical self-hash), then
  releases exactly this module's active taint hold (CAS `changed==1`) and writes an
  events row. Status/verdict/evidence never touched.
- `_e1c_marker_allows()` makes `decision()` honor the marker: on EVERY sweep/claim it
  re-reads the record file, re-computes its canonical hash, and re-checks
  schema/work-item/status `UNCHANGED_EQUIVALENT`/eligibility/pin binding. Any
  tampering, deletion, wrong row, wrong status or pin change fails closed → hold
  re-arms. Never raises.
- Governed applier: `tools/strategy_farm/session_tools/release_e1c_optionb_rows.py`
  (dry-run default; `--apply` under `FactoryMutationLock`, one `BEGIN IMMEDIATE` per
  row; verifies `summary.json` sha + record self-hashes; receipt
  `release_receipt_20260916T144659Z.json`, 91/91 released, 0 errors).
- The tainted sha config entry is KEPT (condition 1: the old bundle is still
  tainted); `tools/strategy_farm/config/news_calendar_taint.v1.json` is byte-untouched
  (git diff empty). No rollback was implemented at all — global or otherwise.

Marker tests: `tools/strategy_farm/tests/test_e1c_release_marker.py` (6/6): happy path
+ sweep never re-applies; tampered record re-arms; wrong-status record refuses
release; wrong-row/other-pin fail closed; transaction + active-hold prerequisites;
double-release race fails. Full taint suite regression: 38/38 green.

Live post-release verification: active `NEWS_CALENDAR_TAINTED` holds = 9
(8 Option-A census rows + 1 drift row, see below); read-only sweep preview over the
live farm: 99 `NONE`, 9 `ALREADY_HELD`, 4 `PRESERVE_OTHER_HOLD` (unrelated newer
holds on post-census rows), **zero `HOLD`/`RELEASE` actions** — released rows stay
released under the live config + live tainted pin.

## Condition-by-condition compliance

1. **Old Q09 evidence preserved**: no verdict/evidence/hold-history/manifest was
   mutated; every record cites the original evidence paths + shas; original verdicts
   reproduced, never rewritten. The tainted calendar hash stays in the config.
2. **Per-row delta contract**: all 14 fields per row in `rows/<work_item_id>.json`
   (EA/symbol/timeframe, windows, old/new bundle+hash, relevant old/new event sets,
   exact added/removed/changed-impact lists, original/recomputed overlap+verdict,
   original Q09 verdict, recomputed verdict, status, `record_sha256`). Statuses limited
   to the four allowed values. Only UNCHANGED_EQUIVALENT rows released, hash-bound.
3. **Fail-closed Option A**: the 8 `EVIDENCE_INCOMPLETE` rows got NO lift; they stay
   taint-held and route to FULL_Q09_REMEASUREMENT_REQUIRED on the clean calendar
   (owner-authorized fallback; the 8 are all Q10_NEWS promoted rows with
   `q09_autoseal_failure` — no hash-bound sealed plan/window exists for them; a fresh
   sealed plan must be built, which is the remeasurement path anyway). No stopped
   classes: no genuinely new semantic ambiguity arose — the shared-gap equivalence
   and the re-application semantics were both anticipated and are documented.
4. **Rebind only after validation**: the live registry pin was NOT repinned (receipt-
   chain divergence is the separate human-apply repair, condition 5). Per-row marker
   releases happened only after delta validation + sealed record generation; each
   release note + marker carry the decision citation and record hash.
5. **Receipt-chain repair**: untouched. No AI-Commit items modified.
6. **Semantics verified from code before any config change**: no config change was
   made at all; semantics tests written first and documented above.
7. **Factory scheduling**: this pass consumed zero MT5 slots (pure deterministic
   analysis); the 91 released rows enter normal Factory scheduling; no scheduler
   configuration was touched; FTMO/frontier/Second-Chance/41478 census lanes
   unaffected.
8. **Required output**: the 9 metrics above, reconciled exactly.

## Drift and boundaries

- One NEW hold appeared mid-session (live sweep, `2026-09-16T14:08Z`,
  `564c7e0e…` QM5_9973/NDX Q10_NEWS) — after the 99-row census. It was classified
  (UNCHANGED_EQUIVALENT) but is **excluded from the metrics** and reported under
  `hold_drift_excluded_from_metrics` in `summary.json`; it remains held (its release
  belongs to the next governed pass once the OWNER confirms census extension).
- Post-release live sweep shows 4 `PRESERVE_OTHER_HOLD` Q10_NEWS rows (post-census
  enqueues already held by unrelated codes) — the taint sweep correctly leaves them;
  when their other holds clear, the guard will apply taint holds and they join the
  next census.
- The equivalence certificate binds the calendar bytes by hash; any refresh that
  changes the live bytes (e.g. the pending registry-repair backfill) invalidates it
  and requires re-running `e1c_delta_revalidate.py` before further releases.

## Artifacts

- `summary.json` — 9-metric authority + per-row table + identity hashes (`summary_sha256`).
- `rows/*.json` — 100 per-row delta records (99 census + 1 classified drift).
- `release_receipt_20260916T144659Z.json` — governed release receipt (91/91).
- Code: `tools/strategy_farm/research/e1c_delta_revalidate.py`,
  `tools/strategy_farm/news_calendar_taint.py` (E1-C marker + `release_e1c_item`),
  `tools/strategy_farm/session_tools/release_e1c_optionb_rows.py`,
  `tools/strategy_farm/tests/test_e1c_taint_guard_semantics.py`,
  `tools/strategy_farm/tests/test_e1c_release_marker.py`.
