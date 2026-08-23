# Q10 — News Impact + FTMO Recommendation

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q10 (Storage-Lanes v4: `Q10_NEWS` / `Q10_PORTFOLIO`) |
| **Makrophase** | 2 · Strategie wird optimiert / requalifiziert |
| **v3-Herkunft** | Q09 — „News Impact + FTMO Recommendation" (Storage `Q09_NEWS` / `Q09_PORTFOLIO`) |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q09 Baseline Full Run]] · → [[Q11 Incumbent Full-History Confirmation]] |

**Herkunft:** v4 Q10 = v3 Q09 (News Impact + FTMO Recommendation), Kriterien/Verdikt-Vokabular
unverändert (ROT). `Q10_PORTFOLIO` ist rein informational (speist Q15), nie ein Pre-Q11-Abbruch
(OWNER E1 2026-08-22).

> **Lese-Hinweis zur Nummerierung:** Der Fließtext unten ist der **verbatim v3-Text** und
> nennt dieses Gate noch „Q09" sowie die Storage-Lanes `Q09_NEWS`/`Q09_PORTFOLIO`; das
> Folgegate heißt dort „Q10 Full-History Confirmation". Das ist Absicht: Storage-Tokens und
> Code-Dateinamen (`q09_news_runner.py`) bleiben bis zur v4-Migration v3. Die v4-Entsprechung
> ist `Q09→Q10`, `Q09_NEWS→Q10_NEWS`, `Q09_PORTFOLIO→Q10_PORTFOLIO`, Folgegate „Q10 Full-History
> Confirmation" → **Q11**. Mapping: [[Gate Manifest v4 Diff]].

---

**Gate Owner:** Claude gate-walk (adjudication review) / OWNER (semantics + live consumption)
**Data window:** Selection ≥60 months + Holdout ≥24 months + Full, per sealed plan
**Spec version:** 2026-08-05 (mirrors OWNER-ratified semantics 2026-08-04 + sealed A/B contract; supersedes 2026-05-23 page)

---

## Purpose (OWNER-ratified 2026-08-04, verbatim intent)

Q09 delivers **recommendations through A/B backtests**: (1) Is the EA
prop-firm-safe? (2) Does it perform better or worse on news days?
Portfolio consumption of those recommendations: **not FTMO-safe → does NOT
enter the FTMO book; trades worse on news days → news days get blocked.**

Q09 is not a survival gate — but it is no longer a silent default-apply
either: the verdict is a **sealed, evidence-locked configuration choice**
(`CONFIG_LOCKED`) that downstream gates enforce.

---

## Two Independent Axes (unchanged design)

### Axis A — Temporal Mode (`QM_NewsTemporalMode`)

| Mode | Behaviour |
|---|---|
| 0 | OFF — trade through everything |
| 1 | PRE30 — pause 30min before high-impact news |
| 2 | PRE60 — pause 60min before |
| 3 | PRE30_POST30 — pause 30min before + after ← compile default |
| 4 | PRE60_POST60 |
| 5 | SKIP_DAY — no new entries on the news day |
| 6 | CLOSE_ALL_PRE — flat 30min before the event |

### Axis B — Compliance Profile (`QM_NewsComplianceProfile`)

NONE / DXZ (placeholder, currently adds no window) / FTMO (2min hard
blackouts around USD/EUR/GBP high-impact) / 5ERS.

Composition rule unchanged: a trade fires only if **both** axes allow it.

---

## The sealed A/B contract (implemented, live since 2026-08-04/05)

- Per (EA, symbol): sealed run plan binding Q07/Q08 lineage SHAs, EX5 +
  setfile identities, a **published calendar bundle**
  (`q09cal-<from>-<to>-<hash>`, manifest-verified), 5 canonical seeds
  (42, 17, 99, 7, 2026), REAL_TICKS, three windows per cell.
- Arms: `CONTROL_OFF/OFF/NONE` vs `POLICY_ON` × temporal modes ×
  compliance scope. Standard scope 7×1 (target compliance, 40 cells);
  a material effect in the target arm expands to the full 7×4 matrix
  (145 cells) before locking.

