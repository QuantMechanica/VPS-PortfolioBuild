# QM5_1325_connors-rsi2-fx-intraday-h1 — Strategy Spec

**EA ID:** QM5_1325
**Slug:** `connors-rsi2-fx-intraday-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

ForexFactory intraday-H1 port of the Larry Connors / Cesar Alvarez RSI(2)
short-term mean-reversion rule, run symmetric (BUY+SELL) because FX has no
inherent long-bias. On the close of each H1 bar: go LONG when the macro bias is
bullish (`close > SMA(200)`), the intermediate trend is bullish
(`close > SMA(50)`, optional), and RSI(2) crosses down into the oversold zone
(`RSI(2) < 10` this bar while it was >= 10 the prior bar). Go SHORT on the exact
mirror (`close < SMA(200)`, `close < SMA(50)`, RSI(2) crossing up above 90). The
trigger is the RSI cross-INTO-zone EVENT; the SMA filters are STATES. Exit on
RSI recovery (BUY closes when `RSI(2) > 70`, SELL when `RSI(2) < 30`), or an
SMA(5) cross after at least 2 bars held, or a hard `2 x ATR(14)` stop, or a
24-bar soft time-stop, or a 48-bar hard force-close. After any close a same-
direction signal is re-armed only once RSI(2) crosses back through the 50
midline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 2 | 2-4 | RSI period (Connors signature RSI(2)) |
| `strategy_rsi_oversold` | 10.0 | 5-15 | BUY entry trigger threshold |
| `strategy_rsi_overbought` | 90.0 | 85-95 | SELL entry trigger threshold |
| `strategy_rsi_exit_buy` | 70.0 | 60-80 | BUY recovery exit threshold |
| `strategy_rsi_exit_sell` | 30.0 | 20-40 | SELL recovery exit threshold |
| `strategy_rsi_rearm_level` | 50.0 | 40-60 | RSI midline cross that re-arms a direction |
| `strategy_sma_macro` | 200 | 100-300 | Macro-bias SMA filter |
| `strategy_sma_inter` | 50 | 20-100 | Intermediate-trend SMA filter |
| `strategy_use_inter_filter` | true | true/false | Enable/disable SMA(50) gate (P3 toggle) |
| `strategy_sma_fast` | 5 | 3-10 | Fast SMA for the SMA-cross fallback exit |
| `strategy_sma_fast_min_bars` | 2 | 1-5 | Bars held before SMA-5 exit arms |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the hard SL |
| `strategy_atr_sl_mult` | 2.0 | 1.5-3.0 | Hard SL distance in ATR multiples |
| `strategy_time_stop_bars` | 24 | 12-48 | Soft time-stop (one trading day of H1 bars) |
| `strategy_hard_close_bars` | 48 | 24-96 | Hard force-close ceiling |
| `strategy_spread_median_bars` | 20 | 5-64 | Lookback for median-spread guard |
| `strategy_spread_median_mult` | 1.5 | 1.0-3.0 | Wide-spread multiple of median that blocks entry |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major; tight spread suits a high-frequency H1 mean-reversion edge.
- `GBPUSD.DWX` — liquid major with intraday mean-reverting tendency.
- `USDJPY.DWX` — liquid major; symmetric port handles its directional regimes.
- `AUDUSD.DWX` — major commodity-FX pair, mean-reverts intraday.
- `USDCAD.DWX` — major; oil-correlated but mean-reverts on H1.
- `NZDUSD.DWX` — major commodity-FX pair.
- `XAUUSD.DWX` — gold; card explicitly lists it, strong short-term mean reversion.
- `XTIUSD.DWX` — WTI crude; card explicitly lists it as a non-FX extension.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — the card scopes this H1 port to FX majors + XAU/XTI; the D1 index lineage is the sibling QM5_1235's domain.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` (all SMA/RSI/ATR computed on H1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120-250 (H1 intraday, multiple oversold/overbought events/week) |
| Typical hold time | A few to ~24 H1 bars (hours to one trading day) |
| Expected drawdown profile | Frequent small wins with occasional 2xATR stop-outs on failed reversions |
| Regime preference | mean-revert |
| Win rate target (qualitative) | high (Connors-style mean reversion targets high hit-rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book + forum (Connors/Alvarez *Short Term Trading Strategies That Work* 2009 + ForexFactory Trading-Systems RSI-2 FX cluster)
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1325_connors-rsi2-fx-intraday-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | board-advisor worktree |
