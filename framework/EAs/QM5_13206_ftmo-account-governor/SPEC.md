# QM5_13206_ftmo-account-governor - Strategy Spec

**EA ID:** QM5_13206  
**Slug:** ftmo-account-governor  
**Type:** no-trade account risk controller  
**Policy:** FTMO_P1_GOVERNOR_V1  
**Last revised:** 2026-07-13

## 1. Strategy Logic

This EA never opens a position. It publishes a challenge-scoped, generation-
guarded heartbeat, entry lock, and risk scale. At an internal policy floor or
the Phase-1 equity target it persists the lock before deleting pending orders
and closing positions whose magic is explicitly whitelisted. Failed closes are
retried on the next timer tick. Foreign magics are never modified and make the
governor fail closed.

The controller defaults to dry-run and an invalid account login, so an
unconfigured instance is fail-closed and cannot liquidate trades.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| expected_account_login | 0 | Must be set to the signed target account. |
| challenge_id | empty | Signed challenge instance; empty is invalid. |
| challenge_start_utc | 0 | Signed challenge start and state-lineage anchor. |
| allowed_magics_csv | empty | Exact signed whitelist; empty is invalid. |
| governor_dry_run | true | Publishes a lock and performs no trade operation. |
| challenge_state_bootstrap | false | One-shot explicit state seed; never runs trading mode. |
| bootstrap_no_prior_breach_confirmed | false | Required explicit history attestation. |
| bootstrap_prague_day_key | 0 | Exact current Prague day for the seed. |
| bootstrap_midnight_balance | 0 | Externally reconciled midnight balance. |
| bootstrap_trading_days | 0 | Externally reconciled opened-position day count. |
| bootstrap_last_trade_day_key | 0 | Last reconciled Prague entry day. |
| governor_timer_ms | 200 | Evaluation and retry interval. |

Policy V1 is not configurable: start `100000`, target `110000`, total floor
`90000`, internal daily stop `4500`, retained-room coefficient `0.20`, full-risk
room `4000`, and four minimum trading days. Its canonical fingerprint is
`03390b7a65ee33153f4fe63064bb163c4bcc692436b694cdd2ed1be7f1117e3d`.

## 3. Symbol Universe

Account-wide observation; liquidation is magic-whitelisted and symbol-agnostic.
The deploy manifest, not source defaults, owns the exact symbol and magic list.

## 4. Timeframe

Timer-driven at 100-1000 ms. Trading-day boundaries use Europe/Prague with EU
DST and do not depend on chart timeframe.

## 5. Expected Behaviour

- Missing, stale, partial, or cross-challenge state blocks every wired client entry.
- A missing state can only be seeded by an explicit one-shot bootstrap. A
  successful seed remains locked and requires restart with bootstrap disabled.
- Day lock resets only across a continuously observed Prague midnight; total
  and completed-target locks are monotone.
- A breach lock is flushed before any cancel/close request.
- Partial liquidation remains locked and retries until governed exposure is flat.
- Target equity starts capture: normal entries lock, all governed pending orders
  are cancelled, and governed positions are flattened. Completion is published
  only after actual balance is at target, the account is flat, and four trading
  days are recorded.
- Target reached before four days remains locked for normal sleeves. A separate
  signed minimum-day completion path is required and is not part of this EA.
- A singleton lease prevents two governor instances from publishing the same
  challenge state. Clients accept only stable even-generation snapshots.
- Non-USD or non-hedging accounts and any unknown magic remain fail closed.

## 6. Source Citation

FTMO Trading Objectives, 2-Step rules, retrieved 2026-07-13:
`https://ftmo.com/en/trading-objectives/`.

## 7. Risk Model

Entry scale is `clamp((equity - effective_floor) / 4000, 0, 1)`. The effective
internal floor is `max(midnight_balance - 4500, 90000 + 0.2 *
max(0, midnight_balance - 90000))`. These conservative controls do not alter
the official 5% daily and 10% static-loss definitions used by simulation.

Status: **BUILD/TEST ONLY; DEPLOYMENT_ALLOWED=false** until every book EA is
client-wired, the special minimum-day completion contract is implemented,
MQL/Python golden parity and T1-T5 fault tests pass, the bootstrap is reconciled,
and an OWNER-signed manifest exists.
