# QM5_11356_robo-10pts - Strategy Spec

**EA ID:** QM5_11356
**Slug:** robo-10pts
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d (see local RoboForex PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades an M5 forex scalp from the RoboForex 10-point system. It buys when MACD(13,26,9) main is above zero and either Stochastic %K or %D crosses up through 20 on the last closed bar. It sells when MACD(13,26,9) main is below zero and either Stochastic %K or %D crosses down through 80. Entries are market orders with a fixed 10-pip take-profit and a stop one pip beyond the lowest low or highest high of the last three closed bars, skipped when the stop would exceed 12 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_macd_fast_period | 13 | >=1 and < slow | MACD fast EMA period. |
| strategy_macd_slow_period | 26 | > fast | MACD slow EMA period. |
| strategy_macd_signal_period | 9 | >=1 | MACD signal period. |
| strategy_stoch_k_period | 5 | >=1 | Stochastic %K period. |
| strategy_stoch_d_period | 3 | >=1 | Stochastic %D period. |
| strategy_stoch_slowing | 3 | >=1 | Stochastic slowing value. |
| strategy_stoch_oversold | 20.0 | >0 and < overbought | Long recovery threshold. |
| strategy_stoch_overbought | 80.0 | > oversold and <100 | Short reversal threshold. |
| strategy_sl_lookback_bars | 3 | >=1 | Closed-bar local extreme lookback for SL. |
| strategy_sl_buffer_pips | 1.0 | >0 | Extra SL buffer beyond the local extreme. |
| strategy_tp_pips | 10 | >0 | Fixed take-profit distance. |
| strategy_max_stop_pips | 12.0 | >0 | Skip entries with wider initial stops. |
| strategy_spread_cap_pips | 3.0 | >0 | Maximum allowed spread. |
| strategy_session_start_gmt | 13 | 0-23 | GMT session start hour. |
| strategy_session_end_gmt | 22 | 0-23 | GMT session end hour. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major EUR/USD pair with low spread and M5 DWX data.
- GBPUSD.DWX - major GBP/USD pair with low spread and M5 DWX data.
- AUDUSD.DWX - major AUD/USD pair with low spread and M5 DWX data.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - the source system is a tight 10-pip forex scalp.
- Wide-spread or non-DWX symbols - the spread cap and broker data convention would not hold.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | Intraday scalp, typically minutes; card frontmatter does not specify a numeric hold time. |
| Expected drawdown profile | Tight-stop high-frequency scalp with many small wins/losses. |
| Regime preference | Momentum continuation with oscillator recovery timing. |
| Win rate target (qualitative) | Medium to high due to 10-pip target and tight stops. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** local PDF
**Pointer:** C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11356_robo-10pts.md`

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
| v1 | 2026-06-08 | Initial build from card | 5322b937-d50b-49f1-a88c-b72129276956 |
