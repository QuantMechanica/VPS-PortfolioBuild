# QM5_10821_tv-wpr-zone - Strategy Spec

**EA ID:** QM5_10821
**Slug:** `tv-wpr-zone`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades a Williams %R zone-cross scalper on M5. A long signal occurs when Williams %R(14) crosses up through -80 on the last closed bar; a short signal occurs when Williams %R(14) crosses down through -20. The baseline requires the selected MA trend filter, Choppiness Index filter, and broker tick-volume filter to agree with the direction, with optional Bollinger Band Width and SuperTrend filters exposed for later parameter tests. Entries use market orders with an ATR(14) bracket: stop at 1.5 * ATR and target at 2.0 * ATR; an opposite Williams %R signal is used as a discretionary exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_length` | 14 | 14-34 | Williams %R lookback length. |
| `strategy_use_ma_filter` | true | true/false | Enable selected MA trend filter. |
| `strategy_ma_method` | 0 | 0-1 | MA method: 0 = EMA, 1 = SMA. |
| `strategy_ma_length` | 20 | 20-50 | MA trend-filter length. |
| `strategy_use_chop_filter` | true | true/false | Enable Choppiness Index regime filter. |
| `strategy_chop_length` | 12 | 12+ | Choppiness Index lookback. |
| `strategy_chop_threshold` | 38.2 | 38.2-42.0 | Trade only when CI is below this threshold. |
| `strategy_use_volume_filter` | true | true/false | Enable broker tick-volume filter. |
| `strategy_volume_ma_length` | 50 | 50+ | Tick-volume moving average length. |
| `strategy_volume_ratio` | 1.0 | 1.0-1.2 | Require volume above MA times this ratio. |
| `strategy_use_bbw_filter` | false | true/false | Enable optional Bollinger Band Width expansion filter. |
| `strategy_bbw_period` | 20 | 10+ | Bollinger period for BBW filter. |
| `strategy_bbw_deviation` | 2.0 | >0 | Bollinger deviation for BBW filter. |
| `strategy_bbw_ma_length` | 20 | 10+ | Moving-average length for BBW comparison. |
| `strategy_use_supertrend` | false | true/false | Enable optional SuperTrend direction filter. |
| `strategy_supertrend_atr` | 10 | 10+ | SuperTrend ATR period. |
| `strategy_supertrend_factor` | 3.0 | >0 | SuperTrend ATR multiplier. |
| `strategy_supertrend_bars` | 80 | 20+ | Bounded SuperTrend recursion depth. |
| `strategy_atr_period` | 14 | 14+ | ATR period for bracket stop and target. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Initial stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | 2.0 | >0 | Initial target distance in ATR multiples. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX forex major in the card's P2 basket.
- `GBPUSD.DWX` - liquid DWX forex major in the card's P2 basket.
- `USDJPY.DWX` - liquid DWX forex major in the card's P2 basket.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's XAUUSD target.
- `GDAXI.DWX` - canonical DWX DAX symbol replacing the card's unavailable `GER40.DWX`.
- `NDX.DWX` - liquid DWX Nasdaq 100 index in the card's P2 basket.
- `WS30.DWX` - liquid DWX Dow 30 index in the card's P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; registered as `GDAXI.DWX`.
- `XAUUSD` - no unsuffixed research/backtest symbol; registered as `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Scalping oscillator strategy with ATR-normalized bracket losses. |
| Regime preference | Momentum-reversal in non-choppy, active-volume conditions. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://my.tradingview.com/script/TJuVmOfk-Williams-R-Zone-Scalper-v1-0-BullByte/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10821_tv-wpr-zone.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | 39c4f045-6286-4c3a-8bb5-cec80534566b |

