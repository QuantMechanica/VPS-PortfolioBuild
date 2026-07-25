# QM5_10584_mql5-digvar — Strategy Spec

**EA ID:** QM5_10584
**Slug:** `mql5-digvar`
**Source:** Nikolay Kositsin, `Exp_DigVariation`, MQL5 CodeBase 13554
**Author of this spec:** Development
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

The EA reproduces the source DigVariation calculation on closed H8 bars:

1. Calculate an SMA(12) of close.
2. Calculate an SMA(12) of `close - SMA(12)`.
3. Form raw variation as
   `1000 * (close - (price_sma + deviation_sma))`.
4. Apply the source `dig_1` 20-tap digital filter.

A trough at shift 2 (`dig[3] > dig[2] < dig[1]`) signals long. A peak at
shift 2 (`dig[3] < dig[2] > dig[1]`) signals short. An opposite reversal
closes the current position and may open the new direction on the same
closed-bar event.

The V5 baseline adds a 2.0 ATR(14) catastrophic stop and a 1.5R target. There
is no ML, grid, martingale, averaging-down, trailing stop, or PnL-adaptive
rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H8` | locked baseline | Source signal timeframe |
| `strategy_dig_period` | 12 | `>= 2` | Two-stage SMA period |
| `strategy_dig_smooth_power` | 1 | `0` or `1` | Source digital smoothing; 1 is baseline |
| `strategy_atr_period` | 14 | `>= 1` | Catastrophic-stop ATR |
| `strategy_atr_sl_mult` | 2.0 | `> 0` | Stop distance in ATR |
| `strategy_tp_r_mult` | 1.5 | `> 0` | Reward/risk target |
| `strategy_max_spread_points` | 250 | `>= 0` | Entry-only execution cap |

Framework risk, news, stress, magic, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `GBPJPY.DWX` — source test carrier and primary diversity recovery.
- `EURUSD.DWX`
- `USDJPY.DWX`
- `XAUUSD.DWX`

Each host instance uses its registered symbol slot. Cross-symbol reads and
synthetic basket execution are not used.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Signal timeframe | `H8` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_H8)` consumption per tick |
| Data window | bounded 44 closed H8 bars at the locked baseline |

The bounded window is the exact requirement for three filtered oscillator
values, 20 digital-filter taps, and two nested SMA(12) stages.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 15-40; card planning prior 25 |
| Typical hold time | several H8 bars |
| Regime preference | persistent swings with distinct oscillator turns |
| Exit | opposite DigVariation reversal, stop, target, Friday close, or kill switch |

The first governed trade-generation evidence belongs to Q02. This spec makes
no performance or portfolio-admission claim.

---

## 6. Source Citation

- **Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
- **Primary source:** Nikolay Kositsin, `Exp_DigVariation`, MQL5 CodeBase,
  published 2015-08-17, updated 2023-03-29,
  <https://www.mql5.com/en/code/13554>
- **Source defaults mapped:** H8, period 12, SMA, `dig_1`, closed-bar
  direction reversal.
- **Approved card:** `docs/strategy_card.md`

The ATR stop, 1.5R target, V5 risk sizing, news gate, and Friday close are
explicit V5 safety additions documented by the approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this repair |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this repair |

The four canonical backtest setfiles use `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This recovery creates no live
setfile and grants no live, deploy, or portfolio authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Q02 infrastructure recovery | Replaced legacy ROC surrogate with source-faithful H8 DigVariation and repaired H8 artifacts |
