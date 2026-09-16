# Evidence Receipt — Second-Chance Wave-2 Retest Commission: QM5_11211, QM5_11855, QM5_11373

**Date (UTC):** 2026-09-16T05:40Z
**Commission author:** kimi-interim (Kimi interim OWNER delegation)
**Programme:** Strategy Second-Chance Programme
(`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`, worktree copy
`.claude/worktrees/wf_717b9d36-ba6-4/docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`)
**Wave:** Wave-2 = style-supersession records (SCALPING / MULTI_POSITION / PYRAMIDING
per programme §5).
**Classification source:** `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md`
(committed ranked shortlist; register `D:/QM/reports/state/second_chance_register.json`,
schema `qm.second-chance-register/v1`, generated 2026-09-15T18:11:23Z,
`inputs_sha256 37ec3be93ae709404a2c829429084cdf9266ed8b916bb29d780adad69fb15982`).
**Mode:** ENQUEUE-ONLY. Zero repo code changes. Zero git commits (central commit pass
owns the worktree). No historical verdicts, work items, holds or register rows modified.

---

## 1. Candidate selection (top-3 commissionable, in priority order)

| # | ea_id | slug | reason (class) | priority | Decision |
|---|---|---|---|---:|---|
| 1 | QM5_11211 | ft-binhv45 | SCALPING (style, superseded §17) | 79.28 | **COMMISSIONED** |
| 2 | QM5_11855 | blade-m5-ema-zone-scalp | SCALPING (style, superseded §17) | 79.28 | **COMMISSIONED** |
| 3 | QM5_11373 | 100pips-daily-range-bracket-usdjpy | MULTI_POSITION (style, superseded §17/§20) | 72.70 | **COMMISSIONED** |

