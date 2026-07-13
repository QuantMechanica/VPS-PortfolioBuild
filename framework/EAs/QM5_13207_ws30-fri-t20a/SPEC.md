# QM5_13207_ws30-fri-t20a - Strategy Spec

**EA ID:** QM5_13207  
**Slug:** `ws30-fri-t20a`  
**Derived from:** `QM5_13202_ws30-fri-pm-long`  
**Approved card:** `artifacts/cards_approved/QM5_13207_ws30-fri-t20a.md`  
**Authorization:** Research build only; no inherited pipeline or deployment status.

## 1. Strategy Logic

On Friday at the first tick of the 13:30 New York M15 bar, the EA reads 1921
completed observed `WS30.DWX` M15 closes. The newest endpoint is shift 1 and
the oldest endpoint is shift 1921. Entry is allowed only when
`close(1) / close(1921) - 1 > 0`. Zero, negative, invalid, incomplete, or
unavailable history rejects entry.

The 1920 intervals are observed M15 bars, not calendar time and not D1 bars.
There is no runtime year or 2020 exclusion. The gate applies only to entry and
must not block open-position management or liquidation.

On acceptance, the EA buys at market with a hard stop exactly one simple ATR56
below entry. ATR56 uses true range on shifts 1 through 56. There is no take
profit. The position closes at 16:00 New York and is immediately flattened if
carried into a later New York date. The EA never re-enters on the same New York
date.

## 2. Parameters

| Parameter | Default | Allowed value | Meaning |
|---|---:|---:|---|
| `qm_ea_id` | 13207 | 13207 | Allocated EA identity. |
| `qm_magic_slot_offset` | 0 | 0 | `WS30.DWX` registered slot. |
| `strategy_atr_bars` | 56 | 56 | Completed M15 true-range samples. |
| `strategy_stop_atr` | 1.0 | 1.0 | Hard-stop ATR multiple. |
| `strategy_entry_hhmm_ny` | 1330 | 1330 | New York entry bar. |
| `strategy_exit_hhmm_ny` | 1600 | 1600 | New York liquidation time. |
| `strategy_weekday_ny` | 5 | 5 | Friday in MQL weekday numbering. |

Any mismatch fails initialization. Trend shifts 1 and 1921 are compile-time
constants, not inputs or tuning parameters.

## 3. Symbol Universe

- Designed and registered only for `WS30.DWX`, magic `132070000`, slot 0.
- No other index, FX, metal, energy, broker-native, or live symbol is allowed.
- `.DWX` stripping is outside the research build and is not performed here.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Host timeframe | M15 only |
| Trend source | Same-symbol observed M15 bars |
| Trend newest endpoint | Completed shift 1 |
| Trend oldest endpoint | Completed shift 1921 |
| ATR source | Completed M15 shifts 1-56 |
| Session timezone | DST-correct New York |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Accepted trades/year | Approximately 28 |
| Direction | Long only |
| Typical hold | 13:30 to 16:00 New York |
| Development evidence | 103 trades, current-cost PF 1.583975 |
| Validation 2023 | 28 trades, current-cost PF 1.654964 |
| Opened holdout 2024-2025 | 68 trades, current-cost PF 1.184862 |

The opened holdout is consumed evidence. Further parameter search is forbidden.

## 6. Source Citation

- Parent strategy card: `artifacts/cards_approved/QM5_13202_ws30-fri-pm-long.md`.
- Original session screen: `artifacts/ftmo_m15_session_premium_screen_2026-07-11.json`.
- Locked causal filter screen:
  `artifacts/ftmo_13202_ws30_causal_filter_screen_2026-07-12.json`.
- Candidate evidence contract:
  `artifacts/ftmo_13202_ws30_trend20d_align_candidate_spec_2026-07-12.json`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02-Q10 research | `RISK_FIXED` | 1000 USD canonical |
| Native entry parity diagnostic | `RISK_FIXED` | 100 USD |
| Live | Not authorized | 0 |

`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1` are fixed in research setfiles.
News filtering and generic broker-hour Friday close are disabled for parity.

## 8. Evidence Contract

MQL acceptance must match the hash-frozen 13202-derived entry oracle at the
entry timestamp, endpoint timestamps, endpoint closes, and boolean result.
Aggregate PF or trade-count similarity is insufficient parity evidence.

The new EA begins at Q02 under ID 13207. No Q02-Q10 result from 13202 transfers.

## 9. Boundary

No `T_Live`, AutoTrading change, live setfile, deploy manifest, portfolio
admission, or paid-challenge permission is authorized by this build.
