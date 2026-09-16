# Evidence Receipt — Second-Chance Continuation 2026-09-16 (Part 1 verification + Part 2 shortlist)

**Date (UTC):** 2026-09-16T04:55Z
**Author:** kimi-interim (Kimi interim OWNER delegation, Directive-3 §13)
**Programme:** Strategy Second-Chance Programme
(`.claude/worktrees/wf_717b9d36-ba6-4/docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`)
**Mode:** PREPARE-ONLY. Zero enqueues, zero work-item/hold/verdict/register mutations,
zero git commits (central commit pass owns the main worktree). New files only:
this receipt, `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md`, and the two
provenance stores under `strategy-seeds/sources/` (plus 4 append-only ledger rows in
`D:/QM/reports/state/research_source_ledger.jsonl` written by the canonical tool).

---

## 1. Inputs (all read-only)

| input | path | note |
|---|---|---|
| register | `D:/QM/reports/state/second_chance_register.json` | sha256 `96beee4e…9812`; `inputs_sha256 37ec3be9…5982`; generated 2026-09-15T18:11:23Z |
| farm DB | `D:/QM/strategy_farm/state/farm_state.sqlite` | read-only URI; tables `work_items`, `agent_tasks`, `ea_metrics`, `work_item_holds` |
| cards | `D:/QM/strategy_farm/artifacts/cards_{rejected,approved}/` | per-ea card files |
| lineage map | `D:/QM/reports/state/lineage_map.json` | sha256 `0a355641…3cb1`; `lineage_map.py --summary` cross-check |
| venue books | `D:/QM/reports/state/book_evolution_dxz.json`, `ftmo_demo_cycle.json` | DXZ 24 sleeves (2026-W38), FTMO 8 sleeves |
| source ledger | `D:/QM/reports/state/research_source_ledger.jsonl` | append-only, via `research_source.py` only |
| eligibility doctrine | `docs/research/STRATEGY_ELIGIBILITY_V2.md` (main) | OWNER-DEC-D3-20260915 |
| source contract | `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (FINAL v1) | mint/seal/verify semantics |
| wave-1 precedent | `docs/ops/evidence/2026-09-15_second_chance_wave1/` | QM5_11563 enqueue receipt + mint procedure |

## 2. Part 1 — the four candidates

### 2.1 Register rows (verbatim classification, all four)

All four: `projection_class REJECTED`, `primary_reason NO_EXTERNAL_SOURCE`,
`matched_rule no_external_source_superseded`, `second_chance_status
ELIGIBLE_FOR_RECONSIDERATION`, `suppressed_clone_of ""`, `portfolio_utility_challenger
false`, `reason_evidence "SUPERSEDED: source-only rejection recovered under OWNER R1
policy on 2026-07-23; original retained in cards_rejected. | legacy_contract_repair |
card_body_incomplete"`.

| ea_id | slug | priority | ftmo_rel | intended symbols | timeframes |
|---|---|---:|---:|---|---|
| QM5_10648 | tv-velox-mtf | 78.636 | 1.0 | GBPJPY, GER40, NDX, XAUUSD (.DWX) | M30 |
| QM5_1355 | williams-vix-fix-fx-h4 | 62.577 | 0.4 | EURUSD, GBPUSD, GDAXI, NDX, SP500, UK100, WS30, XAUUSD | UNKNOWN |
| QM5_1354 | woodie-cci-dual-h1 | 62.103 | 0.4 | AUDUSD, EURUSD, GBPUSD, GDAXI, NDX, USDJPY, WS30, XAUUSD | UNKNOWN |
| QM5_9576 | bandy-zscore-mr-index | 60.400 | 0.2 | NDX, SP500, WS30 | UNKNOWN |

### 2.2 Exact historical rejection reasons (verbatim, from each rejected card's `g0_rejection_reason`)

- **QM5_10648** (2026-05-22): *"R1 FAIL: card frontmatter missing source_citation,
  farmctl approval rejected as card_body_incomplete despite body URL; lean reject for
  incomplete card metadata."*
- **QM5_1355** (2026-05-19): *"R1 FAIL: farmctl approve-card rejects card_body_incomplete
  due missing source_citation; source attribution is not in required approveable form.
  R2/R3/R4 otherwise appear mechanical/testable/HR14-compatible."*
- **QM5_1354** (2026-05-19): *"R1 FAIL: farmctl reports missing source_citation metadata
  despite body attribution; card_body_incomplete blocks G0 approval."*
- **QM5_9576** (2026-05-19): *"R1 FAIL farmctl approve validation reports missing
  source_citation/card_body_incomplete despite prose attribution; cannot approve G0
  without required source citation field."*

