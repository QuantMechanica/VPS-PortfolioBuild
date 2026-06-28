# QM5_12755_wti-spr-refill-bounce - Strategy Spec

**EA ID:** QM5_12755
**Slug:** `wti-spr-refill-bounce`
**Source:** `DOE-WTI-SPR-REFILL-2024`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI policy-zone reclaim bounce on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the prior
completed D1 bar probes the DOE SPR refill price zone and then closes back above
that zone with bullish close-location and ATR-distance confirmation. The
position is flattened when price reaches the rebound exit level, loses the
failed-reclaim level, or the fixed max-hold guard is reached.

The strategy is intentionally not a duplicate of the existing commodity family:
XAU/XAG ratio cards trade precious-metal relative value, XTI/XNG cards trade
energy spreads, XNG RSI/storage/weather cards trade natural gas, and the WTI
WPSR, hurricane, refinery, OPEC, ETF-roll, month/weekday, CAD/oil, and momentum
cards use different information sets or timing rules.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_refill_zone_price` | 79.00 | 77.00-80.00 | DOE SPR refill-zone reference price |
| `strategy_zone_buffer_price` | 1.50 | 0.75-2.50 | Allowed probe cushion above the refill-zone reference |
| `strategy_max_entry_price` | 81.00 | 80.00-82.50 | Maximum prior close for a near-zone entry |
| `strategy_rebound_exit_price` | 85.00 | 83.00-88.00 | Prior close rebound level that exits the long |
| `strategy_failed_reclaim_price` | 76.00 | 74.00-77.50 | Prior close level that invalidates the reclaim |
| `strategy_min_close_location` | 0.60 | 0.55-0.70 | Minimum close location inside the prior D1 range |
| `strategy_min_reclaim_atr` | 0.25 | 0.15-0.40 | Minimum low-to-close reclaim distance in ATR units |
| `strategy_atr_period` | 20 | 14-30 | ATR period for confirmation and hard stop |
| `strategy_atr_sl_mult` | 2.75 | 2.00-3.50 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 12 | 8-18 | Calendar-day stale-position guard |
| `strategy_cooldown_days` | 10 | 5-15 | Minimum calendar days between entry signals |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-10.
- Typical hold: 2-12 D1 bars.
- Regime preference: WTI tests and reclaims the SPR refill price zone instead
  of continuing lower through it.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Department of Energy / CESER, Strategic Petroleum Reserve purchase
solicitations and replenishment strategy, URLs
https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-1
and
https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-7.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

