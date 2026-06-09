# QM5_10158_tv-es-wicklength-hold - Strategy Spec

**EA ID:** QM5_10158
**Slug:** `tv-es-wicklength-hold`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long-only on index CFD bars when the last closed candle has unusually large total wick length. The signal candle's upper wick is `high - max(open, close)`, its lower wick is `min(open, close) - low`, and total wick length must exceed the SMA(20) of total wick length plus the configured offset. The entry is a market buy on the next tick after the closed H1 signal bar. Exit is by protective stop or by closing after the configured holding period.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wick_ma_period` | 20 | 1+ | Number of closed bars used for the SMA of total wick length. |
| `strategy_wick_offset` | 0.0 | 0.0+ | Extra wick-length amount required above the SMA before a long entry. |
| `strategy_hold_bars` | 4 | 1+ | Maximum H1 bars to hold before strategy exit. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback used for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | >0.0 | ATR multiple for the protective stop before the signal-candle-low tightening rule. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - primary ES/SPX analog named by R3; backtest-only custom symbol.
- `NDX.DWX` - live-tradable US index fallback named by R3.
- `WS30.DWX` - live-tradable US index fallback named by R3.

**Explicitly NOT for:**
- Any symbol outside the three registered `.DWX` rows above; this card does not authorize a wider basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | 4 H1 bars, or protective-stop exit earlier |
| Expected drawdown profile | Fixed $1,000 risk per backtest trade with ATR or signal-candle-low stop. |
| Regime preference | Candlestick volatility expansion on liquid US index baskets. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/m78ZqKsX/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10158_tv-es-wicklength-hold.md`

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
| v1 | 2026-06-09 | Initial build from card | eb48ddd2-5730-4ff0-ab5e-d6474b47e57f |
