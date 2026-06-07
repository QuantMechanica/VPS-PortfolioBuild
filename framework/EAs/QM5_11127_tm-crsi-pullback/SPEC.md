# QM5_11127_tm-crsi-pullback - Strategy Spec

**EA ID:** QM5_11127
**Slug:** tm-crsi-pullback
**Source:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates the last closed D1 bar and trades long only. It places a next-session buy limit when price is above SMA(200), the close is at least 2.0 x ATR(14) below the 20-bar high, the close is in the bottom 25% of the daily range, and ConnorsRSI(3,2,100) is below 5. The limit price is 1.0 x ATR(14) below the setup close and expires after one D1 bar if unfilled. It exits when ConnorsRSI(3,2,100) closes above 70 or after 7 D1 bars from entry, with an initial stop 2.5 x ATR(14) below the limit entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_crsi_rsi_period | 3 | 1+ | Price RSI component period for ConnorsRSI. |
| strategy_crsi_streak_rsi_period | 2 | 1+ | RSI period applied to the up/down streak component. |
| strategy_crsi_rank_period | 100 | 1+ | Percent-rank lookback for the daily return component. |
| strategy_crsi_entry | 5.0 | 0-100 | Long setup requires ConnorsRSI to close below this value. |
| strategy_crsi_exit | 70.0 | 0-100 | Open long exits when ConnorsRSI closes above this value. |
| strategy_sma_period | 200 | 1+ | D1 trend filter moving-average period. |
| strategy_atr_period | 14 | 1+ | D1 ATR period used for pullback, limit, and stop distances. |
| strategy_pullback_lookback | 20 | 1+ | Highest-high window used for the ATR pullback proxy. |
| strategy_pullback_atr_mult | 2.0 | 0+ | Required distance below the 20-bar high, in ATR multiples. |
| strategy_closing_range_max | 0.25 | 0-1 | Maximum allowed close location within the daily high-low range. |
| strategy_entry_limit_atr_mult | 1.0 | 0+ | Buy-limit distance below the setup close, in ATR multiples. |
| strategy_atr_sl_mult | 2.5 | 0+ | Initial stop distance below the limit entry, in ATR multiples. |
| strategy_max_hold_bars | 7 | 1+ | Maximum D1 bars to hold a position. |
| strategy_max_spread_points | 300 | 0+ | Blocks new entries when current spread exceeds this many points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 large-cap index exposure named in the approved card; backtest-only per DWX discipline.
- NDX.DWX - Nasdaq 100 large-cap index analog named in the approved card and live-tradable after downstream gates.
- WS30.DWX - Dow 30 large-cap index analog named in the approved card and live-tradable after downstream gates.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols for S&P 500 testing.
- Single stocks - The approved build ports the stock-basket source mechanics to index CFDs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Up to 7 D1 bars |
| Expected drawdown profile | Deep-pullback mean reversion can suffer during persistent index selloffs and gap continuation. |
| Regime preference | Mean-reversion in an SMA(200) uptrend |
| Win rate target (qualitative) | Medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Source type:** guidebook PDF
**Pointer:** Connors Research, "ConnorsRSI Pullbacks Strategy Guidebook", TradingMarkets PDF, 2012, https://www.tradingmarkets.com/media/2012/ConnorsRSI-Pullbacks-Guidebook.pdf
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11127_tm-crsi-pullback.md`

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
| v1 | 2026-06-07 | Initial build from card | c9cfb5c4-c312-4043-ba87-a27f1c3b6df9 |
