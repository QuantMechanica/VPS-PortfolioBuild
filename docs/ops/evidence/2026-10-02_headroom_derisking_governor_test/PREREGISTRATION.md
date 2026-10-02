# Pre-registration — headroom/smooth-de-risking governor lever + phase-specific risk (task 16e8127e)

Written BEFORE any arm is run. Engine: unchanged `tools/strategy_farm/ftmo/book_sim.py` +
`first_passage.py` (2.1.0) + `governor_base.py`, imported read-only from the canonical checkout
(`C:/QM/repo`). SIMULATION ONLY — no MT5, no build, no card, no farm-DB write, no D:/ write, no
change to any deployed governor/EA/set-file/roster. Book: the same frozen D2g6 incumbent loaded by
`governor_ladder.load_book()` (financed streams, fixed common window), i.e. the same book as
`docs/ftmo/P80_LEVER_SYNTHESIS_2026-09-26.md`.

## Why this run uses fresh seeds at 40k paths, not the synthesis's 20k table

The synthesis's published numbers (V3 996 bd / LCB 0.831) were produced at `--paths 20000`
(`p80_levers.py` CLI default). The paired-seed methodology requires IDENTICAL bootstrap index
matrices between an arm and its reference (common random numbers), which requires identical
`n_paths`. This ticket's instruction sets a 40,000-path floor, so a fresh V3 reference (`REF`) is
re-run at 40k paths with the same 5 seeds (`20260924..20260928`) specifically to pair against the
new arms below. REF is expected to reproduce the synthesis's V3 numbers within seed noise; if it
does not, that is reported as a reproduction failure, not papered over.

## Hypothesis 1 — smooth headroom-responsive de-risking replaces the hard phase-1 freeze

**Claim under test.** The deployed governor (V2 latch / V3 day-lock) is a BINARY trigger: once a
day's trough crosses the internal liquidation floor, it fully halts (durably for V2, for the
Prague day for V3). The synthesis's own evidence (`V2 latch is a cliff`, §1) shows this produces
large discrete P80 damage on specific bad days. An alternative never tested: a CONTINUOUS,
state-dependent size multiplier with no discrete halt event at all — full size while equity is
healthy, ramping smoothly toward (not necessarily to) a floor size as the account's cumulative
P&L approaches the REAL OFFICIAL loss line, and ramping back up automatically as equity recovers
(no separate "restoration rule" is needed because the multiplier is a pure function of current
state, not a latch).

**Mechanism (uses only existing, unmodified code).** `governor_base.overlay_cppi(warn, floor,
max_loss_line)` already implements `s = clip((cum + line) / (line - warn), floor, 1)` — this is
exactly the proposed continuous multiplier. It has never been run as the ENTIRE phase-1 governor
(replacing the hard floor); the one place it exists (`base_gov_hooks`) always stacks it ON TOP of
whichever hard policy is in force. This run instead calls `governor_base.phase_walk_gov(...,
policy=governor_base.NO_GOVERNOR, overlay_factory=overlay_cppi(...))` directly for phase 1 only:
`NO_GOVERNOR` has no internal floor/entry-halt at all (its floors sit at ±1e18, so
`entry_risk_scale` is always 1.0 before the overlay), so the ONLY things that can end a path are
(a) the overlay's continuous size scale and (b) the real official FTMO daily/total loss test
(5%/10%, unchanged, tested every day on the overlay-scaled P&L exactly as today). Phase 2 and the
funded stage are left exactly as currently deployed (ungoverned, plain `first_passage._phase_walk`
/ `_funded_walk`) in every arm including REF, so the comparison isolates the phase-1 governor
design only.

**Pre-registered arms (positive USD magnitudes; `warn` = cum P&L at which ramp-down starts, `line`
= cum P&L at which the floor size is reached; official phase-1 total-loss line is -10,000 USD,
daily -5,000 USD):**

