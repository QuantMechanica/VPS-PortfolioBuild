# QM5_21523_wti-xau-div-tr - Strategy Spec

**EA ID:** QM5_21523
**Slug:** `wti-xau-div-tr`
**Source:** `MOP-CME-WTI-XAU-DIV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-14

## 1. Strategy Logic

On the first `XTIUSD.DWX` D1 bar after a genuine broker-month transition,
consume one attempt and intersect bounded completed WTI and read-only
`XAUUSD.DWX` D1 histories at exact timestamps. Reconstruct exactly thirteen
consecutive synchronized broker-month endpoints ending in the immediately
completed month, then calculate an independent exact twelve-month log return
for each market.

Buy WTI only when its return is greater than `1e-12` and gold's is less than
`-1e-12`. Sell WTI only for the inverse signs. A deadband, same-sign state,
stale endpoint, or invalid state consumes the month flat. Gold is never
ordered. Every entry has a frozen `3.5*ATR(20,D1)` hard stop, no take-profit,
monthly replacement, and a forty-calendar-day stale exit.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_trend_months` | `12` | `[12]` | Exact completed-month return horizon for both markets |
| `strategy_history_bars_d1` | `600` | `[600]` | Bounded completed-D1 copy per market |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest common endpoint freshness ceiling |
| `strategy_sign_deadband` | `1e-12` | `[1e-12]` | Strict return-sign threshold |
| `strategy_return_tolerance` | `1e-10` | `[1e-10]` | Endpoint-versus-chain equality tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed WTI D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked. No optimization or alternate sign threshold is
authorized.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - the only traded carrier, D1, slot 0, magic `215230000`.
- `XAUUSD.DWX` - synchronized read-only state input; no magic or order authority.

**Explicitly NOT for:**

- Any other symbol - no alternate carrier, hedge leg, ratio basket, or proxy is authorized.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Thirteen synchronized completed broker-month endpoints derived from D1 bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` plus a genuine broker-month change |
| Hold | Until the next month transition, capped at 40 calendar days |

Current D1 prices and incomplete monthly returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 5-8 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse, high-variance single-commodity trend losses bounded by fixed risk and hard stops |
| Regime preference | WTI-specific structural trend while long-horizon gold moves oppositely |
| Win rate target (qualitative) | Low-to-medium; payoff asymmetry must carry economics |

This is a diversification hypothesis relative to the incumbent
XAU/SP500/NDX/XNG book. Q09 alone owns realized portfolio overlap.

## 6. Source Citation

**Source ID:** `MOP-CME-WTI-XAU-DIV-2026`
**Source type:** peer-reviewed paper plus exchange research packet
**Pointer:** `strategy-seeds/sources/MOP-CME-WTI-XAU-DIV-2026/source.md`
**R1-R4 verdict (Q00):** R1 `PASS_WITH_POLICY_DEFER`; R2-R4 `PASS`; see
`strategy-seeds/cards/approved/QM5_21523_wti-xau-div-tr_card.md` and the
durable approval decisions cited there.

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of
Financial Economics 104(2), 228-250, supplies WTI membership, own-return
sign, twelve-month horizon, and monthly cadence. CME Group (2024), *Through
the Lens of Gold*, supplies the structural oil-through-gold relative-value
lens. The exact opposite-sign conjunction is a locked QM hypothesis.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The canonical backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Environment-to-mode validation is enforced by the V5
framework.

## 8. Exact Arithmetic Contract

Intersect completed WTI and gold D1 bars by exact timestamp. Require strict
chronology, positive finite closes, a newest common endpoint before the
decision bar, and no more than ten calendar days stale. Retain the final
common close of each broker month and require the latest thirteen month keys
to be consecutive and end in the immediately completed broker month.

```text
wti_12m = ln(WTI_end_12 / WTI_end_0)
xau_12m = ln(XAU_end_12 / XAU_end_0)
```

For each market, require its endpoint return to equal the sum of its twelve
component monthly log returns within `1e-10`. Strict positive-WTI/negative-
gold maps to long WTI; strict negative-WTI/positive-gold maps to short WTI;
deadband and all other sign states map to flat.

## 9. Non-Duplicate Boundary

Existing oil/gold systems form and trade ratios, breakouts, return spreads,
or two-leg baskets. `QM5_12603_wti-tsmom12m` is unconditional;
`QM5_21516` uses WTI/XNG decoupling, `QM5_21518` same-sign Brent
confirmation, and `QM5_21522` falling WTI/SP500 downside beta. This EA forms
no ratio or basket and cannot order gold. Synchronized monthly endpoints,
strict opposite twelve-month signs, WTI-only execution, and a consumed
monthly attempt are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong endpoint count, timestamp mismatch, nonconsecutive months,
endpoint-chain mismatch, wrong sign or direction, any gold order, repeated
attempt, missing stop, hold beyond forty days, risk mismatch, or
nondeterminism. No rescue parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading
change, deploy manifest, portfolio-gate edit, portfolio admission, or
correlation waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-14 | Initial implementation from approved card | Q01 pending |
| v2 | 2026-08-14 | Validate locked divergence-gated build | Q01 PASS |

## 12. Q01 Status

PASS. The registered one-slot EA reconstructs synchronized WTI/gold
broker-month endpoints, verifies both exact twelve-month returns, admits only
strict opposite signs, consumes the attempt before fallible gates, and manages
one fixed-risk WTI position with a frozen ATR hard stop. Gold remains read-only.

Strict MetaEditor compilation passed with zero errors and warnings. The
targeted build check passed with zero failures and warnings; seven independent
timestamp, calendar, arithmetic, sign, and carrier-separation tests passed;
and P1 found the compiled `.ex5`. No Strategy Tester run was launched during
Q01.
