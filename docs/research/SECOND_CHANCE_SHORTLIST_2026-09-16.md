# Second-Chance Ranked Shortlist — 2026-09-16

**Authority:** Kimi interim OWNER delegation; Directive-3 §13, SECOND_CHANCE programme
(`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`, worktree copy
`.claude/worktrees/wf_717b9d36-ba6-4/docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`).
**Classification source:** `D:/QM/reports/state/second_chance_register.json`
(schema `qm.second-chance-register/v1`, generated 2026-09-15T18:11:23Z,
`inputs_sha256 37ec3be9…5982`, file sha256 `96beee4e…9812`).
**Doctrine:** `docs/research/STRATEGY_ELIGIBILITY_V2.md` (OWNER-DEC-D3-20260915).
**Provenance contract:** `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (FINAL v1).
**Companion evidence:** `docs/ops/evidence/2026-09-16_second_chance_continuation/evidence_receipt.md`.

> ENQUEUE-ONLY authority was NOT exercised here. This document classifies and ranks;
> commissioning is centralized. Zero work-items/holds/verdicts/register rows were
> touched; zero git commits (central commit pass owns the worktree).

---

## 0. Scope and exclusions

- Population: 1,285 records; 542 ELIGIBLE_FOR_RECONSIDERATION.
- **The five already handled** (excluded from this list): **QM5_11563** (Wave-1
  INFRA_FAIL rerun, enqueued 2026-09-15 as agent task `b0ef5d66`,
  `docs/ops/evidence/2026-09-15_second_chance_wave1/`) and the four Part-1 candidates
  of 2026-09-16: **QM5_10648** (provenance minted, §3), **QM5_1354** (provenance
  minted, §3), **QM5_1355** and **QM5_9576** (stood down, §4 — normal pipeline owns them).
- **Never proposed:** all `SUPPRESSED_CLONE_OF` records (12); `INSUFFICIENT_EVIDENCE`
  (470) and `OTHER` (210) — honestly not retestable without fresh card/research;
  `ML_RUNTIME`; `ECONOMIC_FAIL` without a §27 challenger (0 challengers on the real
  counterfactual); `DUPLICATE` without a `materially_different` edge.
- Clone hygiene: every row below was checked against
  `D:/QM/reports/state/lineage_map.json` (sha256 `0a355641…3cb1`) — **0
  exact/close-implementation clone edges touch any listed record**; no exact-clone
  retests are proposed.

## 1. Ranking logic (expected portfolio value, not nostalgia)

Backbone = the register's deterministic §26 priority (FTMO relevance 0.22 dominates,
per §31 "FTMO is the larger business gap"). Re-ranked within reason families by:
(1) FTMO gap fit — intraday / high-density / low-swap / independent vs the 8-sleeve
all-D1-swing FTMO demo roster (`ftmo_demo_cycle.json`); (2) DXZ diversification vs
the 24-sleeve `book_evolution_dxz.json` book (XAUUSD is the crowded class — 6/24);
(3) evidence availability (sealed work-item/metric history); (4) family independence
(near-sibling records are staggered, not parallel-burned). Programme guardrail
respected: a record with no testable spec or no intended symbols is never enqueued —
those rows carry "card repair first".

**Wave mapping** (programme §5): Wave 2 = style-supersession records the old doctrine
wrongly discarded (MULTI_POSITION 8, SCALPING 8, PYRAMIDING 3, GRID 1) — GRID's only
eligible record was already suppressed as a clone (QM5_38007→11375), so 19 records
remain. Wave 3 = NO_EXTERNAL_SOURCE (109 eligible after the Part-1 batch and
suppression) — each needs a `QM-RESEARCH://` provenance mint before Q00 (pattern:
QM-RESEARCH-2026-0003/0004). Wave 4 = HISTORICAL_POLICY (409) — §30 procedure only,
**never batch-enqueued**; only the two highest-value rows are carried here, the rest
stay parked in the register.

