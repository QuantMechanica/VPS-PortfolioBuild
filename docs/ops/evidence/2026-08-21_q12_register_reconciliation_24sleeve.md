# Q12 portfolio-candidates register vs 24-sleeve live book — reconciliation

- **Date:** 2026-08-21
- **Task:** router `6ad915cb-a9e5-48ca-a538-33dc42ac9957` / QM-TODO-20260821-121 (prio 72)
- **Author:** Claude (board-advisor)
- **Scope:** READ-ONLY analysis. No DB row, no live weight, no T_Live artifact was modified.
  Every correction below is a **proposal for OWNER**, not an action taken.

## Sources (both read read-only)

- **Register:** `portfolio_candidates` in `D:/QM/strategy_farm/state/farm_state.sqlite`.
  Schema `(ea_id TEXT, symbol TEXT, q11_work_item_id TEXT, state TEXT, evidence_path,
  first_seen_at, updated_at)`. 38 rows: `Q12_REVIEW_READY=30`, `EVIDENCE_STALE=6`,
  `DUPLICATE_SUPERSEDED=2`.
- **Live book:** `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json`
  — `book=DXZ_4000090541`, `status=LIVE`, `n_sleeves=24`, OWNER-approved 2026-07-24
  (content sha256 `a766b5b…3db6908`; record `decisions/2026-07-24_owner_approvals_audit_package.md`).
  Baskets matched by `basket_identifier` (12778 → `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`,
  13117 → `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`).

## Acceptance criterion 1 — every live sleeve → register state

Join key = (ea_id, host/chart symbol), baskets remapped via `basket_identifier`.

| # | ea_id | symbol | magic | register rows | register state(s) |
|---|-------|--------|-------|---------------|-------------------|
| 1 | 13301 | GDAXI.DWX | 133010010 | **0** | **NONE — missing** |
| 2 | 13213 | USDJPY.DWX | 132130000 | **0** | **NONE — missing** |
| 3 | 1567 | EURUSD.DWX | 15670007 | 1 | Q12_REVIEW_READY |
| 4 | 10919 | XTIUSD.DWX | 109190001 | 1 | Q12_REVIEW_READY |
| 5 | 11165 | AUDCAD.DWX | 111650002 | 1 | Q12_REVIEW_READY |
| 6 | 12778 | AUDUSD.DWX (basket) | 127780000 | 1 | Q12_REVIEW_READY |
| 7 | 11421 | AUDUSD.DWX | 114210003 | 1 | Q12_REVIEW_READY |
| 8 | 11165 | EURUSD.DWX | 111650000 | 1 | Q12_REVIEW_READY |
| 9 | 11421 | EURUSD.DWX | 114210000 | 1 | Q12_REVIEW_READY |
| 10 | 11708 | EURUSD.DWX | 117080000 | 1 | Q12_REVIEW_READY |
| 11 | 10706 | GBPUSD.DWX | 107060001 | 1 | Q12_REVIEW_READY |
| 12 | 10939 | GBPUSD.DWX | 109390001 | 1 | Q12_REVIEW_READY |
| 13 | 10911 | GDAXI.DWX | 109110003 | 1 | Q12_REVIEW_READY |
| 14 | 13128 | NDX.DWX | 131280000 | 1 | **EVIDENCE_STALE** |
| 15 | 10440 | NDX.DWX | 104400003 | 1 | **EVIDENCE_STALE** |
| 16 | 11132 | SP500.DWX | 111320000 | 3 | Q12_REVIEW_READY + 2×DUPLICATE_SUPERSEDED |
| 17 | 12969 | USDJPY.DWX | 129690000 | 1 | Q12_REVIEW_READY |
| 18 | 10403 | XAUUSD.DWX | 104030002 | 1 | Q12_REVIEW_READY |
| 19 | 10513 | XAUUSD.DWX | 105130003 | 1 | Q12_REVIEW_READY |
| 20 | 12567 | XAUUSD.DWX | 125670003 | 1 | Q12_REVIEW_READY |
| 21 | 12989 | XAUUSD.DWX | 129890003 | **0** | **NONE — missing** |
| 22 | 1556 | XAUUSD.DWX | 15560004 | 1 | Q12_REVIEW_READY |
| 23 | 12567 | XNGUSD.DWX | 125670002 | 1 | Q12_REVIEW_READY |
| 24 | 13117 | EURGBP.DWX (basket) | 131170000 | 1 | Q12_REVIEW_READY |

