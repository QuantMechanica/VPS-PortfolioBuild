# Mission Control v2 — Data Contract (`qm.mission_control.v2`)

Task: QM-TODO-20260820-002 · Router task 891b1860 · Author: Claude · 2026-08-21
Programme page: `G:\My Drive\QuantMechanica - Company Reference\12 ToDo\03_Mission_Control_Cockpit.md`
Emitter: `tools/strategy_farm/mission_control_v2_data.py`
Preview output: `D:\QM\reports\state\mission_control_v2_preview.json`
Tests: `tools/strategy_farm/tests/test_mission_control_v2_data.py`

This contract is **data only**. It fixes every value a Mission Control v2
renderer needs so the renderer makes **zero further data decisions**: what
counts as progress, how the terminal→work-item join is formed, how ETA-to-empty
is computed, and how staleness is classified. HTML/visual redesign is out of
scope (Claude does that separately per the programme page).

The emitter is strictly **read-only**: the DB is opened `mode=ro` with
`PRAGMA query_only=ON` (same pattern as `render_cockpit.db_rows`), and every
other source is a file read. It writes exactly one artifact — the preview JSON.

---

## 1. Envelope

```jsonc
{
  "schema_version": "qm.mission_control.v2",   // const
  "generated_at":   "2026-08-21T14:00:00+00:00", // emitter run time (UTC, ISO-8601)
  "source_db":      "D:\\QM\\strategy_farm\\state\\farm_state.sqlite",
  "control_strip":   { ... },
  "queue":           { ... },
  "progress":        { ... },
  "terminals":       { ... },
  "owner_decisions": { ... }
}
```

Every top-level section carries a `meta` block — this is the per-section
freshness/degradation contract the programme page requires:

```jsonc
"meta": {
  "source":          "farm_state.sqlite:work_items_clean(status='active') + …",
  "source_as_of":    "2026-08-21T14:07:52+00:00",  // as-of of the underlying data
  "age_seconds":     372,                            // now − source_as_of
  "staleness":       "FRESH" | "STALE" | "UNKNOWN" | "N/A",
  "degraded_reason": null | "health.json missing"   // non-null => render DEGRADED
}
```

**Staleness rule.** Each section has an SLA (seconds). `age_seconds ≤ SLA →
FRESH`; `> SLA → STALE`; unknown `source_as_of → UNKNOWN`; sections whose data
is a fresh DB computation (no external producer to age against) use `N/A`. A
renderer badges STALE within one render cycle. `degraded_reason != null` means
the section could not be built from its primary source and is showing a fallback
or empty — badge DEGRADED and keep the last good value visible.

| Section | SLA | Rationale |
|---|---|---|
| `control_strip` (health) | 20 min | `farmctl health` writes `health.json` every 15 min |
| `queue` | N/A | live DB computation |
| `progress` | N/A | live DB computation |
| `terminals` (reservations) | 30 min | reservation file rewritten per claim cycle |
| `owner_decisions` | 48 h | curated hand-maintained feed; lenient |

---

## 2. `control_strip` — global control strip

Answers "is the factory healthy, how deep is the queue, when is it empty, what
must OWNER decide" in one strip.