All four are **G0 card-form R1 rejections** — the style/economics were never judged.
(The cards do carry body-level external attribution: TradingView script + author,
Larry Williams TASC Dec-1999, Woodie CCI club, Bandy QTA 2015 ISBN — the rejection
was the missing `source_citation` frontmatter field under old strict R1.)

### 2.3 Validity under Strategy Eligibility V2

- **Superseded — invalid to uphold.** V2 §5/§16: no external source is required;
  provenance is still required and satisfiable via `QM-RESEARCH://` internal artifacts.
  The 2026-07-23 OWNER R1 relaxation already recovered source-only rejections.
  Classification: reason no longer valid → each record is a legitimate
  reconsideration candidate **provided** a provenance mint exists before any Q00
  (Wave-3 precondition) and the ML boundary/tail-risk rules are met (all four are
  non-ML, non-tail-amplifying per their cards).
- None of the four is blocked by V2's unchanged rules (HR14 runtime ML, §18 bounded
  risk, gate integrity): all are single-position bounded-risk mechanical systems.

### 2.4 Clone / duplicate check

`lineage_map.py --summary`: 4,098 nodes / 775 edges (264 exact clones, 397
close-implementation clones population-wide). For the four: **0 edges of any clone
relation touch any of them**; each has a distinct mechanism signature
(10648 `fb03def4…`, 1355 `2f7bf21d…`, 1354 `628d16b3…`, 9576 `3e64f5fc…`), own
`card_lineage` (no parent/variant/rerun), register `suppressed_clone_of` empty.
No exact-clone retest risk; no suppression warranted.

### 2.5 DB history (work_items) and pipeline state

- **QM5_10648** — 14 items, all `done`/one old `failed`; Q02 4/4 PASS (2026-08-10),
  Q03 GBPJPY PASS, Q04 mixed (GDAXI PASS 2026-09-02; XAUUSD FAIL 2026-08-11; NDX FAIL
  2026-09-02; GBPJPY FAIL 2026-09-06; 4× INFRA_FAIL). **No open items since
  2026-09-06.** `agent_tasks`: only a BLOCKED build-backlog row `5f1f643e` (parked,
  OWNER-DEC-BACKLOG-20260912 rework note) — read-only evidence, untouched.
  `work_item_holds`: none. `ea_metrics`: 13 rows but all `source=missing` (old
  summaries not metrics-extractable) → verdict-count evidence only.
- **QM5_1355** — 22 items; Q02 7/8 PASS; Q04 → Q05 NDX PASS → Q06 PASS → Q07 PASS →
  Q08 FAIL_HARD (2026-08-29) then FAIL_SOFT disposition rerun `3a2e5d0e` (2026-09-01)
  → Q09 NDX PASS (updated 2026-09-14) → **Q10_NEWS `dbd984be` pending since
  2026-09-14T14:56Z (unclaimed)**. Metrics: e.g. Q02 EURUSD PF 0.68/26 trades;
  Q02 GBPUSD PF 0.99/36.
- **QM5_1354** — 27 items; Q02 7/8 PASS (GBPUSD PF 1.83, +12328.49, 39 trades, DD
  4.84%; XAUUSD PF 1.18/35); XAUUSD chain Q03/Q05/Q06/Q07 PASS; Q08 FAIL_SOFT; Q09
  PASS + Q09_PORTFOLIO PASS_PORTFOLIO; Q09_NEWS REVIEW_REQUIRED → PASS; Q10_NEWS
  INFRA_FAIL (2026-08-23); disposition `33015990` CONFIG_LOCKED (2026-09-13); one
  stale unclaimed pending Q04 XAUUSD (2026-08-21T16:25Z — orphaned pre-cascade).
- **QM5_9576** — 15 items; Q02 3/3 PASS (2026-08-02); 2026-09-15 fresh cascade: Q05
  NDX PASS 07:25, Q06 NDX PASS 07:45, **Q07 NDX PASS (updated 21:06Z)**, **Q08 NDX
  `ff0b551b` pending created 2026-09-15T21:12:29Z, `promotion_source pump_cascade`**.
  Metrics largely `source=missing`.

### 2.6 Economic role assessment (FTMO vs DXZ, density, independence)

- FTMO roster (`ftmo_demo_cycle.json`, 8 sleeves): QM5_10706 GBPUSD, 11421 EURUSD,
  11422 USDCAD, 11910 NZDUSD, 13054+20048 USOIL, 1537+21505 XAGUSD — **all D1 swing;
  zero intraday, zero XAUUSD-on-FTMO, zero GBPJPY/GER40/JPY-cross coverage**.