**Result:** 20 sleeves map to exactly one *active* register row (19 `Q12_REVIEW_READY` +
sleeve 16 whose 2 extra rows are historical `DUPLICATE_SUPERSEDED`, not competing live
states). 2 sleeves map to a single `EVIDENCE_STALE` row. **3 sleeves have no register row
at all.**

## Acceptance criterion 2 — divergence root cause

### D1 — 3 live sleeves absent from the register (register is INCOMPLETE)
`13301 GDAXI` (balke-minute-range-breakout), `13213 USDJPY` (balke-gmt3-range-breakout),
`12989 XAUUSD` (grimes-nested-pb-v2). All three are deployed presets in the signed
manifest (sleeves 1, 2, 21) with live magic numbers. **Root cause = register wrong
(missing rows), not manifest.** The manifest is the OWNER-signed source of truth for what
is live; these EAs entered the book (their `ex5_deployed_mtime` are 2026-07-16 / 2026-07-14
/ 2026-07-04) but no `portfolio_candidates` row was ever inserted for them.
**Proposal for OWNER:** insert three `Q12_REVIEW_READY` (or a new `LIVE_UNTRACKED`) rows so
the register covers 24/24. Not done — register writes are out of scope for this task.

### D2 — 2 live sleeves flagged EVIDENCE_STALE (register lags reality)
`13128 NDX` and `10440 NDX` are live (sleeves 14, 15) but the register marks their evidence
stale (both `updated_at=2026-07-18`, the R16 stale-downgrade batch). Their evidence still
reads `verdict=PASS_PORTFOLIO` (see criterion 3). **Root cause = register classification
stale — the flag is a bookkeeping lag, the sleeves are genuinely live.**
**Proposal for OWNER:** refresh evidence (below), then move to `Q12_REVIEW_READY`.

### D3 — register rows that are NOT in the live book (15 rows)
These are **not** manifest errors; the manifest deliberately excludes them. They split:

- **11 `Q12_REVIEW_READY` candidates awaiting admission** (expected, not a defect):
  `10940 XAUUSD`, `10476 USDCAD`, `1567 XAGUSD`, `10815 GDAXI`, `10815 EURUSD`,
  `10700 XAUUSD`, `11422 USDCAD`, `11910 NZDUSD`, `12710 XTIUSD`, `12580 AUDUSD`,
  `12966 GDAXI`. These are candidate-pool entries the live book has not admitted.
  Note: `10476 USDCAD` was explicitly named a "ghost" in the manifest header note
  (replaced-23-sleeve-DRAFT ghosts `10476/10692/10715`) — so this one is arguably a
  stale candidate, not a live-eligible one.
- **4 `EVIDENCE_STALE` non-live rows** — see criterion 3 (two are confirmed ghosts).

## Acceptance criterion 3 — the 6 EVIDENCE_STALE rows, named artifact + mtime

| ea_id / symbol | wi | evidence_path | on disk? | artifact mtime (UTC) | live? | refresh requires |
|---|---|---|---|---|---|---|
| 10440 NDX | 9799d0aa | `D:\QM\reports\portfolio\recert_20260627T113037+0000\summary.json` | **EXISTS** | 2026-06-27T11:30:38Z | **yes (sleeve 15)** | Re-run Q09_PORTFOLIO recert for `10440:NDX` vs current 24-sleeve book; artifact is a 2026-06-27 corr/diversification cert, ~7 wk old and predates the current book. |
| 10692 NDX | 607f7b0c | same `recert_…/summary.json` | **EXISTS** | 2026-06-27T11:30:38Z | no (**GHOST** per manifest note) | Moot unless re-considered as a candidate; artifact is the shared 06-27 recert. |
| 10715 USDJPY | df72b85a | `…\work_items\df72b85a-…\QM5_10715\Q09_PORTFOLIO\USDJPY_DWX\aggregate.json` | **MISSING (dir purged)** | n/a | no (**GHOST**) | Evidence directory no longer on disk; a full Q09_PORTFOLIO re-run would be needed to reconstruct. |
| 10715 USDJPY | 58d8956f | `…\work_items\58d8956f-…\…\aggregate.json` | **MISSING (dir purged)** | n/a | no (**GHOST**, duplicate wi of the above) | Same as above; also a redundant second row for one ghost EA/symbol. |
| 12474 GBPUSD | c028199b | `…\work_items\c028199b-…\QM5_12474\Q09_PORTFOLIO\GBPUSD_DWX\aggregate.json` | **EXISTS** | 2026-07-14T01:38:03Z | no (candidate) | Artifact reads `verdict=PASS_PORTFOLIO` but was scored against an older book; re-run Q09 vs current 24-sleeve book to re-certify as a candidate. |
| 13128 NDX | q09-adhoc-13128-ndx-preFOMC | `D:/QM/reports/QM5_13128/Q09_PORTFOLIO/NDX_DWX/aggregate.json` | **EXISTS** | 2026-07-11T06:36:13Z | **yes (sleeve 14)** | Artifact reads `verdict=PASS_PORTFOLIO` but is an ad-hoc pre-FOMC run (wi id is a hand-minted `q09-adhoc…` string, not a UUID); re-run a canonical Q09_PORTFOLIO for `13128:NDX`. |

