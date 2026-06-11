# QM5_10045_ff-quad-candle-d1 - Strategy Spec

**EA ID:** QM5_10045
**Slug:** `ff-quad-candle-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades only on D1. It enters long when the last four completed D1 candles all closed above their opens, and enters short when all four closed below their opens. The four-candle high-low range must be at least 1.0 x ATR(14), the new D1 open must not gap more than 0.5 x ATR(14) from the prior close, and the fixed 300-pip stop must not exceed 2.5 x ATR(14). Exits use a 100-pip take profit, 300-pip stop loss, break-even at +50 pips, or a market close after 5 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sequence_bars` | 4 | fixed at 4 | Number of same-color completed D1 candles required by the card. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the minimum range, gap, and stop cap filters. |
| `strategy_min_range_atr_mult` | 1.0 | >= 0.0 | Minimum four-candle high-low range as a multiple of ATR(14). |
| `strategy_take_profit_pips` | 100 | >= 1 | Fixed source take-profit distance in pips. |
| `strategy_stop_loss_pips` | 300 | >= 1 | Fixed source stop-loss distance in pips. |
| `strategy_breakeven_pips` | 50 | >= 1 | Profit distance that moves the stop to break-even. |
| `strategy_max_hold_d1_bars` | 5 | >= 1 | Maximum holding period in completed D1 bars. |
| `strategy_max_gap_atr_mult` | 0.5 | >= 0.0 | Maximum allowed new-open gap beyond the prior close as ATR multiple. |
| `strategy_sl_atr_cap_mult` | 2.5 | >= 0.0 | Skip entries when the 300-pip stop is larger than this ATR multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed standard DWX major FX pair.
- `GBPUSD.DWX` - Card-listed standard DWX major FX pair.
- `USDJPY.DWX` - Card-listed standard DWX major FX pair.
- `AUDUSD.DWX` - Card-listed standard DWX major FX pair.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - the card's R3 PASS basket is limited to the four listed major FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | Up to 5 D1 bars. |
| Expected drawdown profile | Sparse D1 continuation entries with fixed 300-pip source stop. |
| Regime preference | Daily continuation / trend follow-through. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/668957-quad-candle-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10045_ff-quad-candle-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | b5f6a266-c7cd-488c-98e8-df056245e32c |
