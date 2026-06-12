# QM5_10289_cinar-cci - Strategy Spec

**EA ID:** QM5_10289
**Slug:** cinar-cci
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades the Cinar CCI plus/minus 100 momentum rule on closed D1 bars. It computes CCI(20) on typical price and opens long when the last closed bar has CCI greater than or equal to +100, or opens short when CCI is less than or equal to -100. If an opposite threshold appears while a position is open, the EA closes that position and the framework then allows the opposite entry on the same closed-bar cycle. The source has no hard stop, so the V5 port adds a catastrophic 2.0 x ATR(14) stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_D1 | MT5 timeframe enum | Signal timeframe from the card. |
| strategy_cci_period | 20 | >= 1 | CCI lookback period. |
| strategy_cci_upper | 100.0 | > strategy_cci_lower | Long entry and short exit threshold. |
| strategy_cci_lower | -100.0 | < strategy_cci_upper | Short entry and long exit threshold. |
| strategy_atr_period | 14 | >= 1 | ATR period for the catastrophic stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiple used for the catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- AUDCHF.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- AUDJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- AUDNZD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- AUDUSD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- CADCHF.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- CADJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- CHFJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURAUD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURCAD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURCHF.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURGBP.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURNZD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- EURUSD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GBPAUD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GBPCAD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GBPCHF.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GBPJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GBPNZD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GBPUSD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- GDAXI.DWX - Liquid DWX index CFD; CCI uses only OHLC typical price.
- NDX.DWX - Liquid DWX index CFD; CCI uses only OHLC typical price.
- NZDCAD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- NZDCHF.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- NZDJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- NZDUSD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- SP500.DWX - Available S&P 500 custom symbol for backtest-only index exposure.
- UK100.DWX - Liquid DWX index CFD; CCI uses only OHLC typical price.
- USDCAD.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- USDCHF.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- USDJPY.DWX - Liquid DWX forex pair; CCI uses only OHLC typical price.
- WS30.DWX - Liquid DWX index CFD; CCI uses only OHLC typical price.
- XAGUSD.DWX - DWX metal CFD; CCI uses only OHLC typical price.
- XAUUSD.DWX - DWX metal CFD; CCI uses only OHLC typical price.

**Explicitly NOT for:**
- XNGUSD.DWX - Energy CFD, excluded because the card names FX, metals, and index CFDs.
- XTIUSD.DWX - Energy CFD, excluded because the card names FX, metals, and index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Days; exits on opposite +/-100 CCI threshold or ATR stop. |
| Expected drawdown profile | Momentum reversals can give abrupt stop-outs; catastrophic stop is 2.0 x ATR(14). |
| Regime preference | Momentum / oscillator-breakout regimes with strong CCI displacement. |
| Win rate target (qualitative) | Medium; stop-and-reverse systems can rely on occasional extended runs. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/trend/cci_strategy.go and https://github.com/cinar/indicator/blob/master/trend/cci.go
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10289_cinar-cci.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3%-0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | a990a916-3710-4c00-ac65-9cf1772799ed |
