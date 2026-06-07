# QM5_11086_pinbar-rev - Strategy Spec

**EA ID:** QM5_11086
**Slug:** pinbar-rev
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `artifacts/cards_approved/QM5_11086_pinbar-rev.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades completed H4 pin bars using the EarnForex Pinbar Detector default geometry. A long entry is opened on the next bar after a bullish pinbar with a lower protruding nose, small body in the upper part of the candle, and an opposite-direction left eye. A short entry is opened after the matching bearish geometry with an upper protruding nose and the body in the lower part of the candle. The EA exits on an opposite pinbar signal, after 12 H4 bars, by the initial stop, or by framework-level forced exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | >= 1 | ATR period used for range filter and stop buffer. |
| `strategy_max_nose_body_size` | 0.33 | 0.0-1.0 | Maximum nose candle body as a fraction of full candle range. |
| `strategy_nose_body_position` | 0.40 | 0.0-1.0 | Required body-zone fraction for the nose candle. |
| `strategy_left_eye_opposite` | true | true/false | Require left eye candle direction opposite to pinbar direction. |
| `strategy_left_eye_min_body_size` | 0.10 | 0.0-1.0 | Minimum left eye body as a fraction of left eye range. |
| `strategy_nose_protruding` | 0.50 | >= 0.0 | Minimum nose protrusion beyond the left eye as a fraction of nose range. |
| `strategy_nose_body_to_left_eye` | 1.00 | >= 0.0 | Maximum nose body relative to left eye body. |
| `strategy_min_range_atr` | 0.40 | >= 0.0 | Minimum pinbar full range as ATR multiple. |
| `strategy_max_range_atr` | 3.00 | >= min | Maximum pinbar full range as ATR multiple. |
| `strategy_stop_atr_buffer` | 0.20 | >= 0.0 | ATR buffer beyond pinbar high or low for the initial stop. |
| `strategy_catastrophic_atr_mult` | 2.00 | > 0.0 | ATR fallback stop if broker stop constraints reject the pattern stop. |
| `strategy_time_stop_bars` | 12 | >= 1 | Maximum holding period in H4 bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary P2 basket includes this liquid major FX pair.
- `GBPUSD.DWX` - Card R3 primary P2 basket includes this liquid major FX pair.
- `USDJPY.DWX` - Card R3 primary P2 basket includes this liquid major FX pair.
- `XAUUSD.DWX` - Card R3 primary P2 basket includes this liquid gold CFD.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX test data is available for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | Geometry-filtered pin bars on H4 should be moderate cadence; conservative estimate 30 trades/year/symbol. |
| Typical hold time | Up to 12 H4 bars, approximately 48 hours, unless opposite signal or stop closes first. |
| Regime preference | Candlestick reversal after local extension. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 source
**Pointer:** EarnForex Pinbar Detector GitHub repository and source articles, as cited in `artifacts/cards_approved/QM5_11086_pinbar-rev.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11086_pinbar-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | 654edc08-1278-4189-8838-18ee356cb43f |