| Arm | warn | floor | line | Rationale |
|---|---|---|---|---|
| E1_TIGHT | 2,000 | 0.10 | 9,000 | Starts de-risking early, never fully stops (10% floor), leaves 1,000 USD buffer to the real total-loss line |
| E2_WIDE | 4,000 | 0.25 | 9,500 | Later, gentler ramp; higher floor (closer to today's effective behaviour before any halt) |
| E3_ZEROFLOOR | 3,000 | 0.00 | 9,500 | Ramps continuously to zero size exactly at the line (closest in spirit to "never breach"), but — unlike V2/V3 — this is a smooth function of state with no discrete halt/latch and no day-lock; size tracks back up immediately once cum improves |

## Hypothesis 2 — phase-specific risk (Challenge hot, Verification/Funded cooled)

**Claim under test.** Today the book runs at one uniform risk weight across Challenge,
Verification and Funded (ungoverned in the latter two). The synthesis never tested whether
lowering Verification/Funded risk (which do not need to pass fast) buys enough LCB/breach-rate
margin to let Challenge risk run hotter without net LCB loss.

**Mechanism.** Two independently risk-scaled copies of the SAME incumbent sleeve set (same trades,
same window — rescaling `risk_percent` does not change the business-day grid, so no grid padding
is required). The Challenge-risk copy feeds stage 1 only; the Verification/Funded-risk copy feeds
stages 2 and 3. Stage 1 keeps the V3 day-lock governor (`policy=None` resolved by target match,
`cfg.daily_event="day_reset"`) in every arm, identical to REF, so this hypothesis is tested in
isolation from Hypothesis 1.

**Pre-registered arms:**

| Arm | Challenge risk factor | Verification/Funded risk factor |
|---|---|---|
| PR_050 | 1.00 (unchanged) | 0.50 |
| PR_075 | 1.00 (unchanged) | 0.75 |
| PR_075_CH125 | 1.25 | 0.75 |

## Common parameters (all arms, both hypotheses)

- `n_paths = 40000`, seeds = `[20260924, 20260925, 20260926, 20260927, 20260928]` (same 5 seeds as
  governor-ladder waves 1-3 and the synthesis).
- `block_len = 20`, `horizon = 1008` (phase 1 / verification), `funded_horizon = 120`,
  `n_batches = 20` — identical to `governor_ladder.py` / `p80_levers.py` defaults.
- Both cost arms: normal (`cost_mult=1.0, slippage=0`) and stress (`cost_mult=1.5,
  slippage=2 USD/lot`).
- Reference book is unchanged: `governor_ladder.load_book()` (the frozen D2g6 incumbent,
  financed streams, `d2g6_roster_financed.json`).

## Admission test (sealed, from `governor_ladder.decide`, applied unmodified)

Adopt only if, in EVERY seed and BOTH cost arms: ΔP80 < 0 (t80 preferred when both REF and arm
reach it in every seed, else point-P80), ΔLCB ≥ −0.01, and no breach-share delta is positive
(phase-1 max-loss, phase-1 daily-loss, all-stage daily-loss, all-stage max-loss). This is the
IDENTICAL mechanical rule already codified and unit-tested in
`tools/strategy_farm/research/governor_ladder.py::decide`, reused verbatim (not re-derived) so the
verdict is comparable to every prior lever in the synthesis's ranking table.

## What would falsify each hypothesis

1. **H1 (smooth de-risking):** ΔP80 ≥ 0 or ΔLCB < −0.01 in any seed/cost-arm for ALL THREE
   parameterizations ⇒ the hard-freeze redesign has no exploitable P80 lever at any tested
   warn/floor/line combination tried here (does not rule out combinations never tried).
2. **H2 (phase-specific risk):** ΔP80 ≥ 0 or ΔLCB < −0.01 for PR_050 and PR_075 (the two
   risk-reduction-only arms) ⇒ de-risking Verification/Funded does not buy enough LCB margin to be
   worth it even without raising Challenge risk, closing the question without needing the combo
   arm's result.

## Scope limits disclosed up front

- In-sample, same window as the synthesis (2019-02-06..2025-10-21), same caveats (day-grid,
  conservative simultaneous-MAE trough proxy, first-order replay).
- `NO_GOVERNOR` + overlay removes ALL of V2/V3's internal early-warning machinery, not just the
  halt event — this is deliberate (testing the overlay AS the governor, not stacked on it), but it
  means any effect attributed to "smooth de-risking" also reflects the absence of V3's taper/target
  logic in phase 1. That attribution gap is reported, not glossed over.
- Three arms per hypothesis is a bounded, pre-registered grid, not a search; no additional arm is
  added after seeing results.
