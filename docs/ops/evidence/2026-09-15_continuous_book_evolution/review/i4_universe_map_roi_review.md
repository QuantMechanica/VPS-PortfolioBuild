# Adversarial Review — slice `i4_universe_map_roi`

Reviewer: Claude (adversarial, read-only). Date: 2026-09-15.
Verdict: **ACCEPT**

Scope: follow-up directive §19 (strategy universe economic map) + §20 (external
source programme ROI); master §46, §49. Deliverables: `universe_map.py`,
`external_roi.py`, `research_state_readmodel.py` folding, `ea_origin.v1.csv`
sidecar, two `docs/research/*.md` overviews, tests, one real run.

## Checks performed

- **`git apply --check` against HEAD:** clean, exit 0. No conflicts.
- **RED grep** (gate thresholds, qualification weakening, T_Live/AutoTrading/FTMO
  purchase/live deployment, sealed-artifact/dated-decision edits, farm DB writes,
  secrets, vault overwrites): **no RED touches.** Every `CREATE TABLE / INSERT /
  .commit()` hit is inside the two new test files building throwaway fixture DBs
  in `tmp_path`. The real DB is opened `mode=ro` + `PRAGMA query_only` via the
  canonical `work_item_clean_view` on both generators. `dxz_relevance` /
  `ftmo_profile` are explicitly labelled descriptive white-space overlays, not
  gate verdicts; no gate manifest / threshold is read or written.
- **Runtime artifacts real:** `D:/QM/reports/state/strategy_universe_map.json`
  (216 KB) and `research_roi.json` (6 KB) exist, written 2026-09-15 18:03. Their
  contents match the reported headline numbers exactly (see below).
- **Idempotency:** re-ran `build_universe_map(now=fixed)` and `build_roi(now=fixed)`
  twice in the implementer worktree — JSON byte-identical, `inputs_sha256` stable;
  `build_origin_table` byte-identical across runs (4,876 rows). Confirmed.
- **Sidecar reproducible + non-mutating:** regenerated `ea_origin.v1.csv` from the
  registry — **identical** to the committed sidecar. `ea_id_registry.csv` is never
  opened for write. 4,876 data rows + header; `basis` column exposes exactly how
  each row was decided.
- **Tests:** `pytest` on the three affected test files → **24 passed** in worktree.
  Covers map cells/classifiers/§19 answers, white-space ranking, origin-derivation
  precedence, ROI funnel arithmetic, sidecar shape, idempotency, and research_state
  folding + graceful degradation. The campaign-test edit is additive (new
  assertions + one new test); no existing assertion weakened.
- **No vault / dated-decision / sealed-artifact writes:** generators write only to
  `D:/QM/reports/state/*.json` and NEW `docs/research/*.md` (both confirmed absent
  in HEAD — genuinely new files). This slice does not touch `G:` vault (that is I1).
- **Honesty:** `economic_contribution.pnl = EVIDENCE_MISSING` with an explicit note
  (no per-EA PnL attribution artifact exists); `book_admission` used as the nearest
  signal, clearly labelled. `frequency_class` UNKNOWN dominance is disclosed in the
  JSON `definitions` and MD caveat. `failure_mining = 0` reported as a real finding.
  `eas_in_db_not_in_registry = 4` surfaced rather than dropped. No invented values.

## Headline numbers (verified against the real JSON)

- Universe = **14,939** ea×symbol pairs (Q02+); qualified **29**; DXZ incumbent
  **24**, FTMO incumbent **8**.
- breakout **10.32%** (1,541) · mean-reversion **10.68%** (1,595) · short-duration
  FX intraday/scalp **27.42%** (4,096) · gold **9.15%** (1,367) · session-tagged
  **4.38%** (654) · high-density FTMO-fit **1.05%** (157).
- Top white space: mean-reversion × intraday × session-open × index (EV 34).
- Origin distribution (4,876 EAs): external_source **4,307** · owner_mission **515**
  · internal_discovery **48** · commercial_rebuild **6** · failure_mining **0**.
- ROI yield (admit/Q02): external 0.935% · internal_discovery 2.273% · owner_mission
  0.478% · commercial_rebuild 0.0%.

All match the implementer summary.

## Minor observations (non-blocking)

1. **35% of origin rows are the slug-default fallback** (`slug:default_external`,
   1,695 rows) — attributed to `external_source` with no positive source evidence.
   This inflates the external_source funnel denominator. It is documented as a known
   weakness in both the module docstring and the ROI report, and the `basis` column
   makes it fully auditable, so the honesty bar is met. Tightening it (a first-class
   registry origin field) is a separate initiative.
2. **`_EXTERNAL_URL_MARKERS` uses broad substrings** ("book", "paper", "blog",
   "thread", "channel"). Matched only against source/citation front-matter lines and
   after the internal/rebuild/failure markers, so blast radius is small; a benign
   heuristic risk, not a correctness bug.
3. **Live `research_state.json` does not yet carry the `universe_map` / `roi`
   blocks** — expected, since the patch is unapplied and the 15-min task still runs
   the old read-model. The folding degrades gracefully (EVIDENCE_MISSING when the
   state JSONs are absent) and will populate once the orchestrator wires
   `universe_map.py` + `external_roi.py` into the 15-min task **before**
   `research_state_readmodel.py` (the implementer flagged this ordering; it is an
   orchestrator action explicitly assigned by the task, not a slice defect).

## Conclusion

Deterministic, idempotent, read-only, honest, well-tested, and directive-faithful
(§19 answered with numbers; §20 funnel by origin with the missing origin field now
derived into a non-mutating sidecar). No RED boundary crossed; `git apply` clean.
Accept as-is. The three minor items are documentation/follow-up, not fixes owed by
this slice.
