# QM5_13206_ftmo-account-governor - Strategy Spec

**EA ID:** QM5_13206  
**Slug:** ftmo-account-governor  
**Type:** no-trade account risk controller  
**Policy:** FTMO_P1_GOVERNOR_V1  
**Last revised:** 2026-07-13

## 1. Strategy Logic

This EA never opens a position. It publishes an account-scoped heartbeat,
entry lock, and risk scale. At an internal policy floor it persists the lock
before deleting pending orders and closing positions whose magic is explicitly
whitelisted. Failed closes are retried on the next timer tick. Foreign magics
are never modified.

The controller defaults to dry-run and an invalid account login, so an
unconfigured instance is fail-closed and cannot liquidate trades.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| expected_account_login | 0 | Must be set to the signed target account. |
| allowed_magics_csv | empty | Exact signed whitelist; empty is invalid. |
| governor_dry_run | true | Publishes a lock and performs no trade operation. |
| policy_execution_daily_stop | 4500 | Internal buffer inside the 5000 rule. |
| policy_total_loss_floor | 90000 | Static Phase-1/Verification loss floor. |
| policy_full_risk_room | 4000 | Equity room at which scale reaches 1.0. |
| governor_timer_ms | 200 | Evaluation and retry interval. |

## 3. Symbol Universe

Account-wide observation; liquidation is magic-whitelisted and symbol-agnostic.
The deploy manifest, not source defaults, owns the exact symbol and magic list.

## 4. Timeframe

Timer-driven at 100-1000 ms. Trading-day boundaries use Europe/Prague with EU
DST and do not depend on chart timeframe.

## 5. Expected Behaviour

- Missing or stale governor state blocks every wired client entry.
- Day lock resets only at a new Prague day; total and target locks persist.
- A breach lock is flushed before any cancel/close request.
- Partial liquidation remains locked and retries until governed exposure is flat.
- Target completion requires a flat account and four trading days.

## 6. Source Citation

FTMO Trading Objectives, 2-Step rules, retrieved 2026-07-13:
`https://ftmo.com/en/trading-objectives/`.

## 7. Risk Model

Entry scale is `clamp((equity - 90000) / 4000, 0, 1)`. The effective internal
floor is `max(midnight_balance - 4500, 90000 + 0.2 *
max(0, midnight_balance - 90000))`. These conservative controls do not alter
the official 5% daily and 10% static-loss definitions used by simulation.

Status: **BUILD/TEST ONLY; DEPLOYMENT_ALLOWED=false** until client wiring,
MQL/Python golden parity, T1-T5 fault tests, current broker symbol mapping, and
an OWNER-signed manifest all pass.
