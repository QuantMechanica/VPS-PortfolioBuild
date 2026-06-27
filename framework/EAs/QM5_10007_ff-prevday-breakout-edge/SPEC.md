# QM5_10007_ff-prevday-breakout-edge - Strategy Spec

**EA ID:** QM5_10007
**Slug:** `ff-prevday-breakout-edge`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA trades a ForexFactory previous-day breakout rule on H1 bars. It computes the previous source trading day's high and low using a 22:00 GMT day boundary, then buys when the last closed H1 candle closes above the prior-day high and sells when it closes below the prior-day low. The baseline keeps the source SMA(34) filter enabled, skips tiny prior-day ranges versus D1 ATR(14), allows one breakout per side per day, and exits by fixed SL/TP, opposite previous-day breakout, or source-day rollover.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 34 | 5-200 | H1 simple moving average period used by the optional trend filter. |
| `strategy_use_sma_filter` | true | true/false | Require long closes above SMA and short closes below SMA. |
| `strategy_sl_pips` | 12.5 | 2.0-100.0 | Fixed stop loss distance in pips. |
| `strategy_tp_pips` | 25.0 | 2.0-200.0 | Fixed take profit distance in pips. |
| `strategy_max_spread_pips` | 2.0 | 0.1-10.0 | Maximum modeled spread before suppressing a new entry. |
| `strategy_spread_sl_frac` | 0.16 | 0.01-0.50 | Spread cap as a fraction of the fixed stop distance. |
| `strategy_atr_period_d1` | 14 | 5-100 | D1 ATR period used to reject tiny previous-day ranges. |
| `strategy_min_range_atr` | 0.5 | 0.0-3.0 | Minimum previous-day range as a fraction of D1 ATR. |
| `strategy_gmt_day_start_hour` | 22 | 0-23 | Source trading-day boundary hour in UTC/GMT. |
| `strategy_day_scan_bars` | 144 | 24-300 | H1 history scan depth used to reconstruct the prior source day. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with deep DWX H1 history and tight modeled spread.
- `GBPUSD.DWX` - major FX pair from the approved card's P2 basket.
- `USDJPY.DWX` - major FX pair from the approved card's P2 basket.
- `AUDUSD.DWX` - major FX pair from the approved card's P2 basket.

**Explicitly NOT for:**
- `XTIUSD.DWX` - energy CFD behavior is not part of the ForexFactory FX breakout source.
- `XAUUSD.DWX` - metal volatility and pip scaling were not approved in this card.
- `SP500.DWX` - index session structure is outside the source and R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 ATR(14) range filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 75 |
| Typical hold time | Hours to one source trading day |
| Expected drawdown profile | Fixed 1:2 reward-risk breakout sleeve with clustered losses in false-breakout regimes. |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/1075281-previous-day-breakout-edge-system`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10007_ff-prevday-breakout-edge.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial build spec from approved card | build task `11bae803-496c-4a8b-bc28-0994821bb9a5` |
