# Strategy Second-Chance Programme

**Authority:** OWNER follow-up directive 2026-09-15 (third), §23–§28, §31–§32, §38
(`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`).
**Decision record:** `decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md`.
**Generator:** `tools/strategy_farm/research/second_chance_register.py`
(schema `qm.second-chance-register/v1`).
**Rule table:** `tools/strategy_farm/config/second_chance_reasons.v1.json`
(schema `qm.second-chance-reasons/v1`).
**Read-models:** `D:/QM/reports/state/second_chance_register.{json,csv}`.
**Vault surface:** `09 Strategy Wiki/Second-Chance Register.md` (generated) + per-node
second-chance fields on every generated Strategy-Wiki node in the population.

> **Immutability.** Historical verdicts, trade streams and dated decisions are never
> rewritten. This programme only *classifies* the historical population and proposes
> **new-lineage** re-evaluation of records blocked by now-superseded style/policy rules.
> Every re-test is an append-only new work-item; the old row stays as evidence.

Counts below are the real run of 2026-09-15
(`inputs_sha256 37ec3be9…`; population from the generated Strategy Wiki).

---

## 1. Method

### 1.1 Population (§23)

The generator enumerates every generated Strategy-Wiki node projected as **REJECTED**,
**RETIRED** or **DRAFT** — the historical population the completed wiki now makes
addressable. Run total: **1285** records.

### 1.2 Primary-reason classification (§24)

Each record is assigned exactly one primary reason from the §24 enum by the deterministic
rule table. Rules are applied in ascending `precedence`; the first that fires wins. The
signals, in precedence bands:

1. **Own pipeline blocker / terminal verdict** (`economic_pipeline_blocker` 12,
   `infra_pipeline_blocker` 13) — a record that reached the pipeline is classified by its
   *own* measured outcome (`Q10:FAIL_PORTFOLIO`, `Q08:INVALID`, …), which outranks any
   stale G0 card note. An approved-then-failed card carries no style rejection.
2. **Hard boundaries** — `ML_RUNTIME` (10), `DUPLICATE` (15).
3. **Superseded style** — `MARTINGALE` (20) › `GRID` (21) › `PYRAMIDING` (22) ›
   `MULTI_POSITION` (23) › `SCALPING` (24).
4. **Superseded policy** — `OLD_HR16` (30), `OLD_PORTFOLIO_CAP` (31).
5. **Card-quality / provenance** — `no_external_source_superseded` (38),
   `INSUFFICIENT_EVIDENCE` (40), `NO_EXTERNAL_SOURCE` (45), `HISTORICAL_POLICY` (50).
6. **Registry disposition** — unmaterialized reservation (41, pinned STILL_INVALID),
   D1 disposition (51), frequency-prior (52).
7. **Verdict/hold class** — economic (60), infra (70/72), hold codes (74/75).
8. **`OTHER`** — no signal matched. **Never guessed.**

Reason text is read from the record's own card (matched by `(ea_id, slug)` so a
**re-purposed** id never inherits a debris card's reason — the 2026-08-21 disposition
trap), its registry `retired_reason`, the read-only farm-DB verdict taxonomy, and active
hold codes. Cards are read tolerant of UTF-8 BOM + CRLF.

### 1.3 Eligibility (§24, §27)

* Superseded style/policy (`MARTINGALE`, `GRID`, `PYRAMIDING`, `MULTI_POSITION`,
  `SCALPING`, `HISTORICAL_POLICY`, `OLD_PORTFOLIO_CAP`, `OLD_HR16`, `NO_EXTERNAL_SOURCE`)
  → **ELIGIBLE_FOR_RECONSIDERATION**.
* `INFRA_FAIL` → **ELIGIBLE** (a clean rerun; infra never judged the strategy).
* `ML_RUNTIME` → **STILL_INVALID** (HR14 / §15 unchanged).
* `INSUFFICIENT_EVIDENCE` → **STILL_INVALID** (needs a repaired/complete card — fresh
  intake — not a retest of the old record).
