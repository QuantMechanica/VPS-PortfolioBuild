# QM5_9942_ff-psar-flip-m30 - Strategy Spec

**EA ID:** QM5_9942
**Slug:** `ff-psar-flip-m30`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M30 Parabolic SAR direction changes. It goes long when the previous completed M30 bar closed below PSAR, the latest completed M30 bar closes above PSAR, and the latest completed H4 bar also has PSAR below its close. It goes short on the mirror condition. Initial risk is placed beyond the most recent confirmed 5-bar swing with an ATR buffer, the stop trails by PSAR, and open trades close on an opposite M30 PSAR flip or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M30` | MT5 timeframe enum | Base timeframe for PSAR flip entries and exits. |
| `strategy_bias_tf` | `PERIOD_H4` | MT5 timeframe enum | Higher-timeframe PSAR direction filter. |
| `strategy_psar_step` | `0.02` | `> 0` | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | `0.20` | `> 0` | Parabolic SAR maximum acceleration. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for stop buffer and risk cap. |
| `strategy_swing_atr_buffer_mult` | `0.15` | `>= 0` | ATR buffer applied beyond confirmed swing stop. |
| `strategy_swing_confirm_bars` | `5` | fixed at `5` | Confirmed swing width from the card. |
| `strategy_swing_search_bars` | `20` | `>= 5` | Maximum bars to search for a confirmed swing. |
| `strategy_fallback_atr_mult` | `1.20` | `> 0` | ATR stop distance when no swing is found. |
| `strategy_max_initial_risk_atr` | `2.00` | `> 0` | Skip entries whose initial risk exceeds this ATR multiple. |
| `strategy_lock1_trigger_r` | `0.80` | `> 0` | Profit threshold for first lock-in rule. |
| `strategy_lock1_stop_r` | `0.25` | `>= 0` | Stop level after first lock-in trigger. |
| `strategy_lock2_trigger_r` | `1.50` | `> 0` | Profit threshold for second lock-in rule. |
| `strategy_lock2_stop_r` | `0.80` | `>= 0` | Minimum locked-in stop after second trigger. |
| `strategy_skip_weekly_open_30m` | `true` | `true/false` | Skip first 30 minutes after weekly open. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary ForexFactory EURUSD M30 PSAR target.
- `GBPUSD.DWX` - card R3 portable DWX FX pair using the same OHLC-derived PSAR/ATR logic.
- `USDJPY.DWX` - card R3 portable DWX FX pair using the same OHLC-derived PSAR/ATR logic.
- `AUDUSD.DWX` - card R3 portable DWX FX pair using the same OHLC-derived PSAR/ATR logic.

**Explicitly NOT for:**
- Non-FX index or commodity `.DWX` symbols - not listed in the card's R3 FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `H4` PSAR/close direction filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Not specified in card frontmatter; exit is PSAR trail or opposite M30 flip. |
| Expected drawdown profile | Not specified in card frontmatter; initial risk is capped at `2.0 * ATR(14,M30)`. |
| Regime preference | Not specified in card frontmatter; PSAR flip and trailing-stop mechanics imply directional trend-following. |
| Win rate target (qualitative) | Not specified in card frontmatter. |
| Expected trade frequency | M30 PSAR flips are frequent; with closed-bar and HTF filter estimate 90-150 trades/year/symbol. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** Everett, "Parabolic SAR robot (modified)", ForexFactory, 2009, https://www.forexfactory.com/thread/142161-parabolic-sar-robot-modified
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9942_ff-psar-flip-m30.md`

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
| v1 | 2026-06-11 | Initial build from card | 85e1e13e-eff1-4881-ba0a-77b392879117 |