> [!note] Seeds are inert at `qm_stress_reject_probability=0` — 40 cells = 8 configs (OWNER, CLAUDE.md "Ratified Rules (recent)")
> The 5 canonical seeds (42, 17, 99, 7, 2026) are **inert** while
> `qm_stress_reject_probability=0`: the RNG is never drawn, so the five
> seeded replicas of any cell are byte-identical. The nominal 40 cells of
> the 7×1 standard scope therefore collapse to **8 distinct economic
> configs**. The **A+B contract v3** (1 seed + seam-reconstructed full
> window) is **OWNER-approved** and supersedes the seed sweep; the original
> **40-cell v2 pilot (`cba63d44`)** is retained as the reference
> measurement.
- Adjudication verdicts: `CONFIG_LOCKED` (chosen_temporal +
  chosen_compliance) / `REVIEW_REQUIRED` (Claude gate-walk input) /
  `INVALID_EVIDENCE`. No algorithmic best-PF picking — the adjudicator
  compares control vs policy under sealed rules.
- Persistence: canonical economic cells are globally deduplicated by run
  identity; per-execution provenance lives in an append-only immutable
  occurrence ledger (`q09_news_cells_by_work_item` view). Deterministic
  economics divergence fails closed (non-determinism alarm).
- Runtime: `tools/strategy_farm/q09_news_runner.py` (sealed plans, bounded
  transient-cell retry → work-item requeue, terminal-succession wait,
  append-only failure sidecars). Artifacts under
  `D:/QM/reports/work_items/<work_item_id>/q09_plan/` + aggregate.
  The 2026-05-23 page's `q09_news_mode.py` / `D:/QM/reports/pipeline/...`
  paths are obsolete.

## Enforcement (fail-closed, wired)

- **DXZ chain:** Q10 dependency gate requires Q09_NEWS `CONFIG_LOCKED` +
  `PASS_PORTFOLIO` sibling of the same lineage (assert_q10_dependency_gate).
- **FTMO chain:** `ftmo_q09_admission.py` fail-closed in all five membership
  surfaces; absence of FTMO-scoped Q09 evidence = exclusion. DXZ-only runs
  do NOT admit to FTMO (by design) — FTMO-book sleeves need FTMO-scoped
  cells (7×4 or 7×1 target FTMO).
- Live activation of a news policy (calendar bundle + manifests + remint)
  remains an **OWNER window**.

## Known live-book state (2026-08-05 findings)

- The 24 deployed live sleeves predate this contract. Their effective news
  policy is **compile-default-inherited** (PRE30_POST30/DXZ via source
  defaults — presets do not pin the news inputs). Consumption ceremony must
  **pin `qm_news_temporal`/`qm_news_compliance` explicitly per preset**.
- An OWNER-directed diagnostic A/B backfill (17 sleeves, fresh builds,
  non-admission rows) is producing per-sleeve control-vs-policy evidence;
  results feed the composition ceremony and the 2026-09-06 probation review.
- First A/B result (QM5_11422/USDCAD): every blocking variant hurts that EA;
  control = best. Recommendation class exists in both directions.

---

## News Calendar Source

Sealed bundles: `D:/QM/data/news_calendar/q09_bundles/` (published +
manifest-verified; current: `q09cal-20150101-20260809-0bb19b5bb9790b76`,
48,245 events 2015→2026-08). Raw seed CSVs remain under
`D:/QM/data/news_calendar/`. Staleness guard: `qm_news_stale_max_hours=336`
(14 days) fail-closed. Firm blackout definitions:
`framework/include/news_rules/ftmo.mqh` / `5ers.mqh`.

---

## What Q09 explicitly does NOT do

- ❌ Auto-apply a default without evidence (superseded 2026-08-04 — the old
  "default-apply Mode 3" workflow is retired)
- ❌ Apply news filters retroactively to Q02–Q08 (those gates run news-naive)
- ❌ Algorithmic best-PF auto-selection (overfitting risk)
- ❌ Mix temporal + compliance into one enum
- ❌ Enable live trading of a chosen config without the OWNER manifest window

---

## After Q10 (v3: „After Q09")

`CONFIG_LOCKED` → `Q10_PORTFOLIO` sibling (v3: `Q09_PORTFOLIO`) →
**[[Q11 Incumbent Full-History Confirmation]]** mit beiden Achsen gelockt und durch das
Dependency-Gate erzwungen. `Q10_PORTFOLIO` bleibt informational (speist die Buchbewertung
in Q15), niemals ein Pre-Q11-Abbruch (OWNER E1 2026-08-22).
