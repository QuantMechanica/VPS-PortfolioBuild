# QM5_10647_tv-crypto-st - Strategy Spec

**EA ID:** QM5_10647
**Slug:** `tv-crypto-st`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA trades on closed M15 bars. It calculates Bollinger Band Width and treats the market as trending when current BBW is above its base moving average. It calculates a core SuperTrend direction and opens long when SuperTrend flips from bearish to bullish during a trending BBW state, or short when it flips from bullish to bearish during a trending BBW state. It exits on an opposite SuperTrend direction, on the framework Friday close, or after 96 M15 bars if no flip occurs.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M15` | M15 primary | Signal timeframe from the card. |
| `strategy_supertrend_atr_period` | `10` | 1-100 | ATR period for the SuperTrend band. |
| `strategy_supertrend_mult` | `3.0` | 0.1-10.0 | ATR multiplier for the SuperTrend band. |
| `strategy_supertrend_warmup_bars` | `80` | 30-300 | Closed-bar history used to stabilize SuperTrend state. |
| `strategy_bbw_period` | `20` | 2-200 | Bollinger period used for BBW. |
| `strategy_bbw_deviation` | `2.0` | 0.1-5.0 | Bollinger deviation used for BBW. |
| `strategy_bbw_ma_period` | `20` | 1-200 | Moving average length for the BBW trend-state baseline. |
| `strategy_emergency_atr_period` | `14` | 1-100 | ATR period for the emergency stop. |
| `strategy_emergency_atr_mult` | `3.0` | 0.1-10.0 | ATR multiplier for the emergency stop. |
| `strategy_max_hold_bars` | `96` | 1-500 | Maximum holding time in M15 bars before forced strategy exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - matrix-present DAX/Germany index equivalent for the card-stated `GER40.DWX`.
- `NDX.DWX` - card-stated volatile US index CFD.
- `XAUUSD.DWX` - card-stated volatile gold CFD.
- `EURUSD.DWX` - card-stated liquid FX CFD.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; this build registers `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | Framework `QM_IsNewBar()` calls `Strategy_EntrySignal` once per closed chart bar. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday to 96 M15 bars maximum. |
| Expected drawdown profile | Trend-following drawdowns during BBW compression/chop and false SuperTrend flips. |
| Regime preference | Volatility-expansion trend-following. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView script
**Pointer:** TradingView script `@santoshpsiii Crypto Algo`, author handle `smvdtravelsolutions`, https://www.tradingview.com/script/9x9ohJ2R-santoshpsiii-Crypto-Algo/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10647_tv-crypto-st.md`

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
| v1 | 2026-05-31 | Initial build from card | 91b95a18-90e0-48c1-91c8-02c162352e9c |
