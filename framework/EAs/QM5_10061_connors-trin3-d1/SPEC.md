# QM5_10061_connors-trin3-d1 - Strategy Spec

**EA ID:** QM5_10061
**Slug:** connors-trin3-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152 (see `sources/connors-research-traders-journal`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades long-only index pullbacks on D1 bars. It buys when the traded index closes above its SMA(200) and the external TRIN daily custom series has closed above 1.0 for three consecutive sessions. Because MT5 cannot execute at the completed D1 close from an EA tick, the EA enters on the next D1 open. It exits when the traded index closes above its SMA(5), or after 5 D1 bars if that exit has not fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | D1 only | Signal and exit timeframe from the card. |
| `strategy_trin_symbol` | `TRIN` | MT5 custom symbol name | External daily TRIN series aligned to the index session calendar. |
| `strategy_regime_sma_period` | `200` | `> 0` | Long regime filter period. |
| `strategy_exit_sma_period` | `5` | `> 0` | SMA close-exit period. |
| `strategy_trin_threshold` | `1.0` | `> 0` | TRIN close threshold for each of the three trigger days. |
| `strategy_trin_days` | `3` | fixed `3` | Number of consecutive TRIN closes required. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for stop loss and spread filter. |
| `strategy_atr_sl_mult` | `3.0` | `> 0` | Stop distance in ATR multiples below entry. |
| `strategy_spread_atr_fraction` | `0.25` | `>= 0` | Blocks entries when current spread exceeds this fraction of ATR(14,D1). |
| `strategy_time_stop_bars` | `5` | `> 0` | Maximum D1 bars held before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S and P 500/SPY/SPX-equivalent backtest target named by the approved card.
- `NDX.DWX` - US large-cap live-validation analogue named by the approved card.
- `WS30.DWX` - US large-cap live-validation analogue named by the approved card.

**Explicitly NOT for:**
- Non-index symbols - the card restricts trading to index analogues.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable or non-canonical S and P variants; the valid custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | 1 to 5 D1 bars |
| Expected drawdown profile | Bounded by fixed 3.0 ATR(14,D1) stop per trade. |
| Regime preference | Pullback mean reversion inside a long-term uptrend. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Source type:** public article
**Pointer:** https://tradingmarkets.com/recent/4_rules_to_time_the_market_using_the_trin-674135
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10061_connors-trin3-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 81d037bc-0c30-4d20-96fd-2f1041d72123 |
