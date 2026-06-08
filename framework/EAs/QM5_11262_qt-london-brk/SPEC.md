# QM5_11262_qt-london-brk - Strategy Spec

**EA ID:** QM5_11262
**Slug:** `qt-london-brk`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA builds a pre-London opening range from 09:00 through 09:59 broker time by default. During the first 30 minutes after the configured London-open time, it enters long when the last closed M1 bar closes above the range high, or short when it closes below the range low. Entries are skipped when the breakout is more than the configured ATR(M30) rejection distance away from the threshold, when spread exceeds 10 percent of the planned stop distance, or when the framework news filter blocks trading. Each symbol can make one trade attempt per broker-date, exits at the ATR-based stop or target, and force-closes any open position at the configured London-close time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_preopen_start_hour` | 9 | 0-23 | Broker-time hour when the pre-open range starts. |
| `strategy_preopen_start_minute` | 0 | 0-59 | Broker-time minute when the pre-open range starts. |
| `strategy_preopen_minutes` | 60 | 1-300 | Number of M1 bars required for the pre-open range. |
| `strategy_entry_start_hour` | 10 | 0-23 | Broker-time hour when breakout entries begin. |
| `strategy_entry_start_minute` | 0 | 0-59 | Broker-time minute when breakout entries begin. |
| `strategy_entry_window_minutes` | 30 | 1-300 | Minutes after entry start when breakouts are valid. |
| `strategy_force_close_hour` | 19 | 0-23 | Broker-time hour for the session time stop. |
| `strategy_force_close_minute` | 0 | 0-59 | Broker-time minute for the session time stop. |
| `strategy_atr_period` | 14 | 1-200 | ATR period on M30 used for rejection and stop/target distance. |
| `strategy_breakout_buffer_atr` | 0.0 | 0.0-1.0 | Optional ATR(M30) buffer beyond the range high or low. |
| `strategy_reject_atr_mult` | 1.0 | 0.1-5.0 | Maximum allowed breakout distance from the threshold. |
| `strategy_stop_tp_atr_mult` | 0.5 | 0.1-5.0 | ATR(M30) multiple for both stop loss and take profit distance. |
| `strategy_max_spread_stop_frac` | 0.10 | 0.0-1.0 | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - source strategy was tested on GBPUSD and the card names it as primary portable FX symbol.
- `EURUSD.DWX` - liquid London-session major with DWX M1 data and matching R3 basket inclusion.
- `USDJPY.DWX` - liquid London-session major with DWX M1 data and matching R3 basket inclusion.

**Explicitly NOT for:**
- `SP500.DWX` - index session structure does not match the FX London-open card.
- `XAUUSD.DWX` - metal volatility and session behavior are outside the approved R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `M30` ATR for rejection and stop/target sizing |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `minutes to one London session` |
| Expected drawdown profile | `Medium risk from intraday breakout false starts and clustered news volatility.` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `GitHub repository script`
**Pointer:** `je-suis-tm/quant-trading` London Breakout backtest script, approved card at `artifacts/cards_approved/QM5_11262_qt-london-brk.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11262_qt-london-brk.md`

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
| v1 | 2026-06-08 | Initial build from card | 644e7a40-ab38-4a1c-baae-14a8d4352b53 |
