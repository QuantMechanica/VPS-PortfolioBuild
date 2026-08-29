# QM5_41207_xauxag-corrbreak-rv - Strategy Spec

**EA ID:** QM5_41207

**Strategy ID:** `KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01`

**Last revised:** 2026-08-30

## 1. Strategy Logic

At the first executable `XAUUSD.DWX` D1 bar of each broker week, the
EA consumes the week before every fallible gate and loads exactly 81
synchronized completed XAU/XAG closes. It forms 80 adjacent log returns in
oldest-to-newest order. The oldest 60 and newest 20 are disjoint.

A trade is possible only when baseline Pearson correlation is at least 0.50,
recent correlation is at most 0.35, their raw drop is at least 0.25, and the
Fisher correlation-drop statistic is at least 1.645. The oldest 60
XAU-minus-XAG returns define a sample mean and sample standard deviation. The
newest five-return displacement must have absolute standardized score at least
1.25.

A positive score opens SELL XAU / BUY XAG; a negative score opens BUY XAU /
SELL XAG. The package target is frozen halfway from the newest completed log
ratio toward the exact five-session-prior anchor. No equilibrium ratio, fitted
hedge coefficient, current-bar price, trained signal, or external feed is used.

## 2. Parameters

| Input | Value |
|---|---:|
| `strategy_history_bars_d1` | 81 |
| `strategy_baseline_returns` / `strategy_recent_returns` | 60 / 20 |
| `strategy_baseline_rho_floor` | 0.50 |
| `strategy_recent_rho_ceiling` | 0.35 |
| `strategy_rho_drop_floor` | 0.25 |
| `strategy_fisher_z_floor` | 1.645 |
| `strategy_displacement_returns` | 5 |
| `strategy_score_abs_floor` | 1.25 |
| `strategy_retracement_fraction` | 0.50 |
| `strategy_atr_period_d1` / multiplier | 20 / 3.5 |
| maximum hold / stale repair | 15 completed D1 bars / 24 days |
| XAU / XAG spread ceiling | 1500 / 3000 points; zero modeled spread allowed |
| maximum notional mismatch | 20% |
| entry grace | 180 minutes |

Q02 uses only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg is independently rounded down from its
USD 500 stop-risk allocation. The post-rounding absolute notional mismatch
must not exceed 20%.

## 3. Symbol Universe

- Logical package: `QM5_41207_XAU_XAG_CORRBREAK_RV_D1`.
- Host: exact `XAUUSD.DWX` D1, slot 0, magic `412070000`.
- Companion: exact `XAGUSD.DWX` D1, slot 1, magic `412070001`.

## 4. Timeframe

- Decision and execution timeframe: D1.
- Formation: 81 synchronized completed D1 closes and 80 adjacent returns.
- Cadence: at most one consumed attempt per broker week.
- Hold: frozen target, 15 completed host D1 bars, or 24 elapsed days.

## 5. Expected Behaviour

- Five to fifteen completed packages per full post-warm-up year; Q02 retires
  the unchanged candidate below five in any such year.
- Symmetric relative-value fading only after a strong-to-weak correlation
  transition and an extreme standardized five-session displacement.
- One atomic opposite-leg research package; neither component is a standalone
  strategy and realized decorrelation remains a Q09 question.

## 6. Source Citation

Approved source packet:
`strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026/source.md`.
Approved card:
`strategy-seeds/cards/approved/QM5_41207_xauxag-corrbreak-rv_card.md`.

Krawiec and Gorska provide positive daily dependence and gold-to-silver
ordering; Schweikert provides state-dependent gold/silver relationship
evidence and adverse evidence against one stable spread; CME documents the
intermarket carrier. The exact rule remains a disclosed QM hypothesis.

## 7. Risk Model

Q02 uses only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg is capped by its separate USD 500 frozen-stop
risk allocation. Only downward lot adjustment is permitted to target equal
notionals, and post-rounding mismatch above 20% rejects the package.

## Lifecycle and persistence

- Entry: one synchronized opposite-leg package; leg-two failure immediately
  repairs leg one.
- Exit: frozen halfway target on a new synchronized completed D1 endpoint,
  15 completed host bars, 24 elapsed days, or immediate malformed/orphan
  repair.
- Both legs carry frozen `3.5*ATR(20,D1)` hard stops and no broker TP.
- Positive finite quotes are mandatory; `Ask<Bid` is rejected. Exact
  `Ask==Bid` is permitted for `.DWX` tester history, while the 1500/3000
  point caps remain binding.
- News temporal/compliance/legacy axes and Friday close are locked OFF.

The consumed-week, target, expected side, and decision time use terminal global
variables. A restart may manage a valid persisted package but may never create
a second weekly attempt. Missing state, duplicate legs, same-side legs, wrong
magic/symbol, a missing stop, or excess notional mismatch closes all owned
legs.

## Evidence and limits

The source lineages support gold/silver dependence, directional ordering,
state dependence, and the intermarket carrier. The precise windows,
thresholds, CFD basket, frequency, economics, and portfolio correlation are QM
hypotheses. Opposite equal-notional legs do not prove neutrality; Q09 alone
owns realized portfolio overlap.

No live/demo/shadow/stress/optimization preset, AutoTrading action,
`T_Live` control or manifest, portfolio-gate change, portfolio
admission, or certification is part of this build.
