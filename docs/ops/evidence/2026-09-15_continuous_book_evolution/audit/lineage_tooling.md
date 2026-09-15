# Lineage / Duplicate-Map Tooling Audit — Directive §9

**Scope:** inventory the deterministic similarity/lineage evidence that exists today, design a
concrete deterministic lineage/duplicate map, and state what can be computed **now** for the
Balke / Gold Reaper / ORB / session-breakout / XAU families. Read-only. Author: Claude (auditor
subagent). Date: 2026-09-15.

## Headline (3 lines)

1. **No lineage/duplicate map exists.** Rich raw material is present — per-trade sealed streams
   (248 EAs at Q08), card `parent_ea_id`/`source_id` frontmatter, `work_item_supersedes`
   (1,720 rows), and two working parsers (`extract_round_trips`, `qm5_35005_equivalence`) — but
   nothing joins them into a company-wide relationship graph; §9's seven relationship classes are
   nowhere machine-encoded.
2. **The hard inputs already exist to compute it deterministically:** Q08 `q08_sealed_stream.*.jsonl`
   gives entry/exit timestamps + daily net per (EA,symbol), so **trade-overlap Jaccard and daily-PnL
   correlation are computable today** for any pair that reached Q08; `.mq5` files carry a demarcated
   strategy region for a normalized rule-hash.
3. **The heavily-represented families are only related in prose.** Gold Reaper is documented as the
   same dead edge as Balke XAU (QM5_13213) in a research dossier, not in any structured field; the
   Balke lineage chain (13213→41097→41398→41405) lives only in loose card frontmatter present on 32
   of 1,710 cards.

## Measured counts

| Metric | Value | Query / command |
|---|---|---|
| EA directories under `framework/EAs` | 4,125 | `ls framework/EAs \| wc -l` |
| Strategy cards (`docs/strategy_card.md`) | 1,710 | `ls framework/EAs/*/docs/strategy_card.md \| wc -l` |
| Cards with `source_id:` frontmatter | 1,571 | `grep -rl "source_id:" framework/EAs --include=strategy_card.md \| wc -l` |
| Cards with `parent_ea_id:` frontmatter | 32 | `grep -rl "parent_ea_id:" ... \| wc -l` |
| Cards with `implementation_parent_source:` | 2 | `grep -rl "implementation_parent_source" ... \| wc -l` |
| Cards with a `family:` key | 11 | `grep -rhoE "^family:" ... \| wc -l` |
| `work_item_supersedes` rows | 1,720 | `select count(*) from work_item_supersedes` |
| — of which "recorded in payload without a stated reason" | 914 | `select reason,count(*) ... group by reason` |
| `work_item_dependencies` rows | 376 | `select count(*) from work_item_dependencies` |
| `candidate_qualifications` rows (has `candidate_lineage_key`, `supersedes_qualification_id`) | 0 | `select count(*) from candidate_qualifications` |
| Distinct EAs with a Q08 work_item | 248 | `select count(distinct ea_id) from work_items where phase='Q08'` |
| Q08 work_items total (each with a sealed per-trade stream) | 956 | `select count(*) from work_items where phase='Q08'` |
| Distinct (ea,symbol) reaching Q14 | 34 | `select count(distinct ea_id\|\|symbol) from work_items where phase='Q14'` |
| `ea_metrics` rows (carry `parent_work_item_id`, `is_ablation`) | 100,175 | `select count(*) from ea_metrics` |
| Balke-named cards | 11 | `ls framework/EAs \| grep -i balke` |
| Gold-Reaper EA cards | 0 (research dossier only) | `ls framework/EAs \| grep -iE reaper` |
| XAU-named EA dirs | 139 | `ls framework/EAs \| grep -icE xau` |

SQLite reads via `sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True, timeout=30)`.

## Findings — inventory of existing lineage/similarity evidence

