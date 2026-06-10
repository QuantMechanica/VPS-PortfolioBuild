# QM5_10123_don20-break - Strategy Spec

**EA ID:** QM5_10123
**Slug:** `don20-break`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA trades a 20-day Donchian channel breakout on D1 bars. It enters long when the last completed daily close is above the prior 20-bar channel high, using a channel that excludes the breakout bar to avoid lookahead. The default mode is long-only; when the short input is enabled, the symmetric close below the prior 20-bar channel low can open a short. Long positions close when the last completed daily close is below the prior 20-bar channel low, and short positions close when the last completed daily close is above the prior 20-bar channel high. A 3 x ATR(14) emergency stop is placed at entry for MT5 risk containment.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_period` | 20 | 10-55 tested by card | Completed daily bars used for the Donchian high/low channel. |
| `strategy_shorts_enabled` | false | false/true | Enables the optional short breakout and short exit/reversal logic. |
| `strategy_atr_period` | 14 | positive integer | ATR lookback for the emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 tested by card | ATR multiple used for the emergency stop distance. |
| `strategy_use_previous_bar_channel` | true | true only for baseline | Requires the prior-channel calculation that avoids lookahead. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

The card is symbol-agnostic and states that the OHLC-only rule is portable to DWX FX, metals, oil, and indices. The registered universe therefore uses the full available DWX basket in `dwx_symbol_matrix.csv`.

**Designed for:**
- `AUDCAD.DWX` - DWX forex cross with daily OHLC history.
- `AUDCHF.DWX` - DWX forex cross with daily OHLC history.
- `AUDJPY.DWX` - DWX forex cross with daily OHLC history.
- `AUDNZD.DWX` - DWX forex cross with daily OHLC history.
- `AUDUSD.DWX` - DWX forex pair with daily OHLC history.
- `CADCHF.DWX` - DWX forex cross with daily OHLC history.
- `CADJPY.DWX` - DWX forex cross with daily OHLC history.
- `CHFJPY.DWX` - DWX forex cross with daily OHLC history.
- `EURAUD.DWX` - DWX forex cross with daily OHLC history.
- `EURCAD.DWX` - DWX forex cross with daily OHLC history.
- `EURCHF.DWX` - DWX forex cross with daily OHLC history.
- `EURGBP.DWX` - DWX forex cross with daily OHLC history.
- `EURJPY.DWX` - DWX forex cross with daily OHLC history.
- `EURNZD.DWX` - DWX forex cross with daily OHLC history.
- `EURUSD.DWX` - DWX forex pair with daily OHLC history.
- `GBPAUD.DWX` - DWX forex cross with daily OHLC history.
- `GBPCAD.DWX` - DWX forex cross with daily OHLC history.
- `GBPCHF.DWX` - DWX forex cross with daily OHLC history.
- `GBPJPY.DWX` - DWX forex cross with daily OHLC history.
- `GBPNZD.DWX` - DWX forex cross with daily OHLC history.
- `GBPUSD.DWX` - DWX forex pair with daily OHLC history.
- `GDAXI.DWX` - DWX equity index with daily OHLC history.
- `NDX.DWX` - DWX equity index with daily OHLC history.
- `NZDCAD.DWX` - DWX forex cross with daily OHLC history.
- `NZDCHF.DWX` - DWX forex cross with daily OHLC history.
- `NZDJPY.DWX` - DWX forex cross with daily OHLC history.
- `NZDUSD.DWX` - DWX forex pair with daily OHLC history.
- `SP500.DWX` - DWX S&P 500 custom symbol, valid for backtest-only daily OHLC.
- `UK100.DWX` - DWX equity index with daily OHLC history.
- `USDCAD.DWX` - DWX forex pair with daily OHLC history.
- `USDCHF.DWX` - DWX forex pair with daily OHLC history.
- `USDJPY.DWX` - DWX forex pair with daily OHLC history.
- `WS30.DWX` - DWX equity index with daily OHLC history.
- `XAGUSD.DWX` - DWX metal symbol with daily OHLC history.
- `XAUUSD.DWX` - DWX metal symbol with daily OHLC history.
- `XNGUSD.DWX` - DWX energy symbol with daily OHLC history.
- `XTIUSD.DWX` - DWX oil symbol with daily OHLC history.

**Explicitly NOT for:**
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data is registered for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Expected trade frequency | not specified in card frontmatter; inferred low frequency from 10 trades/year/symbol |
| Typical hold time | not specified in card frontmatter; expected multi-day trend holds until opposite Donchian exit |
| Expected drawdown profile | not specified in card frontmatter; bounded per trade by fixed-risk sizing and emergency ATR stop |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** blog tutorial
**Pointer:** `https://raposa.trade/blog/three-strategies-for-trading-the-donchian-channel-in-python/` and mirror `https://readmedium.com/use-python-to-trade-the-donchian-channel-6bf59d0bc740`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10123_don20-break.md`

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
| v1 | 2026-06-10 | Initial build from card | 6f483e27-dfcf-4354-ac6b-b64d6c305e61 |
