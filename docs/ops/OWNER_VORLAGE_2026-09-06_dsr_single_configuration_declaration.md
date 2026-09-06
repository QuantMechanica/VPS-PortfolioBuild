# OWNER Vorlage — DSR V2: search-history authority for single-configuration EAs (the "25th pair" blocker)

- **Date:** 2026-09-06 · **Author:** Claude (Orchestrator) · **Origin:** Codex task `f4505fb9-ab9f-4827-aa0b-9af8e209012b` (APPROVED, integrated as `7a89b5b701`), CEO finding 07:13Z
- **Class:** ROT — this decides what counts as an EA's *complete search history* under the OWNER-ratified DSR V2 contract (`OWNER-DEC-DSR-V2-ACTIVATION-20260905`). It touches the candidate-pool/card universe and the evidence a gate relies on. No Auffangregel. Nothing below changes a threshold, a stored verdict, or the counter by itself.
- **Standing release 2026-09-05 03:55Z** does not cover it (gate evidence rules stay ROT).

## 1 · The question

Since DSR V2 went live (sub-gate 8.2, `dsr_v2.evaluate`, cohort producer `348a7eccb8`), **every Q08 for an EA without a sealed, loser-inclusive search ledger ends `INVALID`** (`DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT`, producer status `SEALED_SEARCH_LEDGER_UNAVAILABLE`). Three real cases in 24 h:

| EA / symbol | Q08 row | Governed result now | Card text on search | Factory search ledger before Q08 | Hypothetical n=1 statistic (unsealed replay) |
|---|---|---|---|---|---|
| QM5_11167 XAUUSD | `d7ab61ae` 06:32Z | INVALID | "Optional P3 sweep: fast SMA 8-12, slow SMA 24-30" (5×7 = 35 combos, *optional*) | **none** (phases Q02–Q08 only, zero OPT rows) | p = 0.0007 → would PASS |
| QM5_11196 XAUUSD | 09-05 | INVALID | "Parameters To Test" 5 params × 3 values (243 combos); defaults = "fixed hyperopt constants" of the upstream source | **none** | p = 0.0041 → would PASS |
| QM5_11015 EURUSD | `60f98a58` + successor `34d0e1ba` pending | INVALID (successor will be too) | "P3 sweep candidates" 2×3×3 = 18 combos | **none** | p = 0.0625 → would FAIL; current repaired set differs from the replayed build |

Sources: `docs/ops/evidence/2026-09-06_dsr_trivial_cohort.md` (Codex replay, 42 tests), `D:/QM/strategy_farm/artifacts/cards_approved/QM5_{11167,11196,11015}_*.md`, `farm_state.sqlite` `work_items` (read-only: for all three EAs the only phases ever recorded are Q02–Q08; no `OPT_*`/census rows).

**Consequence for the counter:** the counter (11/25) can still climb to **24** from the 13 census programmes already enrolled, but the **25th pair is unreachable** — every new Q11 survivor must pass Q08, and no single-configuration EA can. This is structural, not a backlog problem.

**What Codex built (integrated, fail-closed, inert until a card declares it):** an explicit `qm-dsr-single-configuration` declaration block in the *approved* card (schema `tools/strategy_farm/schemas/dsr_single_configuration_declaration_v1.schema.json`) that seals a cohort with `declared_trial_count = 1`, `research_trial_count = 0`, an empty loser list, bound to card SHA + SPEC SHA + source/binary/set SHA. The evaluator then returns PASS/FAIL at the **unchanged** p < 0.05. It refuses whenever the card is silent, declares any additional research, or the locked parameters differ from the built set. **It does not decide whether the cards' sweep lists are "research that happened" — that is the OWNER question.**

## 2 · What the evidence says about the sweep lists

