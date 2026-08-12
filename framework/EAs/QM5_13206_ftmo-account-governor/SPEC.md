# QM5_13206_ftmo-account-governor — V2 Strategy Spec

**EA ID:** QM5_13206  
**Slug:** ftmo-account-governor  
**Type:** no-trade account risk controller  
**Policies:** signed 100k FTMO 2-Step Phase 1, Verification, and Funded
**Last revised:** 2026-07-17

## 1. Strategy logic

This EA never creates an alpha position. It publishes a challenge-scoped, generation-guarded heartbeat, entry lock, and risk scale. At an internal liquidation floor or evaluation target it durably writes the lock before deleting pending orders and closing positions whose magic is explicitly whitelisted. Failed closes retry on every timer tick. Foreign magics are never modified and make clients fail closed.

The controller defaults to dry-run, invalid account login, empty policy, and empty whitelist. An unconfigured instance cannot unlock clients or liquidate trades.

## 2. Official FTMO 2-Step contract

Official pages retrieved 2026-07-17:

- https://ftmo.com/en/trading-objectives/
- https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/

The 100k 2-Step lifecycle uses:

| Rule | Phase 1 | Verification | Funded |
|---|---:|---:|---:|
| Profit target | 110,000 | 105,000 | none |
| Official Maximum Daily Loss amount | 5,000 | 5,000 | 5,000 |
| Official static Maximum Loss floor | 90,000 | 90,000 | 90,000 |
| Minimum opening days | 4 | 4 | none |
| Time limit | none | none | n/a |

The daily official limit is recalculated from the balance recorded at 00:00 Europe/Prague, including open P/L, swaps, and commissions in equity. A first Reward claim is available on the 14th or a later day after the first trade on the specific funded account, with all positions and pending orders closed.

## 3. Signed immutable internal policies

The deploy manifest must choose one exact allowlisted ID. Arbitrary runtime thresholds are not supported.

| Policy ID | Entry halt from Prague-midnight balance | Internal liquidation | Internal total floor | Target taper |
|---|---:|---:|---:|---|
| `FTMO_2S_P1_100K_V2` | -900 | -1,250 | 94,000 | max scale 0.75 at 107,500; 0.50 at 109,000 |
| `FTMO_2S_P2_100K_V2` | -650 | -900 | 96,000 | max scale 0.70 at 103,500; 0.40 at 104,500 |
| `FTMO_2S_FUNDED_100K_V2` | -350 | -500 | 97,500 | none |

All three also encode the official 5,000 daily amount and 90,000 static floor. The effective liquidation floor is the maximum of the official daily floor, official total floor, internal total floor, internal daily liquidation floor, and a 20% retained-profit floor. The entry floor is the maximum of that liquidation floor and the tighter entry-halt floor.

Risk scale is `clamp((equity - entry_floor) / full_risk_room, 0, 1)` and is additionally capped by the evaluation target taper. Full-risk room is 900/650/350 USD respectively.

Canonical fingerprints:

| Policy | SHA-256 | exact-double fingerprint |
|---|---|---:|
| Phase 1 | `451bce361ea8f607f159ccaee8dc937f53c1fa837b2510b68f06f4975edba0dd` | 1215771617389199 |
| Verification | `9306859e7acf085c4682e9cb6bde6d9d0a6e4b91557b13dd08df78fbe7523174` | 2586499533483248 |
| Funded | `46fb026dd6a9d3fcbbe3ead4720316918119cf70971df7e615536f43675f35d2` | 1248702263814813 |

## 4. Inputs

| Parameter | Default | Meaning |
|---|---:|---|
| `expected_account_login` | 0 | Must equal the signed target login. |
| `challenge_id` | empty | Signed lifecycle instance; empty is invalid. |
| `challenge_start_utc` | 0 | Signed start and state-lineage anchor. |
| `signed_policy_id` | empty | Exact allowlisted policy ID; empty or unknown fails. |
| `allowed_magics_csv` | empty | Exact signed whitelist; empty is invalid. |
| `governor_dry_run` | true | Publishes a lock and performs no trade operation. |
| `challenge_state_bootstrap` | false | One-shot explicit state seed; never runs trading mode. |
| `bootstrap_no_prior_breach_confirmed` | false | Required external history attestation. |
| `bootstrap_prague_day_key` | 0 | Exact current Prague day for the seed. |
| `bootstrap_midnight_balance` | 0 | Externally reconciled midnight balance. |
| `bootstrap_trading_days` | 0 | Reconciled opening-day count, capped at the phase minimum. |
| `bootstrap_last_trade_day_key` | 0 | Last reconciled Prague entry day. |
| `governor_timer_ms` | 200 | Evaluation and retry interval, valid 100–1000 ms. |
| `close_deviation_points` | 50 | Maximum close deviation for governed liquidation. |

## 5. Persistent-state and client contract

- V2 state keys use the `QM.F2` prefix, so V1 state can never silently migrate.
- A one-shot bootstrap must be followed by a restart with bootstrap disabled.
- Day lock resets only across a continuously observed Prague midnight; total and completed-target locks are monotone.
- The singleton lease prevents two governors publishing the same lifecycle.
- Clients accept only a stable even-generation snapshot with matching policy version/fingerprint, current Prague day, heartbeat age no greater than five seconds, `ready=1`, `entry_lock=0`, and `0 < risk_scale <= 1`.
- A policy mismatch, stale/partial snapshot, missing state, unknown magic, non-USD currency, or non-hedging account fails closed.
- Phase 1 and Verification capture target equity, cancel governed orders, and flatten governed positions. Completion requires target balance, account flatness, and four recorded opening days.
- Funded mode has no target capture and no minimum-day counter.

## 6. Release boundary

Status: **BUILD/TEST ONLY; DEPLOYMENT_ALLOWED=false**.

Strict compilation currently passes for the policy include test, client include test, and governor EA. Deployment remains blocked until:

1. every book EA is wired to `QM_FTMOGovernorClient.mqh` and multiplies planned risk by the published scale;
2. MQL/Python golden parity and T1-T5 stale heartbeat, torn snapshot, restart, midnight, foreign-magic, liquidation-retry, and policy-mismatch tests pass;
3. the Phase-1/Verification target-before-four-days completion path is explicitly implemented or OWNER-accepted as a launch blocker;
4. the bootstrap is independently reconciled against the exact account history;
5. a policy-specific set and magic whitelist are bound to an OWNER-signed deploy manifest; and
6. LiveOps performs read-only T6 verification with AutoTrading off. Agents never toggle AutoTrading.

## 7. Revision history

| Version | Date | Change | Evidence |
|---|---|---|---|
| V1 | 2026-07-13 | Phase-1-only controller | archived policy artifact `artifacts/ftmo_governor_policy_golden_2026-07-13.json` |
| V2 | 2026-07-17 | signed P1/P2/Funded policies, tighter book floors, target taper, V2 state namespace | strict compile logs under `framework/build/compile/20260717_102557`, `20260717_102605`, and `20260717_102612` |