## 2. Ranked top 25

| # | ea_id | reason (class) | priority | eligibility under V2 | metrics / evidence (ea_metrics + work_items join) | concrete next action |
|---|---|---|---:|---|---|---|
| 1 | QM5_11211 | SCALPING (style, superseded §17) | 79.28 | ELIGIBLE | never built; card-only (BB-MR scalp, EURUSD/GBPUSD/USDJPY/XAUUSD, M15) | **Wave-2 style rerun** — highest FTMO fit (ftmo 1.0); new-lineage Q00→Q02 after centralized commission |
| 2 | QM5_11855 | SCALPING (style, superseded §17) | 79.28 | ELIGIBLE | never built; card-only (M5 EMA-zone scalp, EURUSD) | **Wave-2 style rerun** — independent EURUSD M5 scalp; pairs with #1 without family overlap |
| 3 | QM5_11215 | SCALPING (style, superseded §17) | 79.28 | ELIGIBLE | never built; card-only (BB-MR family, vol-capitulation variant) | **Wave-2 rerun, staggered** — same family as #1 (not a clone; distinct impl); run only if #1 clears Q02 |
| 4 | QM5_11650 | SCALPING (style, superseded §17) | 76.20 | ELIGIBLE | never built; card-only | **Wave-2 style rerun** |
| 5 | QM5_11217 | SCALPING (style, superseded §17) | 79.28 | ELIGIBLE | never built; card-only (BB-MR scalp variant) | **Wave-2 rerun, staggered** — family alternate to #1/#3 |
| 6 | QM5_11651 | SCALPING (style, superseded §17) | 76.20 | ELIGIBLE | never built; card-only | **Wave-2 rerun, staggered** — family alternate to #4 |
| 7 | QM5_11373 | MULTI_POSITION (style, superseded §17/§20) | 72.70 | ELIGIBLE | never built; card-only (daily-range bracket, index, set-and-forget) | **Wave-2 style rerun** — DXZ index diversification + FTMO Asian-range density |
| 8 | QM5_34002 | MULTI_POSITION (style, superseded §17/§20) | 71.21 | ELIGIBLE | never built; card-only (Brent/WTI stat-arb, energy) | **Wave-2 style rerun** — DXZ energy diversification first (non-FX), FTMO second |
| 9 | QM5_11849 | MULTI_POSITION (style, superseded §17/§20) | 71.38 | ELIGIBLE | never built; **symbols UNKNOWN** | **Card repair first**, then Wave-2 rerun (guardrail: no intended symbols → never enqueued as-is) |
| 10 | QM5_1280 | MULTI_POSITION (style, superseded §17/§20) | 70.50 | ELIGIBLE | never built; card-only (Chan OU half-life pair) | **Wave-2 style rerun** — DXZ pairs sleeve |
| 11 | QM5_9407 | MULTI_POSITION (style, superseded §17/§20) | 70.50 | ELIGIBLE | never built; card-only (pairs-Z basket) | **Wave-2 style rerun** — DXZ pairs sleeve |
| 12 | QM5_11158 | MULTI_POSITION (style, superseded §17/§20) | 65.21 | ELIGIBLE | never built; card-only (spread-zscore, energy+index) | **Wave-2 style rerun** — lower priority, basket complexity penalty |
| 13 | QM5_11539 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 80.18 | ELIGIBLE | 4 work items; best PF 0.93 / 954 trades (Q02/Q04); **no open items** | **Provenance mint → Wave-3 rerun** (mimic QM-RESEARCH-2026-0003 pattern) |
| 14 | QM5_11904 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 79.74 | ELIGIBLE | 34 work items through Q04 (H1 JPY crosses); best PF 0.97 / 288 trades; no open items | **Provenance mint → Wave-3 rerun** — best evidence depth in the Wave-3 pool |
| 15 | QM5_11465 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 80.18 | ELIGIBLE | 14 items; best PF 0.92 / 836 trades; COMPILE_EA **pending since 2026-08-22** (stale) | **Provenance mint → Wave-3 rerun**, after the stale build item is reconciled (ops lane, not a duplicate enqueue) |
| 16 | QM5_11362 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 80.18 | ELIGIBLE | 13 items; COMPILE_FAIL open 2026-09-12 | **Provenance mint → Wave-3 rerun**; build lane occupied — coordinate, do not double-book |
| 17 | QM5_11388 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 80.18 | ELIGIBLE | 40 items; two Q02 **INVALID stranded 2026-08-25** (GBPUSD/USDJPY) | **Provenance mint → infra rescue → rerun**; stranded-INVALID items pre-date the register run |
| 18 | QM5_11898 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 79.74 | ELIGIBLE | 9 items; COMPILE_FAIL open 2026-09-12 | **Provenance mint → Wave-3 rerun**; build lane occupied |
| 19 | QM5_10282 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 79.38 | ELIGIBLE | 1 Q02 item only — thin evidence | **Provenance mint → Wave-3 rerun**; treat as cheap optionality, low evidence weight |
| 20 | QM5_10645 | NO_EXTERNAL_SOURCE (superseded §5/§16) | 78.18 | ELIGIBLE | 8 items (Q02/Q04, M15, EURUSD/GBPUSD/GER40/USDJPY/XAUUSD); no open items | **Provenance mint → Wave-3 rerun**; tv-batch sibling of handled QM5_10648 — re-verify non-clone at commission (none in current map) |
| 21 | QM5_11637 | PYRAMIDING (§21 tail-amplifying if negative) | 67.70 | ELIGIBLE, tail-risk flagged | never built (robo EMA-fan ribbon M1) | **PARK** — Q00 only with the bounded-risk contract of `PORTFOLIO_TAIL_RISK_RESEARCH.md` attached (§18/§20) |
| 22 | QM5_11936 | PYRAMIDING (§21 tail-amplifying if negative) | 54.50 | ELIGIBLE, tail-risk flagged | never built (millipede) | **PARK** — bounded-risk contract precondition |
| 23 | QM5_11703 | PYRAMIDING (§21 tail-amplifying if negative) | 53.18 | ELIGIBLE, tail-risk flagged | never built (100-pip daily-range breakout) | **PARK** — bounded-risk contract precondition |
| 24 | QM5_10050 | HISTORICAL_POLICY (activity/low-freq, §30) | 80.18 | ELIGIBLE, §30-bound | 81 items, all Q01/Q02; 14 stale open (INFRA/INVALID, June–July) | **§30 procedure only** — counterfactual → versioned contract → test; never batch-enqueued; stranded Q02 items go to the infra-rescue lane first |
| 25 | QM5_10342 | HISTORICAL_POLICY (activity/low-freq, §30) | 77.95 | ELIGIBLE, §30-bound | never built (M5, EURUSD/GBPUSD/USDJPY/XAUUSD) | **§30 procedure only** |

