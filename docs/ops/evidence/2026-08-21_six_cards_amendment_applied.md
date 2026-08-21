# Evidence: Six Strategy Cards — Amendment / Retirement APPLIED (2026-08-21)

- **Authority**: Claude (orchestrator), after the `471cffc3` re-specification pass.
- **Adjudication source (do not re-derive)**: `docs/ops/evidence/471cffc3_strategy_cards_respecification_or_retirement_2026-08-21.md` (committed `d483496e5`).
- **Scope**: CARD TEXT ONLY. No `.mq5` / `.mqh` / `.ex5` created, modified, or compiled. No factory / backtest / terminal run. No `ea_id_registry.csv` or `magic_numbers.csv` edit.
- **Resolution**: 4 cards RE-SPECIFIED, 2 cards RETIRED (per the 471cffc3 adjudication).

---

## 1. Sanctioned edit / validation / retirement path

Cards exist in two places:

- **Runtime (operative — factory reads this):** `D:/QM/strategy_farm/artifacts/cards_approved/` — schema-v2 Markdown cards with YAML frontmatter.
- **Git-tracked mirror (research drafts, auto-committed by the pump):** `strategy-seeds/cards/approved/<id>.md` and the flat copy `strategy-seeds/cards/<id>.md`. Both were byte-identical to the pre-edit runtime cards.

There is **no CLI "edit-approved-card" command**; approved cards are amended by editing the Markdown directly (the in-tree helper is `farmctl.update_card_frontmatter`). Correctness is enforced by the build-readiness **validators in `tools/strategy_farm/farmctl.py`** (there is no standalone JSON validator for these v2 cards — `strategy_card_v3.py` is a *different*, unused JSON format):

- `prebuild_validate_card(root, card_path, fm)` — the hard gate the pump/`render_codex_build_prompt` runs before any build.
- `strategy_card_r_gate_consistency(card_path, fm)` — body R1–R4 table vs frontmatter (fail-closed R2/R4).
- `strategy_card_schema_issues(card_path, fm)` — required frontmatter + body patterns.
- `_verify_card_body_coverage(card_path)` — entry / exit / stop / target / period / frequency presence.

**Retirement** is done with the sanctioned CLI `python tools/strategy_farm/farmctl.py reject-card --card <path> --reason <...>`. On an already-approved card it sets `g0_status: REJECTED` + `g0_rejection_reason` + `last_updated`, and emits a `card … rejected` event in `farm_state.sqlite`. (It moves the file only for `cards_draft` cards; for an approved card it stays in place — a REJECTED card then fails `prebuild_validate_card` with `g0_status_not_approved`, i.e. it is excluded from the build queue, which is the retirement effect.) `retire_approved_cards.py` was **not** usable: its cohort is hard-coded to the 2026-07-20 P2 item-11 EA IDs and does not accept `QM5_38007` / `QM5_41010`.

### Validator trap encountered (as flagged in the task)
Two independent instances of "the validator fails for reasons unrelated to the edit":
1. A stale `inspect.py` left in the scratchpad shadowed stdlib `inspect` (broke `import farmctl` with `AttributeError: module 'inspect' has no attribute 'signature'`) — resolved by running the harness from a clean subdirectory so `sys.path[0]` is clean.
2. `prebuild_validate_card` also runs global/environment checks (`_magic_registry_duplicate_errors`, `custom_history_archive_admission`) that can fail independently of card text — e.g. `QM5_38007` post-retirement additionally reports `custom_history_manifest_admission_invalid`. These are not card-content defects; the four amended cards carry **no** such trap errors.

---

## 2. Four RE-SPECIFIED cards — before → after (each traced to the 471cffc3 doc)

### QM5_34006 — Golubev PriceChannel / Parabolic SAR Breakout
- **Section 2 (channel window)** — the defect made `Close[1] > PC_High[1]` unsatisfiable on every bar (window included the signal bar).
  - BEFORE: `$$\text{PC\_High} = \max_{i=1..24}(\text{High}[i]), \quad \text{PC\_Low} = \min_{i=1..24}(\text{Low}[i])$$`
  - AFTER: `$$\text{PC\_High}[1] = \max_{i=2..25}(\text{High}[i]), \quad \text{PC\_Low}[1] = \min_{i=2..25}(\text{Low}[i])$$` + note "*(… 24 completed bars immediately preceding the signal bar [1])*".