* `ECONOMIC_FAIL` → **STILL_INVALID** unless the §27 counterfactual flags it
  (→ `PORTFOLIO_UTILITY_CHALLENGER`, then ELIGIBLE).
* `DUPLICATE` → **STILL_INVALID** unless lineage carries a `materially_different` edge.
* Unmaterialized reservation → STILL_INVALID (nothing to reconsider without a fresh card).

### 1.4 Clone suppression (§25)

Independently of the reason, any record joined by an `exact_clone` or
`close_implementation_clone` behaviour edge (`D:/QM/reports/state/lineage_map.json`) to a
surviving counterpart is marked **`SUPPRESSED_CLONE_OF:<id>`** — the keeper is the
ACTIVE_CANONICAL neighbour, else the lowest ea-id in the clone group. Suppressed records
are excluded from the ranked re-test plan (do not spend MT5 time re-refuting a clone).

### 1.5 Priority score (§26)

Priority = `100 · Σ wᵢ·componentᵢ − tail_penalty`, components in [0,1]:

| Component | Weight | Source |
|---|---:|---|
| FTMO relevance | 0.22 | intraday timeframe · scalp/session/trailing/MR markers · low-swap FX |
| Expected edge | 0.18 | prior sealed stream + positive verdict |
| White-space bonus | 0.15 | universe-map white-space cell (style × symbol_class) |
| Novelty | 0.12 | lineage clone/family crowding |
| Independence | 0.10 | absence of clone ties |
| DXZ relevance | 0.08 | non-FX diversifying symbol class |
| Validation cost⁻¹ | 0.08 | symbol RAM class (44 GB SP500 … 4 GB FX) |
| Execution complexity⁻¹ | 0.07 | basket/grid/multi-leg penalty |

FTMO and expected edge dominate (§26/§31: FTMO is the larger business gap). Tail-risk
reasons (`MARTINGALE`/`GRID`/`PYRAMIDING`) carry a −5 penalty until a bounded-risk
contract exists. Only ELIGIBLE + challenger records are ranked.

---

## 2. Counts (real, 2026-09-15)

### 2.1 By reason

| Reason | n | Default eligibility |
|---|---:|---|
| INSUFFICIENT_EVIDENCE | 470 | STILL_INVALID (needs fresh card) |
| HISTORICAL_POLICY | 412 | ELIGIBLE (activity/policy, §27/§30 reviewable) |
| OTHER | 210 | STILL_INVALID (no signal; not guessed) |
| NO_EXTERNAL_SOURCE | 116 | ELIGIBLE (§16 superseded) |
| ECONOMIC_FAIL | 37 | STILL_INVALID unless §27 |
| DUPLICATE | 19 | STILL_INVALID unless material |
| MULTI_POSITION | 8 | ELIGIBLE (§17/§20) |
| SCALPING | 8 | ELIGIBLE (§17) |
| PYRAMIDING | 3 | ELIGIBLE (§21; tail-risk contract) |
| INFRA_FAIL | 1 | ELIGIBLE (rerun) |
| GRID | 1 | ELIGIBLE (§18; tail-risk contract) |
| MARTINGALE | 0 | — |

### 2.2 By status

| Status | n |
|---|---:|
| ELIGIBLE_FOR_RECONSIDERATION | 542 |
| STILL_INVALID | 731 |
| SUPPRESSED_CLONE_OF | 12 |
| — of which PORTFOLIO_UTILITY_CHALLENGER | 0 |
| — tail-risk flagged | 4 |