### A. Card-level lineage fields (repo, authoritative)
Strategy-card YAML frontmatter is the only place a human-declared lineage lives. Observed keys
(example `framework/EAs/QM5_41405_balke-clock-audit-opt/docs/strategy_card.md`):
- `parent_ea_id:` (e.g. `QM5_41398`) — direct parent EA. Present on **32/1,710** cards.
- `implementation_parent_source:` — path to the parent `.mq5` the child was copied from. **2** cards.
- `source_id:` — UUID into the `sources` table (external book/video/forum origin). **1,571** cards.
- `family:` — free-text family tag. **11** cards, inconsistently populated.
- `r1_reasoning` / `g0_approval_reasoning` frequently name the inherited lineage in prose
  (e.g. "R1-R4 inherited from the approved parent lineage QM5_13213/41097/41398").

**Gap:** lineage is sparse, free-text, and one-directional (child→parent only); the seven §9
relationship *classes* are absent; no child→children or sibling edges exist.

### B. Work-item / DB lineage tables (runtime)
- `work_items` columns usable as signature/lineage keys: `parent_task_id`, `mq5_sha256`,
  `ex5_sha256`, `include_closure_sha256`, `setfile_sha256`, `build_id`, `data_window_start/end`.
  `mq5_sha256` + `include_closure_sha256` together are an **exact source-identity signature**
  (byte-level), already populated per build.
- `work_item_supersedes(work_item_id, superseded_by_work_item_id, reason, evidence_path, …)` —
  1,720 rows, but **914 have no stated reason** and the semantics are pipeline-hygiene
  (stale-compile, re-adjudication) not *strategy* lineage. Not a strategy-relationship graph.
- `work_item_dependencies(child, dependency_role, parent, required_verdicts_json)` — 376 rows;
  encodes gate-chain dependency (e.g. Q10 depends on Q08 evidence), not strategy similarity.
- `candidate_qualifications` has purpose-built `candidate_lineage_key` and
  `supersedes_qualification_id` columns — **but 0 rows**; the intended lineage ledger was never
  populated.
- `ea_metrics.parent_work_item_id` + `is_ablation` link ablation/child runs to their base.

### C. Deterministic behaviour primitives that already work
- **`tools/strategy_farm/portfolio/ftmo_report_cost_reconcile.py :: extract_round_trips(report_path, symbol)`**
  — parses an MT5 report's Deals table into round trips (entry time, exit time, side, volume,
  profit, commission, swap). Ready-made trade-list extractor from HTML reports.
- **`tools/strategy_farm/qm5_35005_equivalence.py`** — runs two EX5 binaries in one sealed tester
  config, canonicalizes every native Deals field, and emits `IDENTICAL` / `DEVIATION`. This is a
  working **exact-clone-by-runtime-behaviour** proof (no gate verdict). It is the strongest existing
  similarity primitive but is single-pair and task-bound, not a corpus map.
- **Q08 sealed streams** `D:/QM/reports/work_items/<wid>/<ea_id>/Q08/<symbol>/q08_sealed_stream.*.jsonl`
  — one JSON line per closed trade with `entry_time`, `time` (exit, epoch), `net`, `side`,
  `volume`, `symbol`, `magic`. **This is the ideal, already-sealed primitive for both trade-overlap
  Jaccard (on `entry_time`) and daily-PnL return correlation (bucket `net` by exit day).** Available
  for 248 distinct EAs / 956 Q08 runs.
- Q08 also emits `8_1_correlation.json` (portfolio pairwise correlation subgate) — proves the
  correlation math is already trusted inside the pipeline; it operates on the same stream.
- `dxz_lineage_audit.py` (DXZ book preset-provenance/lineage classifier) and
  `q08_recovery_lineage.py` exist but are book/recovery scoped, not a strategy relationship map.

### D. Report / trade-file layout (concrete pair verified)
Per-run evidence root: `D:/QM/reports/work_items/<work_item_id>/<ea_id>/<phase>/<symbol_DWX>/`.
Concrete pair inspected (both XAUUSD, Q08, INVALID):
- `…/914dfeda-ab93-451e-ade3-80af1082ec51/QM5_21507/Q08/XAUUSD_DWX/q08_sealed_stream.126bb069b2caea25.jsonl`
- `…/84202fc0-cf09-419f-81e5-c821f14f5bf3/QM5_11263/Q08/XAUUSD_DWX/q08_sealed_stream.*.jsonl`

