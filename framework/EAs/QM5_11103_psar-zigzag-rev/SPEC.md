# QM5_11103_psar-zigzag-rev — Strategy Spec

**EA ID:** QM5_11103
**Slug:** `psar-zigzag-rev`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex ZigZagOnParabolic, GitHub)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA mechanises the EarnForex "ZigZag on Parabolic" indicator, which marks a
swing reversal whenever the Parabolic SAR flips sides relative to the bar
midpoint `(high+low)/2`. Evaluated only on the two most recently CLOSED H4 bars
(shift 2 = prior, shift 1 = detection bar):

- **Long (new trough):** SAR at shift 2 is at/above its midpoint AND SAR at
  shift 1 is below its midpoint (SAR flipped from above to below price). Enter a
  market BUY on the detection-bar close.
- **Short (new peak):** SAR at shift 2 is at/below its midpoint AND SAR at
  shift 1 is above its midpoint. Enter a market SELL on the detection-bar close.

A new swing must extend more than `min_swing_atr × ATR(14)` from the last
opposite swing extreme to fire (noise filter). The hard stop is
`sl_atr_mult × ATR(14)` from entry; there is no fixed take-profit. A position
exits on the next opposite detection (long closes on a fresh peak, short on a
fresh trough) or after a safety time stop of `time_stop_bars` H4 bars. SAR and
midpoints are read only on closed bars, so a fired detection never repaints. One
position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sar_step` | 0.02 | 0.005-0.1 | Parabolic SAR acceleration step (source default) |
| `strategy_sar_maximum` | 0.20 | 0.05-0.5 | Parabolic SAR acceleration maximum (source default) |
| `strategy_atr_period` | 14 | 5-50 | ATR period for swing filter and stop |
| `strategy_min_swing_atr` | 1.0 | 0.0-3.0 | Min swing move vs opposite swing, in ATR (0 disables) |
| `strategy_sl_atr_mult` | 2.5 | 1.0-5.0 | Hard stop distance = mult × ATR (card P2 baseline) |
| `strategy_time_stop_bars` | 16 | 0-100 | Safety time stop in H4 bars (0 disables) |
| `strategy_spread_pct_of_stop` | 15.0 | 1.0-100.0 | Skip entry if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean Parabolic-SAR swings on H4. Magic slot 0.
- `GBPUSD.DWX` — liquid major with comparable swing structure. Magic slot 1.
- `USDJPY.DWX` — liquid major; 3-digit pip scaling handled by ATR-based stops. Magic slot 2.
- `XAUUSD.DWX` — high-volatility metal; trend/reversal swings suit SAR detection. Magic slot 3.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, etc.) — card targets the FX/XAU basket; index
  microstructure differs and was not validated for this signal.

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
| Trades / year / symbol | `~36` |
| Typical hold time | `hours to a few days (≤16 H4 bars ≈ 2.7 days)` |
| Expected drawdown profile | `moderate; reversal entries against the prior leg` |
| Regime preference | `swing-reversal / mean-revert at SAR flips` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (open-source indicator repository)
**Pointer:** `https://github.com/EarnForex/ZigZagOnParabolic`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11103_psar-zigzag-rev.md`

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
