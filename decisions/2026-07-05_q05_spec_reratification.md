# DL — Q05 spec re-ratification + cost-stress relocation to Q08 (2026-07-05)

**Status: RATIFIED — OWNER 2026-07-05 chat („Folge deinem Rat" on Claude's
explicit recommendation of option b).**

## Finding

Q05's documented gate criteria (vault spec 2026-05-23: slippage +2 pips, spread
×2, commission ×2) were **never implemented**. Evidence chain
(`docs/research/Q05_SALVAGE_TRACK_PROPOSAL_2026-07-05.md`, correction section):

- Generated `*_q05_stress_medium.set` differs from baseline only in comment
  headers + `qm_stress_reject_probability=0.0000`.
- No `ENV=` input exists; `QM_Common.mqh` contains no ENV/stress-cost handling.
- `q05_stress_medium.py::run_stress_backtest` passes no commission/spread/
  slippage arguments to `run_smoke.ps1`.
- The only implemented stress mechanism framework-wide is Q06's trade-rejection
  RNG (`QM_Entry.mqh`, `qm_stress_reject_probability`).

Actual Q05 behaviour since FW2: gross full-history run on Q03 plateau-median
parameters; verdict PF > 1.0 AND DD < 15% AND trades ≥ 20.

## Decision (option b)

1. **The Q05 spec is re-ratified to match the implementation.** Q05 is renamed
   conceptually to **"Gross Full-History Robustness"**: it tests parameter
   robustness (plateau-median, not tuned point) and full-window gross viability.
   This is a meaningful, correctly-functioning gate — it terminally removed 92
   gross-unprofitable (ea,symbol) pairs. **All historical Q05 verdicts remain
   valid** under the re-ratified spec; no re-runs required.
2. **Genuine cost stress relocates to Q08** as a designed sub-gate extension
   (design below, implementation pending explicit OWNER sign-off of the design —
   Q08 criteria are hard-bounded).
3. Vault page `03 Pipeline/Q05 Stress MEDIUM.md` rewritten accordingly
   (2026-07-05); runner docstring fixed (no behaviour change).
4. Ops ticket `ea21909d` resolved by this record.

## Q08 cost-stress sub-gate — RESOLVED AS ALREADY IMPLEMENTED (2026-07-05, post-GO)

OWNER signed off the design („Q08-Design GO", 2026-07-05 chat). Implementation
scoping then found the ratified criterion **already exists — and stricter —**
as the **DL-072 cost-cushion gate** (OWNER-ratified 2026-06-09), live in
`framework/scripts/q08_davey/aggregate.py`:

- `_apply_worst_case_commission` (lines ~442–477): applies the worst-case
  DXZ/FTMO per-instrument commission model to every Q08 trade;
  `cushion = gross_total / cost_total`.
- Thresholds (lines ~420–421): `cushion ≥ 2.0` → PASS (survives **2×**
  worst-case commission — dominates the sketched 1.5×); `1 ≤ cushion < 2` →
  **EDGE_SOFT** (exactly the sketched SOFT-feeds-Q09 semantics);
  `gross ≤ cost` → EDGE_HARD (with DL-077 zero-trade INVALID guard).
- Verdict wiring (lines ~599–617): tier flows into the Q08
  PASS/FAIL_SOFT/FAIL_HARD classification.

**Decision: no new code.** Building a second commission sub-gate would duplicate
DL-072 with a weaker threshold. The 2026-07-05 doc references describing cost
stress at Q08 as "planned" (vault Q05 page, q05 runner docstring) are corrected
to cite DL-072 as the existing mechanism. Lesson recorded: before designing gate
changes, grep the sub-gate implementations — the DL-072 cushion was indexed in
memory but its Q08 wiring was not re-checked when this DL was drafted.

## Why not option (a) — implement the documented stress at Q05

- Would invalidate/require re-running the entire Q05 history (138 FAILs + all
  PASSes) at major compute cost, while Q04 already applies real per-class
  commissions — the marginal information of a synthetic ×2 at Q05 is low.
- Spread ×2 has no clean implementation path (custom-symbol surgery per run);
  pretending otherwise is how the spec drifted from reality in the first place.

## Ratification chain

- Finding + options: Claude, 2026-07-05 evening (ticket `ea21909d`).
- Recommendation (b) incl. Q08 relocation: Claude, same evening, in chat.
- **OWNER: „Folge deinem Rat" — 2026-07-05.**
- **Q08 design sign-off: OWNER „Q08-Design GO" — 2026-07-05**; resolved same
  evening as already-implemented via DL-072 (see section above; no code shipped).
