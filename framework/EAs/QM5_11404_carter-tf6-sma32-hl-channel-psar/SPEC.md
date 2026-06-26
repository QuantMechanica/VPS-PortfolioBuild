# QM5_11404_carter-tf6-sma32-hl-channel-psar - Strategy Spec

**EA ID:** QM5_11404
**Slug:** carter-tf6-sma32-hl-channel-psar
**Source:** 29c77a02-59bd-52f7-bcb3-b3108d5f1e79 (see `sources/thomas-carter-20-trend-following-systems-forex`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades Thomas Carter Strategy #6 on H1 bars. A long signal occurs when the last closed bar closes above the SMA32 applied to highs, above both SMA100 and SMA200, with a bullish candle body and PSAR below price. A short signal mirrors the rule below the SMA32 applied to lows, below SMA100 and SMA200, with a bearish candle body and PSAR above price. The stop is the recent 5-bar swing high or low capped at 50 pips for P2, the take-profit is 1.5 times ATR(14), and break-even management starts around 1 ATR in profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_channel_period` | 32 | 20-50 | SMA period applied separately to high and low series for the channel rails. |
| `strategy_sma_mid_period` | 100 | 50-150 | First close-price SMA trend filter. |
| `strategy_sma_slow_period` | 200 | 100-250 | Second close-price SMA trend filter. |
| `strategy_psar_step` | 0.02 | 0.01-0.02 | Parabolic SAR acceleration step. |
| `strategy_psar_max` | 0.2 | 0.1-0.3 | Parabolic SAR maximum acceleration. |
| `strategy_swing_bars` | 5 | 3-10 | Swing high or low lookback for the structural stop. |
| `strategy_atr_period` | 14 | 10-20 | ATR period for take-profit and break-even trigger distance. |
| `strategy_tp_atr_mult` | 1.5 | 1.0-2.0 | ATR multiple used for the take-profit distance. |
| `strategy_use_breakeven` | true | true/false | Enables break-even move at roughly 1 ATR in profit. |
| `strategy_spread_cap_pips` | 20 | 1-50 | Blocks entries only when modeled spread exceeds this pip cap. |
| `strategy_max_stop_pips` | 50 | 10-100 | P2 stop cap applied when the structural stop is farther away. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 forex major with DWX data available.
- GBPUSD.DWX - Card-listed H1 forex major with DWX data available.
- USDJPY.DWX - Card-listed H1 forex major with DWX data available.
- AUDUSD.DWX - Card-listed H1 forex major with DWX data available.
- USDCAD.DWX - Card-listed H1 forex major with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols - Build and backtest registrations require canonical `.DWX` symbols.
- Index and commodity symbols - The approved card specifies a forex H1 instrument basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | H1 trend-following holds; card does not specify a fixed hold time. |
| Expected drawdown profile | Trend-following breakout profile with structural stop, ATR target, and break-even management. |
| Regime preference | trend-following / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 29c77a02-59bd-52f7-bcb3-b3108d5f1e79
**Source type:** book
**Pointer:** Thomas Carter, 20 Trend Following Systems (2014), Strategy #6, local PDF path recorded in the approved card.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11404_carter-tf6-sma32-hl-channel-psar.md`

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
| v1 | 2026-06-26 | Initial build from card | 4bcfa23d-ec1a-480e-82a8-1546ca98277a |
