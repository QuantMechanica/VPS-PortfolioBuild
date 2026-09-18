# FTMO KPI Contract (canonical)

**Authority:** `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` (directive §2–§3). Record:
`decisions/2026-09-17_owner_fable_full_executive_authority.md`. Version: v1, 2026-09-18. Owner: Fable (orchestrator).
Changes to this contract are versioned in place with a dated changelog at the bottom; the estimator is defined BEFORE
anything is optimised against it, and it is never redefined because a preferred strategy performs poorly.

## 1. North Star KPI — `FTMO_NET_CASH_REALIZED`

```
FTMO_NET_CASH_REALIZED [USD]
  = sum( FTMO cash rewards confirmed as RECEIVED by OWNER on a QM-controlled account )
  - sum( paid FTMO Challenge fees )
  - sum( paid resets / re-tries )
  - sum( other directly attributable evaluation fees, e.g. paid add-ons )
```

- Evidence basis: OWNER-confirmed receipt of funds (bank/PayPal/crypto statement line), never an FTMO dashboard
  "reward approved" state. Fees: FTMO invoice/payment receipt. Ledger: `D:/QM/reports/state/ftmo_cash_ledger.jsonl`
  (append-only; each line = {ts_utc, kind: fee|reset|reward|refund, amount_usd, currency_native, amount_native,
  evidence_path, confirmed_by}). Until the first paid purchase the ledger is empty and the KPI is exactly 0.
- Refunded Challenge fees (FTMO refunds the fee with the first reward) are booked as a `refund` line when received.
- Milestone: `FIRST_NET_FTMO_PAYOUT = TRUE` iff `FTMO_NET_CASH_REALIZED > 0`.
- After the first positive value the objective becomes maximising sustainable cumulative `FTMO_NET_CASH_REALIZED`
  subject to rule compliance, robustness, survival, reproducibility.
- Not the North Star (milestones only, never reported as final success): card created, EA compiled, Q02/Q08/Q14 PASS,
  portfolio admission, Demo profitable, Challenge PASS, Verification PASS, FTMO Account received.

**Current value (2026-09-18):** 0 USD. No paid Challenge purchased. Ledger empty.

## 2. Primary pre-payout control KPI — `P_FIRST_NET_FTMO_PAYOUT_LCB`

A conservative lower-confidence-bound estimate of the probability that a **fresh, frozen, fixed** FTMO configuration
(exact EA/EX5/setfile hashes, symbols, weights, risk policy) reaches its first positive net cash payout without breaching
an FTMO rule, evaluated under the currently bound official rule snapshot.

### 2.1 Definition

```
P_END_TO_END_FIRST_PAYOUT
  = P_CHALLENGE_PASS
  * P_VERIFICATION_PASS | CHALLENGE_PASS
  * P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD | VERIFICATION_PASS
  * P( first reward (after fee refund) > cumulative fees )          # net-positive condition

P_FIRST_NET_FTMO_PAYOUT_LCB = lower bound of the 90% credible interval of P_END_TO_END_FIRST_PAYOUT
```

Each phase probability is a **first-passage** quantity: which event comes first — target reached vs. Daily-Loss or
Max-Loss breach (Phase 1 / Verification), or reward-eligibility reached vs. account breach (funded). Censoring (path
still alive at the horizon) is reported separately and is NOT counted as a pass.

### 2.2 Estimator requirements (binding)

1. Joint portfolio paths from actual per-sleeve trade/equity streams, resampled with dependence-preserving
   calendar-aligned block bootstrap (blocks in business days, `block_len >= 10`), never IID trade shuffling.
2. Serial dependence, cross-strategy dependence and path dependence preserved (same calendar block for all sleeves).
3. Daily Loss and Maximum Loss modelled explicitly against the bound rulepack: equity including floating P/L, swaps and
   commissions; Daily Loss anchored at Europe/Prague midnight balance; Max Loss static vs. initial balance; breach when
   strictly below the limit. Intraday lows via a per-trade MAE proxy at minimum (conservative).
4. Costs: commission, spread, swap and slippage from the venue cost model; report at least the scenarios
   `cost x1.0 / x1.5` and `slippage 0 / 1 / 2 USD per lot`.
5. Correlated open risk: simultaneous positions across sleeves counted jointly; the account-level risk contract binds.
6. Uncertainty: every probability carries a credible interval (bootstrap over path sets, n_paths >= 10,000, fixed seed
   recorded); `_LCB` is the reported control value.
7. Verification and funded stages use the SAME frozen configuration; funded-stage survival horizon = time to the first
   reward-eligible date under the bound payout rule plus the payout request/processing lag.
8. Minimum trading-day requirement (currently 4 per phase) checked on the simulated paths.
9. Never redefine the estimator to rescue a candidate. Changes require: hypothesis, independent critique, new version
   number here, and re-computation of all currently reported values under both versions once.

### 2.3 Supporting metrics (reported alongside, not competing KPIs)

`P_CHALLENGE_PASS`, `P_VERIFICATION_PASS`, `P_FIRST_REWARD`, `P_DAILY_LOSS_BREACH`, `P_MAX_LOSS_BREACH`,
`EXPECTED_TIME_TO_TARGET` (p10/p50/p90 business days), `EXPECTED_TIME_TO_FIRST_REWARD`, `TRADE_DENSITY`
(entries per trading day), `RULE_HEADROOM` (worst simulated day loss / 5%, worst DD / 10%), `COST_SENSITIVITY`
(delta of P_CHALLENGE_PASS between cost x1.0 and x1.5), `TAIL_DEPENDENCE` (lower-tail overlap of sleeve daily P/L),
`PORTFOLIO_CONCENTRATION` (share of P/L from the top sleeve / top symbol). No further KPIs without a contract change.

### 2.4 Current implementation state (2026-09-18)

- Engine: `tools/strategy_farm/ftmo/first_passage.py` → read-model `D:/QM/reports/state/ftmo_first_passage.json`
  (schema `qm.ftmo-first-passage/v1`), manifest `ftmo_first_passage_manifest.json`. Implements: seeded calendar-aligned
  block bootstrap (10,000 paths, block 10 business days), bound rulepack `FTMO_2S_100K_STANDARD_V2`, Daily/Max-Loss
  breach with MAE intraday proxy, five cost/slippage scenarios, Phase-1 target passage and time distribution.
- **GAP (P0 per directive §29):** the engine models Phase 1 only. Verification chaining, funded-stage survival to first
  reward, the net-positive fee condition, credible intervals over path sets and the minimum-trading-day check are not
  implemented. Therefore `P_FIRST_NET_FTMO_PAYOUT_LCB` = **NOT_COMPUTED** until the chain exists.
- Latest Phase-1 figures for the CURRENT demo roster (8 sleeves, 0.3125% risk each; read-model 2026-09-17T23:52Z):
  P(target hit within horizon) 0.816 · P(max-loss breach) 0.024 · P(daily-loss breach) 0.0 · censored 0.159 ·
  P(pass within 60 calendar days) 0.0004 · median business days to target 439. Interpretation: this roster is not
  breach-prone but far too slow to be a purchase candidate; speed, not survival, is its binding constraint.

## 3. Reporting

- Daily FTMO War Room (Vault `08 Current State/FTMO War Room.md`) shows both KPIs, their as-of timestamps, the frozen
  configuration hash they refer to, and the estimator version.
- Weekly operating review asks: are we objectively closer to a real payout, or merely busier?
- Language: probability, robustness, evidence quality. No promises of profit, pass, or payout.

## Changelog

- v1 (2026-09-18, Fable): initial contract under OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917.
