# QM5_1053_vegas-tunnel-ema144-169 - Strategy Spec

**EA ID:** QM5_1053
**Slug:** vegas-tunnel-ema144-169
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1053_vegas-tunnel-ema144-169.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades the Vegas Tunnel method on H1 bars. It defines the tunnel as the band between EMA(144) and EMA(169), then opens long when the last closed bar closes above the upper tunnel edge after the prior bar was not above it, and opens short on the mirrored downside breakout. The breakout must also be beyond the 0.382 level of the preceding 50-bar swing in the breakout direction. Exits are the broker TP at 1.618 times the current tunnel width from the breakout close or a strategy close when the last closed bar returns inside the tunnel.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 144 | 1+ | First EMA used for the Vegas tunnel. |
| `strategy_ema_slow_period` | 169 | 1+ | Second EMA used for the Vegas tunnel. |
| `strategy_swing_lookback` | 50 | 2+ | Closed bars used to find the swing high and swing low for the Fib filter. |
| `strategy_fib_retrace` | 0.382 | 0.0-1.0 | Minimum retracement threshold the breakout close must exceed. |
| `strategy_tp_tunnel_mult` | 1.618 | 0.0+ | Single P2 take-profit distance in multiples of tunnel width. |
| `strategy_sl_buffer_points` | 20 | 0+ | Points beyond the opposite tunnel edge for the initial stop. |
| `strategy_max_spread_points` | 20 | 0+ | Spread cap in points; zero disables the strategy spread cap. |
| `strategy_session_filter_enabled` | false | true/false | Enables the P3 session window; P2 stays 24/5. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-hour start when the optional session filter is enabled. |
| `strategy_session_end_hour` | 24 | 0-24 | Broker-hour end when the optional session filter is enabled. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named in the card's P2 basket.
- `GBPUSD.DWX` - FX major named in the card's P2 basket.
- `USDJPY.DWX` - FX major named in the card's P2 basket.
- `USDCHF.DWX` - FX major named in the card's P2 basket.

**Explicitly NOT for:**
- `GDAXI.DWX` - mentioned only as an optional future index port, not part of the R3 P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | Not specified in card frontmatter. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | Trend-following breakout. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/ Trading Systems forum search for "Vegas Tunnel"; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1053_vegas-tunnel-ema144-169.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1053_vegas-tunnel-ema144-169.md`

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
| v1 | 2026-06-13 | Initial build from card | afaee4f8-7cad-44a8-ab94-ec257d86013d |