Sealed-stream columns (verified): `event, money_basis, magic, side, entry_price, exit_price, time,
entry_time, mae_acct, net, profit, swap, fee, commission, entry_commission, exit_commission,
volume, notional, symbol`. `time`/`entry_time` are Unix epoch seconds → deterministic overlap and
daily-return series without re-running any terminal.

### E. Source normalization for a rule-hash
`.mq5` files carry a demarcated boundary between framework boilerplate and strategy logic
(`framework/EAs/QM5_13213_balke-gmt3-range-breakout/…​.mq5`, lines 7–35 banner:
"boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle …)"). A normalized
strategy-rule hash is feasible by extracting the strategy region, stripping comments/whitespace and
parameter *default values*, and hashing the residual entry/exit logic.

## Drift / risks

- **`candidate_qualifications` designed-for-lineage but empty (0 rows).** A lineage schema was
  intended and abandoned; do not build on it blind — treat as UNKNOWN, re-derive from streams.
- **`work_item_supersedes` is not strategy lineage.** 914/1,720 rows carry no reason and the
  populated reasons are compile/evidence hygiene. Using it as a "superseded strategy" source would
  be wrong (Goodhart risk).
- **Family tags are unreliable** (`family:` on 11 cards; Gold Reaper has 0 cards). §9's own warning
  — "Names are insufficient" — is confirmed by the data: the map MUST be behaviour-first.
- Card `parent_ea_id` is present on only 32 cards; most true parent/child chains (e.g. the WTI/XNG
  seasonal cohort, 300+ near-identical cards) are undeclared and can only be recovered from
  `mq5_sha256`/rule-hash + parameter distance.

## Recommended implementation

### Module
`tools/strategy_farm/lineage_map.py` (read-only builder) + `tools/strategy_farm/tests/test_lineage_map.py`.
Deterministic, idempotent (same inputs → same JSON), quota-flag-aware, no gate/verdict writes.
Companion projector writes the Vault section (see below). Wire a scheduled `STRATEGY_LINEAGE`
health line into Mission Control alongside the §6 `STRATEGY_WIKI_SYNC` check.

### Inputs (all deterministic, all already on disk)
1. **Declared lineage** — card frontmatter `parent_ea_id`, `implementation_parent_source`,
   `source_id`, `family` (weak prior only; never sole basis for a class).
2. **Source signature** `S_src` = SHA256 of the *normalized* strategy region of `.mq5`
   (strip framework banner block, comments, whitespace, and input **default literals**; keep
   entry/exit control flow and indicator calls). Byte-exact fallback = `work_items.mq5_sha256` +
   `include_closure_sha256`.
3. **Parameter-set distance** `d_param` — per shared input, normalized |Δ|/range from the card
   parameter table / `.set`; L1 mean over shared inputs; `+inf` if the input *sets* differ.
4. **Trade-overlap Jaccard** `J` — on entry-day (or entry-timestamp bucketed to the bar) sets from
   the Q08 sealed streams of the two (EA,symbol) runs on the **same symbol + overlapping window**.
   `J = |A∩B| / |A∪B|`.
5. **Return correlation** `ρ` — Pearson on the daily-net PnL vectors (bucket `net` by exit day),
   aligned on the common date index, from the same Q08 (or Q14) streams.

### Relationship classes + proposed numeric thresholds (rationale)
Evaluate top-down; first match wins. All pairs are within the **same symbol** for J/ρ (cross-symbol
pairs can only reach the source-based classes).

| Class | Rule | Why |
|---|---|---|
| `EXACT_CLONE` | `S_src` equal **or** `qm5_35005_equivalence` = IDENTICAL | Byte- or runtime-identical logic; the existing equivalence proof is authoritative. |
| `CLOSE_IMPL_CLONE` | `S_src`≠ but normalized-rule token similarity ≥ 0.90 **and** `J ≥ 0.80` **and** `ρ ≥ 0.95` | Same mechanism re-typed; behaviour near-identical. High bars to avoid false clones. |
| `PARAMETER_VARIANT` | same `S_src` **or** rule-sim ≥0.98, differing `.set`, `0 < d_param`, **and** `J ≥ 0.50` | Same code, retuned knobs; overlap moderate-high because logic identical. Ties to declared `parent_ea_id` when present. |
| `SAME_EDGE_DIFF_IMPL` | rule-sim < 0.90 **but** `J ≥ 0.40` **and** `ρ ≥ 0.70` on same symbol/window | Different code, correlated trades → same underlying edge (the Gold-Reaper/Balke case). |
| `CHILD_CHALLENGER` | card `parent_ea_id` set **and** class is not EXACT/PARAM (i.e. materially reworked descendant) | Declared descendant intended to beat the incumbent. |
| `SUPERSEDED` | a `CHILD_CHALLENGER`/`PARAMETER_VARIANT` whose parent has a terminal RETIRE/worse Q14, or an explicit OWNER supersede receipt | Marks the loser of a head-to-head; drives Vault status badge. |
| `MATERIALLY_DIFFERENT` | none of the above (`J < 0.40` and `ρ < 0.70`) | Default; genuinely distinct. |