- DXZ book (`book_evolution_dxz.json`, 24 sleeves): GDAXI×2, USDJPY×2, EURUSD×3,
  XTIUSD, AUDCAD, AUDUSD×2, GBPUSD×2, NDX×2, SP500, **XAUUSD×6 (crowded)**,
  XNGUSD, EURGBP.
- **10648** → FTMO-first intraday density candidate (M30; GBPJPY/GER40 = FTMO white
  space; NDX/XAUUSD overlap DXZ crowding — restrict to GBPJPY/GER40 for DXZ use).
  Register ftmo 1.0 / independence 1.0.
- **1354** → FTMO gold/GBPUSD H1 candidate (no XAUUSD on FTMO roster; H1 vs all-D1
  books = time-axis diversification); old-lineage Q09 PASS_PORTFOLIO already on record.
- **1355** → H4 vol-spike long-only MR; moderate FTMO fit; pipeline-owned (below).
- **9576** → D1 long-only index MR; FTMO fit LOW (swap/overnight shape that breached
  the -10.26% demo); DXZ diversification role only — but pipeline-owned (below).

### 2.7 Stand-downs (task item h)

- **QM5_9576 — STOOD DOWN (recommended and recorded).** The "Q07 item active on T2"
  is work item `ed61aeac-2fd5-45a7-a03a-831b84104d6a` (Q07 NDX, finished
  2026-09-15T21:06Z); the pump cascade then created **Q08 NDX `ff0b551b-b00c-47d0-9040-110fd75e30a9`,
  status pending**, at 21:12:29Z. The normal pipeline IS advancing the record — a
  second-chance ticket would be a duplicate. No provenance minted; no enqueue.
- **QM5_1355 — second-chance path stood down (observation beyond the brief).** Its
  Q10_NEWS item `dbd984be-792d-4759-a5ac-bfd75b423917` is pending since
  2026-09-14T14:56Z (unclaimed ~16h at review time; no INFRA/INVALID state — queued,
  capacity-bound). The normal pipeline owns this strategy through Q09 already; a
  second-chance rerun would duplicate it. If the item strands, the correct action is
  an ops requeue of the existing item. No provenance minted (no id burned).

### 2.8 Provenance minted (contract-conformant)

Mimicry of QM-RESEARCH-2026-0002's ledger pattern exactly: `research_source.py mint`
(scaffolds store, appends `draft` row) → content authored → `research_source.py seal
--status draft` (recomputes the manifest block + sha256(source.md), appends the
second row). Ledger path `D:/QM/reports/state/research_source_ledger.jsonl`
(append-only, tool-written, sort_keys JSON lines — byte-format identical to the
0001/0002 rows).

**QM-RESEARCH-2026-0003 — QM5_10648** (`strategy-seeds/sources/QM-RESEARCH-2026-0003/`)

| file | sha256 |
|---|---|
| source.md (= ledger `sha256` / future card `source_hash`) | `610d5652b12bfc1fd7054cea9200649312c106449bd2f7269b99d61249e9f6a7` |
| research.json | `46a630f380057bf2442e125e43ac089ab1d005890931a41ad0c3e5405d9ab6cf` |
| lineage.json | `2c639fe90e3c1803d8a633b05130547e79c60e13c5b14f3ed8c40abd4513c98f` |
| critic_receipt.json (non-passing skeleton — no critic yet) | `529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14` |
| second_chance_review.json (deterministic computed output) | `238c0538a8b9d4ad1a0d5e82cca373b42ef3e25a6bf17ffd1cccbd6fda5a9c79` |

Ledger rows: `mint draft 2026-09-16T04:47:39Z sha 133f49…` then
`status_change draft 2026-09-16T04:52:12Z sha 610d56…`, version 1,
parent_version_id null; lineage.json carries `origin_record` NEW-lineage parent link
to QM5_10648 (both rejected + approved cards, register ref).

**QM-RESEARCH-2026-0004 — QM5_1354** (`strategy-seeds/sources/QM-RESEARCH-2026-0004/`)

| file | sha256 |
|---|---|
| source.md | `0ad72c9b4a4477fb91613d6e0aab50c2a2658eee719ad6647867e5d73c06320a` |
| research.json | `def3885bef9c8525da1b008ddb5e49df0e9b92b184559e1d5ac9743610a0a8e2` |
| lineage.json | `fa96918c71ef33e8d11a7845a8fff4ae074cc5d0ff58059ccf64026962efe4e4` |
| critic_receipt.json (skeleton) | `529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14` |
| second_chance_review.json | `40eb7f3f953800c65aaf6dbed7cba2b42d4df79b610dd72a9a12a97006d2346f` |

Ledger rows: `mint draft 2026-09-16T04:47:39Z sha 17a90f…`,
`status_change draft 2026-09-16T04:52:13Z sha 0ad72c…`, version 1, parent null;
`origin_record` link to QM5_1354.