## 3. Provenance minted today (Wave-3 precondition)

| research id | origin record | store | source_hash = sha256(source.md) | ledger |
|---|---|---|---|---|
| QM-RESEARCH-2026-0003 | QM5_10648 (tv-velox-mtf) | `strategy-seeds/sources/QM-RESEARCH-2026-0003/` | `610d5652b12bfc1fd7054cea9200649312c106449bd2f7269b99d61249e9f6a7` | mint(draft) 2026-09-16T04:47:39Z + status_change(draft) 04:52:12Z |
| QM-RESEARCH-2026-0004 | QM5_1354 (woodie-cci-dual-h1) | `strategy-seeds/sources/QM-RESEARCH-2026-0004/` | `0ad72c9b4a4477fb91613d6e0aab50c2a2658eee719ad6647867e5d73c06320a` | mint(draft) 2026-09-16T04:47:39Z + status_change(draft) 04:52:13Z |

Both mimic the QM-RESEARCH-2026-0002 ledger pattern exactly (`research_source.py
mint` → content → `research_source.py seal --status draft`, append-only rows in
`D:/QM/reports/state/research_source_ledger.jsonl`). `research_source.py verify`
passes every hash/manifest/numeric-provenance/field check; the only reported reason
is `LEDGER_STATUS_BAD:draft` — a draft is not intake-admissible until the non-Kimi
cross-vendor critic receipt is attached (contract §4.5/§6.1). Each artifact carries
`lineage.json.origin_record` NEW-lineage parent links to its origin record; the
historical rows stay untouched.

