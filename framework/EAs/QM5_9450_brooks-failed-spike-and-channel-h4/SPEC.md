# QM5_9450_brooks-failed-spike-and-channel-h4 - Strategy Spec

**EA ID:** QM5_9450
**Slug:** `brooks-failed-spike-and-channel-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

This EA trades Al Brooks failed spike-and-channel reversals on closed H4 bars. It looks for a large directional spike bar, a 4 to 10 bar channel that holds above or below the spike origin, a counter-trend break back through that origin, and then a failure bar that closes back inside the spike-and-channel zone. A failed downside break after an up spike opens a market buy; a failed upside break after a down spike opens a market sell. The stop is placed beyond the failed counter-breakout extreme using 0.3 ATR(14), the target is the original channel extreme plus or minus 0.8 ATR(14), and any position still open after 20 H4 bars is closed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 only | Base timeframe required by the card. |
| `strategy_atr_period` | `14` | 5-50 | ATR period used for spike size, breakout threshold, trigger penetration, stop, and target distances. |
| `strategy_spike_atr_mult` | `2.0` | 1.0-5.0 | Minimum spike bar range as a multiple of prior ATR. |
| `strategy_spike_body_ratio` | `0.70` | 0.50-0.95 | Minimum body fraction of the spike bar range. |
| `strategy_channel_min_bars` | `4` | 2-10 | Minimum channel length after the spike. |
| `strategy_channel_max_bars` | `10` | 4-20 | Maximum channel length after the spike. |
| `strategy_channel_range_ratio` | `0.70` | 0.30-1.20 | Maximum channel close range relative to the spike range. |
| `strategy_breakout_window_bars` | `10` | 3-20 | Maximum bars after channel anchor to find the counter-trend breakout. |
| `strategy_breakout_atr_mult` | `0.30` | 0.05-1.00 | Counter-trend breakout distance beyond channel start in ATR units. |
| `strategy_trigger_window_bars` | `6` | 1-12 | Maximum bars after breakout to confirm failure. |
| `strategy_trigger_atr_mult` | `0.40` | 0.05-1.50 | Penetration back into the spike-and-channel zone in ATR units. |
| `strategy_take_profit_atr_mult` | `0.80` | 0.10-3.00 | Extension beyond the original channel extreme for the profit target. |
| `strategy_stop_atr_mult` | `0.30` | 0.05-2.00 | Stop buffer beyond the failed counter-breakout extreme. |
| `strategy_time_stop_bars` | `20` | 1-80 | Maximum H4 bars to hold the trade. |
| `strategy_max_spread_atr_mult` | `0.20` | 0.00-1.00 | Spread cap as a fraction of ATR; zero tester spread is allowed. |
| `strategy_scan_bars` | `80` | 40-200 | Bounded closed-bar scan window for the pattern state machine. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `GBPUSD.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `USDJPY.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `AUDUSD.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `USDCAD.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `USDCHF.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `NZDUSD.DWX` - liquid FX major with H4 trend and failed-breakout structure.
- `XAUUSD.DWX` - metal CFD with frequent H4 spike-and-channel behaviour.
- `XTIUSD.DWX` - crude oil CFD, adding energy exposure beyond the current certified book.
- `GDAXI.DWX` - DAX index CFD for non-US equity-index validation.
- `NDX.DWX` - US Nasdaq index CFD and live-routable large-cap proxy.
- `WS30.DWX` - US Dow index CFD and live-routable large-cap proxy.
- `UK100.DWX` - UK index CFD for non-US equity-index validation.
- `SP500.DWX` - S&P 500 custom symbol, backtest-only per R3 caveat.

**Explicitly NOT for:**
- `FRA40.DWX` - listed in the approved card but absent from `dwx_symbol_matrix.csv`.
- `JP225.DWX` - listed in the approved card but absent from `dwx_symbol_matrix.csv`.
- Symbols outside `dwx_symbol_matrix.csv` - build discipline forbids phantom custom symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | Several H4 bars, capped at 20 H4 bars |
| Expected drawdown profile | Moderate per-trade ATR stop with no averaging or martingale |
| Regime preference | Failed-breakout trend continuation after a spike-and-channel sequence |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum + book lineage`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9450_brooks-failed-spike-and-channel-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9450_brooks-failed-spike-and-channel-h4.md`

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
| v1 | 2026-07-01 | Initial build from card | 73595b46-590c-450b-96a1-782345833e28 |
