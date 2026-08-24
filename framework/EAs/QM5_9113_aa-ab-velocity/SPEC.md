# QM5_9113_aa-ab-velocity — Strategy Spec

**EA ID:** QM5_9113
**Slug:** aa-ab-velocity
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Approved card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9113_aa-ab-velocity.md
**Last revised:** 2026-08-24

## 1. Strategy Logic

The EA applies Henry Stern's alpha-beta tracking filter recursively to completed
D1 closes. The state is seeded once from the first available completed close,
reconstructed from that same history on restart, and then advanced exactly once
for every unseen completed D1 bar.

For each completed close `Close_t`:

1. Predict position: `x_hat_t = x_(t-1) + v_(t-1)`.
2. Compute residual: `r_t = Close_t - x_hat_t`.
3. Update position: `x_t = x_hat_t + alpha * r_t`.
4. Update velocity: `v_t = v_(t-1) + beta * r_t`.

The fixed card constants are `alpha = 0.29896` and `beta = 0.05295`. Long entry
requires a completed-bar velocity cross from non-positive to positive. Optional
short mode requires the opposite cross. A held long exits when the cached
completed-bar velocity is negative; a held short exits when it is positive.
Keeping the sign-based exit intent latched permits a failed close to retry on
later ticks without recalculating history.

The initial stop is `3.0 * ATR(20, D1)` through `QM_StopATR`. Entries require one
position per symbol/magic, at least 120 processed D1 closes, and a valid current
spread no greater than `2.5 *` the exact 20-completed-D1-bar median spread.
Incomplete or non-positive spread evidence blocks entry.

Friday close, open-position management, and the cached strategy exit execute
before the news and spread entry gates.

## 2. Parameters

| Parameter | Default | Contract use |
|---|---:|---|
| `strategy_alpha` | 0.29896 | Recursive position update |
| `strategy_beta` | 0.05295 | Recursive velocity update |
| `strategy_atr_period` | 20 | Initial ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | Initial ATR stop multiplier |
| `strategy_min_warmup_bars` | 120 | Minimum processed completed D1 closes |
| `strategy_enable_shorts` | false | Enables opposite-cross short entries and exits |

Framework inputs retain their V5 roles. Backtest sets bind `RISK_FIXED=1000` and
`RISK_PERCENT=0`; a governed live set would bind `RISK_FIXED=0` and the card's
`RISK_PERCENT=0.5`.

## 3. Symbol Universe

The governed slots are GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX, WS30.DWX,
XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX,
USDCAD.DWX, and NZDUSD.DWX. Each has an active `(ea_id, symbol_slot)` row in
`framework/registry/magic_numbers.csv`.

SP500.DWX remains backtest-only unless the approved card's parallel-validation
condition is satisfied before any T6 promotion.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe reads | None |
| Runtime declaration | `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` |
| Signal refresh | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

Raw series reads are bounded, array-size guarded, and confined to restart or D1
new-bar state refresh. Entry and exit hooks read the cached recursive snapshot.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | Approximately 3–8 |
| Typical hold | Approximately 15–60 days |
| Preferred regime | Persistent trends |
| Baseline mode | Long/cash |
| Optional P2 mode | Long/short |

These figures are expectations, not gate thresholds or claimed test results.

## 6. Source Citation

Henry Stern, “Trend-Following Filters: Part 1/2,” Alpha Architect,
2020-12-29: https://alphaarchitect.com/trend-following-filters-part-1-2/

Source ID: `ede348b4-0fa7-5be1-baa8-09e9089b67b7`. The approved card records
`g0_status: APPROVED` and R1–R4 PASS.

## 7. Risk Model

The EA delegates sizing to the V5 framework. Backtest defaults are
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1.0`. Live mode is not
authorized by this build; if separately governed, it uses the mutually exclusive
live contract `RISK_FIXED=0`, `RISK_PERCENT=0.5`.

Every entry includes the card's initial `3.0 * ATR(20, D1)` stop. The framework
MAE hook runs every tick, magic is resolved through `QM_FrameworkMagic()`, and no
ML, online adaptation, grid, or martingale mechanism is present.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Initial Gemini draft for independent review |
| v2 | 2026-08-24 | Rebuilt recursive state, exit ordering, spread fail-close, and clean text |
