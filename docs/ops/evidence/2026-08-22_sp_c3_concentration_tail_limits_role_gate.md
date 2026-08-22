# SP-C3 concentration/tail limits — role and authority gate

Date: 2026-08-22  
Router task: `4fab7ffd-903c-4218-b2d2-12746839f2ee`  
Disposition: `ROLE_CONTRACT_HOLD`

## Requested outcome

The task asks for new currency, asset-class, strategy-family, session and
shared-tail limits in the portfolio builder/report, plus VaR- and
D-Leverage-adjacent diagnostics. Applying any resulting weights to the live
book is separately OWNER/ROT-gated.

## Binding preflight result

The router payload itself reserves the required information-architecture and
design work to Claude and says it must not be delegated:

> `Claude-eigene IA-/Design-Arbeit (nicht delegieren)`

That reservation is incompatible with implementing or selecting the requested
cap taxonomy and thresholds in the Codex lane. Those choices are not a purely
mechanical code translation: they define portfolio-risk semantics, how sleeves
map to overlapping buckets, and which concentration/tail conditions bind.
Codex therefore made no builder, report, policy, manifest, setfile, or live
weight change.

The cited Company Reference drive was not mounted in this scheduled-task
environment (`G:` unavailable). This does not relax the explicit constraint in
the durable router payload. Existing canonical material also treats live book
weight application as OWNER-reviewed work; no live authority was inferred.

## Evidence and next owner

- Durable source of the reservation: router task payload above.
- Existing canonical design context located read-only:
  - `docs/ops/DXZ_Q6_QUALIFICATION_BOOK_DESIGN_2026-07-16.md`
  - `docs/ops/DXZ_PORTFOLIO_RESIZE_REMEDIATION.md`
- No repository implementation files were mutated for SP-C3.
- No terminal, backtest, deployment, `T_Live`, AutoTrading, setfile, or live
  portfolio action was invoked.

Next action: Claude must first produce/approve the IA and design contract (cap
dimensions, sleeve classification, thresholds, overlap/tail-day semantics,
and report acceptance fixtures). A later deterministic implementation task can
then translate that sealed contract into builder/report code. Applying weights
remains a distinct OWNER/ROT action.

## Verdict

`ROLE_CONTRACT_HOLD`: the requested acceptance criteria cannot be honestly
claimed by Codex without violating the task's own non-delegation constraint.
The task is returned to REVIEW with this evidence, not self-approved and not
advanced to any pipeline phase.