- **Section 3.4 (SL/TP)**
  - BEFORE: `TP = 2.0 × SL_Distance (1:2.0 R:R)` / `SL: Placed at the current Parabolic SAR dot.`
  - AFTER: `SL: Placed strictly at Parabolic_SAR[1]. No ATR corridor clamping is permitted. If SL_Distance < BrokerStopLevel, the order fails closed …` / `TP: EntryPrice ± (2.0 × SL_Distance) (exact 1:2.0 R:R).`
  - Sections 3.2/3.3 already referenced `PC_High[1]`/`PC_Low[1]`; correcting the Section 2 window makes them satisfiable (no text change needed there — matches the corrected doc verbatim).

### QM5_35002 — HLHB Trend-Catcher (Huck)
- **Section 2 (directional filter)**
  - BEFORE: `ADX_Filter: ADX(14,H1)[1] ≥ 25.0 AND +DI[1] > -DI[1]` (asymmetric).
  - AFTER: two symmetric filters — `Long_Directional_Filter: … +DI(14)[1] > -DI(14)[1]` and `Short_Directional_Filter: … -DI(14)[1] > +DI(14)[1]`.
- **Section 3.2 / 3.3 (entries)**: appended `AND +DI(14)[1] > -DI(14)[1]` (Long) and `AND -DI(14)[1] > +DI(14)[1]` (Short).
- **Section 3.4 (SL/TP)**
  - BEFORE: `SL: Hard -50.0 pips (or recent H1 swing extreme).`
  - AFTER: `SL: Hard fixed 50.0 pips (500 points). The swing-extreme alternative is removed.` + `TP = 2.0 × SL = 100.0 pips` + explicit trailing-stop rule.

### QM5_35006 — Guppy GMMA Breakout
- **Section 2**: replaced `Trader_Max / Investor_Min` with mechanical `Trader_Spread[t]`, `Trader_Aligned_Long/Short[t]` (full 6-EMA ordinal alignment) and `Trader_Expanded[t] ⇔ Trader_Spread[t] > Trader_Spread[t-1]`.
- **Section 3.2 / 3.3**
  - BEFORE: `… AND Trader Ribbon Expanded AND …` (undefined term).
  - AFTER: `EMA(15)[1] > EMA(30)[1] AND Trader_Aligned_Long[1] AND Trader_Expanded[1] AND Close[1] > Open[1]` (and the short symmetric form).
- **Section 3.4**: `SL: strictly at EMA(60)[1]`; `TP: EntryPrice ± (2.5 × SL_Distance)`; symmetric short trailing exit added.

### QM5_35007 — Inside Bar Momentum Breakout (Robopip)
- **Sections 3.2 & 3.3 (order generation)** — reconciled the 1:2.0-label vs 1:10-formula contradiction and specified the OCO legs.
  - BEFORE: `Inside_Bar == TRUE ⟹ Place BUY_STOP at High[2] + 2.0 pips` / `… SELL_STOP at Low[2] - 2.0 pips`; and Section 3.4 `TP = 2.0 × Mother_Range (1:2.0 R:R)` / `SL = 0.20 × Mother_Range`.
  - AFTER: `Mother_Range = High[2]-Low[2]`; `SL_Distance = 0.20 × Mother_Range`; `TP_Distance = 2.0 × SL_Distance = 0.40 × Mother_Range (exact 1:2.0 R:R)`; explicit Long/Short pending legs with SL/TP.
- **Section 3.4 (lifecycle)**: `OCO Linked Lifecycle` (fill of one leg cancels the other), `Pending Expiry` (3 completed H4 bars / 12h), strict 1:2.0 R:R metrics.
- Section 1.1 `R:R 1:2.0` label was **left unchanged** — the corrected spec keeps 1:2.0, so the label became correct once the TP formula was fixed.

Each amended card also gained frontmatter provenance (`card_amendment`, `card_amendment_evidence`, `last_updated: 2026-08-21`) and an `## Amendment Provenance (2026-08-21)` body section naming date, authority, defect, corrected sections and the 471cffc3 evidence path.

---

## 3. Two RETIRED cards

Mechanism: `farmctl.py reject-card` (output `"rejected": true` for both) → `g0_status: REJECTED` + `g0_rejection_reason` + `farm_state.sqlite` event. An unmistakable `## RETIRED (2026-08-21) — DO NOT BUILD` body section (reason + evidence path) was added to each card first.

