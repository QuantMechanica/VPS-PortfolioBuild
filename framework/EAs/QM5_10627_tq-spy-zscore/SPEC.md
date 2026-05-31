# QM5_10627_tq-spy-zscore - Strategy Spec

**EA ID:** QM5_10627
**Slug:** `tq-spy-zscore`
**Source:** `31243712-2135-5a59-8319-f053a51f8478` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA evaluates the most recently completed D1 bar. It computes a 20-day z-score as `(Close - SMA(Close, 20)) / StdDev(Close, 20)`. It opens one long position at the next D1 bar when the closed-bar z-score is below -1.5 and no position is already open. It closes the long when the closed-bar z-score is above 0.0, or after 30 D1 bars if reversion has not happened.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_period` | 20 | 2+ | Lookback for the close SMA and standard deviation used in the z-score. |
| `strategy_entry_z` | -1.5 | negative values | Long-entry threshold; enter when the closed-bar z-score is below this value. |
| `strategy_exit_z` | 0.0 | any numeric value | Strategy exit threshold; close when the closed-bar z-score is above this value. |
| `strategy_atr_period` | 14 | 1+ | D1 ATR period used by the framework ATR stop helper. |
| `strategy_atr_sl_mult` | 1.5 | positive values | Initial stop distance as ATR multiple below the long entry. |
| `strategy_max_hold_d1_bars` | 30 | 1+ | Safety time stop in completed D1 bars. |
| `strategy_max_spread_pct_price` | 0.0008 | 0+ | Entry spread cap as fraction of mid price, matching the card's 0.08% limit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical DWX S&P 500 custom symbol for the source SPY/SP500 exposure.
- `NDX.DWX` - live-tradable US large-cap index analogue named in the card's R3 basket.
- `WS30.DWX` - live-tradable Dow index analogue named in the card's R3 basket.

**Explicitly NOT for:**
- `SPY.DWX` - not present in the DWX symbol matrix.
- `SPX500.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton; all signal reads use completed `PERIOD_D1` bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Until z-score reverts above 0.0, capped at 30 D1 bars |
| Expected drawdown profile | Mean-reversion drawdowns can cluster during persistent index selloffs |
| Regime preference | Mean-reverting large-cap index regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `31243712-2135-5a59-8319-f053a51f8478`
**Source type:** blog
**Pointer:** QuantTrader, "Mean Reversion Strategy in Python: What the Backtest Hides", TrustedQuant, 2026-03-12, https://trustedquant.com/quant-methods/mean-reversion-strategy-in-python-what-the-backtest-hides/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10627_tq-spy-zscore.md`

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
| v1 | 2026-05-31 | Initial build from card | 2100cf47-f4bf-4557-9674-d60f2a1bd714 |
