# QM5_11098_channel-break — Strategy Spec

**EA ID:** QM5_11098
**Slug:** `channel-break`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex Channel Pattern Detector)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

On the close of each H4 bar the EA fits a deterministic least-squares
linear-regression line to the closes of the prior `strategy_channel_lookback`
closed bars and builds a channel whose half-width is `strategy_dev_mult` times
the residual standard deviation of those closes about the line. The channel is
only considered valid when its half-width sits inside an ATR-scaled band
(`strategy_min_halfwidth_atr`..`strategy_max_halfwidth_atr` × ATR(14)), which
rejects both flat-noise and structureless windows. The EA goes long when the
last closed price breaks above the upper channel line by at least
`strategy_breakout_atr_mult × ATR` and that break is a fresh event (the prior
bar was not already above the previous channel projection); it goes short on the
symmetric break below the lower line. The stop is the opposite channel line
capped at `strategy_sl_atr_cap_mult × ATR` from entry; the take-profit is
`strategy_tp_rr` times the realised stop distance. A position is closed when
price closes back inside the channel, after `strategy_max_hold_bars` closed
bars, or on an opposite-side channel breakout. One position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_channel_lookback` | 60 | 20-150 | Prior closed bars in the regression-channel window |
| `strategy_dev_mult` | 2.0 | 1.0-3.0 | Channel half-width = mult × residual stddev of closes |
| `strategy_atr_period` | 14 | 5-30 | ATR period (breakout buffer / stop cap / validity scaling) |
| `strategy_breakout_atr_mult` | 0.10 | 0.0-1.0 | Breakout buffer beyond the channel line, in ATR |
| `strategy_min_halfwidth_atr` | 0.75 | 0.0-3.0 | Min channel half-width (× ATR) for a valid channel |
| `strategy_max_halfwidth_atr` | 6.0 | 2.0-15.0 | Max channel half-width (× ATR) for a valid channel |
| `strategy_sl_atr_cap_mult` | 2.5 | 1.0-5.0 | Stop capped at this × ATR from entry (card P2 cap) |
| `strategy_tp_rr` | 2.0 | 1.0-5.0 | Take-profit = RR multiple of realised stop distance |
| `strategy_max_hold_bars` | 12 | 4-60 | Time-stop: close after N closed bars (card: 12 H4 bars) |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Skip if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquid major; forms clean H4 trend channels.
- `GBPUSD.DWX` — liquid major with frequent directional channel breaks.
- `USDJPY.DWX` — liquid major; channel structure on H4 holds well.
- `XAUUSD.DWX` — high-volatility metal; pronounced channel breakouts, ATR-scaled
  validity gate keeps the channel meaningful.

**Explicitly NOT for:**
- Thin / illiquid symbols outside the DWX major-FX + gold set — channel residual
  geometry is noise-dominated and the ATR validity band would rarely arm.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~18` |
| Typical hold time | `hours to a few days (≤12 H4 bars)` |
| Expected drawdown profile | `breakout strategy — clustered small losses on false breaks, occasional larger trend-capture wins` |
| Regime preference | `breakout / volatility-expansion out of a channel` |
| Win rate target (qualitative) | `low-to-medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (open-source indicator repository / article)
**Pointer:** EarnForex "Channel Pattern Detector", https://github.com/EarnForex/Channel-Pattern-Detector
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11098_channel-break.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
