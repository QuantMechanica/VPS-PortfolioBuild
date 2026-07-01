# QM5_12845_trend-tracer-crude - Strategy Spec

**EA ID:** QM5_12845
**Slug:** `trend-tracer-crude`
**Source:** `balke-trend-tracer-swing-20260630`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency H4 WTI swing-structure breakout sleeve on
`XTIUSD.DWX`. It detects confirmed Williams-fractal swing highs and lows, then
requires higher-high/higher-low structure for long entries or lower-high/lower-low
structure for short entries. A trade opens only when the just-closed H4 bar
breaks beyond the latest confirmed swing in the trend direction and ADX is above
the trend threshold.

The card's open swing-detector decision is pinned to Williams-fractal swings for
v1. This avoids ZigZag repaint ambiguity in the build gate while leaving the
fractal wing length as the only structure sensitivity input.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_wing` | 3 | 2-12 | Bars on each side required to confirm a swing |
| `strategy_swing_scan_bars` | 160 | 40-500 | H4 bars scanned for the two latest highs and lows |
| `strategy_adx_period` | 14 | 9-20 | ADX period for the trend gate |
| `strategy_adx_min` | 22.0 | 18.0-28.0 | Minimum closed-bar ADX for entry |
| `strategy_atr_period` | 14 | 10-30 | ATR period for stop buffer |
| `strategy_stop_buffer_atr` | 0.25 | 0.0-0.75 | ATR buffer beyond the protecting swing |
| `strategy_rr_target` | 2.5 | 2.0-3.0 | Fixed reward:risk take-profit multiple |
| `strategy_max_hold_bars` | 60 | 30-90 | H4 bars before time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |
| `strategy_deviation_points` | 20 | 0-80 | Breakout buffer beyond the swing level |

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - Darwinex WTI CFD proxy; matches the card's crude trend-tracer
  hypothesis and supplies non-XNG energy exposure.

**Explicitly NOT for:**
- `XNGUSD.DWX` - already overrepresented in the survivor set and not the card's
  WTI swing-structure target.
- `XBRUSD.DWX` - Brent-specific variants have separate cards and registry IDs.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | several H4 bars to several weeks, capped at 60 H4 bars |
| Expected drawdown profile | medium single-commodity trend sleeve drawdown |
| Regime preference | trend / swing breakout |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `balke-trend-tracer-swing-20260630`  
**Source type:** video synthesis / structural trading method  
**Pointer:** `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md` and
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_12845_trend-tracer-crude.md`  
**R1-R4 verdict (Q00):** all PASS per the approved card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live manifest, `T_Live`, AutoTrading, or
portfolio-gate file is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from card | 7127ce8c-df3c-4e4d-ae3d-6a15ef064d94 |