| Field | Type | Canonical source | Definition |
|---|---|---|---|
| `factory_state` | enum `NOMINAL/DEGRADED/MAINTENANCE/CRITICAL` | `health.json`, `FACTORY_OFF.flag`, `FACTORY_ON_CEREMONY_INCOMPLETE.json` | Precedence (mirrors `render_cockpit` topbar): ceremony-incomplete → CRITICAL; `FACTORY_OFF.flag` present → MAINTENANCE; a FAIL in a factory-down check → CRITICAL; any other FAIL / overall WARN\|FAIL → DEGRADED; else NOMINAL |
| `factory_state_reason` | string | derived | human-readable cause (names the failing check) |
| `health_overall` | string | `health.json:overall` | raw overall verdict |
| `health_fail_count` | int | `health.json:checks[status=FAIL]` | number of failing checks |
| `data_freshness.youngest_age_seconds` / `oldest_age_seconds` | int/null | roll-up | min/max age across critical readmodels |
| `data_freshness.any_stale` | bool | roll-up | true if any critical readmodel is STALE |
| `data_freshness.critical_readmodels[]` | array | roll-up | per-readmodel `{name, as_of, age_seconds, sla_sec, staleness}` for `health.json`, `owner_decisions.json`, `terminal_reservations.json` |
| `queue_total` | int | `queue` section | `pending_total + active` (no double count) |
| `queue_pending_executable` | int | `queue` section | drainable pending only |
| `queue_active` | int | `queue` section | in-flight claims |
| `clear_eta_hours_p50` / `_p90` | number/null | `queue.eta_to_empty` | forecast band (see §3) |
| `terminals` | object | `terminals.counts` | `{running, reserved, idle, fleet_size}` |
| `owner_decisions_open` / `_alert` | int | `owner_decisions` section | open count / alert-severity count |

**Factory-down checks** (a FAIL here forces CRITICAL, not DEGRADED):
`mt5_worker_saturation`, `codex_auth_broken`, `disk_free_gb`,
`pump_task_lastresult`, `factory_on_ceremony_incomplete`,
`ablation_grandchildren`, `active_row_age`. This is the same set
`render_cockpit` uses so v2 never screams CRITICAL for output dryness.

Refresh cadence: recompute whenever the emitter runs (recommended every 2 min,
matching the current cockpit); `health.json` itself refreshes every 15 min.

---

## 3. `queue` — full queue + ETA-to-empty

| Field | Type | Source | Definition |
|---|---|---|---|
| `pending_total` | int | `work_items_clean status='pending'` | all pending rows |
| `pending_executable` | int | pending in MT5-tester phases | terminal-drainable backlog |
| `pending_parked` | int | pending outside MT5-tester phases | operator/decision-gated (e.g. `Q09_NEWS`) + test fixtures |
| `active` | int | `work_items_clean status='active'` | in-flight claims (≤ fleet) |
| `by_phase_executable[]` | array | grouped | `{phase_qid, phase_name, pending, oldest_created_at}` |
| `by_phase_parked[]` | array | grouped | same shape, for parked phases |
| `eta_to_empty` | object | derived | see below |

**MT5-tester phase set** (the phases a T1–T10 worker actually drains):
`Q02, Q03, Q04, Q05, Q06, Q07, Q08, Q10` plus their legacy P-key aliases
(`P2…P8`) for pre-2026-05-23 rows. `Q09_NEWS` is **excluded** — it is
RNG-inert and its service rate has been 0 since 2026-08-07 (the "news dam");
counting it as drainable would inflate every forecast. `HARNESS_PP_FIXTURE` is
a test artifact and excluded.

**ETA-to-empty basis** (`eta_to_empty`):

```jsonc
{
  "basis": "drainable executable backlog / measured 24h throughput; drain-only (no upstream arrivals modelled) -> lower bound",
  "pending_executable":       2224,
  "throughput_per_hour_24h":  8.083,   // terminal MT5 transitions in last 24h / 24
  "throughput_count_24h":     194,
  "eta_hours_p50":            275.13,  // pending_executable / rate
  "eta_hours_p90":            458.56,  // pending_executable / (rate * 0.6)  — slow-fleet band
  "eta_empty_utc_p50":        "2026-09-02T01:21:15+00:00"
}
```

- **Throughput** = count of `work_items_clean` rows that reached a terminal
  clean status (`done`|`failed`) in an MT5-tester phase in the trailing 24 h,
  divided by 24. Measured, not assumed.
- **P50** = `pending_executable / rate`. **P90** assumes throughput can sag to
  ~60 % of the 24 h mean (cold-cache / partial-fleet stretches) — an honest
  band, not false precision.
- **Drain-only caveat**: the estimate models no new arrivals from upstream
  gate passes, so it is a **lower bound** on real clear time.
