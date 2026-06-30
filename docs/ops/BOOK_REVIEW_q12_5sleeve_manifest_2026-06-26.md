# Book Review — Q12-ready T_Live draft manifest (2026-06-26)

Reviewer: Claude. Subject: `D:\QM\strategy_farm\artifacts\portfolio\portfolio_manifest_tlive_DRAFT.json`
(Codex commit `c40505dcd` — q12-ready-all manifest mode). Scope: book review + OWNER-approval prep
for the FIRST V5 live portfolio. **No deploy / no AutoTrading action taken.**

## Verdict: book VERIFIED — draft is OWNER-approval-ready

> 2026-06-26 Codex follow-up: the magic-number artifact defect below has been fixed in
> `portfolio_manifest.py`; regenerated manifest sleeves now resolve `magic_number` and
> `qm_magic_slot_offset` from `framework/registry/magic_numbers.csv`.
>
> The current canonical artifact
> `D:\QM\strategy_farm\artifacts\portfolio\portfolio_manifest_tlive_DRAFT.json` is therefore
> internally consistent on magics and uses the canonical tester capital from
> `framework/registry/tester_defaults.json` (`initial_deposit=100000`). With the corrected capital
> base, the Q12-ready-all book satisfied the configured `--max-dd-pct 6.0` cap.
>
> 2026-06-26 later update: `12567:XNGUSD` was canonically redumped through 2025, reached
> 20 trades, passed Q09_PORTFOLIO, and was materialized as Q12-ready. The current draft is
> therefore **6 sleeves** with observed MaxDD **0.7680115443%**, MC-p95 DD
> **1.3741046694%**, Sharpe **2.05854719**, `cap_met=true`,
> `status=DRAFT_FOR_OWNER_APPROVAL`, `deployment_action=NONE`.
> The earlier 13.83% DD artifact used the stale $10k base and overstated drawdown by ~10x.

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
- **Reproducible:** re-ran the canonical command; current KPIs —
  6 sleeves, **observed MaxDD 0.7680%, MC-p95 DD 1.3741%, Sharpe 2.0585,
  net-of-cost 7478.15**.
- **Book == farm state exactly:** the 6 manifest sleeves == DB `portfolio_candidates`
  `Q12_REVIEW_READY` (10440:NDX, 10513:XAU, 10692:NDX, 10940:XAU, 11132:SP500,
  12567:XNG), 0 duplicate ready rows.
- **Weights** (inverse-vol, sum 1.0): 12567:XNG 0.483, 11132:SP500 0.201,
  10513:XAU 0.142, 10940:XAU 0.112, 10692:NDX 0.036, 10440:NDX 0.026 —
  risk-parity correctly down-weights the volatile NDX sleeves and gives the low-vol XNG
  sleeve a large portfolio weight.
- **Safety flags after Codex follow-up:** `status=DRAFT_FOR_OWNER_APPROVAL`,
  `manual_approval_required=true`, `deployment_action=NONE`, `autotrading_action=NONE`,
  `cap_met=true`. ✔
- **All 6 `.ex5` present** (SHA256 captured for the factory→T_Live verify): 10440 `336b5910…`,
  10513 `ee92f1c6…`, 10692 `e28f8a1e…`, 10940 `363a2793…`, 11132 `7b48a34c…`,
  12567 `e66579c0…`.
- **Tests:** portfolio group 49 OK (incl. manifest + periodic-report regression coverage).

### ✅ Fixed — manifest magic numbers now come from the registry
Before the Codex follow-up, `build_manifest` set `magic_number = ea_id*10000 + slot` and
`set_file_expectation.qm_magic_slot_offset = slot`, where `slot = enumerate(book) position (0–4)`.
But the live magic is
`QM_MagicResolver.mqh:55 → ea_id*10000 + symbol_slot`, and each (ea, symbol) has a **registered**
slot in `framework/registry/magic_numbers.csv`:

| sleeve | registry magic (slot) | manifest magic (slot) | match |
|---|---|---|---|
| 10440:NDX | 104400003 (3) | 104400000 (0) | ❌ |
| 10513:XAU | 105130003 (3) | 105130001 (1) | ❌ |
| 10692:NDX | 106920005 (5) | 106920002 (2) | ❌ |
| 10940:XAU | 109400003 (3) | 109400003 (3) | ✅ (coincidence) |
| 11132:SP500 | 111320000 (0) | 111320004 (4) | ❌ |

Historical impact: the manifest (the artifact OWNER signs) showed wrong magics, and its `set_file_expectation`
(qm_magic_slot_offset = book-position) **contradicts** the setfile gen_setfile.ps1 will actually
produce (qm_magic_slot_offset = registry symbol_slot) — so the deploy-flow "set-file correct"
verification would mismatch. The wrong manifest magics also overlap existing registry reservations
for OTHER symbols of the same EA (e.g. 106920002 is reserved for 10692 at symbol_slot 2, not NDX).
Live magic itself was safe (gen_setfile uses the registry), but the approval artifact had to be fixed.

**Fix implemented:** `build_manifest` resolves each sleeve's `magic_number` and
`qm_magic_slot_offset` from `magic_numbers.csv` (the active reservation for that ea_id+symbol), not
the enumerate position. Regression coverage was added in `test_portfolio_manifest.py`.

Current regenerated manifest values:

| sleeve | manifest magic (slot) | registry match |
|---|---:|---|
| 10440:NDX | 104400003 (3) | ✅ |
| 10513:XAU | 105130003 (3) | ✅ |
| 10692:NDX | 106920005 (5) | ✅ |
| 10940:XAU | 109400003 (3) | ✅ |
| 11132:SP500 | 111320000 (0) | ✅ |
| 12567:XNG | 125670002 (2) | ✅ |

### ⚠️ Caveats to record for OWNER (not blockers)
1. **KPIs are at backtest fixed-lot scale**, not the live `RISK_PERCENT` (default 2% risk-parity)
   scale. Observed MaxDD 0.7680% / MC-p95 DD 1.3741% / Sharpe 2.0585 describe the historical
   book shape from the `q08_trades` streams on the canonical $100k tester capital; the
   **live-sized** DD must be confirmed in the deploy flow.
2. **`--book-source` defaults to `selected` (greedy).** No automated path generates the T_Live draft
   (manual CLI only; periodic report does not build the manifest), and the canonical command uses
   `q12-ready-all` — but recommend flipping the default (or a guard) to remove the greedy footgun.
3. `--max-dd-pct` is now enforced at manifest-status level in `q12-ready-all`: the all-certified
   book is written for evidence, and a DD-cap breach would prevent an owner-ready status.

## Approval prep
The magic-number blocker is closed and the corrected-capital manifest passes the 6% DD cap. The
current 6-sleeve Q12-ready-all book is suitable for OWNER review as the first V5 live portfolio
draft.

**Recommendation: approve only after manual OWNER review of the manifest and the standard T_Live
deploy-verification packet.** No deploy action and no AutoTrading action have been taken.
