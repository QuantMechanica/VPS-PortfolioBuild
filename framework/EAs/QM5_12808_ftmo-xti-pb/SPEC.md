# QM5_12808_ftmo-xti-pb - Strategy Spec

**EA ID:** QM5_12808
**Slug:** `ftmo-xti-pb`
**Source:** `FTMO-MAR2026-XTI-PORTFOLIO`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

This EA implements the FTMO March 2026 XTIUSD trend-pullback component as a
single-symbol H4 crude-oil sleeve. D1 EMA(50/200) defines the trend regime, and
the H4 trigger waits for a pullback into EMA(50) followed by a reclaim of
EMA(21) in the D1 trend direction. Positions exit by ATR hard stop, H4/D1 trend
invalidation, or max-hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_d1_fast_ema` | 50 | 34-89 | D1 fast EMA used for trend state |
| `strategy_d1_slow_ema` | 200 | 150-252 | D1 slow EMA used for trend state |
| `strategy_h4_trigger_ema` | 21 | 13-34 | H4 reclaim EMA after pullback |
| `strategy_h4_pullback_ema` | 50 | 34-89 | H4 pullback-zone EMA |
| `strategy_slope_lookback_d1` | 5 | 3-10 | D1 EMA slope lookback |
| `strategy_atr_period` | 20 | 14-30 | H4 ATR stop period |
| `strategy_atr_sl_mult` | 2.8 | 2.0-3.5 | ATR hard-stop multiplier |
| `strategy_max_hold_bars` | 36 | 24-48 | H4 bars before time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

---

## 3. Symbol Universe

- `XTIUSD.DWX` - registered energy sleeve target for the FTMO XTI trend-pullback source.

No other symbol is registered or traded by this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA trend filter |
| Bar gating | Framework `QM_IsNewBar()` on H4 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 16 |
| Cadence note | 8-24 WTI trend-pullback entries/year after filters |
| Typical hold time | 1-9 trading days |
| Expected drawdown profile | Medium-high crude-oil trend whipsaw risk |
| Regime preference | Sustained WTI trends with orderly H4 pullbacks |
| Win rate target | Medium |

---

## 6. Source Citation

Source ID: `FTMO-MAR2026-XTI-PORTFOLIO`

Pointer: `strategy-seeds/sources/FTMO-MAR2026-XTI-PORTFOLIO/source.md`

R1-R4 verdict: all PASS per
`strategy-seeds/cards/approved/QM5_12808_ftmo-xti-pb_card.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in | RISK_PERCENT | Allocated by portfolio process |
| Full live | RISK_PERCENT | Allocated by Q11/Q12 portfolio process |

ENV-to-mode validation is enforced by the V5 framework. This EA does not set
live risk or modify deploy artifacts.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial build from approved card | FTMO XTI trend-pullback |
