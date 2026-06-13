# QM5_1052_sidus-ema-method-v2 - Strategy Spec

**EA ID:** QM5_1052
**Slug:** `sidus-ema-method-v2`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades the Sidus method on H1. A long entry requires WMA(5) to cross above WMA(8) on the most recent closed bar, both WMAs to be above the EMA(18)/EMA(28) tunnel, and EMA(18) to be above EMA(28). A short entry mirrors those rules below the tunnel. The initial stop is placed on the opposite side of EMA(28) with a 20-point buffer, and an open trade closes when WMA(5) crosses back through WMA(8) in the opposite direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wma_fast_period` | 5 | >= 1 | Fast WMA period used for the trigger cross. |
| `strategy_wma_slow_period` | 8 | >= 1 | Slow WMA period used for the trigger cross. |
| `strategy_ema_fast_period` | 18 | >= 1 | Fast EMA period in the Sidus tunnel. |
| `strategy_ema_slow_period` | 28 | >= 1 | Slow EMA period in the Sidus tunnel and stop reference. |
| `strategy_sl_buffer_points` | 20 | >= 0 | Point buffer added beyond EMA(28) for the initial stop. |
| `strategy_use_rr_take_profit` | false | true/false | Enables the optional fixed reward-to-risk take-profit for P3 sweeps. |
| `strategy_rr_target` | 1.5 | > 0 | Reward-to-risk target used when the optional take-profit is enabled. |
| `strategy_spread_cap_points` | 20 | >= 0 | Maximum spread in points; zero disables this cap. |
| `strategy_session_filter_enabled` | false | true/false | Enables the optional London/New York overlap session filter for P3 sweeps. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start for the optional session filter. |
| `strategy_session_end_hour` | 17 | 0-23 | Broker-hour end for the optional session filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named in the card's P2 basket.
- `GBPUSD.DWX` - FX major named in the card's P2 basket.
- `USDJPY.DWX` - FX major named in the card's P2 basket.
- `AUDUSD.DWX` - FX major named in the card's P2 basket.
- `EURJPY.DWX` - liquid FX cross named in the card's P2 basket.

**Explicitly NOT for:**
- Index, commodity, and crypto `.DWX` symbols - the card specifies FX majors only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `500` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | trend-following whipsaw risk during choppy tunnel regimes |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/` and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1052_sidus-ema-method-v2.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1052_sidus-ema-method-v2.md`

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
| v1 | 2026-06-13 | Initial build from card | 7b018352-cf89-47bd-9086-586d890b9075 |
