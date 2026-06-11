# QM5_9959_ff-daily-wick-hilo-d1 - Strategy Spec

**EA ID:** QM5_9959
**Slug:** `ff-daily-wick-hilo-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

At the start of each new D1 candle, the EA reads the previous completed D1 bar. If the lower wick from open to low is larger than the upper wick from high to open, it places a buy stop above the previous high; if the upper wick is larger, it places a sell stop below the previous low. The setup is skipped when the previous daily range is less than 0.5 ATR(14), and any unfilled stop order is cancelled at the next D1 bar. Exits are handled by the broker SL/TP or by a time stop at the next D1 open after entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 only | Timeframe used for prior-day wick, high, low and ATR calculations. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for range filter and normalized stops. |
| `strategy_fx_entry_buffer_pips` | `5.0` | `>0` | FX stop-entry offset beyond previous high or low. |
| `strategy_fx_sl_pips` | `30.0` | `>0` | Source FX stop distance before ATR normalization. |
| `strategy_fx_tp_pips` | `100.0` | `>0` | Source FX take-profit cap before 2R normalization. |
| `strategy_nonfx_entry_atr_mult` | `0.05` | `>0` | Non-FX stop-entry offset as ATR multiple. |
| `strategy_sl_atr_mult` | `0.8` | `>0` | ATR stop distance when fixed FX stop is outside 0.4-1.2 ATR, and always for non-FX. |
| `strategy_min_range_atr_mult` | `0.5` | `>0` | Minimum previous-day range as ATR multiple. |
| `strategy_rr_multiple` | `2.0` | `>0` | Reward-to-risk multiple for normalized TP. |
| `strategy_max_spread_stop_frac` | `0.10` | `0+` | Maximum allowed spread as a fraction of stop distance. |
| `strategy_pending_days` | `1` | `1+` | Pending stop order expiration in days; stale stops are also removed on the next D1 bar. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major from the card's primary P2 basket.
- `GBPUSD.DWX` - FX major from the card's primary P2 basket.
- `USDJPY.DWX` - FX major from the card's primary P2 basket.
- `XAUUSD.DWX` - liquid metal symbol from the card's primary P2 basket; uses ATR-normalized non-FX offsets.
- `NDX.DWX` - liquid index symbol from the card's primary P2 basket; uses ATR-normalized non-FX offsets.

**Explicitly NOT for:**
- Symbols outside the card's R3 basket - not registered for this EA, so no magic slot exists for them.

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
| Trades / year / symbol | `55` |
| Typical hold time | Same trading day through the next D1 open, unless SL or TP triggers first. |
| Expected drawdown profile | Fixed-risk daily breakout with bounded one-order-per-day exposure. |
| Regime preference | Volatility-expansion breakout after a directional wick-bias day. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** rockzz, "Your EA v3 - Daily Low & High Strategy", ForexFactory, 2023, https://www.forexfactory.com/thread/1233107-your-ea-v3-daily-low-high
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9959_ff-daily-wick-hilo-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | b46dbe8c-56f3-45b7-a2e9-0cddf4532a16 |
