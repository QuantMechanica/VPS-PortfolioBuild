# QM5_9997_tv-pmax-atr-ma-flip - Strategy Spec

**EA ID:** QM5_9997
**Slug:** `tv-pmax-atr-ma-flip`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the TradingView PMax rule on closed H1 bars. It computes a moving average of close, default VWMA(10), then builds upper and lower ATR bands around that average using ATR(10) times 3.0. The bands ratchet like a SuperTrend line, and the trend flips long when the MA crosses above the previous upper trail or short when the MA crosses below the previous lower trail. On each flip the EA closes any opposite position for this magic and opens the new direction at market with a static ATR catastrophic stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_len` | 10 | 2+ | Moving-average length used as the PMax price proxy. |
| `strategy_ma_type` | `STRATEGY_MA_VWMA` | SMA, EMA, VWMA, WMA | Moving-average type for the PMax proxy. |
| `strategy_atr_len` | 10 | 1+ | ATR length for PMax bands and ATR stop/target distances. |
| `strategy_pmax_atr_mult` | 3.0 | >0 | ATR multiplier for the PMax ratchet bands. |
| `strategy_sl_atr_mult` | 2.0 | >0 | Static catastrophic stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | 0.0 | 0=off, >0 enabled | Optional ATR take-profit distance. |
| `strategy_volatility_gate` | false | true/false | Optional gate requiring ATR now to exceed ATR 20 bars ago. |
| `strategy_spread_sl_fraction` | 0.25 | >=0 | Blocks entries only when positive spread exceeds this fraction of SL distance. |
| `strategy_time_stop_bars` | 0 | 0=off, >0 enabled | Optional maximum holding time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - explicit FX target in the approved card.
- `GBPUSD.DWX` - explicit FX target in the approved card.
- `USDJPY.DWX` - explicit FX target in the approved card.
- `XAUUSD.DWX` - explicit metals target in the approved card.
- `XTIUSD.DWX` - explicit crude oil target in the approved card.
- `NDX.DWX` - explicit US index target in the approved card.
- `WS30.DWX` - explicit US index target in the approved card.
- `SP500.DWX` - approved supplementary backtest symbol from the card and DWX matrix.

**Explicitly NOT for:**
- `SPX500.DWX` - not the canonical available S&P 500 custom symbol.
- `SPY.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Hours to several days, until opposite PMax flip or optional time stop |
| Expected drawdown profile | Trend-following whipsaw drawdown bounded per trade by the ATR catastrophic SL |
| Regime preference | Volatility-expansion trend and sustained directional movement |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView community script
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9997_tv-pmax-atr-ma-flip.md`; TradingView PMax by Kivanc Ozbilgic, https://www.tradingview.com/script/sU9molfV/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9997_tv-pmax-atr-ma-flip.md`

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
| v1 | 2026-06-20 | Initial build from card | e4547990-fbde-4122-87e4-1aac8e024cdf |