- **QM5_41010** (Developing d-POC Migration Scalper) — source (Steidlmayer 1986) defines no discrete OHLCV volume-profile algorithm, bucket resolution, or intra-bar volume assignment; mechanization would require invented heuristics (violates R2/R3).
- **QM5_38007** (CodeTrading Python ATR-Spaced Grid Engine) — source never determines the Level-0 trigger/direction; the 1-position cap (3.1) is irreconcilable with the 5-tier grid (3.2–3.4); grid/averaging-down is prohibited under the Edge Lab Charter.

Post-retirement both correctly fail the build gate: `prebuild_validate.ok = False`, error `g0_status_not_approved:'REJECTED'`.

**EA-registry rows (reported, NOT changed — per instruction and hard constraint):** both are still `status = active` in `framework/registry/ea_id_registry.csv`:
```
38007,codetrading-python-atr-grid-engine,MASTER-CENTURY-SUITE-2026-08-15,active,Claude,2026-08-15
41010,developing-poc-migration-scalper,MASTER-CENTURY-SUITE-2026-08-15,active,Claude,2026-08-15
```
A complete retirement would flip these two rows to a retired/rejected status. That row edit is out of scope here (constraint: do not edit `ea_id_registry.csv`; the file is also concurrently modified by the pump) and is left for OWNER/Codex.

---

## 4. Validator output (sanctioned farmctl validators)

Baseline (before edits) and post-edit are identical for the four amended cards — clean, only the benign `r_gate_body_rows_missing` warning (Section 7 uses bullet rows, not a `|`-table, so no R-gate body/frontmatter conflict is possible):

```
QM5_34006 : r_gate.ok=True []  schema_issues=[]  body_coverage.ok=True []  prebuild.ok=True  errors=[]  warnings=['r_gate_body_rows_missing']
QM5_35002 : r_gate.ok=True []  schema_issues=[]  body_coverage.ok=True []  prebuild.ok=True  errors=[]  warnings=['r_gate_body_rows_missing']
QM5_35006 : r_gate.ok=True []  schema_issues=[]  body_coverage.ok=True []  prebuild.ok=True  errors=[]  warnings=['r_gate_body_rows_missing']
QM5_35007 : r_gate.ok=True []  schema_issues=[]  body_coverage.ok=True []  prebuild.ok=True  errors=[]  warnings=['r_gate_body_rows_missing']
```

Retired cards (build-gate exclusion confirmed):
```
QM5_41010 : g0_status=REJECTED  prebuild.ok=False  errors=["g0_status_not_approved:'REJECTED'"]
QM5_38007 : g0_status=REJECTED  prebuild.ok=False  errors=["g0_status_not_approved:'REJECTED'", 'custom_history_manifest_admission_invalid:…']  (2nd error = env/archive, unrelated to card text)
```

**Undefined-term sweep**: `grep` for `Trader Ribbon Expanded`, `Trader_Max`, `Investor_Min`, `i=1..24`, `swing extreme`, `2.0 × Mother_Range` across the four amended cards returns matches **only** inside the amendment/provenance notes (documenting the old defect) — none in any active formula. `QM5_34006`'s corrected long condition `Close[1] > PC_High[1]` with `PC_High[1] = max(High[2..25])` (signal bar excluded) is satisfiable.

---

## 5. Left untouched / ambiguous
- Nothing in the four corrected specs was ambiguous; all four were applied verbatim from the 471cffc3 doc. The only judgement call: `QM5_35007`'s corrected block is titled "Section 3.2 & 3.3" as one unit — the shared `Mother_Range/SL_Distance/TP_Distance` defs were placed in 3.2 (Long leg) and the Short leg in 3.3 references them (a definitional pointer, not a new rule). No rule beyond the doc was added.

## 6. Still to do (not in scope of this task)
- **Rebuild the four re-specified EAs** from the corrected cards — explicitly deferred until the separate build-gate hardening task lands. Rebuild was NOT done here.
- **Registry rows** for `QM5_38007` / `QM5_41010` still read `active` — OWNER/Codex to retire those rows.
- **Runtime vs git-mirror**: edits were applied to the operative runtime cards on `D:` (via the sanctioned farmctl path) AND synced byte-for-byte into the git-tracked mirrors `strategy-seeds/cards/approved/` and `strategy-seeds/cards/` so the fix is durable and committed. If a repo→D: re-import is ever run, it will now carry the corrected cards.
