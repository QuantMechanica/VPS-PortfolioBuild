# Pre-registration — headroom/smooth-de-risking governor lever test (task 16e8127e-dd8d-42ff-aa82-36aa2959a884)

Written 2026-10-02, **before** any arm result of this ticket exists. Simulation only: no governor/EA/set-file/roster
edit, no Demo/T_Live action, no D:/ write. Engine: the unchanged `tools/strategy_farm/ftmo/{book_sim,first_passage,
governor_base}.py` + `tools/strategy_farm/research/governor_ladder{,_w3}.py`, read from the canonical checkout
(`C:/QM/repo`, read-only) and executed from this worktree. All output of this ticket is written only under this
evidence directory in the `agents/claude-orchestration-2` worktree.

## 0. Why this ticket exists (prior-art audit, done before designing anything)

`docs/ftmo/P80_LEVER_SYNTHESIS_2026-09-26.md` varies only `BASE / GOV(V2 latch) / GOVDR(V3 day-reset) / GOVDRC(V3
close-trigger)` — binary floor-or-nothing governors on Phase 1 only — and never exercises `governor_base.py`'s own
`overlay_cppi` hook (a smooth, continuously-reversible risk-scale function of closed equity). That confirms the
ticket's premise for *that* document.

But a search of `docs/ops/evidence/` turns up two prior studies that must be read before re-deriving anything:

