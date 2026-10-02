# RESULT — headroom/smooth-de-risking governor lever test (task 16e8127e-dd8d-42ff-aa82-36aa2959a884)

**Verdict: REJECT (both H1 and H2). The one previously-untested P80 lever (smooth, headroom-responsive de-risking)
does not clear the pre-registered admission bar.** Simulation only; no governor/EA/set-file/roster edit, no Demo/
T_Live action. Engine unchanged (`book_sim`/`first_passage`/`governor_base`/`governor_ladder{,_w3}`, read-only from
canonical `C:/QM/repo`). 100/100 arm-seeds completed (16 H1 cells + 2 reference arms + 2 H2 arms, x5 seeds, both
cost arms). Full numbers: `results.json` (this directory). Admission rule (pre-registered, `00_PREREGISTRATION.md`):
adopt only if `ΔP80 < 0 AND ΔLCB >= 0`, every seed, both cost arms.

## H1 — smooth CPPI-lite overlay (`overlay_cppi`, 16 warn/floor cells) vs the ratified V3 day-reset base (GOVDR)

Reference sanity check passes: 16/16 wave-3 cells reproduce the known anchors (`W3_BASE` LCB ≈0.83-0.84,
`UNGOVERNED_BASE` ≈0.88, within seed noise) — the engine is wired correctly; this is not an engine defect.

**0/16 payload cells pass.** The overlay is directionally interesting but does not clear the bar:

- **LCB (normal cost arm): uniformly positive across every cell and every seed** — `ΔLCB` ranges `+0.0046` to
  `+0.0104` (mean ≈ `+0.006` to `+0.008` per cell). The smooth overlay genuinely raises the payout floor versus the
  hard V3 day-reset governor, consistently, with no sign flips. This is the first lever in this company's P80/LCB
  work that improves LCB monotonically across an entire neighbourhood.
- **P80 (normal cost arm): mean negative but NOT uniformly negative per-seed.** Mean `ΔP80` across the 16 cells runs
  `-6` to `-24` business days (an improvement), but every cell has 1-2 of 5 seeds where `ΔP80` is *positive*
  (worse) by `+5` to `+15` bd. The pre-registered rule requires every seed negative — it correctly rejects on this
  seed-level sign instability, exactly the failure mode wave-2's REJECT already flagged for the cruder ungoverned
  version of this same overlay.
- **Stress cost arm: P80 is not evaluable at all** — both the V3 base and every payload cell report
  `p80_point_bd = None` under the stress arm (P80 is `NOT_REACHED` within the simulation horizon under stress,
  consistent with `P80_LEVER_SYNTHESIS_2026-09-26.md` §1's existing finding that the whole book's stress-arm P80 is
  `NOT_REACHED`). The admission rule cannot pass a dimension that never converges.

**Reading:** this is the most promising single result anyone has produced against LCB in this programme (a clean,
seed-stable floor improvement), but it is not a P80 win by the strict per-seed bar, and it cannot be evaluated at
all under the cost-stress scenario that actually gates `P_PAYOUT_EVER_LCB`. It is evidence the *direction* (smooth,
proportional de-risking beats a hard floor-or-nothing governor on LCB) is real, not evidence that this specific
parameterisation is adoptable.

## H2 — phase-specific risk-scale (Challenge-hotter / Verification+Funded-cooler) vs GOVDR

**0/2 arms pass, and both fail unambiguously (not a close call).**

| arm | mean ΔP80 (normal) | mean ΔLCB (normal) | mean ΔLCB (stress) |
|---|---|---|---|
| `H2_DERISK_ONLY` | **+143.6 bd worse** | +0.00006 (flat) | **-0.00698 worse** |
| `H2_HOT_CHALLENGE` | **+310 bd worse** | **-0.0269 worse** | **-0.0316 worse** |

Both arms make P80 materially *worse* (144-310 business days longer) and `H2_HOT_CHALLENGE` also makes LCB worse in
both cost arms. A per-stage risk multiplier — in either direction tested — is not a usable lever on this roster and
governor; this closes the question `task_79409cc9` left open.

## Bottom line for the 48h/economic-sprint question

This was the one lever identified by `advisor()` as untested in `P80_LEVER_SYNTHESIS_2026-09-26.md`'s ranked list.
It is now tested and **does not change the company's P80 problem**: neither variant clears the pre-registered bar,
and the one genuinely interesting result (H1's clean LCB improvement) cannot even be scored on the stress arm that
drives `P_PAYOUT_EVER_LCB`'s real floor. This reinforces, rather than contradicts, `P80_LEVER_SYNTHESIS_2026-09-26.md`'s
existing #4 ranked action ("governor redesign = hypothesis only") — the hypothesis has now been run, and it is a
negative/mixed result, not a positive one. The dominant remaining lever is still breadth of independent,
economically-validated sleeves (P80_LEVER_SYNTHESIS #3), not governor mechanics.

## Evidence

- `results.json` — full per-cell/per-arm/per-seed numbers (this directory).
- `run/h1/*`, `run/arms/*` — 100 raw arm-seed output files (resumable; some computed in an earlier, orphaned
  background run restarted 2026-10-02T10:02Z after its hosting session exited mid-run — `run_resume_log.txt`).
- `00_PREREGISTRATION.md` — the sealed design and admission rule, written before any result existed.
- `run_headroom_test.py` — the test script (unchanged engine, two documented additions: GOVDR day-reset base swap
  for H1, new H2 phase-hook arms).