- If 24 h throughput is 0, `eta_hours_*` are `null` and `meta.degraded_reason`
  is set — never emit a divide-by-zero or an infinite ETA.

---

## 4. `progress` — today / yesterday / 7-day-average / total

This is the section the programme page flags hardest ("consistent definitions",
"mixed-era caveat"). **One counting basis for all four windows.**

> **Progress event** = a `work_items_clean` row that has reached a terminal
> clean status (`done` or `failed`) in an **MT5-tester phase**, counted by its
> **`updated_at`** transition timestamp.

Critical schema fact: **there is no `completed_at` column** in `work_items`.
`updated_at` is the transition marker. Append-only reruns
(`enqueue-backtest --append-only-rerun-of`) create **new rows**, so a requeue is
a separate progress event and never rewrites a prior row's timestamp — requeues
and subtests are therefore naturally counted as distinct events, exactly as the
page asks ("Requeues und mehrere Subtests werden separat ausgewiesen").

The clean view (`work_item_clean_view.py`, MNT-016) is the taxonomy authority:
it restamps INFRA execution residue that was stored as `done` into
`status=failed / taxonomy=infra`, so infra never masquerades as economic
throughput.

### KPI fields (per window: `today`, `yesterday`, `seven_day_average`, `total`)

| KPI | Definition |
|---|---|
| `completed` | terminal MT5 rows in the window (the denominator) |
| `distinct_ea_symbol` | distinct `(ea_id, symbol)` pairs **touched** (had a terminal transition) — not pairs advanced a gate |
| `gate_pass` | `taxonomy='strategy'` AND verdict is PASS-family (`PASS*`, `AUTO_PASS`, `CONFIG_LOCKED`, `MODE_SELECTED`, `MULTI_SEED_PASS`, `PASS_PORTFOLIO`) |
| `economic_fail` | `taxonomy='strategy'` AND verdict is FAIL/RETIRE/ZERO family (`FAIL*`, `RETIR*`, `ZERO*`, `MULTI_SEED_MIXED`) — a mixed multi-seed is **not** a pass |
| `infra_transient` | `taxonomy IN (infra, invalid)` — execution residue, NOT merit |
| `other` | governance/review/draft_defect/unknown terminal rows (windowed KPIs only) |
| `infra_rate` | `infra_transient / completed` |

Window semantics:
- `today` = `date(updated_at) == today` (UTC).
- `yesterday` = `date(updated_at) == today − 1`.
- `seven_day_average` = **mean of the 7 per-day KPIs** (day 0…6). This is a
  true daily mean: `distinct_ea_symbol` is the mean of each day's own distinct
  count (not a 7-day-window distinct ÷ 7, which double-counts pairs touched on
  several days), and `infra_rate` is recomputed from the averaged counts. Basis
  string: `"mean of the 7 per-day KPIs (day 0..6)"`.
- `total` = all-time aggregate. Carries `since` (`MIN(updated_at)` of the set,
  currently `2026-05-23` — the work_items wipe) and **no `other`** (aggregate
  query).

### Mixed-era caveats (`progress.caveats[]`)

The page warns that a lifetime funnel "looks clean" though contracts/cohorts are
not comparable. The contract makes that explicit:

1. **TOTAL mixes contract eras** — gate thresholds and sub-gate calibrations
   changed over time (2026-05-23 wipe; later Q04/Q08 recalibrations). Cross-era
   PASS/FAIL counts are not strictly comparable; always show TOTAL with its
   `since`.
2. **`infra_transient` is re-labelled residue**, not a merit outcome; excluded
   from `gate_pass`/`economic_fail`, surfaced as its own rate.
3. **`distinct_ea_symbol` counts pairs touched**, not pairs advanced a gate.

`counting_basis` and `phase_set` are echoed in the section for renderer display.

---

## 5. `terminals` — T1–T10 joined to live assignment

The programme page's central complaint: the fields `ea_id`, `symbol`, `phase`,
start time and work-item id **already exist but are not surfaced**. This is the
exact join that surfaces them.

