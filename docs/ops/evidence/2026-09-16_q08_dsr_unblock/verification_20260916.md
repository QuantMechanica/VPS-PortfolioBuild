# Q08 DSR unblock — verification evidence — 2026-09-16

Scope: 21 pending Q08 rows at the head of the canonical claim order
(`farmctl.pending_claim_order_sql()`; selector returns 22 rows = 21 Q08 + 1 Q06 RAM-blocked).
All investigation read-only except the two governed hold releases recorded below.

## Baseline (before)

- Selector rows: `q08_selector_rows.json` (22 rows, canonical SQL executed read-only).
- Precheck over all 88 pending Q08 rows: `q08_precheck_baseline.json`.
- Per-row classification: `q08_classification.json`.

Precheck histogram over the 21 selector Q08 rows:

| reason | rows |
|---|---|
| SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | 20 |
| SINGLE_CONFIGURATION_UNAVAILABLE:SINGLE_CONFIG_CANDIDATE_MISMATCH (QM5_12350: card already declares XAUUSD.DWX/D1 from the 2026-09-14 class-A amendment; this row is NDX.DWX/D1) | 1 |

## Mechanism findings

1. **No "context-window regenerator" exists as a separate artifact step.** For the
   single-configuration path the DSR context is *derived live* at claim time from
   (card declaration on `D:\QM\strategy_farm\artifacts\cards_approved\<label>.md`)
   + EA-dir build identity + factory-search ledger. `terminal_worker._seal_q08_dsr_at_claim`
   re-runs `dsr_cohort.attach()` on every claim; `claimability_precheck` re-derives the
   claim-time-independent subset on every scan. The only durable repair for the 20
   declaration-missing rows is therefore the governed card amendment
   (`session_tools/q08_single_config_amend_0914.py`, append-only, journaled).