1. **`task_5c163d25` (governor ladder wave 2, 2026-09-23ish).** A 16-cell `warn × floor` neighbourhood of exactly this
   CPPI-style overlay (`s = clip((E+10000)/(10000-warn), floor, 1)`, all three stages), run against an **ungoverned**
   BASE (no real floor/ramp/liquidation at all). Verdict: REJECT (sign not stable across the neighbourhood; only the
   `warn >= 5,000` corner survives post-hoc, not adoptable — selected after seeing the grid). The wave-2 author's own
   closing recommendation: build a governor-faithful base (`BASE_GOV`, = today's `governor_base.py`) and re-run the
   *same* lever on top of it.
2. **`task_bdb175e9` (BASE_GOV + wave 3, 2026-09-24ish).** Built `governor_base.py` and `governor_ladder_w3.py`
   exactly to answer that — **wave 3 was sealed (`mechanical_spec_w3.json`) but explicitly never run** ("item 5...
   NOT run"; RESULT.md §5/§7: "commission wave 3 phase A... only if the question still matters; expected verdict
   REJECT"). Critically, **wave 3's sealed base (`W3_BASE_CFG`) uses `daily_event="latch"`** — the V2 contract — and
   the V3 day-reset chain was only ratified afterward (`decisions/2026-09-24_ftmo_governor_v3_daylock_and_funded_v3_
   constants.md`, superseded again by the 2026-09-26 lever synthesis's `GOVDR` decision base). **Nobody has run the
   smooth overlay against the current ratified V3 day-reset base.** That is the exact, real, still-open gap.
3. **`task_79409cc9` (P2/FUNDED governor-constant calibration).** A large, already-executed sweep, but of governor
   *constants* (floor/stop/target levels), not of per-stage *position size*. It independently confirms this ticket's
   phase-specific-risk premise ("the roster carries **one** risk vector for all stages — intended stage risk
   multipliers do not exist") and tests a risk-scale `k` only as an exploratory aside, alone on FUNDED, with the
   *deployed* (unfixed) stops, never paired with an increased Challenge-stage risk arm. The Challenge-hotter / later-
   stages-cooler combination this ticket asks for is not covered.

**Conclusion: this ticket reuses the already-vetted wave-3 cell design (not reinvented) with exactly one change — the
decision base's `daily_event` is `day_reset` (current V3), not `latch` (superseded V2) — plus a new, separate,
smaller phase-specific-risk-percent arm set that the constants study did not run.**

## 1. Book, engine, seeds (unchanged across every arm; common random numbers)

- Book: `governor_ladder.load_book()` — the frozen D2g6 incumbent, financed streams, 1,750-bd grid (2019-01-22 →
  2025-11-21), book risk 1.71875 %. Identical to the lever synthesis and both prior waves.
- Seeds: `[20260924, 20260925, 20260926, 20260927, 20260928]` (the standing paired-seed set of every wave to date).
- Paths: **40,000 per seed** (the payload's stated minimum; the published lever-synthesis used 20,000 — this run is
  at the higher, governor-ladder-wave fidelity, not the cheaper synthesis fidelity).
- Cost arms: normal (1.0×, 0) and stress (1.5× commission + 2 USD/lot) in the same build call.
- Decision base for every governed arm: `GovConfig(daily_event="day_reset", trigger_basis="low", stages=("phase1",))`
  — i.e. `GOVDR` from the lever synthesis, the ratified V3 chain for the stage the Demo governor is actually signed
  for. `BASE` (fully ungoverned) is carried alongside as the standing descriptive reference only.

## 2. H1 — smooth headroom-responsive de-risking vs. the hard floor/day-lock (the named lever)

**Mechanism (unchanged from `governor_base.overlay_cppi`, reused verbatim):** `scale(E) = clip((E + line)/(line -
warn), floor, 1.0)` on the stage's closed-equity P&L state `E` (0 at stage start). Full risk (`scale=1`) while
`E >= -warn`; linear ramp down to `floor` as `E` falls toward `-line`; **continuously reversible** — no latch, no
re-bootstrap, scale rises again the moment equity recovers. Applied via `governor_ladder_w3.measure_job`'s existing
`overlay_factory` plumbing: with `overlay_factory` given, Phase 1 keeps its real V3 floor/ramp **plus** the overlay on
top; Verification/Funded (outside `cfg.stages`, currently fully ungoverned in this simulation) get the overlay
**alone** (`NO_GOVERNOR` + overlay) in place of no control at all.

**Grid (identical to the sealed-but-unrun wave-3 cells, so the result is directly comparable to the wave-2/3
record):** `warn ∈ {5,000, 6,000, 7,000, 8,000} USD × floor ∈ {0.15, 0.25, 0.35, 0.50}` = 16 cells, `line = 10,000 USD`
fixed (the official 10 % total-loss boundary). Plus two references: `W3_BASE` (GOVDR, day-reset, no overlay — the
current decision base) and `UNGOVERNED_BASE` (BASE).

**Admission (payload rule, applied literally):** adopt a cell only if, in **both** cost arms and **every** seed,
`ΔP80 < 0` (t80 if both base and arm reach LCB 0.80, else point-P80) **and** `ΔLCB >= 0`, vs `W3_BASE`. Reported
alongside (context, not a substitute): the wave-3 sealed cell clauses (max-loss down every seed, mean ΔLCB ≥ 0 with a
per-seed floor of −0.002, censored ≤ +5pp, daily-loss not up, speed ≤ +5 t80 bd / +10 point-P80 bd) and the ≥12-of-16-
cells-plus-null-beating multiplicity rule, for comparability with wave 2/3's own bar.

**Pre-registered prior (stated before running, per the payload's falsification requirement):** the wave-3 author's
own expectation was REJECT on the *old* latch base, because the real V3 governor's 900 USD entry ramp already removes
most deep-drawdown mass on Phase 1. Swapping to day-reset only changes *how* the daily event resolves (Prague-day
lock vs durable latch), not the ramp — so the same REJECT is expected on Phase 1. The only stage where this lever can
plausibly help is Verification/Funded, which are currently completely ungoverned in this simulation (anything beats
nothing there) — if an effect appears, it is expected to come from there, not from Phase 1.

## 3. H2 — phase-specific risk (lower risk in Verification/Funded, test room for a hotter Challenge)

**Mechanism (new; not covered by `task_79409cc9`, which varied governor constants, not position size):** a constant
(equity-independent) scale multiplier on the stage's trades, applied through a local `stage_hooks` contextmanager
(same `phase_walk_gov` / `funded_walk_gov` / `NO_GOVERNOR` building blocks as `governor_base.py`, just dispatched
per-stage instead of with one shared overlay — Phase 1 keeps its real V3 floor whenever its own multiplier is used).

**Arms:**
- `H2_REF` = `W3_BASE` (identical config; reused, not re-run).
- `H2_DERISK_ONLY`: Phase 1 unchanged (×1.0, real V3 floor); Verification ×0.6; Funded ×0.8.
- `H2_HOT_CHALLENGE`: Phase 1 ×1.15 (on top of the real V3 floor — the floor still triggers on the scaled trades);
  Verification ×0.6; Funded ×0.8.

**Admission:** same payload rule as H1 (`ΔP80<0` and `ΔLCB>=0`, both cost arms, every seed) vs `H2_REF`.

**Pre-registered prior:** `H2_DERISK_ONLY` is expected to raise LCB slightly (less variance from two currently-
ungoverned stages) at worst a small P80 cost (less Verification/Funded drift). `H2_HOT_CHALLENGE` is the real test:
whether the LCB room bought by de-risking downstream covers the LCB cost of a hotter Challenge. Given Phase 1 is the
stage with a real governor already (900 USD ramp, 1,250 USD liquidation, `target_cap` taper), raising its size by
15% is expected to cost more max-loss-breach mass than the downstream de-risk recovers — pre-registered expectation:
REJECT, but run to get the actual numbers rather than assume.

## 4. What would falsify the "nothing works" prior

- Any H1 cell or H2 arm with `ΔP80<0` and `ΔLCB>=0` in every seed, both cost arms → lever has a real, admissible
  effect; report exactly which cell/arm and by how much, and flag for a proper wave-3-style multiplicity/null check
  before any adoption claim (this single pass does not run the null — see §5).
- A stress-arm P_EVER that crosses 0.80 under any arm where the reference does not → first time a lever lifts the
  stress arm into comparability; report explicitly even if the normal-arm rule fails.

## 5. Scope bound for this single pass

Phase A only (cells/arms × 5 seeds × 40k paths, both cost arms). The wave-3 null-draw phase (12 state-shuffle draws ×
16 cells × 5 seeds, ≈10 CPU-h) is **not** run in this pass; per the wave-3 sequential design this is correct because
the null is only informative once at least one cell clears the cell clauses — if phase A rejects everything (the
pre-registered expectation), the null would not change the verdict. If phase A shows a surviving cell, this is
reported as "admissible, null-check pending" rather than "adopted."

## 6. Reproduction

`python run_headroom_test.py run` then `python run_headroom_test.py analyze`, from this directory. Engine files read
(hashes recorded per run row): `book_sim.py`, `first_passage.py`, `governor_base.py`, `governor_ladder.py`,
`governor_ladder_w3.py` at `C:/QM/repo` HEAD `22866a204d` (2026-10-02, branch `agents/board-advisor`, read-only).