**Where render_cockpit gets terminal state, and the exact join:**
`render_cockpit.mt5_active_work()` (render_cockpit.py:1793) runs
`SELECT ea_id, phase, symbol, claimed_by, payload_json, updated_at FROM
work_items_clean WHERE status='active'`, then the fleet strip
(render_cockpit.py:2648) reduces each row to a single active/idle dot keyed on
`claimed_by`. **The join is `work_items_clean.claimed_by == "T<n>"` for
`status='active'` rows.** v2 keeps that exact join and stops discarding the
columns.

Verified live (2026-08-21): active rows carry `claimed_by ∈ {T1…T10}`, one
active row per terminal, e.g.
`{phase: Q07, ea_id: QM5_11165, symbol: AUDCAD.DWX, claimed_by: T1,
updated_at: 2026-08-21T13:54:17+00:00}`.

Emitted for **every** T1–T10 (`terminals[]`, always length 10):

| Field | Type | Source | Definition |
|---|---|---|---|
| `terminal` | string | fixed `T1…T10` | slot id |
| `state` | enum `RUNNING/RESERVED/IDLE/ERROR` | join + reservations | RUNNING = active farm claim; RESERVED = reservation file, no claim; IDLE = neither. RUNNING beats RESERVED |
| `work_item_id` | string/null | `work_items_clean.id` | the active work item |
| `ea_id` | string/null | `work_items_clean.ea_id` | e.g. `QM5_11165` |
| `ea_slug` | string/null | `framework/registry/ea_id_registry.csv` | name lookup by `ea_id` |
| `symbol` | string/null | `work_items_clean.symbol` | e.g. `AUDCAD.DWX` |
| `phase_qid` | string/null | `phase_ids.phase_label` | **Qxx only, ever** (P-keys mapped) |
| `phase_name` | string/null | `phase_ids.PHASE_NAME` | e.g. "Multi-Seed" |
| `start_utc` | string/null | `work_items_clean.updated_at` of the active claim | claim-transition time (no separate claim-timestamp column exists) |
| `elapsed_seconds` | int/null | `now − start_utc` | runtime so far |
| `reservation` | object/null | `farmctl.terminal_reservations` | `{reserved_by, reason, until_utc}` when RESERVED |
| `idle_reason` | string/null | derived | why not RUNNING |

`counts`: `{running, reserved, idle, fleet_size:10}`.

**Reservations source**: `state/terminal_reservations.json` via
`farmctl.terminal_reservations(ROOT, now)` — reuses its TTL-expiry and
dead-holder ("reservation corpse") pruning. Fail-open to `{}` with
`meta.degraded_reason` if farmctl import fails.