1. **"P3 sweep" is the legacy name of the optimisation branch** (today Q12–Q16 / DL-089 census). In every card of this generation the sweep list is a *proposal for the branch*, written at card time — before any backtest. It is not a record of trials.
2. **The factory never ran them.** For 11167, 11196 and 11015 there is no optimisation row of any kind before their Q08 rows. The incumbent configuration is the card default, fixed before the first Q02. Nothing was selected from a set of alternatives inside the factory.
3. **DSR corrects for selection.** The deflated Sharpe ratio asks "given N trials, how good is the best one?". If the tested configuration was fixed before any trial, N = 1 is the *honest* count — not a loophole. Running the sweeps *now* would not make the incumbent's statistic more honest; it would create post-hoc selection where none existed.
4. **Two multiplicities remain outside this question and must not be hidden:**
   - **Symbol multiplicity.** 11167 has 24 Q02 rows, 11196 31, 11015 34 — these are symbol fan-outs and reruns, not parameter trials. DSR V2's unit is `candidate_configuration`; symbol selection is governed by the per-(EA, symbol) chain and the book rules (Q10/Q11), as ratified. This Vorlage does not change that; it names it.
   - **Upstream search.** 11196's defaults are hyperopt constants from the source repository (unknown upstream trial count). No declaration in our card can make that upstream search "complete". Under the V2 contract as ratified, the unit is *our* search; the upstream provenance stays what it always was — a source-quality question (R1), not a DSR ledger.

## 3 · Options

### Option A — "Sweep lists are proposals, not trials" **(recommended)**
Rule: *a card's sweep/parameters-to-test list counts as **zero research trials** when (i) the factory ledger shows no optimisation row for that EA before its Q08 claim and (ii) the built set equals the card's locked defaults.* The declaration block is then added to the approved card as an **append-only amendment** (card SHA changes → cohort rebinds; old card version stays in git), and the Q08 is re-run append-only.
- **Counter effect:** restores the Q02→Q11 path for every single-configuration EA. Concretely: 11167/XAUUSD and 11196/XAUUSD get real PASS/FAIL Q08 runs (replay suggests PASS, but only a sealed run counts); 11015 likely FAILs — that is the gate working.
- **Cost:** Codex ticket (~1 cycle): card amendments for 11167/11196, a **machine check** that verifies condition (i) from `work_items` at seal time (so the attestation is backed by evidence, not by memory), a card-linter rule that new cards label sweep lists as "Q14 proposals". Then two append-only Q08 reruns (minutes of factory time).
- **Reversibility:** high — remove the block, the cohort refuses again; verdict trail append-only.
- **Refutation criterion:** if a later audit finds any optimisation row for such an EA before its Q08 claim, the declaration is false → the Q08 row is superseded append-only and the rule gets condition (i) enforced retroactively.

### Option B — "Sweep lists are research that must be ledgered"
Every listed combination counts as a trial → a complete loser-inclusive ledger is required → it does not exist and cannot be produced honestly for past cards → all three stay INVALID, **and so does every future single-configuration EA**. The only way out would be to move the Q14 census *before* Q08 (order inversion = contract change, its own ROT card) — which still would not help EAs whose card lists no sweep.
- **Counter effect:** hard cap at 24 for the foreseeable future.
- **Cost:** zero now; the 25-pair book ceremony has no date.

### Option C — Run the declared sweeps now as sealed searches, then DSR with true N
35 + 243 + 18 ≈ 300 cells (~3 factory-hours at ~100/h) competing with the 9,650-cell census (delays the 13 enrolled programmes by ~3 h).
- **Why not:** statistically wrong for the incumbent (it was not selected from those trials) and it manufactures a search after the results are known. It also does not scale: every future single-config EA would need a pre-Q08 sweep.

## 4 · Recommendation

**Option A** with both conditions machine-checked. It is the reading under which DSR V2 measures what it was ratified to measure — selection inside our factory — and it is the only option that keeps the 25-pair goal reachable without touching a threshold.

**Cost of waiting:** every day without a decision the Q02–Q10 funnel contributes **0** to the counter; the census path alone tops out at 24 in ~3–4 factory days, after which the factory would be producing evidence for a book that cannot be built.

## 5 · What happens on JA (exactly one Claude task)

1. Codex ticket (Sol, high): declaration amendments for 11167 and 11196 (append-only card amendment via the approve-card path, SPEC SHA rebind), producer condition (i) machine check, card-linter rule; tests; evidence file.
2. After integration: `farmctl enqueue-backtest --phase Q08 --append-only-rerun-of <INVALID row>` for 11167/XAUUSD and 11196/XAUUSD; 11015 only after its set-lock question is resolved (separate line in OPEN_ITEMS).
3. OPEN_ITEMS + Vault mirror (`03 Pipeline/Q08` addendum: "sweep list = Q14 proposal").

## 6 · What happens on NEIN
Option B is recorded; the counter target is re-stated as 24 (structural) in Mission Control and the Vault; no code change.
