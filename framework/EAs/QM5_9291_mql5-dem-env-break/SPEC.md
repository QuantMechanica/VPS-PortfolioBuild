# QM5_9291_mql5-dem-env-break — Strategy Spec

**EA ID:** QM5_9291
**Slug:** `mql5-dem-env-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On H4 bars, the EA enters long when the DeMarker oscillator is in overbought territory (>= 0.70) AND the last two closed bars both closed above the upper Envelope band — confirming a sustained breakout rather than a single-bar spike. The symmetric short entry fires when DeMarker <= 0.30 and both recent closes are below the lower Envelope band. An additional filter requires the current envelope width to exceed its 20-bar median, blocking entries during low-volatility sideways conditions. The initial stop is placed at the tighter of the distance to the envelope midline or 1.5 × ATR(14). The position exits when the last closed bar's close returns to the opposite side of the midline, or when DeMarker crosses back through 0.50, whichever comes first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dem_period` | 14 | 5–50 | DeMarker averaging period |
| `strategy_dem_ob_level` | 0.70 | 0.60–0.90 | Overbought threshold for long entry |
| `strategy_dem_os_level` | 0.30 | 0.10–0.40 | Oversold threshold for short entry |
| `strategy_dem_exit_level` | 0.50 | 0.40–0.60 | DeMarker level that triggers exit |
| `strategy_env_period` | 14 | 5–50 | Envelopes MA period |
| `strategy_env_deviation` | 0.100 | 0.050–0.500 | Envelope deviation in percent |
| `strategy_atr_period` | 14 | 7–28 | ATR period for stop distance |
| `strategy_atr_sl_mult` | 1.5 | 1.0–3.0 | ATR multiplier for stop distance |
| `strategy_width_lookback` | 20 | 10–50 | Bars for envelope-width median filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair with clean H4 structure; card's primary symbol
- `GBPUSD.DWX` — correlated major FX pair; same breakout dynamics apply
- `GDAXI.DWX` — DAX 40 German index CFD; card stated GER40.DWX which is the same instrument; ported to the canonical DWX name (see open_questions in build artifact)

**Explicitly NOT for:**
- `GER40.DWX` — not a valid DWX symbol; canonical equivalent is GDAXI.DWX above

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 |
| Typical hold time | 1–5 days (H4 bars, signal-based exit) |
| Expected drawdown profile | Moderate; tight envelope-midline stop limits per-trade risk |
| Regime preference | Breakout / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 63): Using Patterns of DeMarker and Envelope Channels", MQL5 Articles, 2025-05-07
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9291_mql5-dem-env-break.md`

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
| v1 | 2026-06-10 | Initial build from card | f83bf041-4df3-4bfb-b041-83303ab70c59 |
