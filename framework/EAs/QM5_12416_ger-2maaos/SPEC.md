# QM5_12416_ger-2maaos — Strategy Spec

**EA ID:** QM5_12416
**Slug:** ger-2maaos
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233 (see `strategy-seeds/sources/041e0d5c-bf76-501d-bee2-31c0f4a6e233/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the H4 close-bar signal from Geraked 2MAAOS. A long entry is opened when Andean Bull crosses above its Signal line, Bull is above Bear, SMA(50) is above SMA(200), and the current ask is not more than half the 50/200 SMA distance below SMA(50). A short entry mirrors the rule with Andean Bear crossing above Signal, Bear above Bull, SMA(50) below SMA(200), and the current bid not more than half the SMA distance above SMA(50). The EA uses a 10-bar swing stop plus 100 points and a 1R take profit; there is no discretionary signal close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 baseline | Timeframe used for all card signals. |
| `strategy_aos_period` | `50` | 34-89 | Andean Oscillator smoothing period. |
| `strategy_aos_signal_period` | `9` | 5-13 | EMA period for the Andean signal line. |
| `strategy_fast_ma_period` | `50` | 34-89 | Fast SMA trend filter. |
| `strategy_slow_ma_period` | `200` | 150-250 | Slow SMA trend filter. |
| `strategy_min_pos_interval` | `6` | 3-12 | Minimum bars between new entry deals. |
| `strategy_sl_lookback` | `10` | fixed from source | Swing stop lookback bars. |
| `strategy_sl_dev_points` | `100` | fixed from source | Stop buffer beyond the swing in points. |
| `strategy_tp_coef` | `1.0` | fixed from source | Take-profit distance as a multiple of stop distance. |
| `strategy_spread_limit_points` | `-1` | `-1` disables | Source spread fuse, disabled by source default. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source card primary FX pair and present in the DWX matrix.
- `EURCAD.DWX` — source card primary FX pair and present in the DWX matrix.
- `USDCAD.DWX` — source card primary FX pair and present in the DWX matrix.

**Explicitly NOT for:**
- Non-FX index and commodity `.DWX` symbols — the approved card names only the three FX pairs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Typical hold time | Not specified in card; H4 swing trades exit by SL or 1R TP. |
| Expected drawdown profile | Trend-filtered FX oscillator entries with fixed $1,000 backtest risk. |
| Regime preference | Moving-average trend continuation with oscillator confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** code
**Pointer:** Geraked / Rabist, `2MAAOS.mq5`, https://github.com/geraked/metatrader5/blob/master/Experts/2MAAOS.mq5
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12416_ger-2maaos.md`

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
| v1 | 2026-06-11 | Initial build from card | 75efa2e0-4cd9-4854-b9a3-c9edfac53982 |