**Reading of the numbers.** The single largest *actionable* second-chance bucket is
**NO_EXTERNAL_SOURCE (116)** — records rejected only because they lacked an external
citation, now valid under §16 (provenance still required → each needs a `QM-RESEARCH://`
artifact, not a new source). The **style-supersession** buckets (MULTI_POSITION 8,
SCALPING 8, PYRAMIDING 3, GRID 1 = **20**) are the records the old HR14 one-position rule
and style doctrine wrongly discarded — small but high-signal. **INSUFFICIENT_EVIDENCE
(470)** and **OTHER (210)** are honestly *not* second-chance retests: they need a
complete/repaired card or carry no recorded reason, so they stay invalid rather than
inflating the queue.

---

## 3. Top candidates by venue

### 3.1 FTMO (§31 — weighted higher; intraday, short-hold, low-swap)

| EA | Reason | Priority | Symbols |
|---|---|---:|---|
| QM5_11563 | INFRA_FAIL | 89.7 | EURUSD/GBPUSD/USDJPY (Q08:INVALID → clean rerun) |
| QM5_10050 | HISTORICAL_POLICY | 80.2 | EURUSD |
| QM5_11362 | NO_EXTERNAL_SOURCE | 80.2 | AUDUSD/EURUSD/GBPUSD/NZDUSD |
| QM5_11388 | NO_EXTERNAL_SOURCE | 80.2 | EURUSD/GBPUSD/USDJPY |
| QM5_11211 | SCALPING | 79.3 | EURUSD/GBPUSD/USDJPY/XAUUSD |
| QM5_11855 | SCALPING | 79.3 | M5 EMA-zone scalp |

### 3.2 DXZ (§32 — diversification, tail, long-term)

Style-supersession candidates with diversifying / non-FX or basket roles:

| EA | Reason | Priority | Role |
|---|---|---:|---|
| QM5_11373 | MULTI_POSITION | 72.7 | daily-range bracket (index) |
| QM5_34002 | MULTI_POSITION | 71.2 | Brent/WTI statistical arb (energy) |
| QM5_1280 | MULTI_POSITION | 70.5 | Chan OU half-life pair |
| QM5_9407 | MULTI_POSITION | 70.5 | pairs-Z basket |

### 3.3 Tail-risk-flagged (need a bounded-risk contract before Q00, §18/§20)

`QM5_11637` (PYRAMIDING, robo EMA-fan ribbon M1), `QM5_11703` (PYRAMIDING, 100-pip daily
range breakout), `QM5_11936` (PYRAMIDING, millipede). `QM5_38007` (GRID, ATR grid engine)
is suppressed as a clone of `QM5_11375`. These enter Q00 **only** with the deterministic
risk contract of `docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md` (slice f1) attached.

---

## 4. §27/§28 counterfactual — portfolio-utility challengers

**Method.** For each `ECONOMIC_FAIL` record owning a sealed Q08 trade stream
(`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades`), the candidate's daily net-PnL is
added to the current DXZ / FTMO roster's combined daily curve over the out-of-sample
holdout, and the venue objective (Calmar-like: cumulative holdout PnL ÷ max drawdown) is
compared. A record becomes a `PORTFOLIO_UTILITY_CHALLENGER` when adding it **raises** the
objective **without** increasing max drawdown.

**Holdout convention.** The canonical sealed OOS window is
`oos_2026_confirmation.py` (2026-01-01…2026-04-06). The sealed Q08 sleeve streams,
however, cover the full backtest history and end 2025-12-30 — they do not yet carry the
2026 confirmation runs — so a 2026 holdout is empty on them. The generator therefore uses
the **trailing full calendar year present in the sealed data (2025)** as the deterministic
OOS split, and switches to the 2026 window automatically once those streams are sealed
into the sleeve-stream store.

**Result (real).** 37 economic-fail records; **3** own a sealed stream (QM5_9641,
QM5_11288, QM5_11294 — two of them additionally suppressed clones). On the 2025 holdout
(DXZ base objective 12.05 over 242 days; FTMO 2.60 over 103 days) **none** improves either
venue objective without adding drawdown → **0 portfolio-utility challengers**. The other 34
economic-fail records have **no sealed stream** → `EVIDENCE_MISSING` (they never reached a
sealed-stream gate); they are not challengers until such evidence exists.