Note on numbering: the commissioning brief said "next free after 0004"; the ledger +
on-disk union (the contract's authoritative allocator) showed 0001/0002 as the only
used counters, so the tool allocated **0003/0004**. Nothing was overwritten; if two
further mints become legitimate (e.g. stand-downs reverse), they will allocate 0005+.

## 4. Stood down / parked observations (not in the 25)

- **QM5_9576 — STOOD DOWN.** Normal pipeline is actively advancing it: Q07 NDX PASS
  2026-09-15T21:06Z, Q08 NDX work item `ff0b551b-b00c-47d0-9040-110fd75e30a9`
  **pending** (pump_cascade promotion) created 21:12Z. A second-chance path would be
  a duplicate of the in-flight normal path. No mint; no ticket.
- **QM5_1355 — pipeline-owned (stand down the second-chance path).** Q09 NDX PASS
  2026-09-14; Q10_NEWS item `dbd984be-792d-4759-a5ac-bfd75b423917` pending since
  2026-09-14T14:56Z (unclaimed ~16h — capacity-bound, not stranded: no INFRA/INVALID
  state). If it strands, the rescue is an ops requeue of the existing item, not a
  new-lineage second-chance. No mint burned.
- **QM5_10911 — excluded from the Wave-3 pool:** register row is stale; the record is
  an incumbent DXZ sleeve (GDAXI) with 17 open items incl. Q12 pending
  2026-09-15T13:43Z — pipeline-active; a second-chance ticket would duplicate it.
- **Stranded-infra pool (rescue via the 2026-09-16 stranded-infra sweep lane, not new
  enqueues):** QM5_12512 (24 open Q02 INFRA_FAIL), QM5_9948 (12, June), QM5_11897 (3),
  QM5_11619 (3), QM5_10050 (14, carried at #24 for its §30 value once rescued).
- **Family alternates beyond the 25** (register-priority order; run only if their
  family lead fails cheaply): QM5_11212/11213/11890 (BB-family M15/M5, novelty 1.0),
  QM5_11214, QM5_11533/11537/11496/11516/11518/11531 (Wave-3 EURUSD-centric tail),
  QM5_10649/11689 (tv-batch), QM5_11053/11061/11374/11239/12370 (Wave-4 §30 pool).

## 5. Honest negatives

- The 470 INSUFFICIENT_EVIDENCE and 210 OTHER records remain **not retestable**
  without fresh card/research — they are not in this shortlist and must not be
  batch-enqueued to inflate the queue (programme §2/§5).
- Wave-3 economics are hypothesis-level: the NO_EXTERNAL_SOURCE records were rejected
  at the card gate, but several carry old-lineage Q04 economic FAILs or stale INVALID
  items (per-row notes above). The provenance mint clears the *admission* bar only;
  Q00–Q17 remains the judge.
- Scalp-heavy Wave-2 top ranks concentrate on EURUSD/GBPUSD/XAUUSD — the same liquid
  symbols the live books already trade. The independence argument is *holding-period*
  diversification (M5–M15 intraday vs all-D1 books), not symbol white space; the
  portfolio layer must still prove non-redundancy (V2 §19).
