# QM5_4007_index-mac5-rev — Strategy Spec

**EA ID:** QM5_4007  
**Slug:** `index-mac5-rev`  
**Strategy ID:** `SRC10_S01`  
**Source:** `SRC10` (`strategy-seeds/sources/SRC10/`)  
**Author of this spec:** Development (Codex)  
**Last revised:** 2026-07-17

## 1. Strategy Logic

At the first executable tick of every new broker D1 bar, the EA reads six
valid completed closes and calculates the source-locked driver from the newest
five:

`m = 4*ln(Close[1]/Close[2]) + 3*ln(Close[2]/Close[3]) + 2*ln(Close[3]/Close[4]) + ln(Close[4]/Close[5])`.

`m > 0` targets short, `m < 0` targets long, and machine-zero targets flat.
Only the required position delta is applied. A position already in the target
direction keeps its entry volume and original stop unchanged. A flip closes
the old position, confirms flat, and makes one opposite entry attempt within
900 seconds of `iTime(SP500.DWX, D1, 0)`. Flat, missing, invalid, or stale
targets flatten. Exit rejection retries every five seconds until flat; missed
entries are never caught up.

Every new entry receives one catastrophic stop at prior completed D1 ATR(20)
times 2.0. There is no TP, trailing stop, break-even, partial close, position
addition, daily lot recalculation, or stop replacement. A stop deal locks the
current D1 target against re-entry until the next actual broker D1 bar.

Restart reconstruction uses the open position plus current-boundary deal
history. Non-tester attempt/stop latches are additionally persisted under an
account-and-boundary-scoped terminal Global Variable; a persistence failure
blocks the entry.

## 2. Parameters

All alpha and safety parameters are frozen in `OnInit`; changing one produces
`INIT_PARAMETERS_INCORRECT` rather than another selectable strategy variant.

| Parameter | Default | Allowed | Meaning |
|---|---:|---:|---|
| `strategy_atr_period_d1` | 20 | 20 only | Prior completed D1 ATR period |
| `strategy_atr_stop_mult` | 2.0 | 2.0 only | Frozen catastrophic-stop multiple |
| `strategy_application_window_seconds` | 900 | 900 only | Maximum target-application delay from broker D1 timestamp |
| `strategy_exit_retry_seconds` | 5 | 5 only | Minimum retry spacing for mandatory exits |
| `strategy_entry_spread_ceiling_points` | 100 | 100 only | Entry-only ceiling; 1.00 price unit at the two-digit intended FTMO contract |
| `strategy_governor_policy_id` | empty | signed manifest value | Exact allowlisted FTMO V2 policy; empty fails closed outside tester |
| `strategy_challenge_instance_id` | empty | signed manifest value | Exact challenge lineage used in governor state keys |
| `strategy_governor_heartbeat_max_age_seconds` | 5 | 5 only | Maximum stable governor heartbeat age |

The 100-point entry ceiling is a pre-Q02 implementation binding, not a test
axis. Exits never consult spread.

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — sole research and Q02 instrument, registry slot 0, magic
  `40070000`, native D1 history 2018–2026.

**Explicitly not authorized by this build:**

- `SP500` — the existing route proof is Darwinex Zero only.
- `US500.cash` — intended FTMO contract, but deployment still requires separate
  price/session/contract/volume/stop-distance/spread/swap-day/order-routing
  qualification. No evidence is transferred from `SP500.DWX` or `SP500`.
- `GDAXI.DWX` and `NDX.DWX` — card permits falsification research only after
  their own validation; they have no magic slot in this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Signal data | completed broker D1 bars only |
| Decision timestamp | `iTime(_Symbol, PERIOD_D1, 0)` |
| Bar gating | exact D1 timestamp transition plus 900-second application window |
| Civil time / DST conversion | none; broker D1 partition is the contract |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Target evaluations / year | approximately 240–255 |
| Completed trades / year | planning band 48–120; unverified until Q02 |
| Typical hold time | one to several broker D1 bars |
| Expected drawdown profile | gap- and financing-sensitive; losses can jump the 2×ATR stop |
| Regime preference | short-horizon equity-index reversal / liquidity provision |
| Win-rate target | unverified; no build-time performance claim |

Q02 acceptance remains exactly the Card gate: two deterministic 2018–2024
Model-4 runs, net positive, PF at least 1.20 after current FTMO costs, at least
336 completed trades overall and at least 36 in every full calendar year,
plus the frozen spread/commission and swap/weekend stresses. This build runs no
pipeline phase and supplies no Q02 result.

## 6. Source Citation

**Source ID:** `SRC10`  
**Source type:** peer-reviewed paper  
**Citation:** Baltussen, Guido, Sjoerd van Bekkum, and Zhi Da,
“Indexing and Stock Market Serial Dependence Around the World,” *Journal of
Financial Economics*, DOI `10.1016/j.jfineco.2018.07.016`, accepted-manuscript
pages 3–4, 13–19, 32–40, Tables 2–3, Appendix B, especially equations (2) and
(20).  
**Approved card:** `strategy-seeds/cards/index-mac5-rev_card.md`, status
`APPROVED`, independent Quality-Business v3 review `APPROVE`.

The EA is the Card's preregistered sign-only fixed-planned-risk operational
port. It does not claim to replicate the paper's full-sample variance-scaled
target magnitude.

## 7. Risk Model and Governor Contract

| Lifecycle | Risk mode | Full-scale value before governor scale |
|---|---|---:|
| Q02–Q10 research | `RISK_FIXED` | USD 1,000 |
| FTMO 2-Step Phase 1 | `RISK_PERCENT` | exactly 0.15% |
| Verification | `RISK_PERCENT` | exactly 0.105% (70% of Phase 1) |
| Funded | `RISK_PERCENT` | at most 0.10% |

The account governor is bypassed only when `MQLInfoInteger(MQL_TESTER) != 0`;
there is no bypass input. Outside the tester, `OnInit` requires an exact
allowlisted V2 policy ID, valid challenge identity, USD hedging account, and the
policy-specific risk value. Every entry then requires a stable even-generation
snapshot with matching policy version/fingerprint, current Prague day,
heartbeat age no greater than five seconds, unlocked entry state, and a valid
`0 < risk_scale <= 1`. The published scale multiplies the per-call planned risk.
Snapshot failure blocks entries but never blocks mandatory exits.

The EA shares the equity-index cluster; the Card's Phase-1 simultaneous planned
cluster-loss cap remains 0.45%. The central governor and eventual signed deploy
manifest own portfolio aggregation.

## Framework Alignment

| V5 module | Implementation |
|---|---|
| No-Trade | valid quote, frozen entry spread ceiling, exact governor snapshot; entry-only |
| Trade Entry | causal Close[1..5] MAC5 sign and frozen ATR20×2 stop |
| Trade Management | intentionally empty; retained lots and SL are never modified |
| Trade Close | target-delta flatten/reverse, stale restart, invalid target, retry-until-flat |

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-17 | Initial build from approved SRC10_S01 card | EA 4007 / magic 40070000; build-only, no pipeline evidence |
