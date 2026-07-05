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

## Q08 cost-stress sub-gate — design sketch (NOT yet implemented)

- Mechanism: reuse the **proven** Q04 commission machinery
  (`run_smoke.ps1 -CommissionPerLot` → `Set-TesterGroupsCommission`, empirically
  verified against tester reports) with the registry commission × **1.5** for one
  additional Q08 baseline run per (ea,symbol).
- New sub-gate 8.x "cost_stress": net PF under 1.5× commission ≥ 1.0. Spread/
  slippage multipliers stay OUT (not implementable via the groups file; slippage
  realism is covered by Model-4 real ticks).
- Failure semantics: SOFT (feeds Q09 context like 8.4/8.6/8.10 per DL-075), not
  hard-kill — the portfolio admission weighs it.
- Cost: +1 full-history run per Q08 item (~30–60 min) — acceptable; Q08 volume
  is low (~10% of Q04 passers).
- Implementation owner: Claude (Sonnet lane per rule 24), review: Codex.
  Prerequisite: OWNER signs off this design (one line suffices).

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
- Q08 design sign-off: _pending OWNER_ (implementation blocked until then).
