# QM5_10470_mql5-adxmacd - Strategy Spec

**EA ID:** QM5_10470
**Slug:** `mql5-adxmacd`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades an H1 ADX and MACD trend-confirmation rule. It enters long when MACD main and signal have both risen over the configured MACD bar interval, ADX has risen over the configured ADX bar interval, and ADX is above 20. It enters short when MACD main and signal have both fallen over the configured interval while ADX is rising and above 20. Each trade uses a 1.5 x ATR(14) stop, a 2R take profit, and exits early if the opposite full setup appears first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 1+ and less than slow | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_macd_price` | `PRICE_CLOSE` | MT5 applied price enum | Price source for MACD. |
| `strategy_macd_bars` | 3 | 1+ | Number of closed bars over which MACD main and signal must move. |
| `strategy_adx_period` | 14 | 1+ | ADX lookback period. |
| `strategy_adx_bars` | 3 | 1+ | Number of closed bars over which ADX must rise. |
| `strategy_adx_min` | 20.0 | greater than 0 | Minimum ADX strength threshold. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for stop placement. |
| `strategy_atr_sl_mult` | 1.5 | greater than 0 | Stop distance as ATR multiple. |
| `strategy_tp_rr` | 2.0 | greater than 0 | Take-profit distance in R multiples. |
| `strategy_min_bars` | 80 | 1+ | Minimum local bar count before trading. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX FX major.
- `GBPUSD.DWX` - liquid DWX FX major.
- `USDJPY.DWX` - liquid DWX FX major.
- `USDCHF.DWX` - liquid DWX FX major.
- `USDCAD.DWX` - liquid DWX FX major.
- `AUDUSD.DWX` - liquid DWX FX major.
- `NZDUSD.DWX` - liquid DWX FX major.
- `XAUUSD.DWX` - card-stated liquid gold symbol.
- `SP500.DWX` - available US large-cap index CFD/custom symbol.
- `NDX.DWX` - liquid US technology index CFD.
- `WS30.DWX` - liquid US blue-chip index CFD.
- `GDAXI.DWX` - liquid DAX index CFD in the DWX matrix.
- `UK100.DWX` - liquid FTSE index CFD in the DWX matrix.

**Explicitly NOT for:**
- `SPX500.DWX` - unavailable phantom S&P 500 symbol; use `SP500.DWX`.
- `SPY.DWX` - unavailable ETF proxy; use `SP500.DWX`.
- `ES.DWX` - unavailable futures proxy; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Until 2R take profit, ATR stop, Friday close, or opposite full setup; exact hold time is not specified in card frontmatter. |
| Expected drawdown profile | Trend-following drawdowns during low-direction or choppy regimes. |
| Regime preference | Trend-following / momentum-confirmation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** MQL5 CodeBase, "ADX MACD Deev - expert for MetaTrader 5", https://www.mql5.com/en/code/23595
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10470_mql5-adxmacd.md`

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
| v1 | 2026-05-28 | Initial build from card | 27024a6a-b38c-4cf4-8c16-2b9ce526de21 |
