# QM5_11358_robo-cci-macd - Strategy Spec

**EA ID:** QM5_11358
**Slug:** robo-cci-macd
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d (see local RoboForex PDF citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades momentum continuation on M5 bars. It opens long when CCI(14) crosses upward through +100 and MACD(12,26,2) main line is above zero on the same closed bar. It opens short when CCI(14) crosses downward through -100 and MACD(12,26,2) main line is below zero. Positions exit through a 12-pip stop, a 15-pip take-profit, Friday close, or when CCI returns inside the threshold that triggered the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_cci_period | 14 | 2-100 | CCI lookback used for entry and exit thresholds. |
| strategy_cci_long_level | 100.0 | 50-300 | Long continuation threshold. |
| strategy_cci_short_level | -100.0 | -300--50 | Short continuation threshold. |
| strategy_macd_fast | 12 | 2-50 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 3-100 | MACD slow EMA period; must exceed fast. |
| strategy_macd_signal | 2 | 1-50 | MACD signal smoothing period from the card. |
| strategy_stop_pips | 12 | 1-200 | Fixed stop-loss distance in pips. |
| strategy_take_pips | 15 | 1-300 | Fixed take-profit distance in pips. |
| strategy_spread_cap_pips | 3 | 0-50 | Maximum live spread in pips; zero modeled spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - named directly in the card's FX instrument list.
- GBPUSD.DWX - named directly in the card's FX instrument list.
- AUDUSD.DWX - named directly in the card's FX instrument list.

**Explicitly NOT for:**
- Non-DWX symbols - the build and backtest pipeline require canonical `.DWX` custom symbols.
- Index and commodity CFDs - the approved card describes a DWX FX M5 oscillator basket, not non-FX markets.

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
| Trades / year / symbol | 300 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Frequent small fixed-risk losses with bounded 12-pip stops. |
| Regime preference | trend / momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** institutional PDF archive
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11358_robo-cci-macd.md`

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
| v1 | 2026-06-20 | Initial build from card | 64dfd42c-97d3-4f6b-883a-f14f85cf3516 |
