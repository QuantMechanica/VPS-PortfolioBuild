# QM5_12954_pring-coppock-h4-variant — Strategy Spec

**EA ID:** QM5_12954

**Slug:** `pring-coppock-h4-variant`

**Approved card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12954_pring-coppock-h4-variant.md`

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`

**Last revised:** 2026-08-22

## 1. Strategy Logic

On each new closed H4 bar, calculate two rates of change and smooth their sum
with a linearly weighted moving average:

```text
ROC11[k]   = (Close[k] / Close[k+11] - 1) * 100
ROC14[k]   = (Close[k] / Close[k+14] - 1) * 100
Coppock[k] = WMA(ROC11 + ROC14, 10)
```

The newest member of the WMA window has weight 10 and the oldest has weight 1.
A cross from non-positive to positive opens long; a cross from non-negative to
negative opens short. The EA uses closed bars at shifts 1 and 2, so it never
acts on a forming-bar cross. One position per resolved magic is allowed.

The initial stop is 2.5 ATR(20), with a hard 4.0 ATR cap. There is no take
profit. The stop moves to the entry price after a favorable 2.0 ATR excursion.
The position exits on the opposite Coppock zero cross or after 200 closed H4
bars. New entries are suppressed for the first 35 closed H4 bars after
initialization and when spread exceeds 0.25 ATR(20).

The card requires a high-impact news blackout of at least 15 minutes before
and after an event. The current V5 two-axis enum has no 15-minute mode, so this
EA uses the nearest fail-closed standard mode, 30 minutes before and after. The
blackout is widened, never weakened. Friday liquidation is disabled because it
would replace the card's multi-week hold contract.

## 2. Parameters

| Parameter | Default | Governed bound | Meaning |
|---|---:|---:|---|
| `strategy_roc_short_period` | 11 | positive integer | Short ROC lookback |
| `strategy_roc_long_period` | 14 | positive integer | Long ROC lookback |
| `strategy_wma_period` | 10 | positive integer | WMA smoothing window |
| `strategy_atr_period` | 20 | positive integer | ATR stop/manage/spread basis |
| `strategy_sl_atr_mult` | 2.5 | positive | Initial ATR stop multiplier |
| `strategy_sl_atr_cap` | 4.0 | positive | Maximum applied ATR stop multiplier |
| `strategy_be_trigger_atr` | 2.0 | positive | Favorable excursion that moves SL to entry |
| `strategy_time_stop_bars` | 200 | positive integer | Maximum closed H4 bars in a position |
| `strategy_warmup_bars` | 35 | minimum 35 | Post-initialization entry warm-up |
| `strategy_max_spread_atr` | 0.25 | non-negative | Maximum entry spread as ATR fraction |

Framework inputs retain `RISK_PERCENT=0`, `RISK_FIXED=1000`,
`qm_news_stale_max_hours=336`, temporal news mode 3, DXZ compliance, and the
canonical seed contract in all backtest sets.

## 3. Symbol Universe

The deterministic magic registry allocates these 13 build-time slots:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `GDAXI.DWX` | 129540000 |
| 1 | `NDX.DWX` | 129540001 |
| 2 | `SP500.DWX` | 129540002 |
| 3 | `UK100.DWX` | 129540003 |
| 4 | `WS30.DWX` | 129540004 |
| 5 | `XAUUSD.DWX` | 129540005 |
| 6 | `EURUSD.DWX` | 129540006 |
| 7 | `GBPUSD.DWX` | 129540007 |
| 8 | `USDJPY.DWX` | 129540008 |
| 9 | `USDCHF.DWX` | 129540009 |
| 10 | `AUDUSD.DWX` | 129540010 |
| 11 | `USDCAD.DWX` | 129540011 |
| 12 | `NZDUSD.DWX` | 129540012 |

The card discusses XTIUSD and further index portability, but no corresponding
QM5_12954 magic slots are allocated. This build does not expand the universe or
compute magic values by hand.

## 4. Timeframe

The base and only timeframe is H4. `OnInit()` rejects any other chart period.
The Coppock seed, ATR, bar counter, opposite-cross exit, and time stop all use
`PERIOD_H4` explicitly.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | approximately 18, per approved card |
| Direction | bidirectional |
| Entry cadence | one zero-cross event per closed H4 bar |
| Typical horizon | swing; up to about six weeks via the 200-bar cap |
| Position count | one per resolved magic |
| Pyramiding/grid/martingale | none |
| ML/adaptive logic | none |

No pipeline or profitability verdict is asserted by this build document.

## 6. Source Citation

The approved card binds Martin Pring, *Technical Analysis Explained*, fifth
edition, chapter 13, pages 269–281, and E. S. C. Coppock's 1962 Barron's work
under canonical source ID `6e967762-b26d-59a3-b076-35c17f2e7c36`. The card's
G0 record is `APPROVED`, with R1–R4 each `PASS`.

## 7. Risk Model

| Environment | Active risk | Inactive risk |
|---|---|---|
| Q02–Q10 backtests | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Any separately approved live package | `RISK_PERCENT` | `RISK_FIXED=0` |

The EA delegates lot calculation and order submission to the V5 framework.
Every entry carries an ATR-derived stop, and the source uses
`QM_StopATRFromValue`, `QM_TM_OpenPosition`, and the deterministic magic
resolver rather than inline sizing or hand-built magic arithmetic.

## Framework alignment

| Card rule | Implementation |
|---|---|
| ROC11 + ROC14, WMA10 | `Strategy_CoppockROC`, `Strategy_CoppockValue` |
| Closed-bar zero cross | `Strategy_AdvanceCoppockOnNewBar` |
| Long and short entry | `Strategy_EntrySignal` |
| 2.5 ATR stop, 4 ATR cap | `Strategy_EntrySignal` |
| 2 ATR break-even | `Strategy_ManageOpenPosition` |
| Opposite cross / 200-bar exit | `Strategy_ExitSignal` |
| 35-bar warm-up / 0.25 ATR spread | `Strategy_EntrySignal` |
| Mandatory news blackout | central V5 two-axis news filter |
| One position per magic | `QM_TM_OpenPositionCount(QM_FrameworkMagic())` |

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Replace inert skeleton with card-faithful V5 build |
