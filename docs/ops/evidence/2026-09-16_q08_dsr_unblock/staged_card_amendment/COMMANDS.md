# Staged governed card amendment — 16 cards — apply recipe for OWNER/Fable

Status: STAGED ONLY. Nothing under `D:\QM\strategy_farm\artifacts\cards_approved` was
modified. Each staged file is byte-identical to what the governed tool would write,
produced by importing `tools/strategy_farm/session_tools/q08_single_config_amend_0914.py`
and running its own `resolve` / `build_block` / `amendment_text` / `offline_validate`
against the read-only DB. See `manifest.json` (before/after card sha, spec sha, setfile
sha, locked parameter count) and per-card `<label>.diff` + `<label>.AMENDED.staged.md`.

## Authority precondition (must happen first)

The staged amendment text currently cites `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`
(receipt `3415f6c0`) — the decision that authorized the 2026-09-14 class-A cohort. That
decision's scope was the 24 rows classified on 2026-09-14; it does NOT cover this
NDX/GDAXI cohort. Before any apply:

1. OWNER issues a decision extending `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914` (or a new
   decision) to this cohort, with the same class-A predicate: APPROVED card, never
   censused (verified: 0 OPT_/Q12–Q16 rows, 0 optimization markers for all 16), exactly
   one configuration, no `||` optimizer sets.
2. Update `DECISION_ID` / `RECEIPT_ID` in
   `tools/strategy_farm/session_tools/q08_single_config_amend_0914.py` (or copy the tool
   to a new session file) so the amendment text and journal cite the new authority.
3. The interim OWNER_DIRECT_SESSION_DELEGATION was judged NOT to cover this act: cards
   are OWNER artifacts (OWNER decision 2026-09-14: "(A) wartet auf JA, weil Karten
   OWNER-Artefakte sind"); the delegation's documented card acts are the three named
   FTMO G0 cards only (`docs/ops/evidence/2026-09-16_opt_sibling_10911/RECEIPT.md`
   stop-line).

## Truth predicate re-verified 2026-09-16 (all 16)

- card on `D:\QM\strategy_farm\artifacts\cards_approved` with `g0_status: APPROVED`
- no existing `qm-dsr-single-configuration` block on the card
- `SPEC.md`, `<label>.mq5`, `<label>.ex5`, row setfile all present
- setfile contains no `||` (not an optimizer set)
- EA has zero OPT_CENSUS/Q12–Q16 rows and zero optimization_fork markers in the DB
- offline `dsr_single_configuration.declaration` + candidate/spec/locked-parameter
  validation: **ok** for all 16 (see dry-run log `../staged_card_amendment_dryrun.txt`)

## Exact apply commands

Dry-run first (idempotent, read-only):

```
python tools/strategy_farm/session_tools/q08_single_config_amend_0914.py \
  --rows "7bc8b34e,d4aebc12,383c45b0,20c533da,a937b9bc,15fed5d8,aa0fa828,94d46fe7,456f590f,ff0b551b,a591ff4c,885b82ab,bb5eccf7,1494bfb4,b11e5b43,aec37e79"
```

Apply (append-only; refuses a card that already carries a block; journals
before/after hashes to `docs/ops/evidence/2026-09-14_q08_context_repair/card_amend_journal.jsonl`
— consider a new journal path for the new decision):

```
python tools/strategy_farm/session_tools/q08_single_config_amend_0914.py \
  --rows "7bc8b34e,d4aebc12,383c45b0,20c533da,a937b9bc,15fed5d8,aa0fa828,94d46fe7,456f590f,ff0b551b,a591ff4c,885b82ab,bb5eccf7,1494bfb4,b11e5b43,aec37e79" \
  --apply
```

Then verify each row flips:

```
python - <<'PY'
import sqlite3, sys, json
sys.path.insert(0, ".")
conn = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
conn.row_factory = sqlite3.Row
from tools.strategy_farm import dsr_cohort
for prefix in ["7bc8b34e","d4aebc12","383c45b0","20c533da","a937b9bc","15fed5d8","aa0fa828","94d46fe7","456f590f","ff0b551b","a591ff4c","885b82ab","bb5eccf7","1494bfb4","b11e5b43","aec37e79"]:
    row = dict(conn.execute("SELECT * FROM work_items WHERE id LIKE ?", (prefix+"%",)).fetchone())
    print(prefix, dsr_cohort.claimability_precheck(conn, row, json.loads(row["payload_json"] or "{}")))
PY
```

Then release the matching Q08_DSR_CONTEXT_UNAVAILABLE holds via governed
`farmctl release-hold` (one per row, dry-run first), citing the new OWNER decision and
this evidence directory. Note: none of the 16 rows currently carries an active
Q08_DSR hold (the 09-15 parking covered other rows); they sit in the claim order failing
the cheap precheck, which is starvation-safe by design (commit f160a0937c) — the
post-amendment claim scan will simply pass them.

## Rows deliberately NOT in the apply set

| row | EA | reason |
|---|---|---|
| bdba95f1 | QM5_10145 / NDX.DWX | EA has a sealed DL-089 census history on XAUUSD (Q12×3, Q13, Q14×2 rows; 6 optimization markers; `DL089_QM5_10145_XAUUSD_DWX_2019_2025` ledger). A `no_optimization_search` declaration would be false, and the claim-time factory-search ledger (`_factory_search_before_q08_claim`) would refuse the claim. Needs a grouped-cohort decision per symbol or retirement — OWNER/Fable call. |
| 0031f42d | QM5_12350 / NDX.DWX | Card already carries one declaration (XAUUSD.DWX/D1, amended 2026-09-14). The contract allows exactly one block per card; the NDX/D1 configuration cannot be declared. Multi-symbol disposition needed. |
| 2276786b | QM5_12361 / NDX.DWX | `SPEC.md` missing in the EA dir — tool FAILs closed. Author SPEC.md first. |
| 3b320089 | QM5_1551 / NDX.DWX | `SPEC.md` missing. |
| dfb2f622 | QM5_12484 / NDX.DWX | `SPEC.md` missing. |

Caveat: two staged rows use `_ablation_00` setfiles (QM5_10804, and QM5_1551 in the
excluded set). The n=1 declaration is still mechanically true for them (single
parameter set, no optimizer `||`), but OWNER may want the ablation provenance noted in
the amendment text before sealing.
