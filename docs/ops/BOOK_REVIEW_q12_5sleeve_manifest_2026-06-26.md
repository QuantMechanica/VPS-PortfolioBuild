# Book Review — Q12-ready 5-sleeve T_Live draft manifest (2026-06-26)

Reviewer: Claude. Subject: `D:\QM\reports\portfolio\portfolio_manifest_q12_ready_all_DRAFT_20260626.json`
(Codex commit `c40505dcd` — q12-ready-all manifest mode). Scope: book review + OWNER-approval prep
for the FIRST V5 live portfolio. **No deploy / no AutoTrading action taken.**

## Verdict: book VERIFIED — approvable AFTER one magic-number artifact fix (not a runtime mis-magic risk)

> Correction (verified post-write): `gen_setfile.ps1` derives `qm_magic_slot_offset` from
> `magic_numbers.csv` `symbol_slot` (L246–275), NOT from the manifest — so the *generated live
> setfile* would carry the correct registry magic regardless of this manifest. The defect below is
> therefore an **approval-artifact + deploy-verification consistency** problem (the manifest shows
> wrong magics and its `set_file_expectation` would mismatch what gen_setfile produces), **not** a
> "the EA would trade at the wrong magic" runtime risk. Still must-fix before OWNER signs — the
> approval artifact must be correct and internally consistent — but it does not endanger live magic.

### ✅ Verified correct
- **Commit `c40505dcd` logic:** `--book-source q12-ready-all` pulls every distinct
  `Q12_REVIEW_READY` sleeve (`read_candidates`) and weights inverse-vol (`inverse_vol_weights`,
  the merged risk-parity basis). Greedy assembler is the separate `selected` mode. Basis recorded
  `portfolio_candidates.Q12_REVIEW_READY_all`.
- **Reproducible:** re-ran the canonical command; KPIs identical to Codex's draft —
  5 sleeves, **MaxDD 13.8307%, Sharpe 1.4929, net-of-cost 9598.11**.
- **Book == farm state exactly:** the 5 manifest sleeves == DB `portfolio_candidates`
  `Q12_REVIEW_READY` (10440:NDX, 10513:XAU, 10692:NDX, 10940:XAU, 11132:SP500), 0 duplicate ready rows.
- **Weights** (inverse-vol, sum 1.0): 11132:SP500 0.389, 10513:XAU 0.275, 10940:XAU 0.216,
  10692:NDX 0.069, 10440:NDX 0.051 — risk-parity correctly down-weights the volatile NDX sleeves.
- **Safety flags:** `status=DRAFT_FOR_OWNER_APPROVAL`, `manual_approval_required=true`,
  `deployment_action=NONE`, `autotrading_action=NONE`. ✔
- **All 5 `.ex5` present** (SHA256 captured for the factory→T_Live verify): 10440 `336b5910…`,
  10513 `ee92f1c6…`, 10692 `e28f8a1e…`, 10940 `363a2793…`, 11132 `7b48a34c…`.
- **Tests:** full portfolio group 34 OK (incl. `test_portfolio_manifest` 5).

### ❌ MUST-FIX before approval — manifest magic numbers wrong for 4/5 sleeves
`build_manifest` sets `magic_number = ea_id*10000 + slot` and `set_file_expectation.qm_magic_slot_offset = slot`,
where `slot = enumerate(book) position (0–4)`. But the live magic is
`QM_MagicResolver.mqh:55 → ea_id*10000 + symbol_slot`, and each (ea, symbol) has a **registered**
slot in `framework/registry/magic_numbers.csv`:

| sleeve | registry magic (slot) | manifest magic (slot) | match |
|---|---|---|---|
| 10440:NDX | 104400003 (3) | 104400000 (0) | ❌ |
| 10513:XAU | 105130003 (3) | 105130001 (1) | ❌ |
| 10692:NDX | 106920005 (5) | 106920002 (2) | ❌ |
| 10940:XAU | 109400003 (3) | 109400003 (3) | ✅ (coincidence) |
| 11132:SP500 | 111320000 (0) | 111320004 (4) | ❌ |

Impact: the manifest (the artifact OWNER signs) shows wrong magics, and its `set_file_expectation`
(qm_magic_slot_offset = book-position) **contradicts** the setfile gen_setfile.ps1 will actually
produce (qm_magic_slot_offset = registry symbol_slot) — so the deploy-flow "set-file correct"
verification would mismatch. The wrong manifest magics also overlap existing registry reservations
for OTHER symbols of the same EA (e.g. 106920002 is reserved for 10692 at symbol_slot 2, not NDX).
Live magic itself is safe (gen_setfile uses the registry), but the approval artifact must be correct.

**Fix (routed to Codex, ops task — see below):** `build_manifest` must resolve each sleeve's
`magic_number` and `qm_magic_slot_offset` from `magic_numbers.csv` (the active reservation for that
ea_id+symbol), not the enumerate position. Add a test: manifest per-sleeve magic == registry magic.
Then regenerate the canonical draft.

### ⚠️ Caveats to record for OWNER (not blockers)
1. **KPIs are at backtest fixed-lot scale**, not the live `RISK_PERCENT` (default 2% risk-parity)
   scale. MaxDD 13.83% / Sharpe 1.49 describe the historical book shape from the `q08_trades`
   streams; the **live-sized** DD must be confirmed in the deploy flow (it will differ from 13.83%).
2. **`--book-source` defaults to `selected` (greedy).** No automated path generates the T_Live draft
   (manual CLI only; periodic report does not build the manifest), and the canonical command uses
   `q12-ready-all` — but recommend flipping the default (or a guard) to remove the greedy footgun.
3. `--max-dd-pct` is recorded, not enforced, in `q12-ready-all` (book = all certified sleeves). Here
   the book DD 13.83% < the 20% target, so OK; flag that the flag is informational in this mode.

## Approval prep (staged — gated on the magic fix)
Once the magic defect is fixed and the draft regenerated, the OWNER-approval package is:
- This review + the regenerated manifest (sleeves/weights/KPIs unchanged; only magics corrected).
- Then the **manual T_Live deploy flow** (post-approval): generate live setfiles (ENV=live,
  RISK_PERCENT per weight, RISK_FIXED=0, qm_magic_slot_offset = registry slot), SHA256 match
  factory→T_Live, magic-registry recheck, news calendar present+current, then OWNER/Claude flip
  AutoTrading and record `decisions/2026-06-26_t_live_q12_5sleeve_book.md`.

**Recommendation: do NOT approve for deploy yet.** Book composition is correct and certified; fix the
magic-number derivation, regenerate, then this becomes approvable.
