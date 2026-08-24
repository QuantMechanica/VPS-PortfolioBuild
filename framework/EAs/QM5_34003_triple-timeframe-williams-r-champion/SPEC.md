# QM5_34003_triple-timeframe-williams-r-champion - Strategy Spec

**EA ID:** QM5_34003
**Slug:** triple-timeframe-williams-r-champion
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_34003_triple-timeframe-williams-r-champion.md`
**Last revised:** 2026-08-24

## 1. Strategy Logic

The EA evaluates closed bar `[1]` only. H4 and H1 Williams %R establish trend
direction; M15 Williams %R identifies the pullback entry.

- Long: WPR(14,H4) >= -35, WPR(14,H1) >= -50, WPR(14,M15) <= -80.
- Short: WPR(14,H4) <= -65, WPR(14,H1) <= -50, WPR(14,M15) >= -20.
- Initial SL: 1.5 * ATR(14,M15)[1].
- Initial TP: 2.5 * initial SL distance.
- Maximum one open position for the EA magic.

The card mentions break-even and trailing states but supplies no numerical
activation rule. The EA therefore does not invent either mechanism; the exact
card SL and TP remain broker-side.

No-trade and capital-preservation rules:

- Block new entries from 23:55 through 00:05 UTC, using `QM_BrokerToUTC`.
- Block when spread exceeds 1.8 * ATR(14,M15)[1].
- Block after daily realized loss reaches 2.0% of start-of-day balance.
- Flatten/halt at 2.5% daily equity drawdown and close/block at 5.0% total
  drawdown from initial session equity.
- Convert the card's three-tick slippage ceiling to points through
  `QM_EntryConfigure`.

Management and hard exits run before entry-only news, rollover, spread, and
signal gates.

## 2. Parameters

| Input | Default | Purpose |
|---|---:|---|
| `strategy_wpr_period` | 14 | Williams %R lookback on H4/H1/M15 |
| `strategy_h4_trend_long` | -35.0 | Long H4 threshold |
| `strategy_h4_trend_short` | -65.0 | Short H4 threshold |
| `strategy_h1_trend_mid` | -50.0 | H1 trend threshold |
| `strategy_m15_pullback_long` | -80.0 | Long M15 pullback threshold |
| `strategy_m15_pullback_short` | -20.0 | Short M15 pullback threshold |
| `strategy_atr_period` | 14 | Stop-distance ATR lookback |
| `strategy_sl_atr_mult` | 1.5 | Initial stop ATR multiple |
| `strategy_tp_rr_mult` | 2.5 | Reward/risk multiple |
| `strategy_spread_atr_period` | 14 | Spread-filter ATR lookback |
| `strategy_spread_atr_mult` | 1.8 | Spread-filter ATR multiple |
| `strategy_max_open_positions` | 1 | EA-magic position ceiling |
| `strategy_max_slippage_ticks` | 3 | Market-entry deviation ceiling |
| `strategy_daily_loss_halt_pct` | 2.0 | Realized-loss entry halt |
| `strategy_daily_hard_stop_pct` | 2.5 | Daily equity hard stop |
| `strategy_total_dd_stop_pct` | 5.0 | Total equity drawdown stop |

Every input is consumed by executable source and sealed into all three
backtest setfiles.

## 3. Symbol Universe

| Symbol | Magic slot |
|---|---:|
| EURUSD.DWX | 0 |
| GBPUSD.DWX | 1 |
| USDCHF.DWX | 2 |

No other symbols are authorized by the approved card or registry rows.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe references | H4, H1, M15 |
| Decision shift | Closed bar `[1]` |
| Entry gate | `QM_IsNewBar(_Symbol, PERIOD_M15)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades/year/symbol | 110 ordering prior; Q02 measures reality |
| Typical holding period | Intraday to multi-day |
| Preferred regime | Trend with M15 pullback |
| Concurrency | One position per EA magic |

## 6. Source Citation

Alexey Bobylov (Better), *Automated Trading Championship 1st Place Winner
Report* (2007), as authenticated by the approved G0 Strategy Card named above.

## 7. Risk Model

- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live packaging: positive `RISK_PERCENT` and `RISK_FIXED=0`; live use is not
  authorized by this build.
- V5 umbrella include only: `QM/QM_Common.mqh`.
- Magic is resolved by the framework/MagicResolver for slots 0-2.
- Entry uses `QM_TM_OpenPosition`; MAE uses
  `QM_FrameworkTrackOpenPositionMae`; indicators use pooled `QM_WPR`/`QM_ATR`.
