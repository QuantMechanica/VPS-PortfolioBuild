# QM5_39003 build blocked by incomplete Strategy Card contract

- Task: `f361cc66-38ca-4125-ab5f-153ce82fc340`
- EA: `QM5_39003_forexfactory-james16-price-action-ppz`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39003_forexfactory-james16-price-action-ppz.md`
- Branch: `agents/board-advisor`
- Disposition: `BLOCKED_CARD_MECHANICS`; no build was accepted and no source was changed.

## Upstream contract blocker

The approved card cannot determine one reproducible EA without inventing strategy mechanics:

1. The take-profit rule says “target next institutional PPZ resistance” and also labels the outcome `1:2.5 R:R`. It does not define whether the next PPZ or fixed 2.5R controls when those prices differ, how a “next” PPZ is selected, or what happens when no qualifying PPZ exists.
2. The required “dynamic swing high/low trailing stop” has no pivot strength, lookback, confirmation delay, price buffer, activation condition, or restart-state contract.
3. `PPZ_Zone` references `PivotLevel`, but the card defines only a 20-bar lookback. It does not specify pivot strength, clustering, repeated-touch threshold, support/resistance role conversion, or deterministic tie-breaking among multiple levels.

Those choices materially alter entries and exits. The existing EA silently chooses two-bar swing pivots, a fixed 2.5R target, and no trailing stop. Accepting or replacing those choices would exceed the build-only authority of this task. Research/OWNER must amend and re-approve the card before Development can implement it exactly.

## Existing implementation audit

The pre-existing files are not an acceptable fallback:

- `Strategy_ManageOpenPosition()` is empty, so the mandatory dynamic swing trail is absent.
- `Strategy_NoTradeFilter()` always returns false, omitting the card's 1.8×ATR spread ceiling, 23:55–00:05 GMT rollover blackout, and 2.0% realized-daily loss halt.
- The source defaults both `RISK_PERCENT=0.5` and `RISK_FIXED=1000`, does not wire the 2.5%/5.0% kill-switch limits, and has no maximum three-trade-tick deviation configuration.
- MQ5 line 156 multiplies the 2-pip stop buffer by ten before calling the pip-native helper. Canonical hardening reports `EA_PIP_DOUBLE_CONVERSION`, so the existing stop is not the card's 2-pip stop.
- The source uses a fixed 2.5R target and an undocumented two-bar pivot strength rather than a card-adjudicated next-PPZ contract.

## Focused verification

| Check | Result |
|---|---|
| Approved-card/registry audit | Card is OWNER-approved; EA ID 39003 and active slots 0–2 exist for EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX |
| `build_gate_hardening.py ... --ea-label QM5_39003_forexfactory-james16-price-action-ppz` | FAIL: one pip double-conversion, three missing loss-limit controls; one GMT-window-undecidable warning |
| `validate_build_guardrails.py <mq5> <sets-dir>` | PASS for generic guardrails; news staleness remains 336 hours and sets use fixed-risk mode |
| `validate_spec_doc.py <ea-dir>` | Structural SPEC check PASS; it does not resolve the missing card mechanics |

## Required upstream repair

- Define a single TP algorithm, including the precedence/fallback relationship between next PPZ and 2.5R.
- Define the PPZ construction and selection algorithm completely.
- Define the swing-trailing algorithm, activation, buffer, and restart reconstruction.
- Re-run OWNER approval on the amended card, then route a fresh build task.

No EX5 was rebuilt, no Q phase or backtest ran, and AutoTrading/T_Live were untouched.
