# QM5_1054_bigdog-tms-tdi-hma-h4 - Strategy Spec

**EA ID:** QM5_1054
**Slug:** `bigdog-tms-tdi-hma-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `sources/forexfactory-trading-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades the H4 Trading Made Simple confluence from the approved BigDog card. A long entry requires the TDI green RSI(13) line to cross above its 2-bar red signal line with both lines above 50, the H4 close to be above HMA(20), and the ASCTrend proxy to be bullish on the signal bar. A short entry mirrors those conditions below the midline and below HMA(20). Open positions close on the first reverse TDI cross or opposite ASCTrend color; initial protection uses the most recent 10-bar H4 structure extreme plus a 30-point buffer and an optional 2.0R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tdi_rsi_period` | 13 | 2-100 | RSI period for the TDI green line. |
| `strategy_tdi_signal_period` | 2 | 1-20 | SMA length over RSI values for the TDI red signal line. |
| `strategy_tdi_midline` | 50.0 | 0-100 | TDI midline filter for long/short direction. |
| `strategy_hma_period` | 20 | 4-200 | HMA period used as the H4 trend filter. |
| `strategy_asctrend_band_points` | 30 | 0-1000 | Point offset for the sequential close-vs-prior-close ASCTrend proxy. |
| `strategy_sl_lookback_bars` | 10 | 1-100 | H4 bars scanned by the framework structure-stop helper. |
| `strategy_sl_buffer_points` | 30 | 0-1000 | Extra point buffer beyond the structure stop. |
| `strategy_rr_target` | 2.0 | 0.1-10.0 | Fixed reward/risk take-profit multiple. |
| `strategy_spread_cap_points` | 25 | 0-500 | Maximum allowed spread in points before trading is blocked. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 names EURUSD as a primary TMS FX major.
- `GBPUSD.DWX` - card R3 names GBPUSD as a primary TMS FX major.
- `AUDUSD.DWX` - card R3 names AUDUSD as a primary TMS FX major.
- `EURJPY.DWX` - card R3 names EURJPY as a primary TMS FX cross.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - the approved card is scoped to BigDog TMS FX majors on H4.

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
| Trades / year / symbol | `500` |
| Typical hold time | H4 swing holds, usually hours to several days |
| Expected drawdown profile | Trend-following drawdowns during range-bound FX regimes |
| Regime preference | trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/291622`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1054_bigdog-tms-tdi-hma-h4.md`

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
| v1 | 2026-06-13 | Initial build from card | bd63c050-5430-4ae3-8095-71bfe472cc9e |
