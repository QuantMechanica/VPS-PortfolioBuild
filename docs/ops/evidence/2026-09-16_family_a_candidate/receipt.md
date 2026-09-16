# Evidence Receipt — TAIL_RISK Family A first candidate (H-PY) 2026-09-16

**STATUS: REVIEW_PENDING**
**Date (UTC):** 2026-09-16T05:55Z
**Author:** Kimi (interim Quant Research + Strategy Engineering lead, OWNER_DIRECT_SESSION_DELEGATION 2026-09-15)
**Programme:** TAIL_RISK (`docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` §4 Family A — bounded positive pyramiding; bounds `tools/strategy_farm/config/tail_risk_families.v1.json`)
**Mode:** RESEARCH SLICE. New files only, zero commits (central commit pass owns the main worktree), zero DB writes, zero registry writes, zero EA code. Append-only research-source ledger rows were written solely by the canonical tool (`tools/strategy_farm/research_source.py` / `research/preregister.py`), mirroring the 2026-09-15/16 H-CW/H-MR slices.

---

## 1. What now exists (all new files)

| Artifact | Path | Note |
|---|---|---|
| Research source (store) | `strategy-seeds/sources/QM-RESEARCH-2026-0007/` | minted via `research_source.py mint` (next free id confirmed = 0007; ledger + on-disk union) |
| source.md | `.../0007/source.md` | review-as-discovery; sealed `status=preregistered` |
| research.json | `.../0007/research.json` | schema qm.internal-research-source/v1 |
| lineage.json | `.../0007/lineage.json` | mechanization block + preregistration version appended by preregister.py |
| critic_receipt.json | `.../0007/critic_receipt.json` | EXPLICIT PENDING scaffold (non-passing by design until the cross-vendor critic seat runs; claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead) |
| preregistration.json | `.../0007/preregistration.json` | schema qm.research-preregistration/v1, version 1 |
| Mechanized card | `.../0007/H_PY_card.md` | the frozen mechanical spec |
| Pilot computed output | `.../0007/h_py_pilot.json` (+ `h_py_pilot.py`) | deterministic fire count, Dukascopy USATECHIDXUSD 2018-2020 in-sample |
| Mechanization result | `.../0007/mechanization_result.json` | MECHANIZE gate PASS |
| Machine risk contract | `.../0007/risk_contract.json` | byte-identical to the card's fenced contract; validated vs the machine gate |
| Rendered card copy | `artifacts/cards_approved/QM5_41479_tail-pyramid-index-session-h1.md` | ea_id QM5_41479 RESERVED BY FILENAME CONVENTION ONLY — no registry row allocated (central allocator runs later, as with 41475-77) |

## 2. Identity and hashes

- research id: **QM-RESEARCH-2026-0007** (`QM-RESEARCH://2026-0007`); ledger rows: mint 2026-09-16T05:41:56Z (draft) → preregistered (preregister.py) → preregistered (seal, 2026-09-16T05:52:44Z).
- source_hash (sha256 of sealed source.md): **4e1299ecdcef4ca35803dd0b4bf4262c18b1ee9fcb15fe374fc83ac17311bf64**
- preregistration record_sha256: **f601ba6a43beeadb14104114a07988fe2d4445b4e9e1731cfebf7f6b8866cfcb**
- mechanical_spec_sha256 (H_PY_card.md, frozen): **526504f117d5b2f61dbc52dd560c724c92a5b14a64cc90dbfca7a1b372211e2a**
- computed outputs (manifest-anchored): mechanization_result.json `816cf398…2659a` (MECHANIZE PASS, 25 bounded params, zero findings, codex_implementable=true); h_py_pilot.json `12b3eec3…5639d`.
- risk_contract.json `4c0715c1…562c`; `strategy_risk_contract.validate_contract=[]`, `is_unbounded=False`, flags `[positive_pyramiding]`, tail-amplifying flags `[]`.
- Freeze guard: `preregister.py --check preregistration.json H_PY_card.md` → **unchanged: true**.

## 3. Mechanization gate (deterministic, no LLM)

`python tools/strategy_farm/research/mechanization_check.py H_PY_card.md --research-json research.json`:
**verdict PASS, findings [], bounded_parameter_count 25, codex_implementable true, numeric_provenance backed.** One earlier parse finding (MECH_PARAM_UNBOUNDED on a prose note inside the Parameter ranges section) was fixed by moving the note to Position sizing; the gate was re-run clean.

## 4. Source verify (fail-closed)

`research_source.py verify --id QM-RESEARCH-2026-0007` (and `--card` on the rendered copy): every integrity check passes (binding, manifest, numeric provenance, ledger status, trial count) except the eight `MISSING_FIELD:critic.*` paths — the explicit PENDING scaffold, identical in kind to QM-RESEARCH-2026-0006's REVIEW_PENDING state. The card is not intake-admissible until the critic seat runs; that is by design.