**`PORTFOLIO_UTILITY_CHALLENGER` class (§28).** Sufficient evidence to test portfolio
utility despite failing an old standalone threshold. It does **not** rewrite the original
gate verdict and grants **no** live eligibility. Requirements: valid sealed evidence;
bounded risk; an independent holdout; an explicit portfolio-role hypothesis. Evaluated
against the current book at portfolio level only.

---

## 5. Re-test plan (capacity-bounded)

The register is a classification, not a dispatch order. Re-tests are commissioned by the
orchestrator, paced against MT5 capacity (§G / `VPS_CAPACITY_AND_SCHEDULING.md`), and never
run blindly (§23). Ordering:

1. **Wave 1 — cheap, high-FTMO, clean rerun.** `INFRA_FAIL` (1) — a genuine clean rerun
   (QM5_11563). Cost: one Q00→Q02 pass.
2. **Wave 2 — style-supersession, low RAM.** The 20 MULTI_POSITION / SCALPING /
   PYRAMIDING / GRID records on FX/metal symbols, top priority first, tail-risk records
   gated on the bounded-risk contract. These are the records the superseded doctrine
   actually cost us.
3. **Wave 3 — NO_EXTERNAL_SOURCE with a QM-RESEARCH provenance mint.** The 116 records
   need a `QM-RESEARCH://` artifact (§16 provenance) before Q00; batch the mint, then
   enqueue highest-priority FTMO-relevant first.
4. **Wave 4 — HISTORICAL_POLICY (activity/low-frequency).** Only via the §30 procedure
   (counterfactual → versioned contract → test) — these are activity-threshold reviews,
   not blind retests.
5. **Never (this programme):** INSUFFICIENT_EVIDENCE, OTHER, ML_RUNTIME, DUPLICATE,
   unmaterialized reservations, and all `SUPPRESSED_CLONE_OF` records.

**Guardrails.** Each wave is a small batch; the ready-card reservoir and MT5 saturation
gate the next batch. A record with no testable spec or no intended symbols is never
enqueued regardless of priority (it needs card repair first, which is a separate lane).

### 5.1 Ticket template — second-chance rerun as NEW lineage (append-only)

```
python tools/strategy_farm/agent_router.py enqueue research_task \
  --priority <=70 \
  --payload-json '{
    "kind": "second_chance_retest",
    "origin_ea_id": "QM5_<old>",
    "second_chance_reason": "<enum>",
    "second_chance_status": "ELIGIBLE_FOR_RECONSIDERATION",
    "register_inputs_sha256": "<from second_chance_register.json>",
    "lineage": "NEW",                       // never re-open the old verdict
    "provenance": "QM-RESEARCH://<id>",     // required for NO_EXTERNAL_SOURCE
    "tail_risk_contract": "<path or null>", // required for tail-risk reasons
    "venue_hypothesis": "FTMO|DXZ + role",
    "notes": "append-only; old work-item row remains as evidence"
  }'
```

Enqueue only ELIGIBLE (or challenger) records; the old EA-id, its verdicts and its trade
streams are read-only inputs. A new ea-id is minted for the retest (`farmctl` allocation),
so the historical evidence trail is untouched. Tail-risk reasons require the bounded-risk
contract; NO_EXTERNAL_SOURCE requires the provenance mint; both are hard preconditions the
ticket makes explicit.

---

## 6. Regeneration & rollback

* **Regenerate:** `python -X utf8 tools/strategy_farm/research/second_chance_register.py`
  (deterministic; safe to re-run). Then `strategy_wiki_sync.py build` to refresh the
  per-node join (idempotent — only population nodes re-render).
* **Rollback:** delete `D:/QM/reports/state/second_chance_register.{json,csv}` and the
  vault page; the wiki-sync join is present-or-absent, so nodes revert to their prior form
  on the next build. The classifier writes no verdicts, no DB rows and touches no live
  surface.
