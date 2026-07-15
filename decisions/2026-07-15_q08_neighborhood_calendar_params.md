# Decision: Q08.5 neighborhood — calendar-denominated window params are structural, not perturbable

- Date: 2026-07-15
- Status: accepted
- Owner: OWNER (ratified in chat, 2026-07-15 morning)
- Affected: `framework/scripts/q08_5_neighborhood_runner.py` (NON_PERTURBABLE_NAME_TOKENS)
- Trigger case: QM5_12474 gh-dual-thrust GBPUSD — Q08 FAIL_HARD solely from perturbing
  `strategy_lookback_sessions` 5→4 (DD ratio 1.998, PF 1.25→1.05).

## Rationale (OWNER)

`strategy_lookback_sessions = 5` denominates the Dual-Thrust range window in TRADING
SESSIONS: five sessions = one calendar week. The parameter encodes *weekly highs/lows* —
a structural market anchor, not a point on a tuning continuum. A 4-session week has no
market meaning; that N=4 and N=6 behave differently is expected and does not indicate an
over-fitted ridge. The plateau/neighborhood concept does not apply to such parameters.

Reinforcing technical fact: the EA collects "N complete sessions" by scanning back as
far as needed (holiday weeks reach further back) — a live configuration with N=4 can
never occur. The perturbation therefore tests a strategy variant that cannot exist in
production.

## Rule

Neighborhood perturbation (Q08.5) excludes parameters whose NAME denominates a window in
calendar units: tokens `session`, `week`, `month` (joining the existing time-of-day
tokens `time/hour/minute/hhmm`). Bar-/period-denominated windows (`*_bars`, `*_period`)
remain perturbable — those are genuine tuning knobs.

Deliberately NOT excluded: the token `day` (collision-prone: `daily_loss` caps etc. are
tunable money values). Day-denominated windows can be added case-by-case with care.

## Consequence / audit trail

- Where a session/week-denominated window genuinely IS tuned (not anchored), plateau
  evidence must come from the Q03 grid instead — Q08.5 no longer covers it.
- The 12474 breach evidence stays on disk (perturbations.json, 2026-07-15T04:56Z) —
  this decision reclassifies the parameter, it does not erase the measurement.
- 12474's 8.5 re-runs post-patch with the remaining perturbable params.