## Acceptance criterion 4 — the 2 DUPLICATE_SUPERSEDED rows, survivor

Both `DUPLICATE_SUPERSEDED` rows are `11132 SP500.DWX`, wi `cfea221d-…` and `b258fc3b-…`.
Both `first_seen_at=2026-06-26T06:28:56Z`, both `updated_at=2026-06-26T06:33:02Z` (same
06:28→06:33 intake batch, superseded the same minute). Their evidence dirs
(`…\work_items\cfea221d-…\…\aggregate.json` and `…\b258fc3b-…\…\aggregate.json`) are **both
MISSING from disk** (directories purged).

**Survivor = wi `1ea996fd-ef55-48ce-93d8-2b0a13c4f19a`** (the `Q12_REVIEW_READY`
`11132 SP500` row). Grounds:
1. Only the survivor has extant evidence: its `evidence_path`
   `D:\QM\reports\portfolio\recert_20260627T113037+0000\summary.json` **exists**
   (mtime 2026-06-27T11:30:38Z) and lists `11132:SP500.DWX` as `admit:true`,
   `max_corr_to_book=-0.018246`, `diversifies:true`.
2. The survivor is the 2026-06-27 recert row; the two duplicates predate it (06-26) and
   were superseded within 5 minutes of intake.
3. Survivor matches the live sleeve 16 magic `111320000`.

**Caveat / open item:** a fund-score comparison between the two superseded rows is
**not possible** — their aggregate.json artifacts have been purged, so the DUPLICATE
selection cannot be re-derived from KPIs; it rests on evidence-survival + recency +
live-magic match above. The outcome (survivor = 1ea996fd) is unaffected.

## Divergence classification counts (summary)

- 24 live sleeves: **19** clean `Q12_REVIEW_READY`; **2** `EVIDENCE_STALE` but live
  (13128, 10440 NDX); **1** clean active + 2 historical duplicates (11132 SP500);
  **3** absent from the register (13301 GDAXI, 13213 USDJPY, 12989 XAUUSD).
- Register rows not in the live book: **15** (11 `Q12_REVIEW_READY` candidates incl. the
  10476 ghost; 4 `EVIDENCE_STALE`, of which 10692 + 10715×2 are confirmed ghosts).
- Missing evidence artifacts on disk: **4** (both 11132 duplicates, both 10715 stale rows).

## Proposals for OWNER (none executed)

1. Insert register rows for the 3 untracked live sleeves (13301, 13213, 12989) so coverage
   is 24/24.
2. Refresh Q09_PORTFOLIO evidence for the 2 live-but-stale sleeves (13128, 10440), then
   promote to `Q12_REVIEW_READY`.
3. Retire/park the confirmed ghosts (10692 NDX, 10715 USDJPY ×2, 10476 USDCAD) — the
   manifest header already declared them non-live.
4. Decide whether 12474 GBPUSD and the 10 other non-live `Q12_REVIEW_READY` candidates
   are re-scored against the current book or dropped from the review queue.

## Open items I could NOT resolve

- **11132 SP500 duplicate KPI comparison** — the two superseded rows' evidence dirs are
  purged; survivor picked on evidence-survival/recency/magic-match, not fund score.
- **Missing 10715 USDJPY evidence** — both stale-row directories are gone; state cannot be
  re-derived without a fresh Q09 run.