**Deliberate boundary**: `state=RUNNING` is authoritative from the **farm
claim**. Live `terminal64.exe` / `terminal_worker.py` process-scan confirmation
(render_cockpit's `factory_terminal_procs()` / `live_worker_terminals()`) spawns
PowerShell and is intentionally **not** done here — the emitter stays read-only
and process-free so it is deterministic and unit-testable. Process-liveness is a
renderer overlay (documented in `terminals.notes`). `ERROR` is reserved in the
enum for that overlay (claim without a live process).

Expected-duration baselines (phase/symbol historical medians) are a **future
enrichment**, not in v1 of this contract — `elapsed_seconds` is emitted; the
renderer can add a baseline later without a data change.

---

## 6. `owner_decisions` — genuine OWNER decisions only

Source order mirrors `render_cockpit.owner_decision_rows` (agent work queues are
**never** OWNER decisions and are excluded by construction):

1. **Curated feed** `D:\QM\reports\state\owner_decisions.json`, Schema
   `qm.owner-decisions/v2`. Jede Zeile hat stabile ID, Status, Frage,
   Empfehlung, JA-/NEIN-Folge, Cost-of-Wait und Evidenz. Nur `OPEN` und
   `DEFERRED` werden gerendert. `source_as_of` = `updated_at_utc`.
2. Nur während der v1-Kompatibilitätsmigration: Q12-Admission und bis zu drei
   BLOCKED-`agent_tasks` als fail-closed Legacy-Fallback. Im v2-Vertrag werden
   dynamische Fallbacks nicht als klickbare Entscheidungen ausgegeben: Sie
   müssen zuerst mit stabiler ID, Empfehlung, Folgen und Evidenz kuratiert
   werden.

| Field | Type | Definition |
|---|---|---|
| `count` / `alert_count` | int | total items / items with `alert=true` |
| `q12_review_ready` | int | `portfolio_candidates` Q12 count |
| `items[]` | array | `{source,id,status,category,title,question,recommendation,yes_effect,no_effect,cost_of_wait,detail,evidence,depends_on,decision_card_sha256,due,severity,alert,execution_plan}`; der Execution-Plan enthält beide Choice-Previews und `plan_sha256` |
| `executions[]` | array | terminal entschiedene Karten mit Receipt-/Task-ID, Router-State, Agent, Artefakt, Verdict, normalisiertem Status `HANDOFF_PENDING/QUEUED/RUNNING/AWAITING_REVIEW/COMPLETE/...` und Stage-SLA |
| `execution_counts` / `execution_open_count` | object / int | Statusverteilung und noch nicht `PASSED` geschlossene Umsetzungen |
| `router_health` | object | letzter erfolgreicher Receipt-Reconcile, Alter, allgemeine Router-Fehlerfolge und `HEALTHY/DEGRADED/STALE/UNKNOWN`; 10 Minuten Warn- und 30 Minuten Breach-Schwelle |
| `intake` | object | `{enabled,endpoint,token,mode:"ROUTER_HANDOFF",degraded_reason}`; Token kommt aus der lokalen State-Datei, Endpunkt ist ausschließlich Loopback |

`source ∈ {curated_feed, q12_review_ready, blocked_agent_task}`. `alert` is true
for `severity ∈ {alert, action}`.

Der Feed ist die offene Queue; OWNER-Antworten werden zuerst append-only in
`owner_decision_receipts.jsonl` geschrieben und danach in Feed und Vault
materialisiert. Ein terminales Receipt (`YES`/`NO`) trägt eine deterministische
`execution_task_id`, `execution_handoff_authorized=true` und die Grenze
`DECISION_SCOPED_ROUTER_TASK`. Der Intake legt genau diese eine `agent_tasks`-
Zeile an; der 5-Minuten-Router reconciliert verpasste Handoffs idempotent.
`DEFERRED` trägt `DEFERRED_NO_HANDOFF` und erzeugt keinen Auftrag.
`decision_card_sha256` bindet Frage, Empfehlung, beide sichtbaren Folgen und
Abhängigkeiten. `execution_plan.plan_sha256` bindet für JA und NEIN jeweils
Modus, Impact, erlaubte Schritte, Prüfkriterien und Containment sowie die
globale Ausführungsgrenze. Der Browser sendet beide im gerenderten HTML
sichtbaren Hashes; der Intake vergleicht sie mit dem aktuellen Feed/Manifest,
bevor er ein Receipt schreibt. Eine veraltete Seite oder spätere Drift wird
damit fail-closed abgewiesen. Der Handoff prüft beide Bindungen erneut.

Die Stage-SLA markiert einen fehlenden Handoff nach 10 Minuten als `BREACH` und
eine noch nicht zugewiesene Claude-Task nach 10 Minuten als `WARN`, nach 30
Minuten als `BREACH`. Diese Anzeige beobachtet nur; sie pausiert weder Factory
noch Router und erzeugt keine zusätzliche Executor-Lane.

Die Ausführungsautorität endet immer an der auf der Karte ausgewiesenen Folge.
Jedes Receipt setzt `live_execution_authorized=false`,
`factory_pause_authorized=false`, `autotrading_authorized=false` und
`deployment_authorized=false`. Freitextnotizen können den Scope nicht erweitern.

### Kompakte `operator_surface`, vollständiger Drill-down

Der Census und alle Aggregate werden weiterhin über sämtliche EA/Symbol-Paare
berechnet. `pair_count` bleibt der Vollbestand. `pairs` enthält im Mission-
Control-Vertrag höchstens 30 handlungsnahe Vorschauzeilen;
`pair_preview_count`, `pair_detail_truncated`, `pair_action_counts` und
`pair_detail_href` machen diese Begrenzung explizit. Der Renderer erzeugt aus
dem einmal berechneten Vollbestand separat `linear_frontier.html`; dadurch
ändert die Kompaktierung keine Metrik und bläht die Schaltzentrale nicht mit
14k+ Detailzeilen auf.

---

## 7. `path_to_25` — kritischer Pfad, getrennt von Queue-leer

`path_to_25` ist read-only und payload-/Sidecar-abgeleitet. Der Block enthält:

- `reservoir`: eindeutige v4-Q09-PASS-Paare und deren Q10-`chosen`-, Q11-,
  Q12-, Q13- und Q14-Fortschritt;
- `pair_progress`: dieselben Schritte pro `(ea_id,symbol)`, einschließlich
  offener Reruns und roher NO_CHANGE-Pilotzeilen;
- `completion_rates`: eindeutige Paarabschlüsse pro Tag im rollierenden
  7×24-h-Fenster;
- `eta_to_25`: Restpaare geteilt durch die gemessene rohe Q14-Abschlussrate;
  dies ist ausdrücklich weder eine Queue-leer-ETA noch ein Survival-Modell;
- `counting_definition`: die durch
  `decisions/2026-08-27_owner_count_definition_option_a.md` versiegelte
  `STRICT_V4_CONTIGUOUS_Q14`-Triggerdefinition plus klar getrennte, niemals
  triggernde B/C/D-Sekundärdiagnostik.

Die aktive Anzeige zählt fail-closed nur Paare mit kanonischer v4-Lineage und
`highest_contiguous_valid_gate=Q14`. Historische Q14-Labels und rohe v4-Q14-
Pilotzeilen werden sichtbar separat ausgewiesen und verändern `qualified_pairs`
nicht. `qualified_pairs`, der Hauptzähler und `eta_to_25.remaining_pairs` werden
aus demselben versiegelten Triggerobjekt abgeleitet. Eine Änderung dieser
Definition ist eine eigene OWNER-Entscheidung, kein Dashboard- oder
Telemetrieeffekt.

---

## 8. Validation

`CONTRACT_SCHEMA` (JSON-Schema draft-2020-12) is embedded in the emitter. The
`jsonschema` package is **not installed** on this VPS, so the module ships a
dependency-free validator (`validate_contract` / `_validate_node`) covering the
subset used here (type incl. lists, required, properties, items, enum, const,
min/maxItems, `$ref`/`$defs`). `validate_contract` prefers `jsonschema` when
importable and falls back to the embedded validator otherwise; both raise
`ContractValidationError` on violation.

The emitter validates its own output on every run unless `--no-validate` is
passed. The live run on 2026-08-21 validated clean.

---

## 9. CLI

```powershell
cd C:/QM/repo
python tools/strategy_farm/mission_control_v2_data.py            # write preview + validate
python tools/strategy_farm/mission_control_v2_data.py --stdout   # also print
python tools/strategy_farm/mission_control_v2_data.py --db <path> --output <path>
```

Exit 0 on success; validation failure raises (non-zero). One line of run
telemetry goes to stderr (factory state, queue total, running terminals, owner
count).

---

## 10. Contract stability notes for the renderer

- All timestamps are UTC ISO-8601.
- Absent values are `null`, never omitted for the documented fields — a renderer
  can bind every field unconditionally.
- Qxx is the only phase vocabulary in every user-facing field; storage P-keys
  are mapped before emission and never surface.
- Counts never double-count: `queue_total = pending_total + active`;
  `pending_total = pending_executable + pending_parked`.
- The emitter is read-only; consuming or re-running it cannot mutate farm state.
