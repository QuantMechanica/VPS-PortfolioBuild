# QM5_1530_connors-double-sevens-h4 - Strategy Spec

**EA ID:** QM5_1530
**Slug:** `connors-double-sevens-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

This EA trades Larry Connors and Cesar Alvarez's Double-7s mean-reversion rule on H4 bars. A long entry is allowed only when the latest H4 close is below the lowest close of the prior 7 H4 bars and the symbol is above its D1 SMA(200). A short entry mirrors that rule when the latest H4 close is above the highest close of the prior 7 H4 bars and the symbol is below its D1 SMA(200). Positions exit on the opposite 7-bar close extreme, after 14 H4 bars, via the 3 ATR hard stop, or by the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_extreme_bars` | 7 | 2-30 | Number of prior H4 closes used for the Double-7s extreme trigger and exit. |
| `strategy_regime_sma_period` | 200 | 50-300 | D1 SMA regime filter period. |
| `strategy_atr_period` | 14 | 5-50 | H4 ATR period used for the hard stop and spread cap. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | ATR multiple for the initial stop loss. |
| `strategy_time_stop_bars` | 14 | 1-60 | Maximum H4 bars to hold a trade if no exit signal appears. |
| `strategy_spread_atr_fraction` | 0.40 | 0.0-1.0 | Blocks only genuinely wide modeled spreads above this fraction of ATR. |
| `strategy_allow_shorts` | true | true/false | Enables the mirrored short-side Double-7s rule. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major included for instrument diversity in the FF H4 port.
- `GBPUSD.DWX` - FX major included for instrument diversity in the FF H4 port.
- `USDJPY.DWX` - FX major included for instrument diversity in the FF H4 port.
- `GDAXI.DWX` - liquid index analogue for the equity-index side of the Connors rule.
- `NDX.DWX` - live-tradable Nasdaq analogue for QQQ-style mean reversion.
- `WS30.DWX` - live-tradable Dow analogue for the equity-index side.
- `XAUUSD.DWX` - liquid metal included in the approved DWX port basket.
- `SP500.DWX` - backtest-only S&P 500 analogue; T6 deploy requires parallel live-routable validation.

**Explicitly NOT for:**
- `XNGUSD.DWX` - excluded because the mission already has excess XNG concentration and the card does not name natural gas.
- `XBRUSD.DWX` - excluded because the card does not name Brent or a crude-specific variant.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(200) regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Hours to 2.3 days |
| Expected drawdown profile | Mean-reversion drawdown clusters during persistent trend continuation. |
| Regime preference | Mean-revert within a D1 trend regime |
| Win rate target (qualitative) | Medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book / forum-port card
**Pointer:** Larry Connors and Cesar Alvarez, *Short-Term Trading Strategies That Work*, chapter 9, via `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1530_connors-double-sevens-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1530_connors-double-sevens-h4.md`

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
| v1 | 2026-07-02 | Initial build from card | 5c099214-43eb-4d8d-9e8d-054400a29167 |
