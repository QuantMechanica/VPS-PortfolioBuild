# QM5_20185_wti-win-bearfade — Strategy Spec

**EA ID:** QM5_20185

**Slug:** `wti-win-bearfade`

**Source:** `BURAKOV-MOP-WTI-WINBEAR-2026`

**Author:** Codex

**Last revised:** 2026-07-31

## 1. Strategy Logic

On the first tradable D1 bar of each broker-calendar week from November
through May, calculate WTI's completed 252-D1 log return. Open one long
`XTIUSD.DWX` position only when that return is strictly negative.

The package has a frozen `3.0 * ATR(20)` hard stop, no profit target, and a
seven-day stale guard. Framework Friday close at broker hour 21 is the
ordinary exit. Consume the broker week before fallible gates so no blocked or
flat attempt can retry after a restart.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_start_month` | 11 | First winter month |
| `strategy_end_month` | 5 | Final winter month |
| `strategy_momentum_lookback_d1` | 252 | Completed state horizon |
| `strategy_min_abs_return_pct` | 0.0 | Strict negative sign |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 7 | Weekly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum entry spread |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact symbol: `XTIUSD.DWX`.
- Magic slot: 0 (`201850000`).
- No cross-symbol or external runtime dependency.

## 4. Timeframe

- Exact timeframe: D1.
- Bar gate: framework `QM_IsNewBar()`.

## 5. Expected Behaviour

Expected cadence is approximately 5-14 completed packages per year after
warm-up; Q02 retires below five/year. Typical exposure runs from the first
weekly D1 bar to Friday close. Primary risks are WTI downside continuation,
gaps, CFD roll/basis, financing, conditional density, and source decay.

## 6. Source Citation

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINBEAR-2026/source.md`; the approved
card is
`strategy-seeds/cards/approved/QM5_20185_wti-win-bearfade_card.md`.

Burakov et al. supply the WTI November-May long regime. Moskowitz, Ooi, and
Pedersen supply the completed trailing-return state. Their conjunction is a
QM falsification hypothesis, not a source performance claim.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. There is no live setfile, live authorization, deploy
manifest, portfolio admission, or portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from approved G0 card | Q01 PASS |
| v1-q02 | 2026-07-31 | Canonical build record | Q02 work item `7639ee30-e765-4211-b276-97a779730a90` active |