Thresholds are proposals (GELB-class new levers): J≥0.80/ρ≥0.95 for "clone" is deliberately strict
so a clone claim is defensible; J≥0.40/ρ≥0.70 for "same edge" catches convergent-death families
without over-merging. All are config-driven and reported with the raw J/ρ so OWNER can recalibrate;
changing them is a GELB decision, not silent.

### Output format
- **JSON** `D:/QM/reports/lineage/lineage_map.json` — nodes = (ea_id[,symbol]); edges =
  `{a, b, class, evidence:{S_src_match, rule_sim, d_param, jaccard, rho, n_days, window}, basis}`.
  Schema sidecar written next to this report: `lineage_map.schema.json`.
- **Vault projection** — a `## Lineage & Duplicates` section per strategy node under
  `09 Strategy Wiki/strategies/` (idempotent, generated), plus a family cluster page listing each
  class with the numeric evidence, satisfying §9 "make these relationships visible in the Vault".
- **Health line** `STRATEGY_LINEAGE = GREEN/…` when every EXACT_CLONE / SUPERSEDED edge is reflected
  in the Vault node status.

## What can be computed TODAY (existing files)

**Balke family — computable now.** Q08 sealed streams exist for the deployable parents:
QM5_13213 (8 Q08 rows), QM5_13036 (4). Card lineage chain 13213→41097→41398→41405 is declared in
frontmatter. Trade-overlap J and daily-ρ can be computed immediately on same-symbol/window pairs
(e.g. 13213 vs 13036 XAU; 13213 vs its USDJPY descendants) from
`D:/QM/reports/work_items/*/QM5_13213/Q08/*/q08_sealed_stream.*.jsonl`. Stage-2 walk-forward
evidence also at `D:/QM/reports/balke_walkforward/`, `D:/QM/reports/balke_symbols_wf/`,
`docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md`.

**Gold Reaper — no EA, prose lineage only.** No `framework/EAs/*reaper*` card exists.
`docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md` already classifies it as the *same dead
edge* as Balke XAU (QM5_13213): both ~PF 1.03–1.08 with 3× / 41.7% DD tails (verified vs
`D:/QM/reports/balke_walkforward/result.json`). This is a ready-made `SAME_EDGE_DIFF_IMPL` /
`SUPERSEDED` edge that today lives only in a markdown verdict — encode it as the map's first
hand-seeded edge and let behaviour confirm it where a cell exists (20007 `GOLD_BREAKOUT` lane).

**ORB / session-breakout — computable where they reached Q08.** ~30+ ORB/session cards exist
(`et-*-orb`, `tv-*orb`, `unger-orb-index`, `tv-london-session-break`, QM5_10181 `tv-xau-ny-orb-retest`).
For each that has a Q08 sealed stream (subset of the 248), pairwise J/ρ is computable now; those
without Q08 evidence get `NOT_EVALUATED` (source-signature edges only).

**XAU systems — 139 XAU EA dirs; behaviour map computable for the Q08 subset.** The XAU cluster is
the highest-value test of the map (Gold Reaper convergence lives here). Compute S_src + J/ρ across
XAU Q08 runs to detect the convergent-death cluster deterministically rather than by name.

**Corpus ceiling today:** exact/rule signatures on all 1,710 cards; behaviour edges (J/ρ) on the
248 EAs with Q08 streams (34 (ea,symbol) also have Q14 streams for the cleaner post-freeze series).