2. **Grouped-cohort (DL-089) path**: `_find_ledger` over
   `D:\QM\strategy_farm\artifacts\opt_census\*\ledger.json` — no ledger matches any of
   the 21 rows on (ea_id, symbol, timeframe). Grouped path not viable for any of them.
   (DL-089 ledgers exist for other symbols of some EAs, e.g. QM5_10145/XAUUSD, but the
   precheck matched none of the 21's identities.)
3. **Authority**: the 2026-09-14 card amendments ran under OWNER decision
   `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914` ("Karten OWNER-Artefakte", class A waited
   for OWNER YES). That decision's class A covered the 24 rows classified on 2026-09-14
   only. The current 21 rows (NDX/GDAXI book cohort) are NOT covered. The interim
   OWNER_DIRECT_SESSION_DELEGATION minted three named FTMO G0 cards (41475/41476/41477)
   but per `docs/ops/evidence/2026-09-16_opt_sibling_10911/RECEIPT.md` stop-line,
   `g0_status`/approved-card acts are OWNER-only; no standing mechanical authority
   covers amending these 20 cards. → STAGED, not applied (see `staged_card_amendment/`).
4. **Claim-time code fix**: workers reloaded 2026-09-15 11:0xZ (reload chunk 86) carry
   commit 25df518e7e (`claimed_at_iso` set before `_seal_q08_dsr_at_claim`), so the
   2026-09-15 09:3xZ `Q08_CLAIM_TIMESTAMP_REQUIRED` failure mode is fixed on the live fleet.

## Executed: governed hold releases (2)

Rows whose input repair was ALREADY complete (cards amended 2026-09-14 under the OWNER
decision, before the 09-15 parking) and whose failure was stale-code + hold-parking:

| work item | EA | symbol | hold | verification |
|---|---|---|---|---|
| d02a1128-c6ee-4e4e-ad82-755937a06421 | QM5_13137 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | precheck claimable; full in-memory `assemble()` OK (DECLARED_SINGLE_CONFIGURATION, window 2018-07-02..2022-12-31, factory search clean, 0 opt rows) |
| a6f023c9-4c33-46b3-8d15-e98ac001e909 | QM5_11121 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | precheck claimable; full in-memory `assemble()` OK (DECLARED_SINGLE_CONFIGURATION, window 2018-07-02..2022-12-31, factory search clean, 0 opt rows) |

NOT released:
- 0e3f3359 (QM5_1328/USDCAD.DWX): precheck passes and assembly OK, but the pair is
  POISON_PILL_QUARANTINED (`phase_runner_invalid_report`, 13 consecutive failures,
  quarantined 2026-09-14T15:36:26Z) — an independent quarantine the selector honors;
  releasing the DSR hold would not make it claimable. Needs its own disposition.
- All other Q08_DSR holds: input repair not complete (see staged amendment) or held
  under unrelated codes (BOOK_V2_STREAM_RECOVERED_RERUN_NOT_NEEDED ×8,
  MONITOR_BUDGET_REVIEW_REQUIRED ×2).

Release command form (governed, CAS, backup, ledger + event, no verdict writes):
```
python tools/strategy_farm/farmctl.py release-hold \
  --work-item-id <id> --expected-hold-code Q08_DSR_CONTEXT_UNAVAILABLE \
  --release-note "..."            # dry-run first with --dry-run
```

Release notes cite this evidence directory. Release receipts: `release_receipts.jsonl`.

## After-state proof (2026-09-16 ~05:52Z)

- d02a1128 (QM5_13137/XAUUSD.DWX): **status=active, claimed_by=T10** at 05:52:12Z;
  payload `dsr_context_status: SEALED` (artifact
  `dsr_cohorts/QM5_13137_XAUUSD_DWX_M30/ba54a7a7…json`).
- a6f023c9 (QM5_11121/XAUUSD.DWX): **status=active, claimed_by=T4** at 05:52:16Z;
  payload `dsr_context_status: SEALED` (artifact
  `dsr_cohorts/QM5_11121_XAUUSD_DWX_H4/1fb15010…json`).
- Selector after: `q08_selector_rows_after.json` — 22 rows (the 21 doomed Q08 + 1 Q06);
  the 2 released rows left the pending set by being claimed.
- Factory-wide active work items went 0 → 2 (the two released rows).
- Unreleased Q08_DSR holds: 50 → 48 (transition ledger seq 4343/4344; backups
  `farm_state_before_hold_release_20260916T054940Z_ce869704.sqlite`, sha
  ab78cbc1…f972f9, reused; `work_items_untouched: true` on both releases —
  receipts `release_receipts.jsonl`).

## Not executed (staged for OWNER/Fable)

- 16 rows: governed card amendment dry-run results + exact per-card diffs + apply
  commands in `staged_card_amendment/` (16 staged, all offline-validated `ok`).
- 1 row (bdba95f1, QM5_10145/NDX): NOT amendable — the EA has a sealed DL-089 census
  history on XAUUSD (Q12/Q13/Q14 rows; 6 optimization markers); a `no_optimization_search`
  declaration would be false and the claim-time factory-search ledger would refuse it.
- 1 row (0031f42d, QM5_12350/NDX): card already declares XAUUSD.D1; one declaration per
  card; the NDX configuration cannot be declared on the same card.
- 3 rows (2276786b QM5_12361, 3b320089 QM5_1551, dfb2f622 QM5_12484): `SPEC.md` missing
  in the EA dir; the amendment tool FAILs closed (`missing ['spec']`). Author SPEC.md
  first, then they join the staged set.
- 2 rows (d02a1128/a6f023c9 class): released above.
- 0e3f3359: poison-pill quarantine, separate disposition.

## Sealed-stream data-gap check

All 21 rows' resolved windows end ≤ 2025-12-31 (20 rows: 2017-01-01..2025-12-31;
QM5_10269: 2021-01-01..2022-12-31; the two released rows resolve to 2018-07-02..2022-12-31
from their payloads). Sealed history ends 2025-12-30 (last close) — no row needs a 2026
window, so the documented sealed-stream gap does not block any of the 21.