## 5. Intake prescreen (DRY_RUN advisory, not a verdict)

`card_intake_prescreen.py --card QM5_41479_tail-pyramid-index-session-h1.md`: REJECT with (a) `NEAR_DUPLICATE:QM5_10140_tv-london-session-break.md:score=1.0000` — a false positive of the coarse mechanism-phrase heuristic (any two session-breakout cards share ≥3 generic mechanism phrases; substantive identity is the Family A bounded pyramid + H-CW envelope, documented in the card) — and (b) `INTERNAL_SOURCE_UNRESOLVED:MISSING_FIELD:critic.*` (the expected PENDING state above). No ML, feed, symbol-matrix, or contract findings.

## 6. Candidate design summary (mechanism-first)

- Base: H-CW cash-session opening-range breakout + EMA(20) filter, NDX/GDAXI/SP500 H1, entries 13-17 UTC, one basket/symbol/day, flat 20 UTC, Friday cutoff 17 UTC.
- Pyramid (Family A contract): L2 at +1.0×ATR open profit AND a new favourable extreme; L3 at +2.0×ATR AND a second new extreme; sizes 1.0/0.75/0.5 (aggregate 2.25 legs, ≤5% margin, 3-level cap fail-closed).
- Stops: L1 reference stop 1.0×ATR; after L2 the basket stop ratchets to blended breakeven+costs then trails 1.0×ATR behind the most favourable close — never widens (max-over-history ratchet). Exit ALL: flatten 20 UTC → basket stop (intrabar) → 0.5% equity adverse bound → 50%-of-peak giveback stop → 6-bar time stop.
- Breakers/filters: daily −1.0% / weekly −2.0%; shock floor default 3.0×ATR (pilot-measured 13:00 bar median ~2.8×ATR); spread 1.5×20-day median; fail-closed FOMC/NFP/CPI blackout (entries and adds).
- Risk contract: positive pyramiding is NOT tail-amplifying (Eligibility V2 §9); the full Family A contract is carried anyway (uniformity + joint-tail engine), embedded in the card and in risk_contract.json.

## 7. Pilot (motivation only — NOT proof)

h_py_pilot.json (exact preregistered rules, NDX-class proxy feed, 2018-2020 in-sample, zero costs on mid fills): 489 evaluated session days (154 shock-skipped at 3.0×), 187 gross signals, 185 baskets, 6.4 baskets/month, ~6.4 active days/month; exits 73 base stops / 37 giveback / 75 flatten; L2 reach 11.9%, **L3 reach 0%**; raw PF(R) 1.26 at +0.12R/basket; avg peak open +0.77R, max +19.1R; giveback-before-L2 15.1%. Deliberately labelled PILOT_MOTIVATION_NOT_PROOF: in-sample, single feed, zero costs; at/above-bar in-sample raises overfitting risk rather than evidence. Known gaps: L3 untested anywhere; GDAXI/SP500 untested; shock floor calibrated in-sample (holdout must re-derive blind).

## 8. Kill criteria (preregistered, ≥3 explicit — six carried)

1. Sealed OOS + Q06 HARSH: expectancy < +0.10R/basket or PF < 1.20.
2. Worst-day p95 > 2.5% equity at 0.25% base risk, or MC P(4% daily budget within 60d) > 2%.
3. > 50% of pyramids giveback-stopped before level 2.
4. Giveback stop realizes more often than profit-taking exits without regime explanation.
5. Joint-tail protocol FAIL vs H-CW/H-MR/passive-book streams (hidden common mode) — before any book claim.
6. H-CW-class gates: swap > 10% gross P&L; > half ±1-step neighbourhood negative; any month < 8 active days.

## 9. What the EA-build lane needs (next, after critic — mirrors H-CW flow)

- Independent non-Kimi critic first (claude from 2026-09-17 / codex from 2026-09-19 / agy when quota returns) → fill critic_receipt.json, re-seal, then registry allocation by the central allocator (41479 is reserved by filename only).
- EA scope: H-CW shell (QM5_41475 integration pattern) + basket manager: L2/L3 trigger state machine (ATR fixed at base signal), never-widening stop ratchet, peak-open-profit tracker, giveback + adverse-bound exits, per-symbol one-basket/day guard, add suspension inside news blackout and after Friday cutoff, basket-depth telemetry column (programme §8 evidence-gap mitigation for the joint-tail engine).
- Validation: farm .DWX sealed runs, Q06 HARSH-class costs (pilot had none), Family A stress set s01/s04/s05/s06/s08, then joint-tail protocol vs H-CW (QM5_41475) / H-MR (QM-RESEARCH-2026-0006) streams before any FTMO/book claim.
- Preregistered parameter space: 25 bounded parameters (see preregistration.json); optimisation freeze (Q13) applies — no in-sample refit.
