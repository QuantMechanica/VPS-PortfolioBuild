# QM5_41040 XAU/XAG Weekly Flow-Conditioned Fade — Q01 PASS / Q02 Enqueued

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41040_xauxag-wflow-fade` is a new low-frequency logical commodity
basket. On the first executable synchronized `XAUUSD.DWX` / `XAGUSD.DWX` D1
tick of a genuine broker Monday, it reconstructs the exact completed prior
Monday-through-Friday week plus the preceding Friday close anchor. For each
metal it separately sums prior-close-to-open and open-to-close log returns,
subtracts silver from gold, and reconciles both metal totals and the relative
total within `1e-10`.

The candidate admits only strict relative-component opposition with strict
session dominance: `abs(session_relative) > abs(overnight_relative)`. It then
fades the completed relative week. A positive week sells XAU and buys XAG; a
negative week buys XAU and sells XAG. Agreement, exact zero, equal component
magnitude, broken calendar identity, timestamp mismatch, invalid endpoints,
failed reconciliation, late attachment, or an already consumed week remains
flat.

Each package targets equal absolute USD notionals, rejects post-rounding
mismatch above 20%, and caps combined frozen-stop risk at one
`RISK_FIXED=1000` budget. Both legs use `3.0 * ATR(20,D1)` hard stops, no
target, and a paired broker-Friday hour-21 exit with later-week and eight-day
repair guards. Both news axes are OFF.

The governed packet combines the OWNER-supplied Tier-A Williams price-flow
decomposition with peer-reviewed Schweikert gold/silver state-dependence and
CME gold/silver carrier material. None of those sources tests this exact
conjunction, Darwinex continuous-CFD implementation, package economics, or
portfolio correlation. This receipt records a build and queue handoff, not
certification, profitability, neutrality, decorrelation, or portfolio
admission.

## Governance And Non-Duplicate Boundary

- Source approval commit: `cf6d369d7`.
- Deterministic EA-ID reservation commit: `98c67e8f4`.
- Strategy Card and OWNER G0 commit: `a1f954d99`.
- Pre-magic directory identity commit: `20ab3c513`.
- Basket magic registration/resolver commit: `ff6476562`.
- Q01 build commit: `51bb2e189`.
- Registered routes are slot 0 `XAUUSD.DWX` / magic `410400000` and slot 1
  `XAGUSD.DWX` / magic `410400001`.
- The canonical dedup check found no exact identity and raised only the
  expected weekly/monthly XAU/XAG flow-family neighbors.
- `QM5_41030_xauxag-flowdiv` follows the session-relative sign on every strict
  weekly opposition state. This identity requires session dominance and takes
  the opposite sides on every admitted state by fading the completed week.
- `QM5_41039_xauxag-mflow-div` forms over a completed broker month, follows
  session-relative flow, and exits at the next-month boundary. This identity
  uses an exact Monday-Friday formation and paired Friday exit.
- Manual verdict:
  `CLEAN_XAUXAG_WEEKLY_SESSION_DOMINANT_FADE_AFTER_FLOW_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- The only preset is the logical D1 backtest setfile with
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- The basket manifest binds both traded symbols to one logical test identity;
  neither leg is a standalone strategy.
- Independent mechanic suite: 14 tests PASS, covering exact calendar and
  synchronization, both fade sides, opposition/dominance strictness, equality
  and flat states, all reconciliation gates, invalid endpoints, durable
  attempt identity, joint risk/notional sizing, and lifecycle boundaries.
- All three Strategy Card copies are byte-identical and pass schema/ML lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_075647/QM5_41040_xauxag-wflow-fade.compile.log`.
- Target build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_075738.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41040/P1/P1_QM5_41040_result.json`.
- Basket symbol-scope verdict: `BASKET_OK`, zero violations.
- Build guardrails: PASS.
- No manual tester, smoke test, phase runner, dispatcher tick, or backtest was
  invoked.

## Paced Q02 Handoff

The canonical scheduled sweeper created one target work item before the
operator dry run:

- work item: `b126ae29-eb19-4c13-8cd3-33f7637eae25`
- phase/status: `Q02` / `pending`
- created: `2026-08-17T07:52:58+00:00`
- symbol: `QM5_41040_XAU_XAG_WFLOWFADE_D1`
- host route: `XAUUSD.DWX`, D1
- basket routes: `XAUUSD.DWX`, `XAGUSD.DWX`
- setfile: `framework/EAs/QM5_41040_xauxag-wflow-fade/sets/QM5_41040_xauxag-wflow-fade_QM5_41040_XAU_XAG_WFLOWFADE_D1_D1_backtest.set`
- attempt count: 0
- priority track: true
- timeout: 450 minutes
- custom-history archive admission: ACTIVE for both basket symbols

The exact-path capacity sample at `2026-08-17T08:00:20.1891002Z` counted only
resolved `D:/QM/mt5/T1..T10/terminal64.exe` paths and explicitly excluded
`T_Live`. Six of the governed seven-slot ceiling were active: T1, T4, T5,
T6, T9, and T10. Host CPU load sampled at 100%, but the binding governed root
ceiling was not reached. No terminal, worker, or tester action was taken.

The subsequent target-only dry run reported zero fresh rows because this EA
already had the pending work item. `farmctl work-items --ea QM5_41040`
confirmed exactly one Q02 row. The operator did not invoke the sweep with
`--apply`, avoiding a duplicate queue mutation.

## Safety And Handoff

No manual MT5 run, terminal start/stop, worker mutation, AutoTrading action,
`T_Live` access, live/demo/shadow/stress/optimization preset, deploy manifest,
T_Live manifest, portfolio-gate edit, portfolio admission, neutrality claim,
or correlation waiver occurred.

The paced factory owns the pending Q02 item. Q02 must retire the identity on
zero trades, fewer than five completed packages per full post-warm-up year,
wrong weekly identity/endpoints, timestamp mismatch, invalid opposition or
dominance, wrong fade side, failed reconciliation, leakage, late/repeated
entry, wrong package lifecycle, nondeterminism, invalid risk mode, or
nonpositive governed economics.
