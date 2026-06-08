# QM5_11221_ft-quickie - Strategy Spec

**EA ID:** QM5_11221
**Slug:** ft-quickie
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only M5 quick-turn setups. On the last closed bar it requires ADX(14) above 30, TEMA(9) below the Bollinger(20,2) middle band, TEMA(9) rising versus its prior value, and SMA(200) above the close. It enters at the next available market price with an ATR(14) x 1.5 stop. It exits on the source exhaustion signal, on the ROI ladder, on the disaster cap, or through the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_adx_period | 14 | 14 fixed | ADX lookback used for entry and exit strength. |
| strategy_adx_entry | 30.0 | 20.0-40.0 | Minimum ADX required for a long entry. |
| strategy_adx_exit | 70.0 | 50.0-70.0 | ADX exhaustion threshold for signal exit. |
| strategy_tema_period | 9 | 7-14 | TEMA lookback for quick-turn signal. |
| strategy_sma_filter | 200 | 100-200 | SMA trend filter; entry requires SMA above close. |
| strategy_bb_period | 20 | 20 fixed | Bollinger middle-band lookback. |
| strategy_bb_deviation | 2.0 | 2.0 fixed | Bollinger band deviation. |
| strategy_atr_period | 14 | 14 fixed | ATR lookback for stop distance. |
| strategy_atr_stop_mult | 1.5 | 1.0-2.0 | ATR stop multiplier. |
| strategy_max_spread_stop_fraction | 0.06 | 0.06 fixed | Blocks entries when spread exceeds 6% of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid forex symbol with M5 OHLC support.
- GBPUSD.DWX - Card-listed liquid forex symbol with M5 OHLC support.
- USDJPY.DWX - Card-listed liquid forex symbol with M5 OHLC support.
- XAUUSD.DWX - Card-listed liquid gold symbol with M5 OHLC support.

**Explicitly NOT for:**
- Non-DWX symbols - Build and backtest artifacts must use canonical `.DWX` custom symbols.
- Symbols outside the card R3 basket - The card names a specific four-symbol P2 basket.

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
| Trades / year / symbol | 70 |
| Typical hold time | Minutes; source describes quick closes with ROI checkpoints at 10, 15, 30, and 100 minutes. |
| Expected drawdown profile | Medium risk profile from a scalping-style M5 momentum-reversal setup. |
| Regime preference | Momentum-reversal under high ADX with TEMA recovery below the Bollinger middle band. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** Quickie.py in freqtrade-strategies, `user_data/strategies/berlinguyinca/Quickie.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11221_ft-quickie.md`

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
| v1 | 2026-06-08 | Initial build from card | 6834110b-9dde-4b34-adf7-54869588f7de |