`research_source.py verify --id …` for both: **ok=false with the single reason
`LEDGER_STATUS_BAD:draft`** — i.e. manifest recompute, all file hashes, numeric
provenance (every quantitative claim cites `second_chance_review.json`), required
fields, and the authorized-author (Kimi) check all PASS; a draft is not
intake-admissible until the non-Kimi cross-vendor critic receipt is attached
(contract §4.5/§6.1). Both are therefore ready for the critic + `status_change` to
`reviewed`, after which a Wave-3 ticket may cite `QM-RESEARCH://2026-0003|0004`.

Content notes: `source.md` describes the internal second-chance review as discovery
(R-C numeric provenance: all figures come from the extract; no LLM-computed numbers).
`research_trial_count: 1` per record (one second-chance examination pass);
`search_history_ref: second-chance-QM5_<id>` — the research-layer
`search_history_ledger.jsonl` has 0 rows for these families, so no understatement.

## 3. Part 2 — expanded shortlist

Delivered at `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md`: ranked top 25
beyond the five already handled (QM5_11563 wave-1 + the four Part-1 records), with
per-row reason class, V2 status, ea_metrics/work_items evidence, and concrete next
action (provenance mint / Wave-2 rerun / park). Top 10:

1. QM5_11211 (SCALPING, 79.28) — Wave-2 rerun
2. QM5_11855 (SCALPING, 79.28) — Wave-2 rerun
3. QM5_11215 (SCALPING, 79.28) — Wave-2 rerun, staggered
4. QM5_11650 (SCALPING, 76.20) — Wave-2 rerun
5. QM5_11217 (SCALPING, 79.28) — Wave-2 rerun, staggered
6. QM5_11651 (SCALPING, 76.20) — Wave-2 rerun, staggered
7. QM5_11373 (MULTI_POSITION, 72.70) — Wave-2 rerun
8. QM5_34002 (MULTI_POSITION, 71.21) — Wave-2 rerun, DXZ energy
9. QM5_11849 (MULTI_POSITION, 71.38) — card repair first, then Wave-2
10. QM5_1280 (MULTI_POSITION, 70.50) — Wave-2 rerun

Register warnings respected: HISTORICAL_POLICY (409) stays §30-bound (only the two
highest-value rows carried, #24/#25, "never batch-enqueued"); INSUFFICIENT_EVIDENCE /
OTHER honestly excluded; SUPPRESSED_CLONE_OF never proposed; 0 clone edges among all
25 (lineage_map check).

## 4. Contract blockers / discrepancies hit

1. **Numbering discrepancy (resolved by the contract's own allocator).** The brief
   said "next free numbers after 0004"; the ledger + on-disk store actually contain
   only 0000/0001/0002, so `research_source.py mint` (authoritative per contract §2.1:
   counter = ledger+on-disk union) allocated **0003 and 0004**. Nothing overwritten;
   if the stand-downs reverse, the next mints allocate 0005+.
2. **Critic precondition (by design, not a failure).** A `draft` is not
   intake-admissible: the non-Kimi read-only critic receipt must be attached and the
   ledger moved to `reviewed` before any card references these ids (contract §4.5/§6.1).
   That step is deliberately left for the centralized lane — no fabricated receipt,
   no premature `seal --status reviewed`.
3. **QM5_10648 old-lineage metrics missing** (`ea_metrics.source=missing` for all 13
   rows) — its claims rest on verdict history + register scores only; honestly noted
   in the artifact's confounders.
4. **Register staleness discovered, not corrected** (register is a read-model; fixing
   it is the generator's job, out of scope here): QM5_10911 is an incumbent DXZ sleeve
   with fresh Q12 pending yet appears ELIGIBLE — excluded from the shortlist and
   flagged; QM5_1355/9576 pipeline states post-date their register rows.

## 5. Files created / modified (all uncommitted, main worktree untouched by git)

- `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md` (new)
- `docs/ops/evidence/2026-09-16_second_chance_continuation/evidence_receipt.md` (this file)
- `strategy-seeds/sources/QM-RESEARCH-2026-0003/{source.md,research.json,lineage.json,critic_receipt.json,second_chance_review.json}` (new)
- `strategy-seeds/sources/QM-RESEARCH-2026-0004/{source.md,research.json,lineage.json,critic_receipt.json,second_chance_review.json}` (new)
- `D:/QM/reports/state/research_source_ledger.jsonl` — 4 appended rows (tool-written only)
- helper (scratch): `.scratch/second_chance_fill_0003_0004.py` — the deterministic writer for the research/lineage JSON contents (kept for reproducibility; not part of the deliverable)
