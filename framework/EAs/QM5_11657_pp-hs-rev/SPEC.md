# QM5_11657_pp-hs-rev - Strategy Spec

**EA ID:** QM5_11657

**Slug:** pp-hs-rev

**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab

**Author of this spec:** Codex

**Last revised:** 2026-08-21

---

## 1. Strategy Logic

On the first tick of each new bar, the EA evaluates PatternPy's
`detect_head_shoulder` mask on completed bars. The labelled source row is
shift 2, its previous row is shift 3, and its future `shift(-1)` row is shift
1. Waiting for shift 1 to close removes the source detector's lookahead; a
confirmed label then enters at the current bar open.

For the labelled row, the three-bar rolling window spans shifts 4, 3, and 2:

- Head and Shoulder: the rolling high is strictly above both high[3] and
  high[1], while high[2] is strictly below both high[3] and high[1]. Enter
  short.
- Inverse Head and Shoulder: the rolling low is strictly below both low[3] and
  low[1], while low[2] is strictly above both low[3] and low[1]. Enter long.
- If both masks hold, the inverse label wins because PatternPy assigns that
  label second.
- A position closes on the opposite label or after 12 completed holding bars,
  whichever occurs first. Its broker hard stop is 2.0 times completed-bar
  ATR(14).

Only one position per magic is allowed. There is no neckline reconstruction,
five-pivot scan, take-profit, pattern-break exit, spread filter, trailing stop,
break-even, partial close, grid, martingale, or ML.

---

## 2. Parameters

| Parameter | Default | Authorized P3 range | Meaning |
|---|---:|---:|---|
| strategy_window | 3 | fixed at 3 | PatternPy rolling high/low window. |
| strategy_atr_period | 14 | fixed at 14 | Emergency-stop ATR period. |
| strategy_sl_atr_mult | 2.0 | 1.0 to 3.0 | Emergency-stop ATR multiple; the card authorizes a P3 sweep. |
| strategy_max_hold_bars | 12 | fixed at 12 | Maximum completed bars held. |

The Q01 baseline uses only the defaults. Framework-level inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - card target EURUSD and the first FX diversity host.
- `GBPUSD.DWX` - card target GBPUSD and the second FX diversity host.
- `XAUUSD.DWX` - card target XAUUSD; the detector uses portable OHLC only.
- `GDAXI.DWX` - canonical DWX broker mapping for the card's GER40 target.
- `NDX.DWX` - card target NDX; the detector uses portable OHLC only.

**Explicitly NOT for:**

- `GER40.DWX` - absent from the DWX symbol matrix; `GDAXI.DWX` is the
  registered canonical target.
- Any symbol outside the five registered hosts - initialization fails closed
  on an unknown symbol or mismatched magic-slot offset.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Authorized later P3 timeframe checks | H1, H4, D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

The generated Q01/Q02 baseline setfiles are H4. All detector inputs are closed
bars from the host timeframe.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 24 (approved prior) |
| Typical hold time | no more than 12 H4 bars in the baseline |
| Expected drawdown profile | repeated local-reversal losses during persistent directional moves |
| Regime preference | structural reversal |
| Win rate target (qualitative) | medium |

The frequency is a card hypothesis, not performance evidence. Q02 must measure
activity independently on each FX, metal, and index host.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab

**Source type:** GitHub repository source

**Pointer:** Keith Orange / `keithorange`, PatternPy,
`tradingpatterns/tradingpatterns.py`, function `detect_head_shoulder`,
https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py

**R1-R4 verdict (Q00):** all PASS / see
`docs/strategy_card.md`

The rolling comparisons and inverse-label precedence are translated literally.
The approved V5 card adds only the emergency stop and lifecycle exit.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

`QM_FrameworkInit` enforces environment-to-risk-mode validation. The baseline
setfiles use `RISK_PERCENT=0`, `RISK_FIXED=1000`, and
`PORTFOLIO_WEIGHT=1`. The strategy never widens or mutates its hard stop.

No live setfile, T_Live action, AutoTrading action, deploy manifest,
portfolio-gate edit, or live-use authorization is part of this build.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial orphan build | Card-deviant five-pivot neckline implementation. |
| v2 | 2026-08-21 | Rebuilt from approved card | Literal PatternPy mask; removed inferred neckline, TP, and extra filters. |