**Skipped from the top ranks (per skip rules):** none of the three selected rows was
skipped. Shortlist rows ranked between them (#3 QM5_11215, #4 QM5_11650, #5 QM5_11217,
#6 QM5_11651) were not selected because the task commissioned exactly the top 3 in
priority order; rows #3–#6 are same-family SCALPING alternates the shortlist says to
stagger (run only if the family lead clears Q02). QM5_11849 (shortlist #9) is flagged
**card-repair-first** (symbols UNKNOWN) and was never a candidate. QM5_9576 / QM5_1355
stood-down precedent (normal pipeline owns them) was checked and does not apply to any
of the three (below).

### 1.1 Skip-gate verification (all three)

**(a) Normal-pipeline ownership — CLEAR for all three.**
`farm_state.sqlite` (`D:/QM/strategy_farm/state/farm_state.sqlite`), BEFORE state:

| ea_id | work_items | work_item_holds | agent_tasks referencing ea_id |
|---|---:|---:|---:|
| QM5_11211 | 0 | 0 | 0 |
| QM5_11855 | 0 | 0 | 0 |
| QM5_11373 | 0 | 0 | 0 |

None is pipeline-owned; unlike 9576 there is no pending Q08/Q10 item and no BLOCKED
build row. Matches the shortlist's "never built; card-only" notes.

**(b) Historical card + evidence — PRESENT for all three.**

| ea_id | card path | card frontmatter | symbols in card |
|---|---|---|---|
| QM5_11211 | `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11211_ft-binhv45.md` | ea_id, slug, source_id `1580128f-e465-5454-bb97-a7572a6cfd6d`, `g0_status: REJECTED` (2026-05-23), R1–R4 all PASS | `target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]`, period M1 |
| QM5_11855 | `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11855_blade-m5-ema-zone-scalp.md` | ea_id, slug, source_id `7f6f2831-ea66-58f6-a7ff-a8c89a44803d`, `g0_status: REJECTED` (2026-05-24), R1/R2 PASS | `target_symbols: [EURUSD]`, period M5 |
| QM5_11373 | `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11373_100pips-daily-range-bracket-usdjpy.md` | ea_id, slug, source_id `e1222215-8e37-5add-90ba-87c1801691bf`, `g0_status: REJECTED` (2026-05-23), R1 CONDITIONAL / R2–R4 PASS | card body: "Instruments: USDJPY.DWX (primary per source); extension: GBPJPY.DWX, EURJPY.DWX", period H1 |

The register's `intended_symbols: UNKNOWN` for QM5_11373 is a projection-extraction
artifact (the card frontmatter has no `target_symbols:` key); the card body fully
specifies USDJPY.DWX — this is **not** a 11849-style card-repair case.

**(c) Card-repair-first flag — NONE.** Only shortlist #9 (QM5_11849) carries that
flag; none of the three selected rows does.

## 2. Provenance verification (no QM-RESEARCH mint needed)

Register rows (classification authority per programme §1.2 rule table):

| ea_id | primary_reason | matched_rule | suppressed_clone_of | tail_risk_flag | second_chance_status |
|---|---|---|---|---|---|
| QM5_11211 | SCALPING | scalping | "" | false | ELIGIBLE_FOR_RECONSIDERATION |
| QM5_11855 | SCALPING | scalping | "" | false | ELIGIBLE_FOR_RECONSIDERATION |
| QM5_11373 | MULTI_POSITION | multi_position | "" | false | ELIGIBLE_FOR_RECONSIDERATION |

Old-card rejection reasons (verbatim from each card's `g0_rejection_reason`):

- **QM5_11211:** "R2 fail: M1 entry requires closedelta > close*17/1000 (about 1.7%
  one-minute move), implausible to support >=2 trades/year/symbol on DWX FX/XAU despite
  inflated 120/year claim." — the cadence-plausibility note attached to the superseded
  §17 scalping rejection (card self-tags `scalping: true`, `hard_rules_at_risk:
  scalping_p5b_latency`).
- **QM5_11855:** "R2 FAIL: card lacks required expected_trade_frequency /
  expected_trades_per_year_per_symbol estimate, so G0 cannot validate cadence despite
  mechanical EMA zone scalp rules."
- **QM5_11373:** "R4 FAIL: card requires three simultaneous same-side pending
  orders/positions for tiered TPs without explicit per-slot magic allocation,
  conflicting with HR14 one-position-per-magic; R1/R2/R3 otherwise pass."

The register's deterministic rule table classifies all three under the superseded
**style** rules (SCALPING §17 / MULTI_POSITION §17·§20) — the R-rule texts above are
the card-reviewers' stated mechanics of *why* the old style doctrine fired. All three
retests re-draft the card under current doctrine, which absorbs the cadence /
trade-frequency / per-slot-magic gaps.

**NO_EXTERNAL_SOURCE check — all three carry external source citations**
(11211: GitHub freqtrade-strategies BinHV45.py; 11855: Blade Forex Strategies PDF
~2010; 11373: JanusTrader 100 Pips Daily PDF). A grep of
`D:/QM/reports/state/research_source_ledger.jsonl` (14 rows; used ids 0001–0006) finds
**no** row referencing any of the three ea_ids, and none is needed → **no
QM-RESEARCH mint was burned for Wave-2** (mint precondition applies to Wave-3
NO_EXTERNAL_SOURCE records only).

**Clone check:** `lineage_map.json` scan — 0 exact/close-implementation clone edges
touch any of the three (consistent with the shortlist's committed clone-hygiene check).

## 3. What was enqueued (canonical mechanism)

Mechanism identical to Wave-1: `python tools/strategy_farm/agent_router.py enqueue
research_strategy --priority 70 --state TODO --payload-json '{…}'` run from
`C:\QM\repo` (the doc's literal `research_task` label is not an enumerated router task
type; `research_strategy` [research, strategy] is the canonical research-lane mapping
preserving the §5.1 template payload verbatim). The payload IS the append-only
NEW-lineage ticket per programme §5.1; no separate ticket files were written.

Each payload carries: `kind: second_chance_retest`, `origin_ea_id`,
`second_chance_reason` (SCALPING / SCALPING / MULTI_POSITION),
`second_chance_status: ELIGIBLE_FOR_RECONSIDERATION`,
`register_inputs_sha256: 37ec3be9…5982`, `lineage: NEW`,
`tail_risk_contract: null`, `provenance: {source: second_chance_wave2, register_ref +
schema + record, commission_author: kimi-interim, commissioned_at_utc:
2026-09-16T05:40:08Z}`, `origin_source_class`, `venue_hypothesis`, `intended_symbols`,
`historical_evidence`, `prior_agent_task_evidence: none`, `action` (new-lineage
Q00→Q02 rerun; mint NEW ea-id via farmctl allocation; never reopen the old verdict),
`notes: append-only`.

Router results:

```json
{ "enqueued": true, "state": "TODO", "task_id": "f05399de-2945-4ab3-8006-896e5b150b3a", "task_type": "research_strategy" }
{ "enqueued": true, "state": "TODO", "task_id": "8eaa5bf9-dd37-446a-a60c-17bf0ac28ed1", "task_type": "research_strategy" }
{ "enqueued": true, "state": "TODO", "task_id": "27ae17d6-beb8-416c-9c25-fade17603fe9", "task_type": "research_strategy" }
```

| origin_ea_id | created agent task | state | priority | capabilities | assigned_agent | budget_class | created_at |
|---|---|---|---:|---|---|---|---|
| QM5_11211 | `f05399de-2945-4ab3-8006-896e5b150b3a` | TODO | 70 | [research, strategy] | unassigned (router routes) | standard | 2026-09-16T05:40:37+00:00 |
| QM5_11855 | `8eaa5bf9-dd37-446a-a60c-17bf0ac28ed1` | TODO | 70 | [research, strategy] | unassigned (router routes) | standard | 2026-09-16T05:40:37+00:00 |
| QM5_11373 | `27ae17d6-beb8-416c-9c25-fade17603fe9` | TODO | 70 | [research, strategy] | unassigned (router routes) | standard | 2026-09-16T05:40:38+00:00 |

## 4. DB before/after (farm_state.sqlite)

**second_chance_retest payloads in agent_tasks: BEFORE = 1** (`b0ef5d66-…` Wave-1,
state REVIEW — progressed TODO→REVIEW since its 2026-09-15 commission; left untouched).
**AFTER = 4** (Wave-1 + the three new rows above).

| ea_id | work_items BEFORE→AFTER | holds BEFORE→AFTER | agent_tasks refs BEFORE→AFTER |
|---|---|---|---|
| QM5_11211 | 0 → 0 | 0 → 0 | 0 → 1 (`f05399de…`) |
| QM5_11855 | 0 → 0 | 0 → 0 | 0 → 1 (`8eaa5bf9…`) |
| QM5_11373 | 0 → 0 | 0 → 0 | 0 → 1 (`27ae17d6…`) |

Exactly three new `agent_tasks` rows; no work_items, holds, verdicts or registry rows
touched. Payload spot-check after enqueue: each row's `payload_json` reads back
`kind: second_chance_retest`, correct `origin_ea_id` / `second_chance_reason`,
`lineage: NEW`, `provenance.commission_author: kimi-interim`.

## 5. Lineage tickets

Per programme §5.1 the enqueued payload **is** the ticket (same mechanism as Wave-1);
no separate ticket files were created. Lineage = NEW, append-only; the old ea-id, its
card, and the historical register row remain read-only evidence. Execution-time
farmctl allocation mints the new retest ea-id.

## 6. Notes and honest caveats

- **Timeframe correction vs shortlist:** the shortlist describes QM5_11211 as "M15";
  the register row and the origin card both say **M1** (`period: M1`, M1 closed-bar
  mechanics). Card + register win; the retest lane re-drafts from the origin card.
- **Shortlist venue note for 11373** mentions "index diversification" but the record is
  a USDJPY H1 bracket (register `dxz_relevance 0.6`, `ftmo_relevance 0.8`); the ticket
  venue_hypothesis records FTMO Asian-range density + DXZ diversification without the
  index claim.
- **Wave-2 remaining pool:** 17 style-supersession records not commissioned here
  (SCALPING #3–#6 family alternates to stagger, MULTI_POSITION #8–#12, PYRAMIDING
  tail-risk-gated). Next batches gate on MT5 capacity per programme §5 guardrails.
- **Provenance mints:** none burned; ledger remains at ids 0001–0006. Wave-3
  (NO_EXTERNAL_SOURCE) mints remain a separate precommission step.
