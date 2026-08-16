# DL-082 — DL-081 Bounded-Grid Cap Extended to Commercial-EA Deconstructions

**Date:** 2026-08-16
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER (verbatim: "Bau die 4 mit dem 1%-Cap!")
**Extends:** DL-081 (bounded-risk grid/hedged-basket exception, account-capped at 1%)
**Scope of extension:** the four Century-Suite commercial-EA deconstruction cards
listed below — and only those.

## Why this decision was needed

DL-081 permits grid / martingale / averaging mechanics **for one strategy class
only** (the T-WIN / U.F.O. currency-strength hedged basket) and states
explicitly: *"This is NOT a blanket repeal of the no-grid Hard Rule; every other
EA remains bound by it unless OWNER extends this DL."*

While preparing the Century-Suite build programme (100 cards, `QM5_30001`–
`QM5_41012`), four approved cards were found to declare grid and/or martingale
mechanics. Their `g0_approval_reasoning` had already applied the DL-081 cap **by
analogy** ("V5 grid cap binds: per-grid-cycle risk <=1% equity + KillSwitch"),
but analogy is not authorization: DL-081's own scope clause forbids it. The
cards were therefore held and put to OWNER rather than built.

OWNER extended the exception. This DL records that extension so the build is an
authorized act and not a silent hard-rule violation.

## Cards covered

| EA | Card slug | Declared mechanics |
|---|---|---|
| `QM5_30001` | `bollinger-bands-grid-waka-waka` | BB/RSI mean reversion + dynamic ATR grid + **martingale recovery**; card itself lists `hard_rules_at_risk: [basket_drawdown_limit, martingale_margin_exhaustion, spread_expansion]` |
| `QM5_30005` | `bollinger-bands-grid-dark-venus` | Bollinger grid |
| `QM5_30006` | `adx-ma-trend-grid-dark-kronos` | ADX/MA trend grid |
| `QM5_38007` | `codetrading-python-atr-grid-engine` | ATR grid engine |

No other card is covered. Any further grid/martingale card requires a new OWNER
extension.

## Binding invariant (inherited from DL-081, unchanged)

- A **basket-level hard equity stop at 1% of ACCOUNT_EQUITY**, measured on
  floating P&L across **all legs of the idea**, flattens the entire basket when
  breached. Max realized loss per cycle = 1% (ex-gap).
- The scale-in / martingale schedule inside that envelope is free. A more
  aggressive schedule hits the stop sooner and grows the gapped-through tail; it
  can never raise the cap.
- `RISK_FIXED` for backtest / `RISK_PERCENT` for live is unchanged. The 1% cap is
  layered on top of per-trade sizing, never a replacement for it.
- The mandatory news blackout (DL-080) and session limits remain in force as the
  gap-tail mitigation. Each of the four EAs must document its residual gap tail
  in its risk notes.

## What this decision does NOT do

- It does not lower any gate. The four EAs must clear Q02–Q08 on their own
  economics exactly like every other candidate; the cap makes the idea *safe*,
  not *profitable*. Repeated 1% stop-outs bleeding capital is precisely what
  Q04/Q08 measure.
- It does not authorize live deployment. T_Live remains OWNER + Claude only, via
  the normal signed deploy-manifest path.
- It does not repeal the no-grid Hard Rule for anything outside the four cards
  above.

## Build implications

The basket/aggregate equity-stop primitive required by DL-081 applies here too:
an account-wide floating-P&L monitor that flattens a tagged group of magics at
−1%, group-scoped rather than account-scoped. Where an EA in this set trades a
single symbol with a grid rather than a multi-leg basket, the same aggregate
stop applies to the grid's combined position.

Verification per EA before release: the aggregate stop must be demonstrated to
fire in a bound test (a run in which the basket reaches −1% must show the flatten
event), alongside the standard host-slot magic check, unwired-input audit and
strict compile.

## Evidence

- Inventory and mechanics scan: `artifacts/century_build_batch1.json`,
  `artifacts/century_clean_buildable.json` (77 clean / 4 grid).
- OWNER decision record for the session: `docs/ops/evidence/2026-08-16_owner_decisions.md`.
- Parent decision: `decisions/DL-081_bounded_grid_basket_risk_capped_exception.md`.
